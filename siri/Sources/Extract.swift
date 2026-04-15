import Foundation
import FoundationModels
import ArgumentParser

// MARK: - Generable Output Type

// NOTE: Unverified API — @Generable macro (macOS 26 beta)

@Generable
struct ExtractionOutput: Encodable {
    @Guide(description: "The heading or title of the extracted section")
    var sectionTitle: String

    @Guide(description: "The full content of the requested section, preserving original structure and formatting")
    var content: String

    @Guide(description: "Whether the requested section was found in the input")
    var found: Bool
}

// MARK: - Subcommand

struct Extract: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Extract a named section from markdown text on stdin."
    )

    @Option(name: .long, help: "The section heading to extract (e.g., \"Phase 2\").")
    var section: String

    @Option(name: .long, help: "System prompt override.")
    var system: String = "You are a precise text extraction engine. Extract the markdown section that best matches the requested heading. Include all content under that heading until the next heading of equal or higher level. Preserve the original formatting exactly. If the section is not found, set found to false and leave content empty."

    mutating func run() async throws {
        let input = try readStdin()

        do {
            let prompt = "Extract the section titled \"\(section)\" from the following document:\n\n\(input)"
            try emitJSON(try await generateIsolated(system: system, prompt: prompt, generating: ExtractionOutput.self))
        } catch {
            FileHandle.standardError.write(Data("Error: \(error.localizedDescription)\n".utf8))
            throw ExitCode.failure
        }
    }
}
