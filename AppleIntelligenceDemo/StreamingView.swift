import SwiftUI
import FoundationModels

// MARK: - View Model

@Observable
final class StreamingViewModel {
    var prompt: String = ""
    var streamedText: String = ""
    var isStreaming: Bool = false
    var errorMessage: String?
    var hasResult: Bool = false

    private var session = LanguageModelSession()
    private var streamingTask: Task<Void, Never>?

    @MainActor
    func startStreaming() async {
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        streamedText = ""
        isStreaming = true
        hasResult = true
        errorMessage = nil

        streamingTask = Task {
            do {
                // NOTE: Unverified API — session.streamResponse(to:) returns AsyncSequence of partial responses
                let stream = session.streamResponse(to: text)
                for try await partial in stream {
                    if Task.isCancelled { break }
                    // NOTE: Unverified API — partial.content gives accumulated text so far
                    streamedText = partial.content
                }
            } catch is CancellationError {
                // User cancelled — no error to show
            } catch {
                errorMessage = formatError(error)
            }

            isStreaming = false
        }
    }

    func cancelStreaming() {
        streamingTask?.cancel()
        streamingTask = nil
        isStreaming = false
    }

    func reset() {
        cancelStreaming()
        streamedText = ""
        prompt = ""
        hasResult = false
        errorMessage = nil
        session = LanguageModelSession()
    }

    private func formatError(_ error: Error) -> String {
        "Streaming failed. The on-device model may be busy or the request was interrupted unexpectedly. Try again with a shorter prompt.\n\nDetails: \(error.localizedDescription)"
    }
}

// MARK: - Streaming View

struct StreamingView: View {
    @State private var viewModel = StreamingViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerCard
                    promptSection

                    if let error = viewModel.errorMessage {
                        errorCard(error)
                    }

                    if viewModel.hasResult {
                        resultSection
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding()
                .animation(.easeInOut(duration: 0.3), value: viewModel.hasResult)
            }
            .navigationTitle("Streaming")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        viewModel.reset()
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }
                    .disabled(!viewModel.hasResult && !viewModel.isStreaming)
                }
            }
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.word.spacing")
                .font(.largeTitle)
                .foregroundStyle(.tint)
            Text("Token-by-Token Streaming")
                .font(.headline)
            Text("Watch the model generate text incrementally using an async sequence. You can cancel mid-generation.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Prompt Section

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Prompt")
                .font(.headline)

            TextField("e.g., Write a short poem about the ocean", text: $viewModel.prompt, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(2...6)
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 12) {
                Button {
                    Task { await viewModel.startStreaming() }
                } label: {
                    Label("Generate", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isStreaming)

                if viewModel.isStreaming {
                    Button(role: .destructive) {
                        viewModel.cancelStreaming()
                    } label: {
                        Label("Cancel", systemImage: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.isStreaming)
        }
    }

    // MARK: - Result Section

    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Response")
                    .font(.headline)
                Spacer()
                if viewModel.isStreaming {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Streaming...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            }

            Text(viewModel.streamedText)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .animation(.easeOut(duration: 0.05), value: viewModel.streamedText)

            if !viewModel.streamedText.isEmpty {
                Text("\(viewModel.streamedText.count) characters")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Error Card

    private func errorCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text("Streaming Error")
                    .font(.caption.bold())
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        .transition(.opacity)
    }
}
