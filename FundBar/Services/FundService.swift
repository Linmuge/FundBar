import Foundation

/// 基金数据服务 - 负责从天天基金 API 获取估值数据
final class FundService {

    static let shared = FundService()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        self.session = URLSession(configuration: config)
    }

    /// 获取单只基金的实时估值
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

        return try parseJSONP(responseString)
    }

    /// 批量获取多只基金的实时估值
    func fetchMultipleEstimates(codes: [String]) async -> [Fund] {
        await withTaskGroup(of: Fund?.self, returning: [Fund].self) { group in
            for code in codes {
                group.addTask {
                    try? await self.fetchEstimate(code: code)
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

    /// 解析 JSONP 响应: jsonpgz({...}) -> Fund
    private func parseJSONP(_ jsonpString: String) throws -> Fund {
        let pattern = "jsonpgz\\((.+)\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: jsonpString,
                range: NSRange(jsonpString.startIndex..., in: jsonpString)
              ),
              let jsonRange = Range(match.range(at: 1), in: jsonpString) else {
            throw FundError.decodingError
        }

        let jsonString = String(jsonpString[jsonRange])
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw FundError.decodingError
        }

        do {
            return try JSONDecoder().decode(Fund.self, from: jsonData)
        } catch {
            throw FundError.decodingError
        }
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
