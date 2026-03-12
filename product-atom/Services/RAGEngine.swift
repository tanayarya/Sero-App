import Foundation
import PDFKit

// MARK: - Data Types

struct DocumentChunk: Identifiable {
    let id: UUID
    let text: String
    let pageNumber: Int
    let chunkIndex: Int
    var embedding: [Float] = []
}

// MARK: - RAG Engine

final class RAGEngine {
    static let shared = RAGEngine()
    private init() {}

    private var chunkStore: [UUID: [DocumentChunk]] = [:]

    // MARK: - Text Extraction
    // alreadyScoped = true means the caller already started security-scoped access.

    func extractText(from url: URL, alreadyScoped: Bool = false) throws -> [(page: Int, text: String)] {
        // AppState always manages scope — we never call startAccessingSecurityScopedResource here.
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf":
            return try extractPDFText(url: url)
        case "md", "markdown":
            let raw = try String(contentsOf: url, encoding: .utf8)
            return extractMarkdownPages(raw)
        default:
            if let utf8 = try? String(contentsOf: url, encoding: .utf8) {
                return extractTextPages(utf8)
            }
            let latin = try String(contentsOf: url, encoding: .isoLatin1)
            return extractTextPages(latin)
        }
    }

    private func extractPDFText(url: URL) throws -> [(page: Int, text: String)] {
        guard let doc = PDFDocument(url: url) else {
            throw NSError(domain: "RAG", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Cannot open PDF — check file permissions"])
        }
        var pages: [(page: Int, text: String)] = []
        var pendingText = ""
        var pendingStart = 1

        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            let raw = page.string ?? ""
            let cleaned = cleanText(raw)
            guard !cleaned.isEmpty else { continue }

            if pendingText.isEmpty {
                pendingText = cleaned
                pendingStart = i + 1
            } else if cleaned.count < 400 {
                pendingText += " " + cleaned
            } else {
                pages.append((page: pendingStart, text: pendingText))
                pendingText = cleaned
                pendingStart = i + 1
            }
        }
        if !pendingText.isEmpty {
            pages.append((page: pendingStart, text: pendingText))
        }
        return pages.isEmpty ? [(page: 1, text: "No readable text found.")] : pages
    }

    private func extractTextPages(_ text: String) -> [(page: Int, text: String)] {
        let paras = text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 20 }
        var pages: [(page: Int, text: String)] = []
        var current = ""; var pageNum = 1
        for para in paras {
            if current.count + para.count > 3000 && !current.isEmpty {
                pages.append((page: pageNum, text: current))
                pageNum += 1; current = para
            } else {
                current += current.isEmpty ? para : "\n\n" + para
            }
        }
        if !current.isEmpty { pages.append((page: pageNum, text: current)) }
        return pages.isEmpty ? [(page: 1, text: text)] : pages
    }

    private func extractMarkdownPages(_ text: String) -> [(page: Int, text: String)] {
        let sections = text.components(separatedBy: "\n## ")
        if sections.count > 1 {
            return sections.enumerated().map { i, s in
                (page: i + 1, text: cleanText(i == 0 ? s : "## " + s))
            }.filter { !$0.text.isEmpty }
        }
        return extractTextPages(cleanText(text))
    }

    private func cleanText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Chunking (~2400 chars, ~400 overlap, sentence-aware)

    func createChunks(pages: [(page: Int, text: String)]) -> [DocumentChunk] {
        let targetChars = 2400
        let overlapChars = 400
        var chunks: [DocumentChunk] = []
        var chunkIndex = 0

        for (pageNum, pageText) in pages {
            guard !pageText.isEmpty else { continue }
            let sentences = splitIntoSentences(pageText)
            guard !sentences.isEmpty else { continue }

            var current = ""
            var sentenceBuffer: [String] = []

            for sentence in sentences {
                let candidate = current + (current.isEmpty ? "" : " ") + sentence
                if candidate.count > targetChars && !current.isEmpty {
                    if current.count > 100 {
                        chunks.append(DocumentChunk(
                            id: UUID(), text: current,
                            pageNumber: pageNum, chunkIndex: chunkIndex
                        ))
                        chunkIndex += 1
                    }
                    // Build overlap from tail of sentence buffer
                    var overlapText = ""
                    for s in sentenceBuffer.reversed() {
                        let attempt = s + " " + overlapText
                        if attempt.count <= overlapChars {
                            overlapText = attempt.trimmingCharacters(in: .whitespaces)
                        } else { break }
                    }
                    current = overlapText.isEmpty ? sentence : overlapText + " " + sentence
                    sentenceBuffer = []
                } else {
                    current = candidate
                    sentenceBuffer.append(sentence)
                }
            }
            if current.count > 100 {
                chunks.append(DocumentChunk(
                    id: UUID(), text: current,
                    pageNumber: pageNum, chunkIndex: chunkIndex
                ))
                chunkIndex += 1
            }
        }
        return chunks
    }

    private func splitIntoSentences(_ text: String) -> [String] {
        var sentences: [String] = []
        var current = ""
        for char in text {
            current.append(char)
            if (char == "." || char == "!" || char == "?") && current.count > 40 {
                sentences.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            }
        }
        if !current.trimmingCharacters(in: .whitespaces).isEmpty {
            sentences.append(current.trimmingCharacters(in: .whitespaces))
        }
        return sentences.filter { $0.count > 10 }
    }

    // MARK: - Embedding & Storage

    func embedChunks(
        docID: UUID,
        chunks: inout [DocumentChunk],
        baseURL: String,
        model: String,
        progress: @escaping (Double) -> Void
    ) async throws {
        let total = Double(chunks.count)
        for i in 0..<chunks.count {
            let embedding = try await OllamaService.shared.generateEmbedding(
                baseURL: baseURL, model: model, text: chunks[i].text
            )
            chunks[i].embedding = embedding
            let p = Double(i + 1) / total
            await MainActor.run { progress(p) }
        }
        chunkStore[docID] = chunks
    }

    func storeChunksWithoutEmbeddings(docID: UUID, chunks: [DocumentChunk]) {
        chunkStore[docID] = chunks
    }

    // MARK: - Retrieval

    func retrieveRelevantChunks(
        for query: String,
        docID: UUID,
        baseURL: String,
        model: String,
        topK: Int = 8
    ) async throws -> [DocumentChunk] {
        guard let chunks = chunkStore[docID], !chunks.isEmpty else { return [] }
        let embedded = chunks.filter { !$0.embedding.isEmpty }
        guard !embedded.isEmpty else {
            return keywordRetrieve(for: query, docID: docID, topK: topK)
        }

        let queryEmbed = try await OllamaService.shared.generateEmbedding(
            baseURL: baseURL, model: model, text: query
        )

        let scored = embedded.map { chunk -> (DocumentChunk, Float) in
            (chunk, cosineSimilarity(queryEmbed, chunk.embedding))
        }
        let topChunks = scored.sorted { $0.1 > $1.1 }.prefix(topK).map { $0.0 }
        let expanded = expandWithNeighbors(Array(topChunks), allChunks: chunks)
        return expanded.sorted { ($0.pageNumber, $0.chunkIndex) < ($1.pageNumber, $1.chunkIndex) }
    }

    private func expandWithNeighbors(_ top: [DocumentChunk], allChunks: [DocumentChunk]) -> [DocumentChunk] {
        var ids = Set(top.map { $0.id })
        var result = top
        for chunk in top {
            let neighbors = allChunks.filter {
                abs($0.chunkIndex - chunk.chunkIndex) == 1 && $0.pageNumber == chunk.pageNumber
            }
            for n in neighbors where !ids.contains(n.id) {
                ids.insert(n.id); result.append(n)
            }
        }
        return result
    }

    func keywordRetrieve(for query: String, docID: UUID, topK: Int = 8) -> [DocumentChunk] {
        guard let chunks = chunkStore[docID], !chunks.isEmpty else { return [] }
        let keywords = query.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 3 }
        guard !keywords.isEmpty else { return Array(chunks.prefix(topK)) }

        let scored = chunks.map { chunk -> (DocumentChunk, Int) in
            let lower = chunk.text.lowercased()
            let score = keywords.reduce(0) { acc, kw in
                acc + lower.components(separatedBy: kw).count - 1
            }
            return (chunk, score)
        }
        let sorted = scored.sorted { $0.1 > $1.1 }
        if (sorted.first?.1 ?? 0) == 0 { return Array(chunks.prefix(topK)) }
        return sorted.prefix(topK).map { $0.0 }
            .sorted { ($0.pageNumber, $0.chunkIndex) < ($1.pageNumber, $1.chunkIndex) }
    }

    func clearDocument(_ docID: UUID) {
        chunkStore.removeValue(forKey: docID)
    }

    // MARK: - Cosine Similarity

    func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot: Float = 0; var normA: Float = 0; var normB: Float = 0
        for i in 0..<a.count { dot += a[i]*b[i]; normA += a[i]*a[i]; normB += b[i]*b[i] }
        let denom = normA.squareRoot() * normB.squareRoot()
        return denom == 0 ? 0 : dot / denom
    }

    // MARK: - System Prompt

    func buildSystemPrompt(chunks: [DocumentChunk], documentName: String) -> String {
        guard !chunks.isEmpty else {
            return """
            You are a helpful PDF document assistant. No relevant context was found for this question.
            Say: "I couldn't find relevant information in the document for your question."
            """
        }

        let context = chunks.map { chunk in
            "--- [Page \(chunk.pageNumber)] ---\n\(chunk.text)"
        }.joined(separator: "\n\n")

        return """
        You are a helpful PDF document assistant. Answer the user's question based on the provided document excerpts.

        Rules:
        1. Only answer based on the provided context
        2. Always cite page numbers (e.g., "According to page 5...")
        3. If the answer isn't in the context, say so clearly
        4. Be concise and accurate
        5. Use bullet points and **bold** for key terms where appropriate

        Document: \(documentName)

        DOCUMENT CONTEXT:
        \(context)
        """
    }
}
