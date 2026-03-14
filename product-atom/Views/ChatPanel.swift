import SwiftUI
import AppKit

extension Notification.Name {
    static let focusChatInput = Notification.Name("focusChatInput")
}

// MARK: - Chat Panel

struct ChatPanel: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool
    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        VStack(spacing: 0) {
            chatToolbar
            Divider().opacity(0.3)
            messagesArea
            inputSection
        }
        .background(isDark ? Color(red: 0.055, green: 0.063, blue: 0.071) : Color.white)
        .onReceive(NotificationCenter.default.publisher(for: .focusChatInput)) { _ in
            isInputFocused = true
        }
        .onKeyPress("/") {
            NotificationCenter.default.post(name: .focusChatInput, object: nil)
            return .handled
        }
    }

    // MARK: - Toolbar
    @ViewBuilder
    private var chatToolbar: some View {
        HStack {
            Text("Assistant")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isDark ? Color(red: 0.902, green: 0.906, blue: 0.91) : Color(red: 0.1, green: 0.1, blue: 0.1))
            Spacer()
            processingStatus
            if !appState.messages.isEmpty {
                Button { appState.clearChat() } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(isDark ? Color.white : Color(red: 0.3, green: 0.3, blue: 0.3))
                }
                .buttonStyle(.plain).help("Clear chat")
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 16)
    }

    @ViewBuilder
    private var processingStatus: some View {
        switch appState.processingState {
        case .extracting:
            HStack(spacing: 5) {
                ProgressView().controlSize(.mini)
                Text("Extracting…").font(.system(size: 10))
                    .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
            }
        case .embedding(let p):
            HStack(spacing: 5) {
                ProgressView().controlSize(.mini)
                Text("Embedding \(Int(p * 100))%").font(.system(size: 10))
                    .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
            }
        case .failed(let msg):
            Text(msg).font(.system(size: 10))
                .foregroundStyle(Color(red: 1, green: 0.373, blue: 0.341)).lineLimit(1)
        default: EmptyView()
        }
    }

    // MARK: - Messages
    @ViewBuilder
    private var messagesArea: some View {
        if appState.messages.isEmpty {
            VStack(spacing: 0) {
                emptyChatState
                if appState.currentDocument != nil {
                    suggestionsRowInline
                        .padding(.bottom, 16)
                }
            }
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(appState.messages) { msg in
                            MessageBubbleView(message: msg).id(msg.id)
                        }
                        typingIndicator
                        Color.clear.frame(height: 8).id("bottom")
                    }
                    .padding(.horizontal, 20).padding(.vertical, 20)
                }
                // Streaming: scroll on every token (assistant message growing)
                .onChange(of: appState.streamingToken) { _, _ in
                    guard appState.isStreaming else { return }
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
                // Streaming ended → one final scroll to settle
                .onChange(of: appState.isStreaming) { _, streaming in
                    if !streaming {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo("bottom", anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var typingIndicator: some View {
        if appState.isStreaming {
            let lastContent = appState.messages.last?.content ?? ""
            if lastContent.isEmpty {
                TypingIndicatorView().id("typing")
            }
        }
    }

    @ViewBuilder
    private var emptyChatState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "text.bubble")
                .font(.system(size: 32))
                .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651).opacity(0.4))
            Text(appState.currentDocument != nil
                 ? "Ask a question about your document"
                 : "Open a document to start chatting")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Suggestions chips row (shown in empty state + input area)
    @ViewBuilder
    private var suggestionsRowInline: some View {
        let chips = ["Summarize this document", "Find important sections", "Highlight critical information"]
        VStack(spacing: 8) {
            ForEach(chips, id: \.self) { chip in
                Button {
                    inputText = ""
                    appState.sendMessage(chip)
                } label: {
                    Text(chip)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 100)
                            .strokeBorder(isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.1), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 100))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Input Section
    @ViewBuilder
    private var inputSection: some View {
        VStack(spacing: 6) {
            inputField
            // Show horizontal chips below input only when messages exist (otherwise vertical ones shown in empty state)
            if appState.currentDocument != nil && !appState.messages.isEmpty {
                suggestionsRow
            }
        }
        .padding(.top, 10)
        .padding(.bottom, appState.messages.isEmpty ? 12 : 0)
        .background(isDark ? Color.black.opacity(0.1) : Color.black.opacity(0.02))
        .overlay(alignment: .top) {
            Rectangle().fill(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)).frame(height: 1)
        }
    }

    @ViewBuilder
    private var inputField: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ChatInputField(text: $inputText, placeholder: "Ask about this document…", onSubmit: sendMessage)
                .frame(height: inputHeight)
                .padding(.leading, 10)
            Button {
                if appState.isStreaming {
                    appState.stopStreaming()
                } else {
                    sendMessage()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(appState.isStreaming
                              ? Color(red: 0.9, green: 0.25, blue: 0.2)
                              : (canSend ? Color(red: 0.039, green: 0.518, blue: 1)
                                         : Color(red: 0.604, green: 0.627, blue: 0.651).opacity(0.3)))
                        .frame(width: 32, height: 32)
                    Image(systemName: appState.isStreaming ? "stop.fill" : "arrow.up")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .disabled(!appState.isStreaming && !canSend)
            .padding(.trailing, 4).padding(.bottom, 4)
        }
        .padding(.horizontal, 4).padding(.vertical, 4)
        .background(isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
        .overlay(RoundedRectangle(cornerRadius: 16)
            .strokeBorder(isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.1), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
        .animation(.easeInOut(duration: 0.15), value: inputHeight)
    }

    /// Dynamically compute input height: single line until text wraps, max 120pt
    private var inputHeight: CGFloat {
        let singleLine: CGFloat = 35
        if inputText.isEmpty { return singleLine }
        let lineCount = inputText.components(separatedBy: "\n").count
        let estimatedLines = max(lineCount, inputText.count / 40 + 1)
        let h = singleLine + CGFloat(max(0, estimatedLines - 1)) * 18
        return min(h, 120)
    }

    @ViewBuilder
    private var suggestionsRow: some View {
        let chips = ["Explain more", "Give examples", "Action items"]
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(chips, id: \.self) { chip in
                    Button {
                        inputText = ""
                        appState.sendMessage(chip)
                    } label: {
                        Text(chip)
                            .font(.system(size: 11))
                            .foregroundStyle(Color(red: 0.604, green: 0.627, blue: 0.651))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.04))
                            .overlay(Capsule()
                                .strokeBorder(isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.1), lineWidth: 1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 12)
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !appState.isStreaming else { return }
        let toSend = trimmed
        inputText = ""
        appState.sendMessage(toSend)
    }
}

// MARK: - Native Chat Input
// Uses NSTextView directly. Placeholder is drawn via a separate NSTextField overlay.
// updateNSView NEVER touches tv.string while the user is editing to prevent cursor/reverse-text bugs.

struct ChatInputField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true

        // --- text view ---
        let scrollView = NSTextView.scrollableTextView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false

        guard let tv = scrollView.documentView as? NSTextView else { return container }
        tv.isRichText = false
        tv.font = .systemFont(ofSize: 13)
        tv.backgroundColor = .clear
        tv.drawsBackground = false
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.textContainerInset = NSSize(width: 0, height: 8)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.textContainer?.widthTracksTextView = true
        tv.delegate = context.coordinator
        context.coordinator.textView = tv

        // --- placeholder label ---
        let ph = NSTextField(labelWithString: placeholder)
        ph.translatesAutoresizingMaskIntoConstraints = false
        ph.font = .systemFont(ofSize: 13)
        ph.textColor = .placeholderTextColor
        ph.backgroundColor = .clear
        ph.isBezeled = false
        ph.isEditable = false
        ph.isSelectable = false
        ph.cell?.lineBreakMode = .byTruncatingTail
        context.coordinator.placeholderField = ph

        // Clickable container so clicking anywhere in the field focuses it
        let clickable = ClickableInputContainer()
        clickable.translatesAutoresizingMaskIntoConstraints = false
        clickable.wantsLayer = true
        clickable.targetTextView = tv
        container.addSubview(scrollView)
        container.addSubview(ph)
        container.addSubview(clickable)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            ph.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 5),
            ph.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -5),
            ph.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            clickable.topAnchor.constraint(equalTo: container.topAnchor),
            clickable.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            clickable.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            clickable.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])

        // Sync initial state
        if !text.isEmpty {
            tv.string = text
            ph.isHidden = true
        } else {
            ph.isHidden = false
        }

        NotificationCenter.default.addObserver(
            context.coordinator, selector: #selector(Coordinator.focusFromNotification),
            name: .focusChatInput, object: nil
        )
        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        guard let tv = context.coordinator.textView,
              let ph = context.coordinator.placeholderField else { return }

        // Only update the text view when NOT actively editing to avoid cursor corruption
        if !context.coordinator.isEditing {
            if tv.string != text {
                tv.string = text
            }
            ph.isHidden = !text.isEmpty
        }
    }

    class ClickableInputContainer: NSView {
        weak var targetTextView: NSTextView?
        override func mouseDown(with event: NSEvent) {
            // Only focus if the text view itself isn't already first responder
            if let tv = targetTextView, window?.firstResponder !== tv {
                window?.makeFirstResponder(tv)
            } else {
                super.mouseDown(with: event)
            }
        }
        // Pass through hit-testing so scroll/selection still works inside the text view
        override func hitTest(_ point: NSPoint) -> NSView? {
            // Return self only when the point is not inside the scrollView's text view
            let sub = super.hitTest(point)
            if sub == self { return self }
            return sub
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ChatInputField
        weak var textView: NSTextView?
        weak var placeholderField: NSTextField?
        var isEditing = false

        init(_ parent: ChatInputField) { self.parent = parent }

        func textDidBeginEditing(_ notification: Notification) {
            isEditing = true
            placeholderField?.isHidden = true
        }

        func textDidEndEditing(_ notification: Notification) {
            isEditing = false
            guard let tv = notification.object as? NSTextView else { return }
            placeholderField?.isHidden = !tv.string.isEmpty
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            let current = tv.string
            // Update binding on main thread without re-triggering updateNSView mid-keystroke
            DispatchQueue.main.async { [weak self] in
                self?.parent.text = current
                self?.placeholderField?.isHidden = !current.isEmpty
            }
        }

        func textView(_ tv: NSTextView, doCommandBy sel: Selector) -> Bool {
            if sel == #selector(NSResponder.insertNewline(_:)) {
                if NSEvent.modifierFlags.contains(.shift) {
                    tv.insertNewlineIgnoringFieldEditor(nil)
                    return true
                }
                let trimmed = tv.string.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return true }
                // Clear the text view immediately before calling onSubmit
                tv.string = ""
                DispatchQueue.main.async { [weak self] in
                    self?.parent.text = ""
                    self?.placeholderField?.isHidden = false
                }
                parent.onSubmit()
                return true
            }
            return false
        }

        @objc func focusFromNotification() {
            textView?.window?.makeFirstResponder(textView)
        }
    }
}

// MARK: - Message Bubble

struct MessageBubbleView: View {
    @EnvironmentObject var appState: AppState
    let message: ChatMessage
    @Environment(\.colorScheme) var colorScheme
    private var isDark: Bool { colorScheme == .dark }
    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            if isUser { Spacer(minLength: 60) }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                bubbleContent
                if !message.sourcePages.isEmpty && !isUser { pageReferences }
            }
            if !isUser { Spacer(minLength: 40) }
        }
    }

    @ViewBuilder
    private var bubbleContent: some View {
        if isUser {
            Text(message.content)
                .font(.system(size: 13)).foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 11)
                .background(Color(red: 0.039, green: 0.518, blue: 1))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .frame(maxWidth: 260, alignment: .trailing)
        } else if !message.content.isEmpty {
            FormattedResponseView(text: message.content, isStreaming: message.isStreaming)
                .padding(.horizontal, 12).padding(.vertical, 11)
                .background(isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .frame(maxWidth: 280, alignment: .leading)
        }
    }

    @ViewBuilder
    private var pageReferences: some View {
        HStack(spacing: 4) {
            ForEach(message.sourcePages.prefix(4), id: \.self) { page in
                Button { appState.jumpToPage = page } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "doc.text").font(.system(size: 8))
                        Text("Page \(page)").font(.system(size: 11))
                    }
                    .foregroundStyle(Color(red: 0.039, green: 0.518, blue: 1))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(isDark
                        ? Color(red: 0.039, green: 0.518, blue: 1).opacity(0.15)
                        : Color(red: 0.039, green: 0.518, blue: 1).opacity(0.10))
                    .overlay(Capsule()
                        .strokeBorder(Color(red: 0.039, green: 0.518, blue: 1).opacity(isDark ? 0.3 : 0.25), lineWidth: 1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Formatted Response

struct FormattedResponseView: View {
    let text: String
    let isStreaming: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let attr = try? AttributedString(
                markdown: text,
                options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            ) {
                Text(attr)
                    .font(.system(size: 13)).foregroundStyle(Color.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(text)
                    .font(.system(size: 13)).foregroundStyle(Color.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if isStreaming && !text.isEmpty {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(red: 0.039, green: 0.518, blue: 1))
                    .frame(width: 6, height: 13).opacity(0.8)
            }
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicatorView: View {
    @State private var dotPhase = 0
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color(red: 0.039, green: 0.518, blue: 1)
                            .opacity(dotPhase == i ? 0.9 : 0.25))
                        .frame(width: 6, height: 6)
                        .animation(.easeInOut(duration: 0.4).delay(Double(i) * 0.15), value: dotPhase)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            Spacer()
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                dotPhase = (dotPhase + 1) % 3
            }
        }
    }
}
