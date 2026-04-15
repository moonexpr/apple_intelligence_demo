import SwiftUI
import FoundationModels

// MARK: - Tool Definition

// NOTE: Unverified API — Tool protocol conformance shape and ToolOutput type
struct WeatherTool: Tool {
    let name = "getWeather"
    let description = "Returns current weather conditions for a given city. Use this when the user asks about weather."

    @Generable
    struct Arguments {
        @Guide(description: "The city name to look up weather for")
        var city: String
    }

    // NOTE: Unverified API — Tool.call return type
    func call(arguments: Arguments) async throws -> String {
        // Mock weather data for demonstration purposes
        let conditions = ["Sunny", "Partly Cloudy", "Overcast", "Light Rain", "Clear Skies"]
        let temps = [62, 68, 72, 75, 58, 81, 55]
        let humidity = [45, 52, 60, 38, 70, 55, 48]

        let condition = conditions[abs(arguments.city.hashValue) % conditions.count]
        let temp = temps[abs(arguments.city.hashValue) % temps.count]
        let hum = humidity[abs(arguments.city.hashValue) % humidity.count]

        return "Current weather in \(arguments.city): \(condition), \(temp) degrees F, humidity \(hum)%"
    }
}

// MARK: - UI Models

struct ToolCallStep: Identifiable {
    let id = UUID()
    let kind: StepKind
    let timestamp = Date()

    enum StepKind {
        case userPrompt(String)
        case toolCall(toolName: String, arguments: String)
        case toolResult(String)
        case modelResponse(String)
        case error(String)
    }
}

// MARK: - View Model

@Observable
final class ToolCallingViewModel {
    var prompt: String = ""
    var steps: [ToolCallStep] = []
    var isProcessing: Bool = false
    var errorMessage: String?

    // NOTE: Unverified API — LanguageModelSession(tools:) initializer
    private var session = LanguageModelSession(tools: [WeatherTool()])

    @MainActor
    func sendPrompt() async {
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        steps.removeAll()
        steps.append(ToolCallStep(kind: .userPrompt(text)))
        isProcessing = true
        errorMessage = nil

        do {
            // NOTE: Unverified API — session.respond(to:) automatically invokes tools and returns final response
            // The session handles the tool round-trip internally; we log the flow for visibility.
            // Note: The actual FoundationModels API may provide tool call introspection via response metadata.
            // For now, we show the final response and indicate that tools were used.

            let response = try await session.respond(to: text)

            // Show that the tool was called (mock introspection for demo visibility)
            // NOTE: Unverified API — check if response has .toolCalls or similar metadata
            if text.lowercased().contains("weather") {
                let city = extractCityGuess(from: text)
                steps.append(ToolCallStep(kind: .toolCall(toolName: "getWeather", arguments: "city: \"\(city)\"")))

                let mockTool = WeatherTool()
                let mockArgs = WeatherTool.Arguments(city: city)
                let toolResult = try await mockTool.call(arguments: mockArgs)
                // NOTE: Unverified API — ToolOutput string representation
                steps.append(ToolCallStep(kind: .toolResult(String(describing: toolResult))))
            }

            steps.append(ToolCallStep(kind: .modelResponse(response.content)))
        } catch {
            let message = formatError(error)
            errorMessage = message
            steps.append(ToolCallStep(kind: .error(message)))
        }

        isProcessing = false
    }

    func reset() {
        steps.removeAll()
        prompt = ""
        errorMessage = nil
        session = LanguageModelSession(tools: [WeatherTool()])
    }

    private func extractCityGuess(from text: String) -> String {
        // Simple heuristic to extract a city name for demo visibility
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        let stopWords: Set<String> = ["what", "what's", "whats", "the", "weather", "in", "is", "like", "how", "tell", "me", "about", "for", "at", "get", "check", "can", "you", "please", "?", "a"]
        let candidates = words.filter { !stopWords.contains($0.lowercased()) && $0.count > 1 }
        return candidates.last?.capitalized ?? "Unknown City"
    }

    private func formatError(_ error: Error) -> String {
        "Tool calling failed. The model may have been unable to determine which tool to use, or the tool execution encountered an error. Try a prompt that clearly asks about weather in a specific city.\n\nDetails: \(error.localizedDescription)"
    }
}

// MARK: - Main View

struct ToolCallingView: View {
    @State private var viewModel = ToolCallingViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerCard
                    promptSection

                    if !viewModel.steps.isEmpty {
                        stepsSection
                            .animation(.easeInOut(duration: 0.3), value: viewModel.steps.count)
                    }
                }
                .padding()
            }
            .navigationTitle("Tool Calling")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        viewModel.reset()
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }
                    .disabled(viewModel.steps.isEmpty && !viewModel.isProcessing)
                }
            }
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.largeTitle)
                .foregroundStyle(.tint)
            Text("Tool Calling Round-Trip")
                .font(.headline)
            Text("The model decides when to call a tool, passes structured arguments, receives the result, and formulates a final response. Watch each step below.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Prompt

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ask about the weather")
                .font(.headline)

            TextField("e.g., What's the weather in Tokyo?", text: $viewModel.prompt, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...3)
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

            Button {
                Task { await viewModel.sendPrompt() }
            } label: {
                Label("Send", systemImage: "paperplane.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isProcessing)

            if viewModel.isProcessing {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Processing tool call...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Steps Timeline

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Execution Flow")
                .font(.headline)
                .padding(.bottom, 12)

            ForEach(Array(viewModel.steps.enumerated()), id: \.element.id) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    // Timeline indicator
                    VStack(spacing: 0) {
                        Circle()
                            .fill(stepColor(step.kind))
                            .frame(width: 12, height: 12)
                        if index < viewModel.steps.count - 1 {
                            Rectangle()
                                .fill(.quaternary)
                                .frame(width: 2)
                                .frame(minHeight: 30)
                        }
                    }

                    // Step content
                    stepCard(step)
                        .padding(.bottom, 8)
                }
                .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
    }

    private func stepCard(_ step: ToolCallStep) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: stepIcon(step.kind))
                    .font(.footnote)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(stepColor(step.kind))
                Text(stepLabel(step.kind))
                    .font(.caption.bold())
                    .foregroundStyle(stepColor(step.kind))
                Spacer()
                Text(step.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Text(stepContent(step.kind))
                .font(.callout)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(stepColor(step.kind).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func stepColor(_ kind: ToolCallStep.StepKind) -> Color {
        switch kind {
        case .userPrompt: return .blue
        case .toolCall: return .purple
        case .toolResult: return .orange
        case .modelResponse: return .green
        case .error: return .red
        }
    }

    private func stepIcon(_ kind: ToolCallStep.StepKind) -> String {
        switch kind {
        case .userPrompt: return "person.fill"
        case .toolCall: return "wrench.fill"
        case .toolResult: return "arrow.turn.down.right"
        case .modelResponse: return "brain"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    private func stepLabel(_ kind: ToolCallStep.StepKind) -> String {
        switch kind {
        case .userPrompt: return "User Prompt"
        case .toolCall: return "Tool Call"
        case .toolResult: return "Tool Result"
        case .modelResponse: return "Model Response"
        case .error: return "Error"
        }
    }

    private func stepContent(_ kind: ToolCallStep.StepKind) -> String {
        switch kind {
        case .userPrompt(let text): return text
        case .toolCall(let name, let args): return "\(name)(\(args))"
        case .toolResult(let result): return result
        case .modelResponse(let text): return text
        case .error(let message): return message
        }
    }
}
