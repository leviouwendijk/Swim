import Position
import Swim
import SwimInterpreter

enum SwimRegisterPasteSmoke {
    enum Failure:
        Error
    {
        case unexpectedTargetCapture
        case unexpectedSelectionCapture
        case unexpectedRegisterBank
        case unexpectedCharacterPaste
        case unexpectedLinePaste
        case unexpectedBlockPaste
        case unexpectedBlockCountPaste
        case missingBlockMappingWasAccepted
    }

    static func run() throws {
        try runCaptureProbe()
        try runRegisterBankProbe()
        try runCharacterPasteProbe()
        try runLinePasteProbe()
        try runBlockPasteProbe()
    }

    private static func runCaptureProbe() throws {
        let targetBuffer = SwimTextBuffer(
            text: "ab\ncd",
            cursor: PositionIndex(0)
        )

        guard SwimRegisterValue(
            capturing: SwimResolvedTextTarget(
                range: PositionRange(0..<2),
                kind: .character
            ),
            in: targetBuffer
        ) == .character("ab"),
        SwimRegisterValue(
            capturing: SwimResolvedTextTarget(
                range: PositionRange(0..<3),
                kind: .line
            ),
            in: targetBuffer
        ) == .line("ab\n") else {
            throw Failure.unexpectedTargetCapture
        }

        let text = "ab\ncd"
        let blockBuffer = SwimTextBuffer(
            text: text,
            cursor: PositionIndex(0)
        )
        let mapping = SwimHeadlessDisplayColumnMapping(
            text: text
        )
        let selection = SwimSelection(
            anchor: PositionIndex(0),
            cursor: PositionIndex(4),
            kind: .block
        )

        guard let resolved = selection.resolved(
            in: blockBuffer,
            displayColumns: mapping
        ),
        SwimRegisterValue(
            capturing: resolved,
            in: blockBuffer
        ) == .block(
            [
                "ab",
                "cd",
            ]
        ) else {
            throw Failure.unexpectedSelectionCapture
        }
    }

    private static func runRegisterBankProbe() throws {
        var bank = SwimRegisterBank()

        bank.writeUnnamed(
            .character("abc")
        )

        guard bank.unnamed == .character("abc") else {
            throw Failure.unexpectedRegisterBank
        }

        bank.clearUnnamed()

        guard bank.unnamed == nil else {
            throw Failure.unexpectedRegisterBank
        }
    }

    private static func runCharacterPasteProbe() throws {
        var buffer = SwimTextBuffer(
            text: "abc",
            cursor: PositionIndex(1)
        )

        guard SwimRegisterPaste.apply(
            .character("X"),
            placement: .afterCursor,
            count: 2,
            to: &buffer
        ),
        buffer.text == "abXXc",
        buffer.cursor == PositionIndex(3) else {
            throw Failure.unexpectedCharacterPaste
        }

        buffer = SwimTextBuffer(
            text: "abc",
            cursor: PositionIndex(1)
        )

        guard SwimRegisterPaste.apply(
            .character("X"),
            placement: .beforeCursor,
            count: 2,
            to: &buffer
        ),
        buffer.text == "aXXbc",
        buffer.cursor == PositionIndex(2) else {
            throw Failure.unexpectedCharacterPaste
        }
    }

    private static func runLinePasteProbe() throws {
        var buffer = SwimTextBuffer(
            text: "aa\nbb",
            cursor: PositionIndex(1)
        )

        guard SwimRegisterPaste.apply(
            .line("X"),
            placement: .afterCursor,
            to: &buffer
        ),
        buffer.text == "aa\nX\nbb",
        buffer.cursor == PositionIndex(3) else {
            throw Failure.unexpectedLinePaste
        }

        buffer = SwimTextBuffer(
            text: "aa\nbb",
            cursor: PositionIndex(4)
        )

        guard SwimRegisterPaste.apply(
            .line("X\n"),
            placement: .beforeCursor,
            to: &buffer
        ),
        buffer.text == "aa\nX\nbb",
        buffer.cursor == PositionIndex(3) else {
            throw Failure.unexpectedLinePaste
        }

        buffer = SwimTextBuffer()

        guard SwimRegisterPaste.apply(
            .line("X"),
            placement: .afterCursor,
            to: &buffer
        ),
        buffer.text == "X\n",
        buffer.cursor == PositionIndex(0) else {
            throw Failure.unexpectedLinePaste
        }
    }

    private static func runBlockPasteProbe() throws {
        let text = "a\tb\nx"
        let mapping = SwimHeadlessDisplayColumnMapping(
            text: text,
            tabWidth: 4
        )
        var buffer = SwimTextBuffer(
            text: text,
            cursor: PositionIndex(1)
        )

        guard !SwimRegisterPaste.apply(
            .block(
                [
                    "Q",
                    "Z",
                ]
            ),
            placement: .afterCursor,
            to: &buffer
        ) else {
            throw Failure.missingBlockMappingWasAccepted
        }

        buffer = SwimTextBuffer(
            text: text,
            cursor: PositionIndex(1)
        )

        guard SwimRegisterPaste.apply(
            .block(
                [
                    "Q",
                    "Z",
                ]
            ),
            placement: .afterCursor,
            to: &buffer,
            displayColumns: mapping
        ),
        buffer.text == "a\tQb\nx   Z",
        buffer.cursor == PositionIndex(2) else {
            throw Failure.unexpectedBlockPaste
        }

        let repeatedText = "ab\ncd"
        let repeatedMapping = SwimHeadlessDisplayColumnMapping(
            text: repeatedText
        )
        buffer = SwimTextBuffer(
            text: repeatedText,
            cursor: PositionIndex(0)
        )

        guard SwimRegisterPaste.apply(
            .block(
                [
                    "X",
                    "Y",
                ]
            ),
            placement: .beforeCursor,
            count: 2,
            to: &buffer,
            displayColumns: repeatedMapping
        ),
        buffer.text == "XXab\nYYcd",
        buffer.cursor == PositionIndex(0) else {
            throw Failure.unexpectedBlockCountPaste
        }

        let shortText = "ab"
        let shortMapping = SwimHeadlessDisplayColumnMapping(
            text: shortText
        )
        buffer = SwimTextBuffer(
            text: shortText,
            cursor: PositionIndex(1)
        )

        guard SwimRegisterPaste.apply(
            .block(
                [
                    "M",
                    "N",
                ]
            ),
            placement: .afterCursor,
            to: &buffer,
            displayColumns: shortMapping
        ),
        buffer.text == "abM\n  N",
        buffer.cursor == PositionIndex(2) else {
            throw Failure.unexpectedBlockPaste
        }
    }
}
