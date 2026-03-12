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
    // MARK: Persisted Settings
    @AppStorage("ollamaURL") var ollamaURL: String = "http://localhost:11434"
    @AppStorage("selectedModel") var selectedModel: String = ""
    @AppStorage("embeddingModel") var embeddingModel: String = ""
    @AppStorage("colorSchemePref") var colorSchemePref: String = "system"

    // MARK: Persisted Recent Documents
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

    // MARK: - Document Management

    func loadDocument(_ doc: ChatDocument) {
        if let old = currentDocument, old.id != doc.id {
            RAGEngine.shared.clearDocument(old.id)
        }
        currentDocument = doc
        addToRecents(doc)
        messages.removeAll()
        processingState = .idle
        Task { await processDocument(doc) }
    }

    func switchDocument(_ doc: ChatDocument) {
        guard currentDocument?.id != doc.id else { return }
        if let old = currentDocument {
            RAGEngine.shared.clearDocument(old.id)
        }
        currentDocument = doc
        addToRecents(doc)
        messages.removeAll()
        processingState = .idle
        Task { await processDocument(doc) }
    }

    private func addToRecents(_ doc: ChatDocument) {
        var recents = recentDocuments.filter { $0.id != doc.id }
        recents.insert(doc, at: 0)
        recentDocuments = Array(recents.prefix(10))
    }

    // MARK: - Document Processing

    @MainActor
    func processDocument(_ doc: ChatDocument) async {
        guard let url = doc.url else {
            processingState = .failed("Cannot access file. Please re-open it.")
            return
        }

        processingState = .extracting
        do {
            let pages = try RAGEngine.shared.extractText(from: url)
            guard !pages.isEmpty else {
                processingState = .failed("No readable text found.")
                return
            }

            var chunks = RAGEngine.shared.createChunks(pages: pages)

            if !embeddingModel.isEmpty {
                processingState = .embedding(progress: 0)
                try await RAGEngine.shared.embedChunks(
                    docID: doc.id,
                    chunks: &chunks,
                    baseURL: ollamaURL,
                    model: embeddingModel
                ) { [weak self] p in
                    self?.processingState = .embedding(progress: p)
                }
            } else {
                RAGEngine.shared.storeChunksWithoutEmbeddings(docID: doc.id, chunks: chunks)
            }

            processingState = .ready
            showToastMessage("✓ Document ready for questions")
        } catch {
            processingState = .failed("Processing failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Chat

    func sendMessage(_ text: String) {
        guard !isStreaming else { return }
        let userMsg = ChatMessage(role: .user, content: text)
        messages.append(userMsg)
        isStreaming = true
        Task { await performRAGChat(userQuestion: text) }
    }

    @MainActor
    private func performRAGChat(userQuestion: String) async {
        guard let doc = currentDocument else {
            isStreaming = false
            return
        }

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
                        id: assistantID,
                        role: .assistant,
                        content: fullResponse,
                        sourcePage: primaryPage,
                        sourcePages: sourcePages,
                        isStreaming: true
                    )
                }
            }

            if let idx = messages.firstIndex(where: { $0.id == assistantID }) {
                messages[idx] = ChatMessage(
                    id: assistantID,
                    role: .assistant,
                    content: fullResponse,
                    sourcePage: primaryPage,
                    sourcePages: sourcePages,
                    isStreaming: false
                )
            }
        } catch {
            if let idx = messages.firstIndex(where: { $0.id == assistantID }) {
                messages[idx] = ChatMessage(
                    id: assistantID,
                    role: .assistant,
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

    // MARK: - Toast

    func showToastMessage(_ msg: String) {
        toastMessage = msg
        withAnimation(.spring(response: 0.4)) { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            withAnimation { self?.showToast = false }
        }
    }

    // MARK: - Color Scheme

    var preferredColorScheme: ColorScheme? {
        switch colorSchemePref {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}
