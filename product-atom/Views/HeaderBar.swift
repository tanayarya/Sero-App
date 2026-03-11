import SwiftUI

struct HeaderBar: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 16) {
            logoSection
            Spacer()
            centerControls
            Spacer()
            trailingControls
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var logoSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.appAccent)
            Text("DocChat")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Color.textPrimary)
        }
    }

    @ViewBuilder
    private var centerControls: some View {
        if appState.currentDocument != nil {
            HStack(spacing: 8) {
                Image(systemName: appState.currentDocument!.fileType.icon)
                    .foregroundStyle(Color(appState.currentDocument!.fileType.tintColor))
                Text(appState.currentDocument!.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private var trailingControls: some View {
        HStack(spacing: 12) {
            uploadButton
            modelPicker
            settingsButton
        }
    }

    @ViewBuilder
    private var uploadButton: some View {
        Button {
            openFilePicker()
        } label: {
            Label("Open Document", systemImage: "plus.circle.fill")
                .font(.system(size: 13, weight: .medium))
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.appAccent)
        .controlSize(.small)
    }

    @ViewBuilder
    private var modelPicker: some View {
        Menu {
            ForEach(appState.availableModels, id: \.self) { model in
                Button {
                    appState.selectedModel = model
                } label: {
                    HStack {
                        Text(model)
                        if model == appState.selectedModel {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "cpu")
                Text(appState.selectedModel)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    @ViewBuilder
    private var settingsButton: some View {
        Button {
            appState.showSettings.toggle()
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 15))
                .foregroundStyle(Color.textSecondary)
        }
        .buttonStyle(.plain)
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf, .plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select a PDF, TXT, or Markdown file"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let ext = url.pathExtension.lowercased()
            let fileType: DocFileType
            switch ext {
            case "pdf": fileType = .pdf
            case "md", "markdown": fileType = .markdown
            default: fileType = .txt
            }
            let sizeStr = fileSizeString(url: url)
            let doc = ChatDocument(
                name: url.lastPathComponent,
                fileType: fileType,
                pageCount: 1,
                fileSize: sizeStr,
                url: url
            )
            appState.addDocument(doc)
        }
    }

    private func fileSizeString(url: URL) -> String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else { return "—" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
