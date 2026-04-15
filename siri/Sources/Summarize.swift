import Foundation
import FoundationModels
import ArgumentParser

// MARK: - Generable Output Types

// NOTE: Unverified API — @Generable macro and @Guide constraints (macOS 26 beta)

@Generable
struct SummaryCompact: Encodable {
    @Guide(description: "One-sentence overall status")
    var status: String

    @Guide(description: "Key points, most important first", .count(3))
    var keyPoints: [String]

    @Guide(description: "Items requiring attention or action")
    var actionItems: [String]

    @Guide(description: "Items that are complete")
    var completedItems: [String]
}

@Generable
struct SummaryNormal: Encodable {
    @Guide(description: "One-sentence overall status")
    var status: String

    @Guide(description: "Key points, most important first", .count(5))
    var keyPoints: [String]

    @Guide(description: "Items requiring attention or action")
    var actionItems: [String]

    @Guide(description: "Items that are complete")
    var completedItems: [String]
}

@Generable
struct SummaryDetailed: Encodable {
    @Guide(description: "One-sentence overall status")
    var status: String

    @Guide(description: "Key points, most important first", .count(8))
    var keyPoints: [String]

    @Guide(description: "Items requiring attention or action")
    var actionItems: [String]

    @Guide(description: "Items that are complete")
    var completedItems: [String]
}

// MARK: - Subcommand

struct Summarize: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Summarize text from stdin into a structured JSON summary."
    )

    @Option(name: .long, help: "Maximum key points: 3 (compact), 5 (normal), or 8 (detailed).")
    var maxPoints: Int = 5

    @Option(name: .long, help: "System prompt override.")
    var system: String = "You are a summarization engine. Read the input and produce a structured summary. Focus on active, incomplete, or blocked items first. Completed items are secondary. Be precise — do not invent information not present in the input."

    mutating func run() async throws {
        let input = try readStdin()

        do {
            switch maxPoints {
            case ...3:
                try emitJSON(try await generateIsolated(system: system, prompt: input, generating: SummaryCompact.self))
            case 6...:
                try emitJSON(try await generateIsolated(system: system, prompt: input, generating: SummaryDetailed.self))
            default:
                try emitJSON(try await generateIsolated(system: system, prompt: input, generating: SummaryNormal.self))
            }
        } catch {
            FileHandle.standardError.write(Data("Error: \(error.localizedDescription)\n".utf8))
            throw ExitCode.failure
        }
    }
}
