import Swim

enum SwimExCommandLineSmoke {
    static func run() throws {
        var interaction = ModalInteraction()

        guard interaction.handle(
            .char(":")
        ) == .action(
            .enterCommandLine
        ) else {
            throw SwimTestFailure(
                probe: "normal colon enters ex command line",
                expectation: "enterCommandLine action",
                observed: "unexpected interaction"
            )
        }

        var commandLine = ExCommandLine()

        commandLine.begin()

        guard commandLine.isActive,
              commandLine.handle(
                .char("w")
              ) == .editing,
              commandLine.handle(
                .enter
              ) == .command(
                .write
              ),
              !commandLine.isActive else {
            throw SwimTestFailure(
                probe: "ex write command",
                expectation: ":w resolves to write and closes command line",
                observed: String(
                    describing: commandLine
                )
            )
        }

        commandLine.begin()

        guard commandLine.handle(
            .char("q")
        ) == .editing,
        commandLine.handle(
            .enter
        ) == .command(
            .quit
        ) else {
            throw SwimTestFailure(
                probe: "ex quit command",
                expectation: ":q resolves to quit",
                observed: String(
                    describing: commandLine
                )
            )
        }

        commandLine.begin()
        _ = commandLine.handle(
            .char("nope")
        )

        guard commandLine.handle(
            .enter
        ) == .invalid(
            "nope"
        ) else {
            throw SwimTestFailure(
                probe: "invalid ex command",
                expectation: "invalid(nope)",
                observed: "unexpected result"
            )
        }

        commandLine.begin()

        guard commandLine.handle(
            .escape
        ) == .cancelled,
        !commandLine.isActive else {
            throw SwimTestFailure(
                probe: "ex command cancellation",
                expectation: "escape cancels and closes command line",
                observed: String(
                    describing: commandLine
                )
            )
        }
    }
}
