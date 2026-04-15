import ArgumentParser

@main
struct Siri: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "siri",
        abstract: "On-device AI assistant for text processing.",
        subcommands: [Ask.self, Summarize.self, Extract.self, Classify.self],
        defaultSubcommand: Ask.self
    )
}
