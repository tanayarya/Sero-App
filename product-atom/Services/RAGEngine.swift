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

// MARK: - Chunk Cache Entry

private struct CachedDoc {
    var chunks: [DocumentChunk]
    let docID: UUID
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
        case "pdf":
            return try extractPDFText(url: url)
        case "md", "markdown":
            let raw = try String(contentsOf: url, encoding: .utf8)
            return extractMarkdownPages(raw)
        default:
            let raw = try String(contentsOf: url, encoding: .utf8)
            return extractTextPages(raw)
        }
    }

    // Extract PDF - merge small pages, preserve paragraph structure
    private func extractPDFText(url: URL) throws -> [(page: Int, text: String)] {
        guard let doc = PDFDocument(url: url) else {
            throw NSError(domain: "RAG", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot open PDF"])
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
                // Merge small pages with previous
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
        let paragraphs = text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 20 }
        // Group paragraphs into ~3000 char pages
        var pages: [(page: Int, text: String)] = []
        var current = ""
        var pageNum = 1
        for para in paragraphs {
            if current.count + para.count > 3000 && !current.isEmpty {
                pages.append((page: pageNum, text: current))
                pageNum += 1
                current = para
            } else {
                current += current.isEmpty ? para : "\n\n" + para
            }
        }
        if !current.isEmpty { pages.append((page: pageNum, text: current)) }
        return pages.isEmpty ? [(page: 1, text: text)] : pages
    }

    private func extractMarkdownPages(_ text: String) -> [(page: Int, text: String)] {
        // Split on ## headings as logical pages
        let sections = text.components(separatedBy: "\n## ")
        if sections.count > 1 {
            return sections.enumerated().map { i, s in
                let cleaned = cleanText(i == 0 ? s : "## " + s)
                return (page: i + 1, text: cleaned)
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

    // MARK: - Chunking (2400 chars, ~400 char overlap, paragraph-aware)

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
                    // Save current chunk
                    if current.count > 100 {
                        chunks.append(DocumentChunk(
                            id: UUID(),
                            text: current,
                            pageNumber: pageNum,
                            chunkIndex: chunkIndex
                        ))
                        chunkIndex += 1
                    }
                    // Build overlap from tail of sentenceBuffer
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
                    id: UUID(),
                    text: current,
                    pageNumber: pageNum,
                    chunkIndex: chunkIndex
                ))
                chunkIndex += 1
            }
        }
        return chunks
    }

    private func splitIntoSentences(_ text: String) -> [String] {
        var sentences: [String] = []
        var current = ""
        let terminators: Set<Character> = [".", "!", "?", "\n"]
        for char in text {
            current.append(char)
            if terminators.contains(char) && current.count > 40 {
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
                baseURL: baseURL,
                model: model,
                text: chunks[i].text
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

    func hasDocument(_ docID: UUID) -> Bool {
        chunkStore[docID] != nil
    }

    // MARK: - Semantic Retrieval

    func retrieveRelevantChunks(
        for query: String,
        docID: UUID,
        baseURL: String,
        model: String,
        topK: Int = 8
    ) async throws -> [DocumentChunk] {
        guard let chunks = chunkStore[docID], !chunks.isEmpty else { return [] }
        let embeddedChunks = chunks.filter { !$0.embedding.isEmpty }
        guard !embeddedChunks.isEmpty else {
            return keywordRetrieve(for: query, docID: docID, topK: topK)
        }

        let queryEmbed = try await OllamaService.shared.generateEmbedding(
            baseURL: baseURL, model: model, text: query
        )

        let scored = embeddedChunks.map { chunk -> (DocumentChunk, Float) in
            (chunk, cosineSimilarity(queryEmbed, chunk.embedding))
        }
        let topChunks = scored.sorted { $0.1 > $1.1 }.prefix(topK).map { $0.0 }

        // Include adjacent chunks for context continuity
        let expanded = expandWithNeighbors(topChunks, allChunks: chunks)
        return expanded.sorted { ($0.pageNumber, $0.chunkIndex) < ($1.pageNumber, $1.chunkIndex) }
    }

    // Include immediate neighbors of top chunks for better context
    private func expandWithNeighbors(_ topChunks: [DocumentChunk], allChunks: [DocumentChunk]) -> [DocumentChunk] {
        var ids = Set(topChunks.map { $0.id })
        var result = topChunks
        for chunk in topChunks {
            let neighbors = allChunks.filter {
                abs($0.chunkIndex - chunk.chunkIndex) == 1 && $0.pageNumber == chunk.pageNumber
            }
            for n in neighbors where !ids.contains(n.id) {
                ids.insert(n.id)
                result.append(n)
            }
        }
        return result
    }

    // MARK: - Keyword Fallback

    func keywordRetrieve(for query: String, docID: UUID, topK: Int = 8) -> [DocumentChunk] {
        guard let chunks = chunkStore[docID], !chunks.isEmpty else { return [] }
        let keywords = query.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 3 }
        guard !keywords.isEmpty else { return Array(chunks.prefix(topK)) }

        let scored = chunks.map { chunk -> (DocumentChunk, Int) in
            let lower = chunk.text.lowercased()
            let score = keywords.reduce(0) { acc, kw in
                let count = lower.components(separatedBy: kw).count - 1
                return acc + count
            }
            return (chunk, score)
        }
        let sortedScored = scored.sorted { $0.1 > $1.1 }
        // Fallback: if no keyword matches, use first chunks
        let topScore = sortedScored.first?.1 ?? 0
        if topScore == 0 {
            return Array(chunks.prefix(topK))
        }
        return sortedScored.prefix(topK).map { $0.0 }
            .sorted { ($0.pageNumber, $0.chunkIndex) < ($1.pageNumber, $1.chunkIndex) }
    }

    func clearDocument(_ docID: UUID) {
        chunkStore.removeValue(forKey: docID)
    }

    // MARK: - Cosine Similarity

    func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot: Float = 0
        var normA: Float = 0
        var normB: Float = 0
        for i in 0..<a.count {
            dot  += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        let denom = normA.squareRoot() * normB.squareRoot()
        return denom == 0 ? 0 : dot / denom
    }

    // MARK: - System Prompt

    func buildSystemPrompt(chunks: [DocumentChunk], documentName: String) -> String {
        guard !chunks.isEmpty else {
            return """
            You are a document assistant. No document context was retrieved.
            Tell the user: "I couldn't find relevant information in the document for your question."
            """
        }

        let context = chunks.enumerated().map { i, chunk in
            "--- [Page \(chunk.pageNumber), Chunk \(chunk.chunkIndex + 1)] ---\n\(chunk.text)"
        }.joined(separator: "\n\n")

        return """
        You are an expert document analyst for "\(documentName)".

        STRICT RULES:
        1. Answer ONLY using the document excerpts provided below.
        2. If the answer is NOT in the excerpts, respond with exactly:
           "I couldn't find that information in this document."
        3. Do NOT generate, assume, or hallucinate information.
        4. ALWAYS format responses as:
           - Use **bold** for key terms
           - Use bullet lists (- item) for multiple points
           - Use ### headings for major sections when the answer is long
           - Cite page numbers inline as **(Page X)**
           - Keep responses concise and scannable
        5. For page-specific questions, reference only what was retrieved.

        DOCUMENT CONTEXT:
        \(context)
        """
    }
}
