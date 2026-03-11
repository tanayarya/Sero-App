import Foundation

struct ChatMessage: Identifiable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date
    let sourcePage: Int?
    let isStreaming: Bool

    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        sourcePage: Int? = nil,
        isStreaming: Bool = false
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.sourcePage = sourcePage
        self.isStreaming = isStreaming
    }
}

enum MessageRole {
    case user, assistant, system
}
