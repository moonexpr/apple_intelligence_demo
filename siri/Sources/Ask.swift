import Foundation
import FoundationModels
import ArgumentParser

struct Ask: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Send a prompt and get a plain text response (default)."
    )

    @Argument(help: "The prompt to send to the model.")
    var prompt: String?

    @Option(name: .long, help: "System prompt for the model session.")
    var system: String = "You are Siri, an Apple Intelligence assistant invoked from the command line. You are being called as a helper tool by Claude, an AI assistant. Provide direct, concise answers. No markdown formatting. Plain text only."

    mutating func run() async throws {
        let promptText: String

        if let prompt = prompt {
            promptText = prompt
        } else if isatty(STDIN_FILENO) == 0 {
            let data = FileHandle.standardInput.readDataToEndOfFile()
            promptText = String(data: data, encoding: .utf8) ?? ""
        } else {
            FileHandle.standardError.write(Data("Error: No prompt provided. Pass as argument or pipe via stdin.\n".utf8))
            throw ExitCode.failure
        }

        let trimmed = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            FileHandle.standardError.write(Data("Error: Prompt is empty.\n".utf8))
            throw ExitCode.failure
        }

        do {
            let result = try await runIsolated(system: system, prompt: trimmed)
            print(result)
        } catch {
            FileHandle.standardError.write(Data("Error: \(error.localizedDescription)\n".utf8))
            throw ExitCode.failure
        }
    }
}
