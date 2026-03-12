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

    private var chunkStore: [UUID: [DocumentChunk]] = [:]

    // MARK: - Text Extraction

    func extractText(from url: URL) throws -> [(page: Int, text: String)] {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf":  return try extractPDFText(url: url)
        case "md", "markdown":
            let raw = try String(contentsOf: url, encoding: .utf8)
            return splitIntoPageChunks(normalizeMarkdown(raw), charsPerPage: 3000)
        default:
            let raw = try String(contentsOf: url, encoding: .utf8)
            return splitIntoPageChunks(normalize(raw), charsPerPage: 3000)
        }
    }

    private func splitIntoPageChunks(_ text: String, charsPerPage: Int) -> [(page: Int, text: String)] {
        var result: [(page: Int, text: String)] = []
        let words = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        var page = 1
        var current: [String] = []
        var charCount = 0
        for word in words {
            current.append(word)
            charCount += word.count + 1
            if charCount >= charsPerPage {
                result.append((page: page, text: current.joined(separator: " ")))
                page += 1
                current = []
                charCount = 0
            }
        }
        if !current.isEmpty {
            result.append((page: page, text: current.joined(separator: " ")))
        }
        return result.isEmpty ? [(page: 1, text: text)] : result
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
        result = result.replacingOccurrences(of: "```[\\s\\S]*?```", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "`[^`]+`", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "#{1,6}\\s+", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\*{1,3}([^*]+)\\*{1,3}", with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\[([^\\]]+)\\]\\([^)]+\\)", with: "$1", options: .regularExpression)
        // Remove list prefixes and blockquotes line by line
        result = result.components(separatedBy: "\n").map { line -> String in
            var l = line
            if let r = l.range(of: "^[-*+]\\s+", options: .regularExpression) { l.removeSubrange(r) }
            if let r = l.range(of: "^>\\s*", options: .regularExpression) { l.removeSubrange(r) }
            return l
        }.joined(separator: "\n")
        return normalize(result)
    }

    // MARK: - Chunking (improved: sentence-aware, overlapping)

    func createChunks(pages: [(page: Int, text: String)], targetTokens: Int = 512) -> [DocumentChunk] {
        var chunks: [DocumentChunk] = []
        var chunkIndex = 0
        // ~4 chars per token, ~5 chars per word → ~0.8 words per token
        let maxWords = targetTokens * 4 / 5

        for (pageNum, pageText) in pages {
            let words = pageText.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard !words.isEmpty else { continue }

            let overlap = maxWords / 4  // 25% overlap for better context
            var i = 0
            while i < words.count {
                let end = min(i + maxWords, words.count)
                let slice = words[i..<end]
                let chunkText = slice.joined(separator: " ")
                if chunkText.count > 80 {
                    chunks.append(DocumentChunk(
                        id: UUID(),
                        text: chunkText,
                        pageNumber: pageNum,
                        chunkIndex: chunkIndex
                    ))
                    chunkIndex += 1
                }
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
        // Batch embed with concurrency limit
        for i in 0..<total {
            chunks[i].embedding = try await OllamaService.shared.generateEmbedding(
                baseURL: baseURL,
                model: model,
                text: chunks[i].text
            )
            let p = Double(i + 1) / Double(total)
            await MainActor.run { progress(p) }
        }
        chunkStore[docID] = chunks
    }

    func storeChunksWithoutEmbeddings(docID: UUID, chunks: [DocumentChunk]) {
        chunkStore[docID] = chunks
    }

    // MARK: - Retrieval (semantic)

    func retrieveRelevantChunks(
        for query: String,
        docID: UUID,
        baseURL: String,
        model: String,
        topK: Int = 8
    ) async throws -> [DocumentChunk] {
        guard let chunks = chunkStore[docID], !chunks.isEmpty else { return [] }

        let queryEmbed = try await OllamaService.shared.generateEmbedding(
            baseURL: baseURL, model: model, text: query
        )

        // Use only embedded chunks for semantic search
        let embeddedChunks = chunks.filter { !$0.embedding.isEmpty }
        guard !embeddedChunks.isEmpty else { return keywordRetrieve(for: query, docID: docID, topK: topK) }

        let scored: [(chunk: DocumentChunk, score: Double)] = embeddedChunks.map { chunk in
            (chunk, cosineSimilarity(queryEmbed, chunk.embedding))
        }

        let sorted = scored.sorted { $0.score > $1.score }
        let topChunks = sorted.prefix(topK).map { $0.chunk }

        // Re-order by page for coherent context
        return topChunks.sorted { $0.pageNumber < $1.pageNumber }
    }

    // MARK: - Keyword Fallback Retrieval

    func keywordRetrieve(for query: String, docID: UUID, topK: Int = 8) -> [DocumentChunk] {
        guard let chunks = chunkStore[docID] else { return [] }
        let keywords = query.lowercased().components(separatedBy: .whitespaces)
            .filter { $0.count > 3 }
        guard !keywords.isEmpty else { return Array(chunks.prefix(topK)) }

        let scored: [(chunk: DocumentChunk, score: Int)] = chunks.map { chunk in
            let lower = chunk.text.lowercased()
            let score = keywords.reduce(0) { acc, kw in
                acc + (lower.contains(kw) ? 1 : 0)
            }
            return (chunk, score)
        }
        return scored.sorted { $0.score > $1.score }.prefix(topK).map { $0.chunk }
    }

    func clearDocument(_ docID: UUID) {
        chunkStore.removeValue(forKey: docID)
    }

    // MARK: - Cosine Similarity

    private func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot = 0.0, normA = 0.0, normB = 0.0
        for i in 0..<a.count {
            dot  += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        let denom = sqrt(normA) * sqrt(normB)
        return denom == 0 ? 0 : dot / denom
    }

    // MARK: - System Prompt Builder (improved formatting instructions)

    func buildSystemPrompt(chunks: [DocumentChunk], documentName: String) -> String {
        let context = chunks.enumerated().map { i, chunk in
            "[Source \(i + 1) — Page \(chunk.pageNumber)]\n\(chunk.text)"
        }.joined(separator: "\n\n")

        return """
        You are an expert document assistant analyzing "\(documentName)".

        INSTRUCTIONS:
        1. Answer ONLY using the provided document excerpts below.
        2. If the answer is not in the excerpts, say: "I couldn't find that information in the document."
        3. Format ALL responses using Markdown:
           - Use **bold** for key terms and important points
           - Use bullet lists (- item) for multiple points
           - Use numbered lists for steps or sequences
           - Use ### headings to separate major sections if needed
           - Keep paragraphs short and scannable
        4. Always cite sources as (Page X) inline when referencing specific content.
        5. Be concise and precise. Avoid filler phrases.

        DOCUMENT EXCERPTS:
        \(context.isEmpty ? "No relevant sections found." : context)
        """
    }
}
