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
    let embedding: [Double]
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

    func fetchModels(baseURL: String) async throws -> [OllamaModel] {
        guard let url = URL(string: "\(baseURL)/api/tags") else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        let resp = try JSONDecoder().decode(OllamaModelsResponse.self, from: data)
        return resp.models
    }

    func generateEmbedding(baseURL: String, model: String, text: String) async throws -> [Double] {
        guard let url = URL(string: "\(baseURL)/api/embeddings") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
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
        guard let url = URL(string: "\(baseURL)/api/chat") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let messages: [OllamaChatMessage] = [
            OllamaChatMessage(role: "system", content: systemPrompt),
            OllamaChatMessage(role: "user", content: userMessage)
        ]
        let body = OllamaChatRequest(model: model, messages: messages, stream: true)
        req.httpBody = try JSONEncoder().encode(body)

        let (asyncBytes, _) = try await URLSession.shared.bytes(for: req)
        for try await line in asyncBytes.lines {
            guard !line.isEmpty, let data = line.data(using: .utf8) else { continue }
            guard let chunk = try? JSONDecoder().decode(OllamaChatChunk.self, from: data) else { continue }
            if let token = chunk.message?.content, !token.isEmpty {
                await MainActor.run { onToken(token) }
            }
            if chunk.done { break }
        }
    }

    func testConnection(baseURL: String) async -> Bool {
        guard let url = URL(string: baseURL) else { return false }
        var req = URLRequest(url: url)
        req.timeoutInterval = 5
        guard let (_, resp) = try? await URLSession.shared.data(for: req) else { return false }
        return (resp as? HTTPURLResponse)?.statusCode == 200
    }
}
