import SwiftUI

struct DocumentViewerPanel: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            viewerToolbar
            Divider()
            viewerContent
        }
        .background(Color.surfaceSecondary)
    }

    @ViewBuilder
    private var viewerToolbar: some View {
        HStack(spacing: 12) {
            Text("Document Viewer")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
            Spacer()
            HStack(spacing: 8) {
                Button { } label: {
                    Image(systemName: "minus.magnifyingglass")
                }
                Text("100%")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.textSecondary)
                Button { } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.surfaceSecondary)
    }

    @ViewBuilder
    private var viewerContent: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "doc.text")
                .font(.system(size: 44))
                .foregroundStyle(Color.textTertiary)
            Text("Document preview will appear here")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.textSecondary)
            if let doc = appState.currentDocument {
                Text(doc.name)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
