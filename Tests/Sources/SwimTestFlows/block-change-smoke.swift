import Position
import Swim
import SwimInterpreter

enum SwimBlockChangeSmoke {
    enum Failure:
        Error
    {
        case unexpectedBegin
        case unexpectedRegister
        case unexpectedReplication
        case unexpectedHistory
        case unexpectedFreshMapping
    }

    static func run() throws {
        try runChangeProbe()
        try runFreshMappingProbe()
    }

    private static func runChangeProbe() throws {
        let original = SwimTextBuffer(
            text: "abcd\nwxyz",
            cursor: PositionIndex(1)
        )
        var buffer = original
        var registers = SwimRegisterBank()
        var history = SwimEditHistory()
        let provider = SwimHeadlessDisplayColumnMappingProvider()
        let selection = SwimResolvedBlockSelection(
            columns: 1..<3,
            rows: [
                SwimResolvedBlockRow(
                    line: 1,
                    sourceRange: PositionRange(1..<3)
                ),
                SwimResolvedBlockRow(
                    line: 2,
                    sourceRange: PositionRange(6..<8)
                ),
            ]
        )

        guard history.begin(
            with: buffer
        ),
        var session = SwimBlockInsertSession.begin(
            operation: .change,
            selection: selection,
            in: &buffer,
            registers: &registers,
            displayColumns: provider
        ),
        buffer.text == "ad\nwz",
        buffer.cursor == PositionIndex(1) else {
            throw Failure.unexpectedBegin
        }

        guard registers.unnamed == .block([
            "bc",
            "xy",
        ]) else {
            throw Failure.unexpectedRegister
        }

        guard buffer.insert(
            "Q"
        ) else {
            throw Failure.unexpectedReplication
        }

        session.append(
            "Q"
        )

        let replicationMapping = provider.mapping(
            for: buffer.text
        )

        guard session.replicateInsertedText(
            in: &buffer,
            displayColumns: replicationMapping
        ),
        buffer.text == "aQd\nwQz",
        buffer.cursor == PositionIndex(2) else {
            throw Failure.unexpectedReplication
        }

        guard history.commit(
            current: buffer
        ),
        history.undoDepth == 1,
        history.undo(
            current: buffer
        ) == original else {
            throw Failure.unexpectedHistory
        }
    }

    private static func runFreshMappingProbe() throws {
        var buffer = SwimTextBuffer(
            text: "a\tb\nx界z",
            cursor: PositionIndex(1)
        )
        var registers = SwimRegisterBank()
        let provider = SwimHeadlessDisplayColumnMappingProvider(
            tabWidth: 4
        ) { character in
            character == "界"
                ? 2
                : 1
        }
        let initialMapping = provider.mapping(
            for: buffer.text
        )
        let semanticSelection = SwimSelection(
            anchor: PositionIndex(1),
            cursor: PositionIndex(6),
            kind: .block,
            blockPreferredColumn: 1
        )

        guard case .block(let selection)? = semanticSelection.resolved(
            in: buffer,
            displayColumns: initialMapping
        ),
        var session = SwimBlockInsertSession.begin(
            operation: .change,
            selection: selection,
            in: &buffer,
            registers: &registers,
            displayColumns: provider
        ) else {
            throw Failure.unexpectedFreshMapping
        }

        guard buffer.insert(
            "Q"
        ) else {
            throw Failure.unexpectedFreshMapping
        }

        session.append(
            "Q"
        )

        let replicationMapping = provider.mapping(
            for: buffer.text
        )

        guard session.replicateInsertedText(
            in: &buffer,
            displayColumns: replicationMapping
        ) else {
            throw Failure.unexpectedFreshMapping
        }
    }
}
