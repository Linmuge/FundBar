import Foundation

/// 基金数据源协议
protocol FundDataSource {
    var name: String { get }
    func fetchEstimate(code: String) async throws -> Fund
}

/// 基金数据服务 - 管理数据源和请求
final class FundService {

    static let shared = FundService()

    private let session: URLSession

    /// 主数据源（当前使用东方财富移动端接口）
    private let primarySource: FundDataSource

    /// 历史注册表，供 switchSource(to:) 按 DataSource 枚举切换（保留外部 API 兼容）
    private let sourcesByEnum: [DataSource: FundDataSource]

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        let session = URLSession(configuration: config)
        self.session = session

        let eastmoneyMobile = EastMoneyMobileSource(session: session)
        self.primarySource = eastmoneyMobile
        self.sourcesByEnum = [:]
    }

    /// 切换数据源（保留外部 API 兼容；内部默认走 primarySource + fallback 链）
    func switchSource(to source: DataSource) {
        // 当前架构以 primarySource + fallbackSources 自动降级为主，此处保留空实现以兼容现有调用
        _ = source
    }

    /// 获取单只基金的实时估值
    func fetchEstimate(code: String) async throws -> Fund {
        try await primarySource.fetchEstimate(code: code)
    }

    /// 批量获取多只基金的实时估值
    func fetchMultipleEstimates(codes: [String]) async -> [Fund] {
        await withTaskGroup(of: Fund?.self, returning: [Fund].self) { group in
            for code in codes {
                group.addTask {
                    try? await self.primarySource.fetchEstimate(code: code)
                }
            }

            var results: [Fund] = []
            for await fund in group {
                if let fund = fund {
                    results.append(fund)
                }
            }

            // 按传入的代码顺序排序
            return codes.compactMap { code in
                results.first { $0.fundcode == code }
            }
        }
    }

    /// 搜索基金
    func searchFunds(keyword: String) async -> [FundSearchResult] {
        let encoded = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword
        let urlString = "https://fundsearchapi.eastmoney.com/FundSearchApi/FundSearchAS498.ashx?m=1&key=\(encoded)&_=\(Int(Date().timeIntervalSince1970 * 1000))"
        guard let url = URL(string: urlString) else { return [] }

        do {
            var request = URLRequest(url: url)
            request.setValue("https://fund.eastmoney.com", forHTTPHeaderField: "Referer")
            let (data, _) = try await session.data(for: request)

            guard let str = String(data: data, encoding: .utf8) else { return [] }

            // 解析 JSONP: jQuery...({"Datas":[...],...})
            let pattern = "\\((.+)\\)"
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: str, range: NSRange(str.startIndex..., in: str)),
                  let jsonRange = Range(match.range(at: 1), in: str),
                  let jsonData = String(str[jsonRange]).data(using: .utf8) else { return [] }

            let response = try JSONDecoder().decode(FundSearchResponse.self, from: jsonData)
            return response.datas?.compactMap { item in
                guard let code = item.code, let name = item.name else { return nil }
                return FundSearchResult(code: code, name: name, type: item.fundBaseInfo?.ftype ?? "")
            } ?? []
        } catch {
            return []
        }
    }

    /// 获取7日历史净值
    func fetchHistory(code: String, days: Int = 7) async -> [HistoryNav] {
        let urlString = "https://api.fund.eastmoney.com/f10/lsjz?fundCode=\(code)&pageIndex=1&pageSize=\(days)&_=\(Int(Date().timeIntervalSince1970 * 1000))"
        guard let url = URL(string: urlString) else { return [] }

        do {
            var request = URLRequest(url: url)
            request.setValue("https://fund.eastmoney.com", forHTTPHeaderField: "Referer")
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")
            let (data, _) = try await session.data(for: request)

            let emResponse = try JSONDecoder().decode(EastMoneyResponse.self, from: data)
            return emResponse.data?.lsjzList?.compactMap { item in
                guard let dateStr = item.fsrq, let navStr = item.dwjz, let nav = Double(navStr) else { return nil }
                return HistoryNav(date: dateStr, nav: nav)
            } ?? []
        } catch {
            return []
        }
    }
}

/// 搜索结果
struct FundSearchResult: Identifiable {
    let code: String
    let name: String
    let type: String
    var id: String { code }
}

/// 历史净值
struct HistoryNav: Identifiable {
    let date: String
    let nav: Double
    var id: String { date }
}

// MARK: - 搜索 API 响应模型

struct FundSearchResponse: Codable {
    let datas: [FundSearchItem]?

    enum CodingKeys: String, CodingKey {
        case datas = "Datas"
    }
}

struct FundSearchItem: Codable {
    let code: String?
    let name: String?
    let fundBaseInfo: FundSearchBaseInfo?

    enum CodingKeys: String, CodingKey {
        case code = "CODE"
        case name = "NAME"
        case fundBaseInfo = "FundBaseInfo"
    }
}

struct FundSearchBaseInfo: Codable {
    let ftype: String?

    enum CodingKeys: String, CodingKey {
        case ftype = "FTYPE"
    }
}

// MARK: - 天天基金数据源

final class TiantianFundSource: FundDataSource {
    let name = "天天基金"
    private let session: URLSession

    init(session: URLSession) {
        self.session = session
    }

    func fetchEstimate(code: String) async throws -> Fund {
        let urlString = "https://fundgz.1234567.com.cn/js/\(code).js?rt=\(Date().timeIntervalSince1970)"
        guard let url = URL(string: urlString) else {
            throw FundError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw FundError.serverError
        }

        guard let responseString = String(data: data, encoding: .utf8) else {
            throw FundError.decodingError
        }

        // 解析 JSONP: jsonpgz({...})
        let pattern = "jsonpgz\\((.+)\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: responseString,
                range: NSRange(responseString.startIndex..., in: responseString)
              ),
              let jsonRange = Range(match.range(at: 1), in: responseString) else {
            throw FundError.decodingError
        }

        let jsonString = String(responseString[jsonRange])
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw FundError.decodingError
        }

        return try JSONDecoder().decode(Fund.self, from: jsonData)
    }
}

/// 东方财富移动端数据源（主源）—— 使用 fundmobapi FundMNFInfo 接口
/// 替代已废弃的 fundgz.1234567.com.cn
final class EastMoneyMobileSource: FundDataSource {
    let name = "东方财富(移动)"
    private let session: URLSession

    init(session: URLSession) {
        self.session = session
    }

    func fetchEstimate(code: String) async throws -> Fund {
        let urlString = "https://fundmobapi.eastmoney.com/FundMNewApi/FundMNFInfo?pageIndex=1&pageSize=1&plat=Android&appType=ttjj&product=EFund&Version=1&deviceid=1&Fcodes=\(code)"
        guard let url = URL(string: urlString) else {
            throw FundError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")
        request.setValue("https://mpservice.com/", forHTTPHeaderField: "Referer")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw FundError.serverError
        }

        let mnfResponse = try JSONDecoder().decode(FundMNFInfoResponse.self, from: data)
        guard let item = mnfResponse.datas?.first(where: { $0.fcode == code }) ?? mnfResponse.datas?.first else {
            throw FundError.decodingError
        }

        return Fund(fromMNFInfo: item, expansion: mnfResponse.expansion)
    }
}

/// 东方财富 API 响应模型
struct EastMoneyResponse: Codable {
    let data: EastMoneyData?
    let errCode: Int?

    enum CodingKeys: String, CodingKey {
        case data = "Data"
        case errCode = "ErrCode"
    }
}

struct EastMoneyData: Codable {
    let lsjzList: [EastMoneyNavItem]?
    let fundType: String?

    enum CodingKeys: String, CodingKey {
        case lsjzList = "LSJZList"
        case fundType = "FundType"
    }
}

struct EastMoneyNavItem: Codable {
    let fsrq: String?   // 净值日期
    let dwjz: String?   // 单位净值
    let ljjz: String?   // 累计净值
    let jzzzl: String?  // 净值增长率

    enum CodingKeys: String, CodingKey {
        case fsrq = "FSRQ"
        case dwjz = "DWJZ"
        case ljjz = "LJJZ"
        case jzzzl = "JZZZL"
    }
}

/// 东方财富移动端 FundMNFInfo 接口响应模型（替代已废弃的 fundgz.1234567.com.cn）
struct FundMNFInfoResponse: Codable {
    let datas: [FundMNFInfoItem]?
    let errCode: Int?
    /// Expansion 字段包含"当前估值日期"(GZTIME)和"净值日期"(FSRQ)，
    /// 即使盘中 GSZ/GSZZL 为 null，Expansion.GZTIME 仍是今天，可用于判断 isNavUpdatedToday
    let expansion: FundMNFInfoExpansion?

    enum CodingKeys: String, CodingKey {
        case datas = "Datas"
        case errCode = "ErrCode"
        case expansion = "Expansion"
    }
}

/// FundMNFInfo 的 Expansion 字段
struct FundMNFInfoExpansion: Codable {
    let gztime: String?   // GZTIME 当前估值日期（今天，无论是否交易时段）
    let fsrq: String?     // FSRQ   净值日期（最近一个交易日）

    enum CodingKeys: String, CodingKey {
        case gztime = "GZTIME"
        case fsrq = "FSRQ"
    }
}

struct FundMNFInfoItem: Codable {
    let fcode: String?        // FCODE     基金代码
    let shortname: String?    // SHORTNAME 基金简称
    let nav: String?          // NAV       单位净值
    let navchgrt: String?     // NAVCHGRT  净值涨跌幅 (盘外仍有值)
    let gsz: String?          // GSZ       估算净值 (盘外可能为 null)
    let gszzl: String?        // GSZZL     估算涨跌幅 (盘外可能为 null)
    let gztime: String?       // GZTIME    估算时间 yyyy-MM-dd (Datas 内，盘外常为 null)
    let pdate: String?        // PDATE     净值日期 yyyy-MM-dd

    enum CodingKeys: String, CodingKey {
        case fcode = "FCODE"
        case shortname = "SHORTNAME"
        case nav = "NAV"
        case navchgrt = "NAVCHGRT"
        case gsz = "GSZ"
        case gszzl = "GSZZL"
        case gztime = "GZTIME"
        case pdate = "PDATE"
    }
}

/// 基金服务错误类型
enum FundError: LocalizedError {
    case invalidURL
    case serverError
    case decodingError
    case networkUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的请求地址"
        case .serverError:
            return "服务器响应异常"
        case .decodingError:
            return "数据解析失败"
        case .networkUnavailable:
            return "网络连接不可用"
        }
    }
}
