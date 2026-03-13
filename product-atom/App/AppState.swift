import SwiftUI
import PDFKit

// MARK: - Processing State

enum ProcessingState: Equatable {
    case idle
    case extracting
    case embedding(progress: Double)
    case ready
    case failed(String)
}

// MARK: - AppState

final class AppState: ObservableObject {

    // MARK: Settings
    @AppStorage("ollamaURL") var ollamaURL: String = "http://localhost:11434"
    @AppStorage("selectedModel") var selectedModel: String = ""
    @AppStorage("embeddingModel") var embeddingModel: String = ""
    @AppStorage("colorSchemePref") var colorSchemePref: String = "system"
    @AppStorage("recentDocumentsJSON") private var recentDocumentsJSON: String = "[]"

    var recentDocuments: [ChatDocument] {
        get {
            guard let data = recentDocumentsJSON.data(using: .utf8),
                  let docs = try? JSONDecoder().decode([ChatDocument].self, from: data) else { return [] }
            return docs
        }
        set {
            let trimmed = Array(newValue.prefix(20))
            if let data = try? JSONEncoder().encode(trimmed),
               let str = String(data: data, encoding: .utf8) {
                recentDocumentsJSON = str
            }
        }
    }

    // MARK: Runtime State
    @Published var currentDocument: ChatDocument?
    @Published var activeDocumentURL: URL?
    @Published var messages: [ChatMessage] = []
    @Published var isStreaming = false
    @Published var showSettings = false
    @Published var showHowItWorks = false
    @Published var ollamaConnected: Bool = false
    @Published var availableModels: [OllamaModel] = []
    @Published var processingState: ProcessingState = .idle
    @Published var showToast: Bool = false
    @Published var toastMessage: String = ""
    @Published var jumpToPage: Int? = nil
    @Published var showSidebar: Bool = true

    // Keep the security-scoped URL alive for the session
    private var activeScopedURL: URL?

    // MARK: - Open from file picker (always fresh, no bookmark needed)
    func openFromPicker(url: URL, doc: ChatDocument) {
        releaseScope()
        // NSOpenPanel gives us direct access — start scope to keep it alive
        let started = url.startAccessingSecurityScopedResource()
        NSLog("[DocChat] openFromPicker: %@ startScope=%d", url.path, started ? 1 : 0)
        activeScopedURL = url
        activeDocumentURL = url
        currentDocument = doc
        messages.removeAll()
        processingState = .idle
        addToRecents(doc)
        RAGEngine.shared.clearDocument(doc.id)
        Task { await processDocument(doc, url: url) }
    }

    // MARK: - Open from recents (uses bookmark)
    func switchDocument(_ doc: ChatDocument) {
        guard currentDocument?.id != doc.id else { return }
        releaseScope()
        guard let bookmark = doc.urlBookmark else {
            processingState = .failed("Cannot access file. Please re-open it.")
            currentDocument = doc; activeDocumentURL = nil; return
        }
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else {
            processingState = .failed("Cannot access file. Please re-open it.")
            currentDocument = doc; activeDocumentURL = nil; return
        }
        let started = url.startAccessingSecurityScopedResource()
        NSLog("[DocChat] switchDocument: %@ startScope=%d stale=%d", url.path, started ? 1 : 0, stale ? 1 : 0)
        if !started {
            processingState = .failed("Cannot access file. Please re-open it.")
            currentDocument = doc; activeDocumentURL = nil; return
        }
        activeScopedURL = url
        activeDocumentURL = url
        currentDocument = doc
        messages.removeAll()
        processingState = .idle
        addToRecents(doc)
        RAGEngine.shared.clearDocument(doc.id)
        Task { await processDocument(doc, url: url) }
    }

    private func releaseScope() {
        activeScopedURL?.stopAccessingSecurityScopedResource()
        activeScopedURL = nil
        activeDocumentURL = nil
        currentDocument = nil
        processingState = .idle
    }

    private func addToRecents(_ doc: ChatDocument) {
        var recents = recentDocuments.filter { $0.id != doc.id }
        recents.insert(doc, at: 0)
        recentDocuments = Array(recents.prefix(20))
    }

    // MARK: - Document Processing

    @MainActor
    private func processDocument(_ doc: ChatDocument, url: URL) async {
        processingState = .extracting
        NSLog("[DocChat] Processing: %@", url.path)
        do {
            let pages = try RAGEngine.shared.extractText(from: url)
            NSLog("[DocChat] Extracted %d pages", pages.count)
            guard !pages.isEmpty else {
                processingState = .failed("No readable text found.")
                return
            }
            var chunks = RAGEngine.shared.createChunks(pages: pages)
            NSLog("[DocChat] Created %d chunks", chunks.count)
            RAGEngine.shared.storeChunksWithoutEmbeddings(docID: doc.id, chunks: chunks)

            if !embeddingModel.isEmpty && ollamaConnected {
                processingState = .embedding(progress: 0)
                NSLog("[DocChat] Embedding with: %@", embeddingModel)
                do {
                    try await RAGEngine.shared.embedChunks(
                        docID: doc.id, chunks: &chunks,
                        baseURL: ollamaURL, model: embeddingModel
                    ) { [weak self] p in
                        Task { @MainActor [weak self] in
                            self?.processingState = .embedding(progress: p)
                        }
                    }
                    NSLog("[DocChat] Embeddings done")
                } catch {
                    NSLog("[DocChat] Embedding failed (keyword fallback): %@", error.localizedDescription)
                }
            }
            processingState = .ready
            showToastMessage("✓ Document ready")
        } catch {
            NSLog("[DocChat] Processing error: %@", error.localizedDescription)
            processingState = .failed("Processing failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Chat

    func sendMessage(_ text: String) {
        guard !isStreaming else { return }
        messages.append(ChatMessage(role: .user, content: text))
        isStreaming = true
        Task { await performRAGChat(userQuestion: text) }
    }

    @MainActor
    private func performRAGChat(userQuestion: String) async {
        guard let doc = currentDocument else { isStreaming = false; return }

        let assistantID = UUID()
        messages.append(ChatMessage(id: assistantID, role: .assistant, content: "", isStreaming: true))

        do {
            let chunks: [DocumentChunk]
            if !embeddingModel.isEmpty && ollamaConnected {
                chunks = try await RAGEngine.shared.retrieveRelevantChunks(
                    for: userQuestion, docID: doc.id,
                    baseURL: ollamaURL, model: embeddingModel, topK: 8
                )
            } else {
                chunks = RAGEngine.shared.keywordRetrieve(for: userQuestion, docID: doc.id, topK: 8)
            }

            let systemPrompt = RAGEngine.shared.buildSystemPrompt(chunks: chunks, documentName: doc.name)
            let sourcePages = Array(Set(chunks.map { $0.pageNumber })).sorted()
            let primaryPage = chunks.first?.pageNumber
            let modelName = selectedModel.isEmpty ? "llama3.2" : selectedModel
            var fullResponse = ""

            try await OllamaService.shared.streamChat(
                baseURL: ollamaURL, model: modelName,
                systemPrompt: systemPrompt, userMessage: userQuestion
            ) { [weak self] token in
                guard let self else { return }
                fullResponse += token
                if let idx = self.messages.firstIndex(where: { $0.id == assistantID }) {
                    self.messages[idx] = ChatMessage(
                        id: assistantID, role: .assistant, content: fullResponse,
                        sourcePage: primaryPage, sourcePages: sourcePages, isStreaming: true
                    )
                }
            }

            if let idx = messages.firstIndex(where: { $0.id == assistantID }) {
                messages[idx] = ChatMessage(
                    id: assistantID, role: .assistant, content: fullResponse,
                    sourcePage: primaryPage, sourcePages: sourcePages, isStreaming: false
                )
            }
        } catch {
            if let idx = messages.firstIndex(where: { $0.id == assistantID }) {
                messages[idx] = ChatMessage(
                    id: assistantID, role: .assistant,
                    content: "⚠️ \(error.localizedDescription)", isStreaming: false
                )
            }
        }
        isStreaming = false
    }

    // MARK: - Model Fetching

    func fetchModels() {
        Task {
            let models = (try? await OllamaService.shared.fetchModels(baseURL: ollamaURL)) ?? []
            await MainActor.run {
                self.availableModels = models
                if self.selectedModel.isEmpty, let first = models.first(where: {
                    !$0.name.contains("embed") && !$0.name.contains("nomic") && !$0.name.contains("mxbai")
                }) ?? models.first {
                    self.selectedModel = first.name
                }
                if self.embeddingModel.isEmpty {
                    let embed = models.first(where: {
                        $0.name.contains("embed") || $0.name.contains("nomic") || $0.name.contains("mxbai")
                    })
                    self.embeddingModel = embed?.name ?? ""
                }
                self.ollamaConnected = !models.isEmpty
            }
        }
    }

    func clearChat() { messages.removeAll() }

    func showToastMessage(_ msg: String) {
        toastMessage = msg
        withAnimation(.spring(response: 0.4)) { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            withAnimation { self?.showToast = false }
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch colorSchemePref {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}
