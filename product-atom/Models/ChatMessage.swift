import Foundation

enum MessageRole: String, Codable {
    case user, assistant
}

struct ChatMessage: Identifiable {
    let id: UUID
    let role: MessageRole
    var content: String
    var sourcePage: Int?
    var sourcePages: [Int]
    var isStreaming: Bool

    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        sourcePage: Int? = nil,
        sourcePages: [Int] = [],
        isStreaming: Bool = false
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.sourcePage = sourcePage
        self.sourcePages = sourcePages
        self.isStreaming = isStreaming
    }
}
