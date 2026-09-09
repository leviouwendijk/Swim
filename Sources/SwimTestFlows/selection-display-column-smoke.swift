import Position
import Swim
import SwimInterpreter

enum SwimSelectionDisplayColumnSmoke {
    enum Failure:
        Error
    {
        case unexpectedASCIIColumns
        case unexpectedTabColumns
        case unexpectedWideColumns
        case unexpectedCharacterSelection
        case unexpectedLineSelection
        case unexpectedBlockSelection
    }

    static func run() throws {
        try runASCIIProbe()
        try runTabProbe()
        try runWideCharacterProbe()
        try runContiguousSelectionProbe()
        try runBlockSelectionProbe()
    }

    private static func runASCIIProbe() throws {
        let mapping = SwimHeadlessDisplayColumnMapping(
            text: "ab\ncd"
        )

        guard mapping.width(
            ofLine: 1
        ) == 2,
        mapping.width(
            ofLine: 2
        ) == 2,
        mapping.column(
            at: PositionIndex(1)
        ) == 1,
        mapping.column(
            at: PositionIndex(3)
        ) == 0,
        mapping.index(
            line: 2,
            column: 1
        ) == PositionIndex(4) else {
            throw Failure.unexpectedASCIIColumns
        }
    }

    private static func runTabProbe() throws {
        let mapping = SwimHeadlessDisplayColumnMapping(
            text: "a\tb",
            tabWidth: 4
        )

        guard mapping.width(
            ofLine: 1
        ) == 5,
        mapping.column(
            at: PositionIndex(1)
        ) == 1,
        mapping.column(
            at: PositionIndex(2)
        ) == 4,
        mapping.index(
            line: 1,
            column: 2
        ) == PositionIndex(1),
        mapping.index(
            line: 1,
            column: 4
        ) == PositionIndex(2) else {
            throw Failure.unexpectedTabColumns
        }
    }

    private static func runWideCharacterProbe() throws {
        let mapping = SwimHeadlessDisplayColumnMapping(
            text: "a界b"
        ) { character in
            character == "界"
                ? 2
                : 1
        }

        guard mapping.width(
            ofLine: 1
        ) == 4,
        mapping.column(
            at: PositionIndex(2)
        ) == 3,
        mapping.index(
            line: 1,
            column: 2
        ) == PositionIndex(1) else {
            throw Failure.unexpectedWideColumns
        }
    }

    private static func runContiguousSelectionProbe() throws {
        let characterBuffer = SwimTextBuffer(
            text: "abcd",
            cursor: PositionIndex(0)
        )
        let characterSelection = SwimSelection(
            anchor: PositionIndex(1),
            cursor: PositionIndex(3),
            kind: .character
        )

        guard characterSelection.resolved(
            in: characterBuffer
        ) == .contiguous(
            range: PositionRange(1..<4),
            kind: .character
        ) else {
            throw Failure.unexpectedCharacterSelection
        }

        let lineBuffer = SwimTextBuffer(
            text: "a\nbc\n",
            cursor: PositionIndex(0)
        )
        let lineSelection = SwimSelection(
            anchor: PositionIndex(0),
            cursor: PositionIndex(2),
            kind: .line
        )

        guard lineSelection.resolved(
            in: lineBuffer
        ) == .contiguous(
            range: PositionRange(0..<5),
            kind: .line
        ) else {
            throw Failure.unexpectedLineSelection
        }
    }

    private static func runBlockSelectionProbe() throws {
        let text = "a\tb\nxy界z"
        let buffer = SwimTextBuffer(
            text: text,
            cursor: PositionIndex(0)
        )
        let mapping = SwimHeadlessDisplayColumnMapping(
            text: text,
            tabWidth: 4
        ) { character in
            character == "界"
                ? 2
                : 1
        }
        let selection = SwimSelection(
            anchor: PositionIndex(1),
            cursor: PositionIndex(6),
            kind: .block,
            blockPreferredColumn: 1
        )

        guard selection.resolved(
            in: buffer,
            displayColumns: mapping
        ) == .block(
            SwimResolvedBlockSelection(
                columns: 1..<4,
                rows: [
                    SwimResolvedBlockRow(
                        line: 1,
                        sourceRange: PositionRange(1..<2)
                    ),
                    SwimResolvedBlockRow(
                        line: 2,
                        sourceRange: PositionRange(5..<7)
                    ),
                ]
            )
        ) else {
            throw Failure.unexpectedBlockSelection
        }
    }
}
