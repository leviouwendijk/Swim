import Dispatch

public struct CommandTiming:
    Sendable,
    Codable,
    Hashable
{
    public var sequenceTimeoutNanoseconds: UInt64

    public init(
        sequenceTimeoutNanoseconds: UInt64 = 750_000_000
    ) {
        self.sequenceTimeoutNanoseconds =
            sequenceTimeoutNanoseconds
    }
}

public struct CommandInterpreter:
    Sendable,
    Codable,
    Hashable
{
    public var timing: CommandTiming

    private var count: Int?
    private var operatorCount: Int?
    private var targetCount: Int?
    private var pendingOperator: Operator?
    private var pendingPrefix: CommandPrefix?
    private var pendingReplacementCount: Int?
    private var lastInputAtNanoseconds: UInt64?

    public init(
        timing: CommandTiming = .init()
    ) {
        self.timing = timing
        self.count = nil
        self.operatorCount = nil
        self.targetCount = nil
        self.pendingOperator = nil
        self.pendingPrefix = nil
        self.pendingReplacementCount = nil
        self.lastInputAtNanoseconds = nil
    }

    public var state: CommandSequenceState {
        CommandSequenceState(
            count: count,
            operatorCount: operatorCount,
            targetCount: targetCount,
            pendingOperator: pendingOperator,
            pendingPrefix: pendingPrefix,
            pendingReplacementCount: pendingReplacementCount,
            lastInputAtNanoseconds: lastInputAtNanoseconds
        )
    }

    public mutating func handle(
        _ key: Input
    ) -> CommandInterpretation {
        handle(
            key,
            atNanoseconds:
                DispatchTime
                    .now()
                    .uptimeNanoseconds
        )
    }

    public mutating func handle(
        _ key: Input,
        atNanoseconds now: UInt64
    ) -> CommandInterpretation {
        expirePendingSequence(
            atNanoseconds: now
        )

        if state.isPending,
           key == .escape
        {
            reset()
            return .cancelled
        }

        if let pendingReplacementCount {
            return finishReplacement(
                key,
                count: pendingReplacementCount
            )
        }

        switch key {
        case .left:
            return finishMotion(
                .left
            )

        case .right:
            return finishMotion(
                .right
            )

        case .up:
            return finishMotion(
                .up
            )

        case .down:
            return finishMotion(
                .down
            )

        case .home:
            return finishMotion(
                .lineStart
            )

        case .end:
            return finishMotion(
                .lineEnd
            )

        case .pageUp:
            return finishMotion(
                .pageUp
            )

        case .pageDown:
            return finishMotion(
                .pageDown
            )

        case .char(
            let character
        ):
            return handleCharacter(
                character,
                atNanoseconds: now
            )

        default:
            reset()

            return .unhandled
        }
    }

    public mutating func reset() {
        count = nil
        operatorCount = nil
        targetCount = nil
        pendingOperator = nil
        pendingPrefix = nil
        pendingReplacementCount = nil
        lastInputAtNanoseconds = nil
    }

    private mutating func handleCharacter(
        _ character: String,
        atNanoseconds now: UInt64
    ) -> CommandInterpretation {
        if pendingPrefix != nil,
           character != "g"
        {
            reset()
        }

        if let digit = singleDigit(
            character
        ) {
            let current =
                pendingOperator == nil
                ? count
                : targetCount

            if digit == 0,
               current == nil
            {
                return finishMotion(
                    .lineStart
                )
            }

            if pendingOperator == nil {
                count = appending(
                    digit: digit,
                    to: count
                )
            } else {
                targetCount = appending(
                    digit: digit,
                    to: targetCount
                )
            }

            touch(
                atNanoseconds: now
            )

            return .pending
        }

        switch character {
        case "h":
            return finishMotion(
                .left
            )

        case "j":
            return finishMotion(
                .down
            )

        case "k":
            return finishMotion(
                .up
            )

        case "l":
            return finishMotion(
                .right
            )

        case "b":
            return finishMotion(
                .wordBackward
            )

        case "w":
            return finishMotion(
                .wordForward
            )

        case "e":
            return finishMotion(
                .wordEnd
            )

        case "$":
            return finishMotion(
                .lineEnd
            )

        case "G":
            return finishMotion(
                .documentEnd
            )

        case "g":
            if pendingPrefix == .g {
                pendingPrefix = nil

                return finishMotion(
                    .documentStart
                )
            }

            pendingPrefix = .g

            touch(
                atNanoseconds: now
            )

            return .pending

        case "d":
            return handleOperator(
                .delete,
                atNanoseconds: now
            )

        case "y":
            return handleOperator(
                .yank,
                atNanoseconds: now
            )

        case "c":
            return handleOperator(
                .change,
                atNanoseconds: now
            )

        case ">":
            return handleOperator(
                .shiftRight,
                atNanoseconds: now
            )

        case "<":
            return handleOperator(
                .shiftLeft,
                atNanoseconds: now
            )

        case "r":
            return beginReplacement(
                atNanoseconds: now
            )

        case "J":
            return finishJoinLines()

        case "~":
            return finishToggleCase()

        case "D":
            return finishImmediateOperation(
                .delete,
                target:
                    .motion(
                        .lineEnd,
                        count: count ?? 1
                    )
            )

        case "C":
            return finishImmediateOperation(
                .change,
                target:
                    .motion(
                        .lineEnd,
                        count: count ?? 1
                    )
            )

        case "S":
            return finishImmediateOperation(
                .change,
                target:
                    .line(
                        count: count ?? 1
                    )
            )

        case "s":
            return finishImmediateOperation(
                .change,
                target:
                    .characters(
                        count: count ?? 1
                    )
            )

        case "p":
            return finishPaste(
                .afterCursor
            )

        case "P":
            return finishPaste(
                .beforeCursor
            )

        case "I":
            return finishEdit(
                .insertAtFirstNonWhitespace
            )

        case "A":
            return finishEdit(
                .appendAtLineEnd
            )

        case "o":
            return finishEdit(
                .openLineBelow
            )

        case "O":
            return finishEdit(
                .openLineAbove
            )

        case "R":
            return finishEdit(
                .enterReplaceMode
            )

        default:
            reset()

            return .unhandled
        }
    }

    private mutating func beginReplacement(
        atNanoseconds now: UInt64
    ) -> CommandInterpretation {
        guard pendingOperator == nil,
              pendingPrefix == nil else {
            reset()
            return .unhandled
        }

        pendingReplacementCount = max(
            1,
            count ?? 1
        )
        count = nil
        operatorCount = nil
        targetCount = nil

        touch(
            atNanoseconds: now
        )

        return .pending
    }

    private mutating func finishReplacement(
        _ key: Input,
        count: Int
    ) -> CommandInterpretation {
        guard let replacement = replacementText(
            for: key
        ) else {
            reset()
            return .unhandled
        }

        let command = Command.replaceCharacters(
            replacement: replacement,
            count: max(
                1,
                count
            )
        )

        reset()

        return .command(
            command
        )
    }

    private func replacementText(
        for key: Input
    ) -> String? {
        switch key {
        case .char(let character):
            return character.count == 1
                ? character
                : nil

        case .space:
            return " "

        case .tab:
            return "\t"

        case .enter:
            return "\n"

        default:
            return nil
        }
    }

    private mutating func handleOperator(
        _ value: Operator,
        atNanoseconds now: UInt64
    ) -> CommandInterpretation {
        if let pendingOperator {
            if pendingOperator == value {
                return finishLineOperation(
                    value
                )
            }

            reset()
        }

        operatorCount = count ?? 1
        count = nil
        targetCount = nil
        pendingOperator = value

        touch(
            atNanoseconds: now
        )

        return .pending
    }

    private mutating func finishMotion(
        _ motion: Motion
    ) -> CommandInterpretation {
        let command: Command

        if let pendingOperator {
            command = .operate(
                pendingOperator,
                target:
                    .motion(
                        motion,
                        count:
                            saturatedProduct(
                                operatorCount ?? 1,
                                targetCount ?? 1
                            )
                    )
            )
        } else {
            command = .motion(
                motion,
                count: count ?? 1
            )
        }

        reset()

        return .command(
            command
        )
    }

    private mutating func finishJoinLines() -> CommandInterpretation {
        guard pendingOperator == nil,
              pendingPrefix == nil else {
            reset()
            return .unhandled
        }

        let command = Command.joinLines(
            count: max(
                2,
                count ?? 2
            )
        )

        reset()

        return .command(
            command
        )
    }

    private mutating func finishToggleCase() -> CommandInterpretation {
        guard pendingOperator == nil,
              pendingPrefix == nil else {
            reset()
            return .unhandled
        }

        let command = Command.toggleCase(
            count: max(
                1,
                count ?? 1
            )
        )

        reset()

        return .command(
            command
        )
    }

    private mutating func finishImmediateOperation(
        _ operation: Operator,
        target: CommandTarget
    ) -> CommandInterpretation {
        guard pendingOperator == nil,
              pendingPrefix == nil else {
            reset()
            return .unhandled
        }

        let command = Command.operate(
            operation,
            target: target
        )

        reset()

        return .command(
            command
        )
    }

    private mutating func finishPaste(
        _ placement: PastePlacement
    ) -> CommandInterpretation {
        guard pendingOperator == nil,
              pendingPrefix == nil else {
            reset()
            return .unhandled
        }

        let command = Command.paste(
            placement,
            count: count ?? 1
        )

        reset()

        return .command(
            command
        )
    }

    private mutating func finishEdit(
        _ edit: EditCommand
    ) -> CommandInterpretation {
        guard pendingOperator == nil,
              pendingPrefix == nil,
              count == nil else {
            reset()
            return .unhandled
        }

        reset()

        return .command(
            .edit(
                edit
            )
        )
    }

    private mutating func finishLineOperation(
        _ value: Operator
    ) -> CommandInterpretation {
        let command = Command.operate(
            value,
            target:
                .line(
                    count:
                        saturatedProduct(
                            operatorCount ?? 1,
                            targetCount ?? 1
                        )
                )
        )

        reset()

        return .command(
            command
        )
    }

    private mutating func expirePendingSequence(
        atNanoseconds now: UInt64
    ) {
        guard
            let lastInputAtNanoseconds,
            now >= lastInputAtNanoseconds,
            now - lastInputAtNanoseconds
                > timing.sequenceTimeoutNanoseconds
        else {
            return
        }

        reset()
    }

    private mutating func touch(
        atNanoseconds now: UInt64
    ) {
        lastInputAtNanoseconds = now
    }

    private func singleDigit(
        _ value: String
    ) -> Int? {
        guard
            value.count == 1,
            let digit = Int(
                value
            ),
            (0...9).contains(
                digit
            )
        else {
            return nil
        }

        return digit
    }

    private func appending(
        digit: Int,
        to current: Int?
    ) -> Int {
        let base = current ?? 0

        let (
            multiplied,
            multiplicationOverflow
        ) = base.multipliedReportingOverflow(
            by: 10
        )

        guard !multiplicationOverflow else {
            return Int.max
        }

        let (
            added,
            additionOverflow
        ) = multiplied.addingReportingOverflow(
            digit
        )

        return additionOverflow
            ? Int.max
            : added
    }

    private func saturatedProduct(
        _ lhs: Int,
        _ rhs: Int
    ) -> Int {
        let (
            result,
            overflow
        ) = lhs.multipliedReportingOverflow(
            by: rhs
        )

        return overflow
            ? Int.max
            : max(
                1,
                result
            )
    }
}
