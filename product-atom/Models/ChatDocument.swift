import Foundation

// MARK: - ChatDocument
// urlBookmark stores a security-scoped bookmark for persistence.
// The LIVE url (with active scope) is held by AppState.activeDocumentURL.

struct ChatDocument: Identifiable, Hashable, Codable {
    let id: UUID
    let name: String
    let fileType: DocFileType
    let dateAdded: Date
    let pageCount: Int
    let fileSize: String
    let urlBookmark: Data?

    // Resolve bookmark → URL (caller must startAccessingSecurityScopedResource)
    var bookmarkURL: URL? {
        guard let bookmark = urlBookmark else { return nil }
        var stale = false
        let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        )
        return url
    }

    init(
        id: UUID = UUID(),
        name: String,
        fileType: DocFileType,
        dateAdded: Date = Date(),
        pageCount: Int = 1,
        fileSize: String = "—",
        url: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.fileType = fileType
        self.dateAdded = dateAdded
        self.pageCount = pageCount
        self.fileSize = fileSize
        if let u = url {
            self.urlBookmark = try? u.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } else {
            self.urlBookmark = nil
        }
    }
}

enum DocFileType: String, CaseIterable, Codable {
    case pdf, txt, markdown

    var icon: String {
        switch self {
        case .pdf: return "doc.richtext"
        case .txt: return "doc.plaintext"
        case .markdown: return "doc.text"
        }
    }

    var label: String {
        switch self {
        case .pdf: return "PDF"
        case .txt: return "TXT"
        case .markdown: return "Markdown"
        }
    }
}
