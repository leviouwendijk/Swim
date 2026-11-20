import Position
import Swim
import SwimInterpreter

enum SwimBufferTargetSmoke {
    enum Failure:
        Error
    {
        case unexpectedPositionFoundation
        case unexpectedNormalization
        case unexpectedPosition
        case unexpectedWordMotion
        case unexpectedPositionRangeMutation
        case unexpectedTarget
        case unexpectedLineTarget
    }

    static func run() throws {
        try runPositionFoundationProbe()
        try runBufferProbe()
        try runTargetProbe()
    }

    private static func runPositionFoundationProbe() throws {
        let table = LineTable(
            text: "alpha\nbeta\ngamma"
        )

        guard table.lines.count == 3,
              table.lines.start(2) == PositionIndex(6),
              table.lines.contentEnd(1) == PositionIndex(5),
              table.lines.end(1) == PositionIndex(6),
              table.lines.ranges.structural(1) == PositionRange(0..<6),
              table.indices.at(
                line: 2,
                column: 1
              ) == PositionIndex(6),
              PositionRange(0..<6).offsets == 0..<6 else {
            throw Failure.unexpectedPositionFoundation
        }
    }

    private static func runBufferProbe() throws {
        var normalized = SwimTextBuffer(
            text: "alpha\r\nbeta\rgamma"
        )

        guard normalized.text == "alpha\nbeta\ngamma",
              normalized.lineCount == 3 else {
            throw Failure.unexpectedNormalization
        }

        normalized.setCursor(
            PositionIndex(6)
        )

        guard normalized.cursor == PositionIndex(6),
              normalized.cursorPosition == Position(
                uncheckedFile: nil,
                line: 2,
                column: 1
              ) else {
            throw Failure.unexpectedPosition
        }

        var motion = SwimTextBuffer(
            text: "alpha beta\ngamma",
            cursor: PositionIndex(0)
        )

        guard motion.moveWordForward(),
              motion.cursor == PositionIndex(6) else {
            throw Failure.unexpectedWordMotion
        }

        var editing = SwimTextBuffer(
            text: "abcdef",
            cursor: PositionIndex(0)
        )

        guard editing.text(
            in: PositionRange(1..<4)
        ) == "bcd",
        editing.replace(
            PositionRange(1..<3),
            with: "XY"
        ),
        editing.text == "aXYdef",
        editing.delete(
            PositionRange(3..<4)
        ),
        editing.text == "aXYef" else {
            throw Failure.unexpectedPositionRangeMutation
        }
    }

    private static func runTargetProbe() throws {
        let buffer = SwimTextBuffer(
            text: "alpha beta\ngamma",
            cursor: PositionIndex(0)
        )

        guard SwimTextTargetResolver.resolve(
            .motion(
                .wordForward,
                count: 1
            ),
            in: buffer
        ) == SwimResolvedTextTarget(
            range: PositionRange(0..<6),
            kind: .character
        ) else {
            throw Failure.unexpectedTarget
        }

        guard SwimTextTargetResolver.resolve(
            .line(
                count: 1
            ),
            in: buffer
        ) == SwimResolvedTextTarget(
            range: PositionRange(0..<11),
            kind: .line
        ) else {
            throw Failure.unexpectedLineTarget
        }
    }
}
