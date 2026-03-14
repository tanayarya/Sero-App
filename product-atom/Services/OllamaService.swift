import Foundation

// MARK: - Ollama API Models

struct OllamaModel: Identifiable, Decodable, Hashable {
    let name: String
    var id: String { name }
}

struct OllamaModelsResponse: Decodable {
    let models: [OllamaModel]
}

struct OllamaEmbedRequest: Encodable {
    let model: String
    let prompt: String
}

struct OllamaEmbedResponse: Decodable {
    let embedding: [Float]
}

struct OllamaChatMessage: Codable {
    let role: String
    let content: String
}

struct OllamaChatRequest: Encodable {
    let model: String
    let messages: [OllamaChatMessage]
    let stream: Bool
}

struct OllamaChatChunk: Decodable {
    let message: OllamaChatMessage?
    let done: Bool
}

// MARK: - Service

final class OllamaService {
    static let shared = OllamaService()
    private init() {}

    private func normalizeURL(_ base: String) -> String {
        var u = base.trimmingCharacters(in: .whitespaces)
        if !u.hasPrefix("http://") && !u.hasPrefix("https://") {
            u = "http://" + u
        }
        return u
    }

    func fetchModels(baseURL: String) async throws -> [OllamaModel] {
        let base = normalizeURL(baseURL)
        guard let url = URL(string: "\(base)/api/tags") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.timeoutInterval = 8
        let (data, _) = try await URLSession.shared.data(for: req)
        let resp = try JSONDecoder().decode(OllamaModelsResponse.self, from: data)
        return resp.models
    }

    func generateEmbedding(baseURL: String, model: String, text: String) async throws -> [Float] {
        let base = normalizeURL(baseURL)
        guard let url = URL(string: "\(base)/api/embeddings") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 60
        let body = OllamaEmbedRequest(model: model, prompt: text)
        req.httpBody = try JSONEncoder().encode(body)
        let (data, _) = try await URLSession.shared.data(for: req)
        let resp = try JSONDecoder().decode(OllamaEmbedResponse.self, from: data)
        return resp.embedding
    }

    func streamChat(
        baseURL: String,
        model: String,
        systemPrompt: String,
        userMessage: String,
        onToken: @escaping (String) -> Void
    ) async throws {
        let base = normalizeURL(baseURL)
        guard let url = URL(string: "\(base)/api/chat") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 120
        let chatMessages: [OllamaChatMessage] = [
            OllamaChatMessage(role: "system", content: systemPrompt),
            OllamaChatMessage(role: "user", content: userMessage)
        ]
        let chatBody = OllamaChatRequest(model: model, messages: chatMessages, stream: true)
        req.httpBody = try JSONEncoder().encode(chatBody)

        let session = URLSession(configuration: .default)
        defer { session.invalidateAndCancel() }
        let (asyncBytes, _) = try await session.bytes(for: req)
        for try await line in asyncBytes.lines {
            // Check for cooperative cancellation on every line
            try Task.checkCancellation()
            guard !line.isEmpty, let data = line.data(using: .utf8) else { continue }
            guard let chunk = try? JSONDecoder().decode(OllamaChatChunk.self, from: data) else { continue }
            if let token = chunk.message?.content, !token.isEmpty {
                await MainActor.run { onToken(token) }
            }
            if chunk.done { break }
        }
    }

    func testConnection(baseURL: String) async -> Bool {
        let base = normalizeURL(baseURL)
        guard let url = URL(string: base) else { return false }
        var req = URLRequest(url: url)
        req.timeoutInterval = 5
        guard let (_, resp) = try? await URLSession.shared.data(for: req) else { return false }
        return (resp as? HTTPURLResponse)?.statusCode == 200
    }
}
