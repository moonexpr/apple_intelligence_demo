import SwiftUI
import FoundationModels

// MARK: - Generable Model

// NOTE: Unverified API — @Generable macro and @Guide constraints
@Generable
struct RecipeOutput {
    @Guide(description: "Name of the dish")
    var name: String

    @Guide(description: "Brief description of the dish in one sentence")
    var summary: String

    @Guide(description: "List of ingredients needed", .count(4...8))
    var ingredients: [String]

    @Guide(description: "Step-by-step cooking instructions")
    var instructions: [String]

    @Guide(.range(1...60))
    var prepTimeMinutes: Int

    @Guide(.range(1...5))
    var difficulty: Int
}

// MARK: - View Model

@Observable
final class StructuredOutputViewModel {
    var prompt: String = ""
    var recipe: RecipeOutput?
    var isGenerating: Bool = false
    var errorMessage: String?

    private var session = LanguageModelSession()

    @MainActor
    func generate() async {
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        recipe = nil
        isGenerating = true
        errorMessage = nil

        do {
            // NOTE: Unverified API — session.respond(generating:) with trailing prompt closure
            let result = try await session.respond(generating: RecipeOutput.self) { text }
            recipe = result.content
        } catch {
            errorMessage = formatError(error)
        }

        isGenerating = false
    }

    func reset() {
        recipe = nil
        prompt = ""
        errorMessage = nil
        session = LanguageModelSession()
    }

    private func formatError(_ error: Error) -> String {
        "Failed to generate structured output. The model may have been unable to produce a response matching the required schema. Try a more specific recipe prompt.\n\nDetails: \(error.localizedDescription)"
    }
}

// MARK: - Main View

struct StructuredOutputView: View {
    @State private var viewModel = StructuredOutputViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerCard
                    promptSection

                    if let error = viewModel.errorMessage {
                        errorCard(error)
                    }

                    if viewModel.isGenerating {
                        loadingCard
                            .transition(.opacity)
                    }

                    if let recipe = viewModel.recipe {
                        RecipeCardView(recipe: recipe)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    }
                }
                .padding()
                .animation(.easeInOut(duration: 0.35), value: viewModel.recipe != nil)
                .animation(.easeInOut(duration: 0.25), value: viewModel.isGenerating)
            }
            .navigationTitle("Structured Output")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        viewModel.reset()
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }
                    .disabled(viewModel.recipe == nil && !viewModel.isGenerating)
                }
            }
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "list.bullet.rectangle")
                .font(.largeTitle)
                .foregroundStyle(.tint)
            Text("Typed Structured Output")
                .font(.headline)
            Text("The model generates a strongly-typed Swift struct using @Generable. No JSON parsing needed — the result is a native RecipeOutput value.")
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
            Text("What recipe would you like?")
                .font(.headline)

            TextField("e.g., A quick weeknight pasta with garlic and lemon", text: $viewModel.prompt, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(2...4)
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

            Button {
                Task { await viewModel.generate() }
            } label: {
                Label("Generate Recipe", systemImage: "wand.and.stars")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isGenerating)
        }
    }

    // MARK: - Loading

    private var loadingCard: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("Generating structured recipe...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Error

    private func errorCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text("Generation Failed")
                    .font(.caption.bold())
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Recipe Card

private struct RecipeCardView: View {
    let recipe: RecipeOutput

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title Row
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.name)
                        .font(.title2.bold())
                    Text(recipe.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider()

            // Metadata Row
            HStack(spacing: 20) {
                metadataItem(
                    icon: "clock",
                    label: "\(recipe.prepTimeMinutes) min",
                    caption: "Prep Time"
                )
                metadataItem(
                    icon: "flame",
                    label: difficultyLabel(recipe.difficulty),
                    caption: "Difficulty"
                )
                metadataItem(
                    icon: "basket",
                    label: "\(recipe.ingredients.count)",
                    caption: "Ingredients"
                )
            }
            .frame(maxWidth: .infinity)

            Divider()

            // Ingredients
            VStack(alignment: .leading, spacing: 8) {
                Label("Ingredients", systemImage: "basket.fill")
                    .font(.headline)
                    .symbolRenderingMode(.hierarchical)

                ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { _, ingredient in
                    HStack(spacing: 8) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 5))
                            .foregroundStyle(.secondary)
                        Text(ingredient)
                            .font(.body)
                    }
                }
            }

            Divider()

            // Instructions
            VStack(alignment: .leading, spacing: 10) {
                Label("Instructions", systemImage: "list.number")
                    .font(.headline)
                    .symbolRenderingMode(.hierarchical)

                ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(.blue, in: Circle())

                        Text(step)
                            .font(.body)
                    }
                }
            }

            // Difficulty Stars
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= recipe.difficulty ? "star.fill" : "star")
                        .foregroundStyle(star <= recipe.difficulty ? Color.yellow : Color.secondary.opacity(0.3))
                        .font(.caption)
                }
                Text("Difficulty")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 4)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func metadataItem(icon: String, label: String, caption: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
            Text(label)
                .font(.subheadline.bold())
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func difficultyLabel(_ level: Int) -> String {
        switch level {
        case 1: return "Easy"
        case 2: return "Simple"
        case 3: return "Medium"
        case 4: return "Hard"
        case 5: return "Expert"
        default: return "Unknown"
        }
    }
}
