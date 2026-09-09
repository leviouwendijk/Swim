import SwimInterpreter

public struct SwimBlockInsertSession:
    Sendable,
    Codable,
    Hashable
{
    public let operation: SwimInterpreter.BlockInsertOperation

    /// One-based logical source lines participating in the block operation.
    public let lines: [Int]

    /// Zero-based display-cell column at which replication occurs.
    public let insertionColumn: Int

    /// One-based logical source line on which insertion is performed live.
    public let primaryLine: Int

    public private(set) var insertedText: String

    public init(
        operation: SwimInterpreter.BlockInsertOperation,
        lines: [Int],
        insertionColumn: Int,
        primaryLine: Int,
        insertedText: String = ""
    ) {
        self.operation = operation

        let primaryLine = max(
            1,
            primaryLine
        )
        var normalizedLines = Set(
            lines.map {
                max(
                    1,
                    $0
                )
            }
        )

        normalizedLines.insert(
            primaryLine
        )

        self.lines = normalizedLines.sorted()
        self.insertionColumn = max(
            0,
            insertionColumn
        )
        self.primaryLine = primaryLine
        self.insertedText = insertedText
    }

    public mutating func append(
        _ text: String
    ) {
        insertedText += text
    }

    @discardableResult
    public mutating func removeLastCharacter() -> Bool {
        guard !insertedText.isEmpty else {
            return false
        }

        insertedText.removeLast()
        return true
    }
}
