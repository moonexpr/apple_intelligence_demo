import Foundation
import FoundationModels
import ArgumentParser

// MARK: - Generable Output Type

// NOTE: Unverified API — @Generable macro (macOS 26 beta)

@Generable
struct ClassificationOutput: Encodable {
    @Guide(description: "The chosen category from the provided options")
    var category: String

    @Guide(description: "Confidence level: high, medium, or low")
    var confidence: String

    @Guide(description: "One-sentence reasoning for the classification")
    var reasoning: String
}

// MARK: - Subcommand

struct Classify: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Classify text from stdin into one of the given categories."
    )

    @Option(name: .long, help: "Comma-separated categories. Plain labels (\"a,b,c\") or label=description pairs (\"a=Desc one,b=Desc two\").")
    var categories: String

    @Option(name: .long, help: "System prompt override.")
    var system: String = "You are a classification engine. Read the input text and assign it to exactly one of the provided categories. Choose the single best match based on the category definitions. Be concise in your reasoning."

    mutating func run() async throws {
        let input = try readStdin()
        let parsed = parseCategories(categories)

        guard !parsed.isEmpty else {
            FileHandle.standardError.write(Data("Error: --categories must contain at least one category.\n".utf8))
            throw ExitCode.failure
        }

        do {
            let categoryBlock = parsed.map { entry in
                if let description = entry.description {
                    return "- \(entry.label): \(description)"
                } else {
                    return "- \(entry.label)"
                }
            }.joined(separator: "\n")

            let prompt = "Classify the following text into exactly one of these categories:\n\(categoryBlock)\n\nText:\n\(input)"
            try emitJSON(try await generateIsolated(system: system, prompt: prompt, generating: ClassificationOutput.self))
        } catch {
            FileHandle.standardError.write(Data("Error: \(error.localizedDescription)\n".utf8))
            throw ExitCode.failure
        }
    }

    /// Parse "a=Desc one,b=Desc two" or plain "a,b,c" into structured entries.
    private func parseCategories(_ raw: String) -> [(label: String, description: String?)] {
        raw.split(separator: ",").compactMap { segment in
            let trimmed = segment.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }
            if let eqIndex = trimmed.firstIndex(of: "=") {
                let label = String(trimmed[trimmed.startIndex..<eqIndex]).trimmingCharacters(in: .whitespaces)
                let desc = String(trimmed[trimmed.index(after: eqIndex)...]).trimmingCharacters(in: .whitespaces)
                return (label: label, description: desc.isEmpty ? nil : desc)
            } else {
                return (label: trimmed, description: nil)
            }
        }
    }
}
