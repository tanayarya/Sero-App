import SwiftUI

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
    @AppStorage("colorScheme") var colorSchemePref: String = "system"

    // MARK: Runtime State
    @Published var currentDocument: ChatDocument?
    @Published var documents: [ChatDocument] = []
    @Published var messages: [ChatMessage] = []
    @Published var isStreaming = false
    @Published var showSettings = false
    @Published var ollamaConnected: Bool = false
    @Published var availableModels: [OllamaModel] = []
    @Published var processingState: ProcessingState = .idle
    @Published var showToast: Bool = false
    @Published var toastMessage: String = ""

    // MARK: - Document Management

    func loadDocument(_ doc: ChatDocument) {
        currentDocument = doc
        if !documents.contains(where: { $0.id == doc.id }) {
            documents.append(doc)
        }
        messages.removeAll()
        processingState = .idle
        Task { await processDocument(doc) }
    }

    // MARK: - Document Processing (RAG)

    @MainActor
    func processDocument(_ doc: ChatDocument) async {
        guard let url = doc.url else { return }

        processingState = .extracting
        do {
            // Step 1: Extract text
            let pages = try RAGEngine.shared.extractText(from: url)
            guard !pages.isEmpty else {
                processingState = .failed("No readable text found in this document.")
                return
            }

            // Step 2: Chunk
            processingState = .embedding(progress: 0)
            var chunks = RAGEngine.shared.createChunks(pages: pages)

            // Step 3: Embed (if model set)
            if !embeddingModel.isEmpty {
                try await RAGEngine.shared.embedChunks(
                    docID: doc.id,
                    chunks: &chunks,
                    baseURL: ollamaURL,
                    model: embeddingModel
                ) { [weak self] p in
                    self?.processingState = .embedding(progress: p)
                }
            }

            processingState = .ready
            showToastMessage("Document ready for questions ✓")
        } catch {
            processingState = .failed("Processing failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Chat

    func sendMessage(_ text: String) {
        let userMsg = ChatMessage(role: .user, content: text)
        messages.append(userMsg)
        isStreaming = true

        Task { await performRAGChat(userQuestion: text) }
    }

    @MainActor
    private func performRAGChat(userQuestion: String) async {
        guard let doc = currentDocument else { return }

        // Placeholder assistant message for streaming
        let assistantID = UUID()
        messages.append(ChatMessage(id: assistantID, role: .assistant, content: "", isStreaming: true))

        do {
            // Retrieve relevant chunks
            let chunks: [DocumentChunk]
            if !embeddingModel.isEmpty {
                chunks = try await RAGEngine.shared.retrieveRelevantChunks(
                    for: userQuestion,
                    docID: doc.id,
                    baseURL: ollamaURL,
                    model: embeddingModel
                )
            } else {
                chunks = []
            }

            let systemPrompt = RAGEngine.shared.buildSystemPrompt(
                chunks: chunks,
                documentName: doc.name
            )
            let sourcePage = chunks.first?.pageNumber

            var fullResponse = ""
            try await OllamaService.shared.streamChat(
                baseURL: ollamaURL,
                model: selectedModel.isEmpty ? "llama3.2" : selectedModel,
                systemPrompt: systemPrompt,
                userMessage: userQuestion
            ) { [weak self] token in
                fullResponse += token
                guard let self else { return }
                if let idx = self.messages.firstIndex(where: { $0.id == assistantID }) {
                    self.messages[idx] = ChatMessage(
                        id: assistantID,
                        role: .assistant,
                        content: fullResponse,
                        sourcePage: sourcePage,
                        isStreaming: true
                    )
                }
            }

            // Finalize
            if let idx = messages.firstIndex(where: { $0.id == assistantID }) {
                messages[idx] = ChatMessage(
                    id: assistantID,
                    role: .assistant,
                    content: fullResponse,
                    sourcePage: sourcePage,
                    isStreaming: false
                )
            }
        } catch {
            if let idx = messages.firstIndex(where: { $0.id == assistantID }) {
                messages[idx] = ChatMessage(
                    id: assistantID,
                    role: .assistant,
                    content: "⚠️ Error: \(error.localizedDescription)",
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
                    let embedCandidate = models.first(where: {
                        $0.name.contains("embed") || $0.name.contains("nomic") || $0.name.contains("mxbai")
                    })
                    self.embeddingModel = embedCandidate?.name ?? models.first?.name ?? ""
                }
                self.ollamaConnected = !models.isEmpty
            }
        }
    }

    func clearChat() {
        messages.removeAll()
    }

    // MARK: - Toast

    func showToastMessage(_ msg: String) {
        toastMessage = msg
        showToast = true
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
