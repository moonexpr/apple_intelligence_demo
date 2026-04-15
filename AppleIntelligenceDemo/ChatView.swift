import SwiftUI
import FoundationModels

// MARK: - View Model

@Observable
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isGenerating: Bool = false
    var errorMessage: String?

    // NOTE: Unverified API — LanguageModelSession init with system prompt builder pattern
    private var session = LanguageModelSession {
        "You are a friendly, concise assistant. Keep responses helpful and under a few paragraphs."
    }

    @MainActor
    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        inputText = ""
        isGenerating = true
        errorMessage = nil

        do {
            // NOTE: Unverified API — session.respond(to:) returns response with .content property
            let response = try await session.respond(to: text)
            let assistantMessage = ChatMessage(role: .assistant, content: response.content)
            messages.append(assistantMessage)
        } catch {
            errorMessage = formatError(error)
        }

        isGenerating = false
    }

    func clearChat() {
        messages.removeAll()
        errorMessage = nil
        // NOTE: Unverified API — re-creating session resets conversation context
        session = LanguageModelSession {
            "You are a friendly, concise assistant. Keep responses helpful and under a few paragraphs."
        }
    }

    private func formatError(_ error: Error) -> String {
        "The model failed to generate a response. This may happen if the on-device model is busy or the request was too complex. Try a simpler prompt or wait a moment.\n\nDetails: \(error.localizedDescription)"
    }
}

// MARK: - Data Model

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: MessageRole
    let content: String
    let timestamp = Date()

    enum MessageRole {
        case user, assistant
    }
}

// MARK: - Chat View

struct ChatView: View {
    @State private var viewModel = ChatViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.messages.isEmpty {
                    emptyState
                } else {
                    messageList
                }

                if let error = viewModel.errorMessage {
                    errorBanner(error)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                inputBar
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.errorMessage != nil)
            .navigationTitle("Chat")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        viewModel.clearChat()
                    } label: {
                        Label("New Chat", systemImage: "arrow.counterclockwise")
                    }
                    .disabled(viewModel.messages.isEmpty)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Start a Conversation", systemImage: "bubble.left.and.bubble.right")
        } description: {
            Text("Send a message to begin chatting with the on-device language model. The conversation context is preserved across turns.")
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        MessageBubbleView(message: message)
                            .id(message.id)
                    }

                    if viewModel.isGenerating {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Thinking...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .id("loading")
                    }
                }
                .padding(.vertical, 16)
                .animation(.spring(duration: 0.3, bounce: 0.2), value: viewModel.messages.count)
            }
            .onChange(of: viewModel.messages.count) {
                withAnimation(.easeOut(duration: 0.3)) {
                    if viewModel.isGenerating {
                        proxy.scrollTo("loading", anchor: .bottom)
                    } else if let last = viewModel.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.body)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Message", text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))

            Button {
                Task {
                    await viewModel.sendMessage()
                }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
            }
            .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isGenerating)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }
}

// MARK: - Message Bubble

private struct MessageBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .padding(12)
                    .foregroundStyle(isUser ? .white : .primary)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isUser ? AnyShapeStyle(Color.blue) : AnyShapeStyle(.regularMaterial))
                    )

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if message.role == .assistant { Spacer(minLength: 60) }
        }
        .padding(.horizontal)
        .transition(.asymmetric(insertion: .scale(scale: 0.95, anchor: .bottom).combined(with: .opacity), removal: .opacity))
    }

    private var isUser: Bool {
        message.role == .user
    }
}
