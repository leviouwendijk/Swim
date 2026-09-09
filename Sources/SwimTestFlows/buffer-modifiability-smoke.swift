import Position
import Swim

enum SwimBufferModifiabilitySmoke {
    enum Failure:
        Error
    {
        case navigation
        case yank
        case editing
        case hostReplacement
        case hostAppend
        case editingMode
    }

    static func run() throws {
        try runNavigationProbe()
        try runYankProbe()
        try runEditingProbe()
        try runHostReplacementProbe()
        try runHostAppendProbe()
        try runEditingModeProbe()
    }

    private static func runNavigationProbe() throws {
        var editor = SwimEditor(
            text: "abc",
            cursor: PositionIndex(0),
            bufferModifiability: .nonmodifiable
        )

        guard editor.handle(
            .char("l")
        ) == .changed,
        editor.buffer.cursor == PositionIndex(1),
        editor.buffer.text == "abc" else {
            throw Failure.navigation
        }
    }

    private static func runYankProbe() throws {
        var editor = SwimEditor(
            text: "abc",
            cursor: PositionIndex(0),
            bufferModifiability: .nonmodifiable
        )

        guard editor.handle(
            .char("v")
        ) == .changed,
        case .copyRequested(let copy)? = editor.handle(
            .char("y")
        ),
        copy.text == "a",
        editor.registers.unnamed == .character(
            "a"
        ),
        editor.buffer.text == "abc" else {
            throw Failure.yank
        }
    }

    private static func runEditingProbe() throws {
        var editor = SwimEditor(
            text: "alpha beta",
            cursor: PositionIndex(0),
            bufferModifiability: .nonmodifiable
        )

        guard editor.handle(
            .char("i")
        ) == .changed,
        editor.mode == .normal,
        editor.buffer.text == "alpha beta",
        editor.handle(
            .char("x")
        ) == .changed,
        editor.buffer.text == "alpha beta",
        editor.handle(
            .char("d")
        ) == nil,
        editor.handle(
            .char("w")
        ) == .changed,
        editor.buffer.text == "alpha beta",
        editor.handle(
            .char("p")
        ) == .changed,
        editor.buffer.text == "alpha beta",
        editor.paste(
            "!"
        ) == nil,
        editor.buffer.text == "alpha beta",
        editor.history.undoDepth == 0 else {
            throw Failure.editing
        }
    }

    private static func runHostReplacementProbe() throws {
        var editor = SwimEditor(
            text: "old",
            cursor: PositionIndex(0),
            bufferModifiability: .nonmodifiable
        )

        editor.replace(
            with: "streamed",
            cursor: PositionIndex(3)
        )

        guard editor.buffer.text == "streamed",
              editor.buffer.cursor == PositionIndex(3),
              editor.bufferModifiability == .nonmodifiable else {
            throw Failure.hostReplacement
        }
    }

    private static func runHostAppendProbe() throws {
        var editor = SwimEditor(
            text: "old",
            cursor: PositionIndex(0),
            bufferModifiability: .nonmodifiable
        )

        guard editor.appendBufferContent(
            " tail"
        ),
        editor.buffer.text == "old tail",
        editor.buffer.cursor == PositionIndex(0),
        editor.history.undoDepth == 0 else {
            throw Failure.hostAppend
        }

        guard editor.appendBufferContent(
            "!",
            moveCursorToEnd: true
        ),
        editor.buffer.text == "old tail!",
        editor.buffer.cursor.offset
            == editor.buffer.characterCount,
        editor.history.undoDepth == 0 else {
            throw Failure.hostAppend
        }
    }

    private static func runEditingModeProbe() throws {
        var editor = SwimEditor(
            text: "abc",
            mode: .insert,
            bufferModifiability: .nonmodifiable
        )

        guard editor.mode == .normal else {
            throw Failure.editingMode
        }

        editor.setMode(
            .replace
        )

        guard editor.mode == .normal,
              editor.buffer.text == "abc" else {
            throw Failure.editingMode
        }
    }
}
