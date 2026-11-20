import Position
import Swim
import SwimInterpreter

enum SwimEditSessionSmoke {
    enum Failure:
        Error
    {
        case unexpectedReplace
        case unexpectedReplaceRestore
        case unexpectedReplaceNewline
        case unexpectedReplaceBoundary
        case unexpectedBlockSession
        case unexpectedBlockSelectionSession
        case unexpectedBlockInsertion
        case unexpectedBlockPadding
        case unexpectedBlockDisplayCells
        case unexpectedBlockHistory
    }

    static func run() throws {
        try runReplaceProbe()
        try runReplaceNewlineProbe()
        try runReplaceBoundaryProbe()
        try runBlockSessionProbe()
        try runBlockSelectionSessionProbe()
        try runBlockInsertionProbe()
        try runBlockPaddingProbe()
        try runBlockDisplayCellProbe()
        try runBlockHistoryProbe()
    }

    private static func runReplaceProbe() throws {
        var buffer = SwimTextBuffer(
            text: "abc",
            cursor: PositionIndex(1)
        )
        var session = SwimReplaceSession(
            start: buffer.cursor
        )

        guard session.apply(
            "X",
            to: &buffer
        ),
        buffer.text == "aXc",
        buffer.cursor == PositionIndex(2),
        session.steps.count == 1,
        session.steps[0].index == PositionIndex(1),
        session.steps[0].original == "b" else {
            throw Failure.unexpectedReplace
        }

        guard session.apply(
            "Y",
            to: &buffer
        ),
        buffer.text == "aXY",
        buffer.cursor == PositionIndex(3),
        session.apply(
            "Z",
            to: &buffer
        ),
        buffer.text == "aXYZ",
        buffer.cursor == PositionIndex(4) else {
            throw Failure.unexpectedReplace
        }

        guard session.restoreLast(
            in: &buffer
        ),
        buffer.text == "aXY",
        buffer.cursor == PositionIndex(3),
        session.restoreLast(
            in: &buffer
        ),
        buffer.text == "aXc",
        buffer.cursor == PositionIndex(2),
        session.restoreLast(
            in: &buffer
        ),
        buffer.text == "abc",
        buffer.cursor == PositionIndex(1),
        session.steps.isEmpty else {
            throw Failure.unexpectedReplaceRestore
        }
    }

    private static func runReplaceNewlineProbe() throws {
        var buffer = SwimTextBuffer(
            text: "ab",
            cursor: PositionIndex(1)
        )
        var session = SwimReplaceSession(
            start: buffer.cursor
        )

        guard session.apply(
            "\r",
            to: &buffer
        ),
        buffer.text == "a\nb",
        buffer.cursor == PositionIndex(2),
        session.steps.count == 1,
        session.steps[0].replacement == "\n",
        session.steps[0].original == nil,
        session.restoreLast(
            in: &buffer
        ),
        buffer.text == "ab",
        buffer.cursor == PositionIndex(1) else {
            throw Failure.unexpectedReplaceNewline
        }
    }

    private static func runReplaceBoundaryProbe() throws {
        var buffer = SwimTextBuffer(
            text: "a\nb",
            cursor: PositionIndex(1)
        )
        var session = SwimReplaceSession(
            start: buffer.cursor
        )

        guard session.apply(
            "X",
            to: &buffer
        ),
        buffer.text == "aX\nb",
        buffer.cursor == PositionIndex(2),
        session.steps.last?.original == nil,
        !session.apply(
            "multiple",
            to: &buffer
        ) else {
            throw Failure.unexpectedReplaceBoundary
        }
    }

    private static func runBlockSessionProbe() throws {
        var session = SwimBlockInsertSession(
            operation: .change,
            lines: [
                2,
                3,
                4,
            ],
            insertionColumn: 5,
            primaryLine: 2
        )

        session.append(
            "ab"
        )
        session.append(
            "界"
        )

        guard session.operation == .change,
        session.lines == [
            2,
            3,
            4,
        ],
        session.insertionColumn == 5,
        session.primaryLine == 2,
        session.insertedText == "ab界",
        session.removeLastCharacter(),
        session.insertedText == "ab",
        session.removeLastCharacter(),
        session.insertedText == "a",
        session.removeLastCharacter(),
        session.insertedText.isEmpty,
        !session.removeLastCharacter() else {
            throw Failure.unexpectedBlockSession
        }

        let clamped = SwimBlockInsertSession(
            operation: .insertBefore,
            lines: [
                0,
                -4,
                2,
            ],
            insertionColumn: -8,
            primaryLine: 0
        )

        guard clamped.lines == [
            1,
            2,
        ],
        clamped.insertionColumn == 0,
        clamped.primaryLine == 1 else {
            throw Failure.unexpectedBlockSession
        }
    }

    private static func runBlockSelectionSessionProbe() throws {
        let selection = SwimResolvedBlockSelection(
            columns: 2..<5,
            rows: [
                SwimResolvedBlockRow(
                    line: 2,
                    sourceRange: PositionRange(5..<7)
                ),
                SwimResolvedBlockRow(
                    line: 3,
                    sourceRange: PositionRange(9..<11)
                ),
            ]
        )

        guard SwimBlockInsertSession(
            operation: .insertBefore,
            selection: selection
        ) == SwimBlockInsertSession(
            operation: .insertBefore,
            lines: [
                2,
                3,
            ],
            insertionColumn: 2,
            primaryLine: 2
        ),
        SwimBlockInsertSession(
            operation: .insertAfter,
            selection: selection
        ) == SwimBlockInsertSession(
            operation: .insertAfter,
            lines: [
                2,
                3,
            ],
            insertionColumn: 5,
            primaryLine: 2
        ) else {
            throw Failure.unexpectedBlockSelectionSession
        }
    }

    private static func runBlockInsertionProbe() throws {
        let original = "abcd\nx\nwxyz"
        var buffer = SwimTextBuffer(
            text: original,
            cursor: PositionIndex(0)
        )
        var session = SwimBlockInsertSession(
            operation: .insertBefore,
            lines: [
                1,
                2,
                3,
            ],
            insertionColumn: 1,
            primaryLine: 1
        )
        let initialMapping = SwimHeadlessDisplayColumnMapping(
            text: buffer.text
        )

        guard session.preparePrimaryInsertion(
            in: &buffer,
            displayColumns: initialMapping
        ),
        buffer.cursor == PositionIndex(1),
        buffer.insert(
            "Q"
        ) else {
            throw Failure.unexpectedBlockInsertion
        }

        session.append(
            "Q"
        )

        let replicationMapping = SwimHeadlessDisplayColumnMapping(
            text: buffer.text
        )

        guard session.replicateInsertedText(
            in: &buffer,
            displayColumns: replicationMapping
        ),
        buffer.text == "aQbcd\nxQ\nwQxyz",
        buffer.cursor == PositionIndex(2) else {
            throw Failure.unexpectedBlockInsertion
        }
    }

    private static func runBlockPaddingProbe() throws {
        var buffer = SwimTextBuffer(
            text: "abcd\nx\nwxyz",
            cursor: PositionIndex(0)
        )
        var session = SwimBlockInsertSession(
            operation: .insertBefore,
            lines: [
                1,
                2,
                3,
            ],
            insertionColumn: 3,
            primaryLine: 1
        )
        let initialMapping = SwimHeadlessDisplayColumnMapping(
            text: buffer.text
        )

        guard session.preparePrimaryInsertion(
            in: &buffer,
            displayColumns: initialMapping
        ),
        buffer.insert(
            "Q"
        ) else {
            throw Failure.unexpectedBlockPadding
        }

        session.append(
            "Q"
        )

        let replicationMapping = SwimHeadlessDisplayColumnMapping(
            text: buffer.text
        )

        guard session.replicateInsertedText(
            in: &buffer,
            displayColumns: replicationMapping
        ),
        buffer.text == "abcQd\nx  Q\nwxyQz" else {
            throw Failure.unexpectedBlockPadding
        }
    }

    private static func runBlockDisplayCellProbe() throws {
        var buffer = SwimTextBuffer(
            text: "a\tb\nx界z",
            cursor: PositionIndex(0)
        )
        var session = SwimBlockInsertSession(
            operation: .insertBefore,
            lines: [
                1,
                2,
            ],
            insertionColumn: 2,
            primaryLine: 1
        )
        let initialMapping = SwimHeadlessDisplayColumnMapping(
            text: buffer.text,
            tabWidth: 4
        ) { character in
            character == "界"
                ? 2
                : 1
        }

        guard session.preparePrimaryInsertion(
            in: &buffer,
            displayColumns: initialMapping
        ),
        buffer.insert(
            "Q"
        ) else {
            throw Failure.unexpectedBlockDisplayCells
        }

        session.append(
            "Q"
        )

        let replicationMapping = SwimHeadlessDisplayColumnMapping(
            text: buffer.text,
            tabWidth: 4
        ) { character in
            character == "界"
                ? 2
                : 1
        }

        guard session.replicateInsertedText(
            in: &buffer,
            displayColumns: replicationMapping
        ),
        buffer.text == "a\tQb\nx界Qz" else {
            throw Failure.unexpectedBlockDisplayCells
        }
    }

    private static func runBlockHistoryProbe() throws {
        let original = SwimTextBuffer(
            text: "abcd\nx\nwxyz",
            cursor: PositionIndex(0)
        )
        var buffer = original
        var history = SwimEditHistory()
        var session = SwimBlockInsertSession(
            operation: .insertBefore,
            lines: [
                1,
                2,
                3,
            ],
            insertionColumn: 1,
            primaryLine: 1
        )

        guard history.begin(
            with: buffer
        ) else {
            throw Failure.unexpectedBlockHistory
        }

        let initialMapping = SwimHeadlessDisplayColumnMapping(
            text: buffer.text
        )

        guard session.preparePrimaryInsertion(
            in: &buffer,
            displayColumns: initialMapping
        ),
        buffer.insert(
            "Q"
        ) else {
            throw Failure.unexpectedBlockHistory
        }

        session.append(
            "Q"
        )

        let replicationMapping = SwimHeadlessDisplayColumnMapping(
            text: buffer.text
        )

        guard session.replicateInsertedText(
            in: &buffer,
            displayColumns: replicationMapping
        ),
        history.commit(
            current: buffer
        ),
        history.undoDepth == 1,
        history.undo(
            current: buffer
        ) == original else {
            throw Failure.unexpectedBlockHistory
        }
    }
}
