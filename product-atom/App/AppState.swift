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
            let trimmed = Array(newValue.prefix(10))
            if let data = try? JSONEncoder().encode(trimmed),
               let str = String(data: data, encoding: .utf8) {
                recentDocumentsJSON = str
            }
        }
    }

    // MARK: Runtime State
    @Published var currentDocument: ChatDocument?

    /// The LIVE security-scoped URL kept open for the current document.
    /// This is the single source of truth for file access.
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

    // Security scope management
    private var scopedURL: URL?

    // MARK: - Document Management

    /// Call this when user picks a file from the open panel.
    /// Pass the ORIGINAL url from NSOpenPanel (scope already granted by OS).
    func loadDocument(_ doc: ChatDocument, liveURL: URL? = nil) {
        // Release previous scope
        releaseActiveScope()

        currentDocument = doc
        messages.removeAll()
        processingState = .idle
        activeDocumentURL = nil  // reset first so view clears

        // Prefer the live URL (from open panel).
        // NSOpenPanel ALREADY grants access — do NOT call startAccessingSecurityScopedResource on it.
        // Just store it directly. We only use security scope for bookmark-resolved URLs.
        if let live = liveURL {
            scopedURL = nil  // no scope to release for live URLs
            activeDocumentURL = live
        } else if let bookmarkURL = doc.bookmarkURL {
            let ok = bookmarkURL.startAccessingSecurityScopedResource()
            NSLog("[DocChat] Bookmark scope started: %@, ok=%d", bookmarkURL.path, ok ? 1 : 0)
            if ok {
                scopedURL = bookmarkURL
                activeDocumentURL = bookmarkURL
            } else {
                activeDocumentURL = nil
                processingState = .failed("Cannot access file. Please re-open it.")
                return
            }
        } else {
            activeDocumentURL = nil
            processingState = .failed("Cannot access file. Please re-open it.")
            return
        }

        addToRecents(doc)
        RAGEngine.shared.clearDocument(doc.id)
        Task { await processDocument(doc) }
    }

    func switchDocument(_ doc: ChatDocument) {
        guard currentDocument?.id != doc.id else { return }
        // For recent docs, we have no live URL — must use bookmark
        loadDocument(doc, liveURL: nil)
    }

    private func releaseActiveScope() {
        if let old = scopedURL {
            old.stopAccessingSecurityScopedResource()
        }
        scopedURL = nil
        activeDocumentURL = nil
    }

    private func addToRecents(_ doc: ChatDocument) {
        var recents = recentDocuments.filter { $0.id != doc.id }
        recents.insert(doc, at: 0)
        recentDocuments = Array(recents.prefix(10))
    }

    // MARK: - Document Processing

    @MainActor
    func processDocument(_ doc: ChatDocument) async {
        guard let url = activeDocumentURL else {
            processingState = .failed("No file URL available.")
            return
        }

        processingState = .extracting
        NSLog("[DocChat] Processing document: %@", url.path)

        do {
            // alreadyScoped=true: either live URL (panel) or bookmark scope already active
            let pages = try RAGEngine.shared.extractText(from: url, alreadyScoped: true)
            NSLog("[DocChat] Extracted %d pages", pages.count)
            guard !pages.isEmpty else {
                processingState = .failed("No readable text found.")
                return
            }

            var chunks = RAGEngine.shared.createChunks(pages: pages)
            NSLog("[DocChat] Created %d chunks", chunks.count)

            // Always store chunks immediately so keyword search works even without embeddings
            RAGEngine.shared.storeChunksWithoutEmbeddings(docID: doc.id, chunks: chunks)

            if !embeddingModel.isEmpty && ollamaConnected {
                processingState = .embedding(progress: 0)
                NSLog("[DocChat] Starting embeddings with model: %@", embeddingModel)
                do {
                    try await RAGEngine.shared.embedChunks(
                        docID: doc.id,
                        chunks: &chunks,
                        baseURL: ollamaURL,
                        model: embeddingModel
                    ) { [weak self] p in
                        Task { @MainActor [weak self] in
                            self?.processingState = .embedding(progress: p)
                        }
                    }
                    NSLog("[DocChat] Embeddings complete")
                } catch {
                    // Embedding failed but chunks still stored — continue with keyword search
                    NSLog("[DocChat] Embedding failed (will use keyword search): %@", error.localizedDescription)
                }
            }

            processingState = .ready
            showToastMessage("✓ Document ready for questions")
        } catch {
            NSLog("[DocChat] Processing failed: %@", error.localizedDescription)
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
            if !embeddingModel.isEmpty {
                chunks = try await RAGEngine.shared.retrieveRelevantChunks(
                    for: userQuestion,
                    docID: doc.id,
                    baseURL: ollamaURL,
                    model: embeddingModel,
                    topK: 8
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
                baseURL: ollamaURL,
                model: modelName,
                systemPrompt: systemPrompt,
                userMessage: userQuestion
            ) { [weak self] token in
                guard let self else { return }
                fullResponse += token
                if let idx = self.messages.firstIndex(where: { $0.id == assistantID }) {
                    self.messages[idx] = ChatMessage(
                        id: assistantID, role: .assistant,
                        content: fullResponse,
                        sourcePage: primaryPage, sourcePages: sourcePages,
                        isStreaming: true
                    )
                }
            }

            if let idx = messages.firstIndex(where: { $0.id == assistantID }) {
                messages[idx] = ChatMessage(
                    id: assistantID, role: .assistant,
                    content: fullResponse,
                    sourcePage: primaryPage, sourcePages: sourcePages,
                    isStreaming: false
                )
            }
        } catch {
            if let idx = messages.firstIndex(where: { $0.id == assistantID }) {
                messages[idx] = ChatMessage(
                    id: assistantID, role: .assistant,
                    content: "⚠️ \(error.localizedDescription)",
                    isStreaming: false
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
                if self.selectedModel.isEmpty, let first = models.first {
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
