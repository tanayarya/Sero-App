import Foundation

struct ChatDocument: Identifiable, Hashable {
    let id: UUID
    let name: String
    let fileType: DocFileType
    let dateAdded: Date
    let pageCount: Int
    let fileSize: String
    let url: URL?

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
        self.url = url
    }
}

enum DocFileType: String, CaseIterable {
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

    var tintColor: String {
        switch self {
        case .pdf: return "docPDF"
        case .txt: return "docTXT"
        case .markdown: return "docMD"
        }
    }
}
