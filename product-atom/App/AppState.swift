import SwiftUI

final class AppState: ObservableObject {
    @Published var currentDocument: ChatDocument?
    @Published var documents: [ChatDocument] = []
    @Published var messages: [ChatMessage] = []
    @Published var isProcessing = false
    @Published var showSettings = false
    @Published var selectedModel: String = "llama3.2"
    @Published var ollamaURL: String = "http://localhost:11434"
    @Published var embeddingModel: String = "nomic-embed-text"
    @Published var ollamaConnected: Bool = false

    var availableModels: [String] {
        ["llama3.2", "llama3.1", "mistral", "gemma2", "phi3"]
    }

    func addDocument(_ doc: ChatDocument) {
        documents.append(doc)
        currentDocument = doc
    }

    func clearChat() {
        messages.removeAll()
    }
}
