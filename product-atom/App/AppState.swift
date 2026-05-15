import SwiftUI
import PDFKit
import AppKit

// MARK: - Processing State

enum ProcessingState: Equatable {
    case idle
    case extracting
    case embedding(progress: Double)
    case ready
    case failed(String)
}

enum LocalRuntimeState: Equatable {
    case checking
    case missing
    case installed
    case ready
}

// MARK: - AppState

final class AppState: ObservableObject {

    // MARK: Settings
    @AppStorage("ollamaURL") var ollamaURL: String = "http://localhost:11434"
    @AppStorage("selectedModel") var selectedModel: String = ""
    @AppStorage("embeddingModel") var embeddingModel: String = ""
    @AppStorage("colorSchemePref") var colorSchemePref: String = "dark"
    @AppStorage("recentDocumentsJSON") private var recentDocumentsJSON: String = "[]"
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false

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
    /// Increments on every streamed token — used to drive auto-scroll in ChatPanel
    @Published var streamingToken: Int = 0
    @Published var localRuntimeState: LocalRuntimeState = .checking
    @Published var onboardingIsChecking = false
    @Published var onboardingIsPulling = false
    @Published var onboardingStatusMessage: String?
    @Published var onboardingDetailText: String?
    @Published var onboardingProgress: Double?

    // Active streaming task — cancelled when user taps Stop
    private var streamingTask: Task<Void, Never>?
    private var onboardingDownloadTask: Task<Void, Never>?

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

    func returnToHome() {
        stopStreaming()
        messages.removeAll()
        releaseScope()
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
        streamingTask = Task { await performRAGChat(userQuestion: text) }
    }

    func stopStreaming() {
        streamingTask?.cancel()
        streamingTask = nil
        // Finalise all assistant messages that still have isStreaming=true
        for idx in messages.indices where messages[idx].role == .assistant && messages[idx].isStreaming {
            let msg = messages[idx]
            // Drop empty assistant placeholders that have nothing to show
            if msg.content.isEmpty {
                messages.remove(at: idx)
            } else {
                messages[idx] = ChatMessage(
                    id: msg.id, role: .assistant, content: msg.content,
                    sourcePage: msg.sourcePage, sourcePages: msg.sourcePages, isStreaming: false
                )
            }
            break
        }
        isStreaming = false
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

            guard !chunks.isEmpty else {
                if let idx = messages.firstIndex(where: { $0.id == assistantID }) {
                    messages[idx] = ChatMessage(
                        id: assistantID,
                        role: .assistant,
                        content: "Reopen this document, let it finish preparing, then chat again.",
                        isStreaming: false
                    )
                }
                isStreaming = false
                streamingTask = nil
                return
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
                self.streamingToken += 1
            }

            if let idx = messages.firstIndex(where: { $0.id == assistantID }) {
                messages[idx] = ChatMessage(
                    id: assistantID, role: .assistant, content: fullResponse,
                    sourcePage: primaryPage, sourcePages: sourcePages, isStreaming: false
                )
            }
        } catch is CancellationError {
            // User stopped — stopStreaming() already finalised the message and set isStreaming=false
            // Just make sure nothing leaks
            streamingTask = nil
            return
        } catch {
            if let idx = messages.firstIndex(where: { $0.id == assistantID }) {
                messages[idx] = ChatMessage(
                    id: assistantID, role: .assistant,
                    content: userFacingChatErrorMessage(for: error), isStreaming: false
                )
            }
        }
        isStreaming = false
        streamingTask = nil
    }

    private func userFacingChatErrorMessage(for error: Error) -> String {
        let message = error.localizedDescription.lowercased()
        if message.contains("couldn’t be read because it is missing")
            || message.contains("couldn't be read because it is missing")
            || message.contains("could not be read because it is missing")
            || message.contains("missing") {
            return "Reopen this document, let it finish preparing, then chat again."
        }
        return "Something went wrong. Reopen the document, let it finish preparing, then try again."
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

    @MainActor
    func refreshRuntimeStatus() async {
        onboardingIsChecking = true
        onboardingStatusMessage = "Checking local setup"
        onboardingDetailText = "Looking for Ollama on this Mac."
        onboardingProgress = nil

        let installed = isOllamaAppInstalled()
        let localReachable = await OllamaService.shared.testConnection(baseURL: "http://localhost:11434")
        if localReachable {
            ollamaURL = "http://localhost:11434"
            localRuntimeState = .ready
            await refreshModelsAndConnection()
            onboardingStatusMessage = nil
            onboardingDetailText = nil
        } else {
            localRuntimeState = installed ? .installed : .missing
            onboardingStatusMessage = installed ? "Ollama is installed" : "Ollama is not installed"
            onboardingDetailText = installed
                ? "Open Ollama, then come back here and check again."
                : "Use the official download page, then return here when the install is complete."
        }
        onboardingIsChecking = false
    }

    @MainActor
    func refreshModelsAndConnection() async {
        let models = (try? await OllamaService.shared.fetchModels(baseURL: ollamaURL)) ?? []
        availableModels = models
        if selectedModel.isEmpty || !models.contains(where: { $0.name == selectedModel }) {
            if let chat = models.first(where: { !isEmbeddingModelName($0.name) }) ?? models.first {
                selectedModel = chat.name
            }
        }
        if embeddingModel.isEmpty || !models.contains(where: { $0.name == embeddingModel }) {
            let embed = models.first(where: { isEmbeddingModelName($0.name) })
            embeddingModel = embed?.name ?? ""
        }
        ollamaConnected = !models.isEmpty
    }

    @MainActor
    func validateRemoteServer(urlString: String) async {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            onboardingStatusMessage = "Enter a server URL"
            onboardingDetailText = "Use a local network address or a localhost address."
            onboardingProgress = nil
            return
        }

        onboardingIsChecking = true
        onboardingStatusMessage = "Validating server"
        onboardingDetailText = trimmed
        onboardingProgress = nil

        let isReachable = await OllamaService.shared.testConnection(baseURL: trimmed)
        if isReachable {
            ollamaURL = trimmed
            await refreshModelsAndConnection()
            onboardingStatusMessage = ollamaConnected ? "Server is ready" : "Server responded"
            onboardingDetailText = ollamaConnected
                ? "Models were found on this server. Continue when you are ready."
                : "The server responded, but no models were found yet."
        } else {
            availableModels = []
            ollamaConnected = false
            onboardingStatusMessage = "Could not reach that server"
            onboardingDetailText = "Check the address and make sure Ollama is running on that machine."
        }
        onboardingIsChecking = false
    }

    @MainActor
    func downloadStarterModels(chatModel: String) async {
        guard !onboardingIsPulling else { return }
        onboardingIsPulling = true
        onboardingProgress = 0.05
        onboardingStatusMessage = "Preparing model setup"
        onboardingDetailText = chatModel

        do {
            try await OllamaService.shared.pullModel(baseURL: ollamaURL, model: chatModel) { [weak self] chunk in
                guard let self else { return }
                self.onboardingStatusMessage = "Downloading chat model"
                self.onboardingDetailText = "This can take a few minutes depending on the model size."
                if let completed = chunk.completed, let total = chunk.total, total > 0 {
                    self.onboardingProgress = max(0.05, min(0.96, Double(completed) / Double(total) * 0.91))
                } else {
                    self.onboardingProgress = nil
                }
            }

            onboardingProgress = 1
            onboardingStatusMessage = "Model setup is ready"
            onboardingDetailText = "You can start chatting with your documents now."
            await refreshModelsAndConnection()

            if availableModels.contains(where: { $0.name == chatModel }) {
                selectedModel = chatModel
            }
        } catch is CancellationError {
            onboardingStatusMessage = "Download cancelled"
            onboardingDetailText = "You can choose another model or continue later."
            onboardingProgress = nil
        } catch {
            onboardingStatusMessage = "Model download failed"
            onboardingDetailText = error.localizedDescription
            onboardingProgress = nil
        }

        onboardingIsPulling = false
        onboardingDownloadTask = nil
    }

    func beginStarterModelDownload(chatModel: String) {
        guard !onboardingIsPulling else { return }
        onboardingDownloadTask = Task { @MainActor [weak self] in
            await self?.downloadStarterModels(chatModel: chatModel)
        }
    }

    func cancelOnboardingDownload() {
        onboardingDownloadTask?.cancel()
        onboardingDownloadTask = nil
    }

    func resetOnboardingStatus() {
        onboardingDownloadTask?.cancel()
        onboardingDownloadTask = nil
        onboardingIsChecking = false
        onboardingIsPulling = false
        onboardingStatusMessage = nil
        onboardingDetailText = nil
        onboardingProgress = nil
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        resetOnboardingStatus()
    }

    func reopenOnboarding() {
        hasCompletedOnboarding = false
        resetOnboardingStatus()
    }

    func openOllamaDownloadPage() {
        guard let url = URL(string: "https://ollama.com/download") else { return }
        NSWorkspace.shared.open(url)
    }

    func openInstalledOllama() {
        let appURL = URL(fileURLWithPath: "/Applications/Ollama.app")
        NSWorkspace.shared.openApplication(at: appURL, configuration: .init())
    }

    private func isOllamaAppInstalled() -> Bool {
        FileManager.default.fileExists(atPath: "/Applications/Ollama.app")
    }

    private func isEmbeddingModelName(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower.contains("embed") || lower.contains("nomic") || lower.contains("mxbai")
    }

    func clearChat() { messages.removeAll() }

    func clearRecentDocuments() { recentDocuments = [] }

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
