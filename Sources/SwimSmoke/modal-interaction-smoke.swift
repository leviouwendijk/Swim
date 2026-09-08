import Swim

enum SwimModalInteractionSmoke {
    static func run() throws {
        var interaction = ModalInteraction()

        guard interaction.mode == .normal else {
            throw SwimTestFailure(
                probe: "initial modal mode",
                expectation: "normal",
                observed: String(describing: interaction.mode)
            )
        }

        guard interaction.handle(
            .char("I")
        ) == .action(
            .command(
                .edit(
                    .insertAtFirstNonWhitespace
                )
            )
        ) else {
            throw SwimTestFailure(
                probe: "normal I command",
                expectation: "insert-at-first-non-whitespace command",
                observed: "unexpected interaction"
            )
        }

        guard interaction.handle(
            .char("i")
        ) == .action(
            .enterInsert(
                .beforeCursor
            )
        ),
        interaction.mode == .insert else {
            throw SwimTestFailure(
                probe: "enter insert mode",
                expectation: "insert before cursor",
                observed: String(describing: interaction.mode)
            )
        }

        guard interaction.handle(
            .char("x")
        ) == .action(
            .literal(
                .char("x")
            )
        ) else {
            throw SwimTestFailure(
                probe: "insert literal input",
                expectation: "literal Swim.Input.char(x)",
                observed: "unexpected interaction"
            )
        }

        guard interaction.handle(
            .escape
        ) == .action(
            .returnToNormal
        ),
        interaction.mode == .normal else {
            throw SwimTestFailure(
                probe: "return to normal",
                expectation: "normal",
                observed: String(describing: interaction.mode)
            )
        }

        guard interaction.handle(
            .char("u")
        ) == .action(
            .undo
        ),
        interaction.handle(
            .control("R")
        ) == .action(
            .redo
        ) else {
            throw SwimTestFailure(
                probe: "normal undo redo routing",
                expectation: "u -> undo and Ctrl-R -> redo",
                observed: "unexpected interaction"
            )
        }

        guard interaction.handle(
            .char("g")
        ) == .consumed,
        interaction.handle(
            .char("g")
        ) == .action(
            .command(
                .motion(
                    .documentStart,
                    count: 1
                )
            )
        ) else {
            throw SwimTestFailure(
                probe: "modal gg routing",
                expectation: "document-start command",
                observed: "unexpected interaction"
            )
        }

        guard interaction.handle(
            .char("2")
        ) == .consumed,
        interaction.handle(
            .char("3")
        ) == .consumed,
        interaction.handle(
            .char("j")
        ) == .action(
            .command(
                .motion(
                    .down,
                    count: 23
                )
            )
        ) else {
            throw SwimTestFailure(
                probe: "modal counted motion routing",
                expectation: "23j",
                observed: "unexpected interaction"
            )
        }

        guard interaction.handle(
            .control("V")
        ) == .action(
            .enterVisual(
                .block
            )
        ),
        interaction.mode == .visual,
        interaction.visualSelectionKind == .block else {
            throw SwimTestFailure(
                probe: "enter visual block",
                expectation: "visual block",
                observed: String(describing: interaction.visualSelectionKind)
            )
        }

        guard interaction.handle(
            .char("c")
        ) == .action(
            .enterBlockInsert(
                .change
            )
        ),
        interaction.mode == .insert,
        interaction.visualSelectionKind == nil else {
            throw SwimTestFailure(
                probe: "block change transition",
                expectation: "block change into insert mode",
                observed: String(describing: interaction.mode)
            )
        }

        guard interaction.handle(
            .escape
        ) == .action(
            .returnToNormal
        ),
        interaction.mode == .normal else {
            throw SwimTestFailure(
                probe: "block insert escape",
                expectation: "normal",
                observed: String(describing: interaction.mode)
            )
        }
    }
}
