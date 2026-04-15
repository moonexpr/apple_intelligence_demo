import Foundation
import FoundationModels

/// Global verbose flag — set via SIRI_VERBOSE=1 env var or --verbose on subcommands.
var siriVerbose: Bool {
    ProcessInfo.processInfo.environment["SIRI_VERBOSE"] != nil
}

func debugLog(_ message: @autoclosure () -> String) {
    guard siriVerbose else { return }
    FileHandle.standardError.write(Data("[siri] \(message())\n".utf8))
}

func dumpTranscript(_ session: LanguageModelSession) {
    guard siriVerbose else { return }
    let transcript = session.transcript
    FileHandle.standardError.write(Data("[siri] transcript: \(transcript)\n".utf8))
}

/// Read all of stdin as a trimmed string. Fails if stdin is a TTY or empty.
func readStdin() throws -> String {
    guard isatty(STDIN_FILENO) == 0 else {
        throw SiriError.noStdin
    }
    let data = FileHandle.standardInput.readDataToEndOfFile()
    guard let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
          !text.isEmpty else {
        throw SiriError.emptyStdin
    }

    if data.count > 16_384 {
        FileHandle.standardError.write(Data("WARN: Input is \(data.count) bytes — on-device model may truncate.\n".utf8))
    }

    return text
}

/// Encode any Encodable value as pretty-printed JSON to stdout.
func emitJSON<T: Encodable>(_ value: T) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(value)
    guard let json = String(data: data, encoding: .utf8) else {
        throw SiriError.encodingFailed
    }
    print(json)
}

// MARK: - Session management

/// Run a single prompt against a fresh, isolated session. The session is created
/// and discarded within this scope to minimize on-device context accumulation.
/// The underlying FoundationModels daemon may retain context across sessions —
/// keeping sessions short-lived and single-use is the best mitigation.
func runIsolated(system: String, prompt: String) async throws -> String {
    debugLog("creating session (system: \(system.prefix(60))...)")
    let start = ContinuousClock.now
    let session = LanguageModelSession { system }
    let response = try await session.respond(to: prompt)
    debugLog("responded in \(ContinuousClock.now - start)")
    dumpTranscript(session)
    return response.content
}

/// Run a structured output generation against a fresh, isolated session.
func generateIsolated<T: Generable>(
    system: String,
    prompt: String,
    generating type: T.Type
) async throws -> T {
    debugLog("creating session for \(T.self) (system: \(system.prefix(60))...)")
    let start = ContinuousClock.now
    let session = LanguageModelSession { system }
    let response = try await session.respond(generating: type) { prompt }
    debugLog("generated \(T.self) in \(ContinuousClock.now - start)")
    dumpTranscript(session)
    return response.content
}

enum SiriError: Error, CustomStringConvertible {
    case noStdin
    case emptyStdin
    case encodingFailed
    case emptyPrompt

    var description: String {
        switch self {
        case .noStdin:
            return "This subcommand reads from stdin. Pipe input to it."
        case .emptyStdin:
            return "stdin was empty."
        case .encodingFailed:
            return "Failed to encode output as JSON."
        case .emptyPrompt:
            return "Prompt is empty."
        }
    }
}
