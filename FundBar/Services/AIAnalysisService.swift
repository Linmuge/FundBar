import Foundation

struct AIAnalysisService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func analyze(baseURL: String, apiKey: String, model: String, systemPrompt: String, context: String, timeoutSeconds: TimeInterval) async throws -> String {
        guard let url = makeRequestURL(from: baseURL) else {
            throw AIAnalysisError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeoutSeconds
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ChatCompletionRequest(
            model: model,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: context)
            ],
            temperature: 0.3,
            stream: false
        )
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw AIAnalysisError.timedOut(seconds: Int(timeoutSeconds))
        } catch let error as URLError {
            throw AIAnalysisError.network(message: error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIAnalysisError.emptyResponse
        }

        let decoder = JSONDecoder()
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = (try? decoder.decode(ChatCompletionErrorResponse.self, from: data).error.message)
                ?? String(data: data, encoding: .utf8)
                ?? "请求失败"
            throw AIAnalysisError.requestFailed(statusCode: httpResponse.statusCode, message: message)
        }

        let result = try decoder.decode(ChatCompletionResponse.self, from: data)
        let content = result.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !content.isEmpty else {
            throw AIAnalysisError.emptyResponse
        }
        return content
    }

    private func makeRequestURL(from input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }
}

private struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
    let stream: Bool
}

private struct ChatMessage: Codable {
    let role: String
    let content: String
}

private struct ChatCompletionResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: ChatMessage
    }
}

private struct ChatCompletionErrorResponse: Decodable {
    let error: APIError

    struct APIError: Decodable {
        let message: String
    }
}

enum AIAnalysisError: LocalizedError {
    case invalidURL
    case emptyResponse
    case timedOut(seconds: Int)
    case network(message: String)
    case requestFailed(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "AI 接口 URL 无效"
        case .emptyResponse:
            return "AI 接口没有返回有效内容"
        case .timedOut(let seconds):
            return "AI 请求超过 \(seconds) 秒仍未响应。请确认填写的是完整接口 URL，或把超时时间调大。"
        case .network(let message):
            return "AI 网络请求失败：\(message)"
        case .requestFailed(let statusCode, let message):
            return "AI 请求失败（\(statusCode)）：\(message)"
        }
    }
}
