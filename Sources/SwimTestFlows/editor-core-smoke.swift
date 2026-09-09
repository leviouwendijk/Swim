import Position
import Swim
import SwimInterpreter

enum SwimEditorCoreSmoke {
    enum Failure:
        Error
    {
        case insertHistory
        case undoRedo
        case copyEvent
        case operatorDelete
        case blockMotion
        case blockChange
        case commandLine
    }

    static func run() throws {
        try runInsertHistoryProbe()
        try runCopyProbe()
        try runOperatorProbe()
        try runBlockMotionProbe()
        try runBlockChangeProbe()
        try runCommandLineProbe()
    }

    private static func runInsertHistoryProbe() throws {
        var editor = SwimEditor(
            cursor: PositionIndex(0)
        )

        guard editor.handle(
            .char("i")
        ) == .changed,
        editor.handle(
            .char("a")
        ) == .changed,
        editor.handle(
            .char("b")
        ) == .changed,
        editor.handle(
            .escape
        ) == .changed,
        editor.buffer.text == "ab",
        editor.mode == .normal,
        editor.history.undoDepth == 1 else {
            throw Failure.insertHistory
        }

        guard editor.handle(
            .char("u")
        ) == .changed,
        editor.buffer.text.isEmpty,
        editor.handle(
            .control("R")
        ) == .changed,
        editor.buffer.text == "ab" else {
            throw Failure.undoRedo
        }
    }

    private static func runCopyProbe() throws {
        var editor = SwimEditor(
            text: "abc",
            cursor: PositionIndex(0)
        )

        guard editor.handle(
            .char("v")
        ) == .changed,
        case .copyRequested(let copy)? = editor.handle(
            .char("y")
        ),
        copy.text == "a",
        copy.sourceRanges == [
            PositionRange(
                0..<1
            ),
        ],
        editor.registers.unnamed == .character(
            "a"
        ),
        editor.mode == .normal,
        editor.selection == nil else {
            throw Failure.copyEvent
        }
    }

    private static func runOperatorProbe() throws {
        var editor = SwimEditor(
            text: "alpha beta",
            cursor: PositionIndex(0)
        )

        guard editor.handle(
            .char("d")
        ) == nil,
        editor.handle(
            .char("w")
        ) == .changed,
        editor.buffer.text != "alpha beta",
        editor.registers.unnamed != nil else {
            throw Failure.operatorDelete
        }
    }

    private static func runBlockMotionProbe() throws {
        var editor = SwimEditor(
            text: "a\tb\nx界z",
            cursor: PositionIndex(1)
        )
        let context = SwimEditorContext(
            displayColumns:
                SwimHeadlessDisplayColumnMappingProvider(
                    tabWidth: 4
                ) { character in
                    character == "界"
                        ? 2
                        : 1
                }
        )

        guard editor.handle(
            .control("V"),
            context: context
        ) == .changed,
        editor.selection?.kind == .block,
        editor.handle(
            .down,
            context: context
        ) == .changed,
        editor.buffer.cursorPosition.line == 2,
        editor.selection?.blockPreferredColumn == 1 else {
            throw Failure.blockMotion
        }
    }

    private static func runBlockChangeProbe() throws {
        var editor = SwimEditor(
            text: "abcd\nwxyz",
            cursor: PositionIndex(1)
        )

        guard editor.handle(
            .control("V")
        ) == .changed,
        editor.handle(
            .down
        ) == .changed,
        editor.handle(
            .char("c")
        ) == .changed,
        editor.mode == .insert,
        editor.registers.unnamed == .block([
            "b",
            "x",
        ]),
        editor.handle(
            .char("Q")
        ) == .changed,
        editor.handle(
            .escape
        ) == .changed,
        editor.buffer.text == "aQcd\nwQyz",
        editor.history.undoDepth == 1 else {
            throw Failure.blockChange
        }
    }

    private static func runCommandLineProbe() throws {
        var editor = SwimEditor(
            text: "abc",
            cursor: PositionIndex(0)
        )

        guard editor.handle(
            .char(":")
        ) == .commandLineRequested else {
            throw Failure.commandLine
        }
    }
}
