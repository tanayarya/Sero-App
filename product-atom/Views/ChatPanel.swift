import SwiftUI

struct ChatPanel: View {
    @EnvironmentObject var appState: AppState
    @State private var inputText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            chatToolbar
            Divider()
            messagesList
            Divider()
            inputBar
        }
        .background(Color.surfaceChat)
    }

    @ViewBuilder
    private var chatToolbar: some View {
        HStack {
            Text("Chat")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
            Spacer()
            Button {
                appState.clearChat()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderless)
            .disabled(appState.messages.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var messagesList: some View {
        if appState.messages.isEmpty {
            emptyChatState
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(appState.messages) { msg in
                        MessageBubble(message: msg)
                    }
                }
                .padding(16)
            }
        }
    }

    @ViewBuilder
    private var emptyChatState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 36))
                .foregroundStyle(Color.appAccent.opacity(0.4))
            Text("Ask a question about your document")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.textSecondary)
            VStack(spacing: 6) {
                suggestChip("Summarize the key points")
                suggestChip("What are the main topics?")
                suggestChip("Explain the conclusion")
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func suggestChip(_ text: String) -> some View {
        Button {
            inputText = text
        } label: {
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(Color.appAccent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.appAccentLight)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask about your document…", text: $inputText)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .onSubmit { sendMessage() }
            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(inputText.isEmpty ? Color.textTertiary : Color.appAccent)
            }
            .buttonStyle(.plain)
            .disabled(inputText.isEmpty)
        }
        .padding(12)
    }

    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let userMsg = ChatMessage(role: .user, content: inputText)
        appState.messages.append(userMsg)

        let reply = ChatMessage(
            role: .assistant,
            content: "This is a placeholder response. Once connected to Ollama, I'll retrieve relevant sections from your document and generate a contextual answer.",
            sourcePage: 1
        )
        let trimmed = inputText
        inputText = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            _ = trimmed
            appState.messages.append(reply)
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }
            bubbleContent
            if message.role == .assistant { Spacer(minLength: 60) }
        }
    }

    @ViewBuilder
    private var bubbleContent: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
            Text(message.content)
                .font(.system(size: 13))
                .foregroundStyle(message.role == .user ? .white : Color.textPrimary)
                .padding(12)
                .background(message.role == .user ? Color.appAccent : Color.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            if let page = message.sourcePage, message.role == .assistant {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 9))
                    Text("Page \(page)")
                        .font(.system(size: 10))
                }
                .foregroundStyle(Color.textTertiary)
                .padding(.leading, 4)
            }
        }
    }
}
