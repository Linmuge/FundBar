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
        let eastmoney = EastMoneyFundSource(session: session)

        self.sources = [
            .tiantian: tiantian,
            .eastmoney: eastmoney
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

// MARK: - 东方财富数据源

final class EastMoneyFundSource: FundDataSource {
    let name = "东方财富"
    private let session: URLSession

    init(session: URLSession) {
        self.session = session
    }

    func fetchEstimate(code: String) async throws -> Fund {
        // 用历史净值 API 获取最新已发布净值
        let urlString = "https://api.fund.eastmoney.com/f10/lsjz?fundCode=\(code)&pageIndex=1&pageSize=1&_=\(Int(Date().timeIntervalSince1970 * 1000))"
        guard let url = URL(string: urlString) else {
            throw FundError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("https://fund.eastmoney.com", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw FundError.serverError
        }

        let emResponse = try JSONDecoder().decode(EastMoneyResponse.self, from: data)

        guard let item = emResponse.Data?.LSJZList?.first else {
            throw FundError.decodingError
        }

        let nav = item.DWJZ ?? "0"
        let changeRate = item.JZZZL ?? "0"
        let navDate = item.FSRQ ?? ""

        return Fund(
            fundcode: code,
            name: emResponse.Data?.FundType ?? code,
            dwjz: nav,
            gsz: nav,       // 历史净值源无估算值，用实际净值
            gszzl: changeRate,
            gztime: navDate,
            jzrq: navDate
        )
    }
}

/// 东方财富 API 响应模型
private struct EastMoneyResponse: Codable {
    let Data: EastMoneyData?
    let ErrCode: Int?
}

private struct EastMoneyData: Codable {
    let LSJZList: [EastMoneyNavItem]?
    let FundType: String?
}

private struct EastMoneyNavItem: Codable {
    let FSRQ: String?   // 净值日期
    let DWJZ: String?   // 单位净值
    let LJJZ: String?   // 累计净值
    let JZZZL: String?  // 净值增长率
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

