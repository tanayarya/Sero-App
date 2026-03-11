import Foundation
import PDFKit

// MARK: - Data Types

struct DocumentChunk: Identifiable {
    let id: UUID
    let text: String
    let pageNumber: Int
    let chunkIndex: Int
    var embedding: [Double] = []
}

// MARK: - RAG Engine

final class RAGEngine {
    static let shared = RAGEngine()
    private init() {}

    // Stored chunks per document (keyed by document ID)
    private var chunkStore: [UUID: [DocumentChunk]] = [:]

    // MARK: - Text Extraction

    func extractText(from url: URL) throws -> [(page: Int, text: String)] {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf":
            return try extractPDFText(url: url)
        case "md", "markdown":
            let raw = try String(contentsOf: url, encoding: .utf8)
            let clean = normalizeMarkdown(raw)
            return [(page: 1, text: clean)]
        default:
            let raw = try String(contentsOf: url, encoding: .utf8)
            return [(page: 1, text: normalize(raw))]
        }
    }

    private func extractPDFText(url: URL) throws -> [(page: Int, text: String)] {
        guard let doc = PDFDocument(url: url) else {
            throw NSError(domain: "RAG", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot open PDF"])
        }
        var pages: [(page: Int, text: String)] = []
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            let text = page.string ?? ""
            let cleaned = normalize(text)
            if !cleaned.isEmpty {
                pages.append((page: i + 1, text: cleaned))
            }
        }
        return pages
    }

    private func normalize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func normalizeMarkdown(_ text: String) -> String {
        var result = text
        // Remove code blocks
        result = result.replacingOccurrences(of: "```[\\s\\S]*?```", with: "", options: .regularExpression)
        // Remove headers
        result = result.replacingOccurrences(of: "#{1,6}\\s", with: "", options: .regularExpression)
        // Remove bold/italic
        result = result.replacingOccurrences(of: "\\*{1,3}([^*]+)\\*{1,3}", with: "$1", options: .regularExpression)
        // Remove links
        result = result.replacingOccurrences(of: "\\[([^\\]]+)\\]\\([^)]+\\)", with: "$1", options: .regularExpression)
        return normalize(result)
    }

    // MARK: - Chunking

    func createChunks(pages: [(page: Int, text: String)], targetTokens: Int = 400) -> [DocumentChunk] {
        var chunks: [DocumentChunk] = []
        var chunkIndex = 0
        let approxCharsPerToken = 4

        for (pageNum, pageText) in pages {
            let words = pageText.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            let maxWords = targetTokens * approxCharsPerToken / 5  // ~5 chars/word average
            var i = 0
            while i < words.count {
                let slice = words[i..<min(i + maxWords, words.count)]
                let chunkText = slice.joined(separator: " ")
                if chunkText.count > 50 {  // skip tiny fragments
                    chunks.append(DocumentChunk(
                        id: UUID(),
                        text: chunkText,
                        pageNumber: pageNum,
                        chunkIndex: chunkIndex
                    ))
                    chunkIndex += 1
                }
                // Overlap of 20% for context continuity
                let overlap = max(1, maxWords / 5)
                i += maxWords - overlap
            }
        }
        return chunks
    }

    // MARK: - Embedding & Storage

    func embedChunks(
        docID: UUID,
        chunks: inout [DocumentChunk],
        baseURL: String,
        model: String,
        progress: @escaping (Double) -> Void
    ) async throws {
        let total = chunks.count
        for (i, _) in chunks.enumerated() {
            chunks[i].embedding = try await OllamaService.shared.generateEmbedding(
                baseURL: baseURL,
                model: model,
                text: chunks[i].text
            )
            await MainActor.run { progress(Double(i + 1) / Double(total)) }
        }
        chunkStore[docID] = chunks
    }

    // MARK: - Retrieval

    func retrieveRelevantChunks(
        for query: String,
        docID: UUID,
        baseURL: String,
        model: String,
        topK: Int = 5
    ) async throws -> [DocumentChunk] {
        guard let chunks = chunkStore[docID], !chunks.isEmpty else { return [] }
        let queryEmbed = try await OllamaService.shared.generateEmbedding(
            baseURL: baseURL, model: model, text: query
        )
        let scored: [(chunk: DocumentChunk, score: Double)] = chunks.compactMap { chunk in
            guard !chunk.embedding.isEmpty else { return nil }
            let score = cosineSimilarity(queryEmbed, chunk.embedding)
            return (chunk, score)
        }
        return scored
            .sorted { $0.score > $1.score }
            .prefix(topK)
            .map { $0.chunk }
    }

    func clearDocument(_ docID: UUID) {
        chunkStore.removeValue(forKey: docID)
    }

    // MARK: - Cosine Similarity

    private func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot = 0.0, normA = 0.0, normB = 0.0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        let denom = sqrt(normA) * sqrt(normB)
        return denom == 0 ? 0 : dot / denom
    }

    // MARK: - System Prompt Builder

    func buildSystemPrompt(chunks: [DocumentChunk], documentName: String) -> String {
        let context = chunks.enumerated().map { i, chunk in
            "--- Source \(i + 1) (Page \(chunk.pageNumber)) ---\n\(chunk.text)"
        }.joined(separator: "\n\n")

        return """
        You are a helpful document assistant. The user is asking about the document "\(documentName)".

        Use ONLY the following document excerpts to answer the user's question. If the answer cannot be found in the excerpts, say so honestly.

        Format your response clearly with:
        - Bullet points for lists or multiple points
        - Short paragraphs for explanations
        - Clear section headings if covering multiple topics
        - Page references like (Page X) when citing specific content

        Document excerpts:
        \(context)
        """
    }
}
