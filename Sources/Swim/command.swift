public enum Operator:
    String,
    Sendable,
    Codable,
    Hashable,
    CaseIterable
{
    case delete
    case yank
    case change
    case shiftLeft
    case shiftRight
}

public enum IndentationShift:
    String,
    Sendable,
    Codable,
    Hashable,
    CaseIterable
{
    case left
    case right
}

public enum CommandPrefix:
    String,
    Sendable,
    Codable,
    Hashable,
    CaseIterable
{
    case g
}

public enum PastePlacement:
    String,
    Sendable,
    Codable,
    Hashable,
    CaseIterable
{
    case beforeCursor
    case afterCursor
}

public enum EditCommand:
    String,
    Sendable,
    Codable,
    Hashable,
    CaseIterable
{
    case insertAtFirstNonWhitespace
    case appendAtLineEnd
    case openLineBelow
    case openLineAbove
    case enterReplaceMode
}

public enum CommandTarget:
    Sendable,
    Codable,
    Hashable
{
    case motion(
        Motion,
        count: Int
    )
    case line(
        count: Int
    )
    case characters(
        count: Int
    )
}

public enum Command:
    Sendable,
    Codable,
    Hashable
{
    case motion(
        Motion,
        count: Int
    )
    case operate(
        Operator,
        target: CommandTarget
    )
    case paste(
        PastePlacement,
        count: Int
    )
    case edit(
        EditCommand
    )
    case replaceCharacters(
        replacement: String,
        count: Int
    )
    case joinLines(
        count: Int
    )
    case toggleCase(
        count: Int
    )
}

public struct CommandSequenceState:
    Sendable,
    Codable,
    Hashable
{
    public let count: Int?
    public let operatorCount: Int?
    public let targetCount: Int?
    public let pendingOperator: Operator?
    public let pendingPrefix: CommandPrefix?
    public let pendingReplacementCount: Int?
    public let lastInputAtNanoseconds: UInt64?

    public init(
        count: Int? = nil,
        operatorCount: Int? = nil,
        targetCount: Int? = nil,
        pendingOperator: Operator? = nil,
        pendingPrefix: CommandPrefix? = nil,
        pendingReplacementCount: Int? = nil,
        lastInputAtNanoseconds: UInt64? = nil
    ) {
        self.count = count
        self.operatorCount = operatorCount
        self.targetCount = targetCount
        self.pendingOperator = pendingOperator
        self.pendingPrefix = pendingPrefix
        self.pendingReplacementCount = pendingReplacementCount
        self.lastInputAtNanoseconds = lastInputAtNanoseconds
    }

    public var isPending: Bool {
        count != nil
            || operatorCount != nil
            || targetCount != nil
            || pendingOperator != nil
            || pendingPrefix != nil
            || pendingReplacementCount != nil
    }
}

public enum CommandInterpretation:
    Sendable,
    Codable,
    Hashable
{
    case pending
    case command(Command)
    case cancelled
    case unhandled
}
