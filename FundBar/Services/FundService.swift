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
    private var currentSource: FundDataSource

    /// 所有可用数据源
    private let sources: [DataSource: FundDataSource]

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        let session = URLSession(configuration: config)
        self.session = session

        let tiantian = TiantianFundSource(session: session)

        self.sources = [
            .tiantian: tiantian
        ]
        self.currentSource = tiantian
    }

    /// 切换数据源
    func switchSource(to source: DataSource) {
        if let newSource = sources[source] {
            currentSource = newSource
        }
    }

    /// 获取单只基金的实时估值
    func fetchEstimate(code: String) async throws -> Fund {
        try await currentSource.fetchEstimate(code: code)
    }

    /// 批量获取多只基金的实时估值
    func fetchMultipleEstimates(codes: [String]) async -> [Fund] {
        await withTaskGroup(of: Fund?.self, returning: [Fund].self) { group in
            for code in codes {
                group.addTask {
                    try? await self.currentSource.fetchEstimate(code: code)
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

