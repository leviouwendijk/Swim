public struct ExCommandLine:
    Sendable,
    Codable,
    Hashable
{
    public private(set) var isActive: Bool
    public private(set) var text: String
    public private(set) var cursorOffset: Int

    public init(
        isActive: Bool = false,
        text: String = "",
        cursorOffset: Int? = nil
    ) {
        self.isActive = isActive
        self.text = text
        self.cursorOffset = min(
            text.count,
            max(
                0,
                cursorOffset ?? text.count
            )
        )
    }

    public var textBeforeCursor: String {
        String(
            text.prefix(
                cursorOffset
            )
        )
    }

    public mutating func begin() {
        isActive = true
        text = ""
        cursorOffset = 0
    }

    public mutating func reset() {
        isActive = false
        text = ""
        cursorOffset = 0
    }

    public mutating func handle(
        _ input: Input
    ) -> ExCommandLineResult {
        guard isActive else {
            return .inactive
        }

        switch input {
        case .escape:
            reset()
            return .cancelled

        case .enter:
            return resolve()

        case .left:
            cursorOffset = max(
                0,
                cursorOffset - 1
            )
            return .editing

        case .right:
            cursorOffset = min(
                text.count,
                cursorOffset + 1
            )
            return .editing

        case .home:
            cursorOffset = 0
            return .editing

        case .end:
            cursorOffset = text.count
            return .editing

        case .backspace:
            deleteBackward()
            return .editing

        case .delete:
            deleteForward()
            return .editing

        case .space:
            insert(
                " "
            )
            return .editing

        case .char(let value):
            insert(
                value
            )
            return .editing

        default:
            return .editing
        }
    }

    private mutating func resolve() -> ExCommandLineResult {
        let normalized = text
            .split(
                whereSeparator: {
                    $0.isWhitespace
                }
            )
            .joined(
                separator: " "
            )

        guard let command = ExCommand(
            rawValue: normalized
        ) else {
            let invalid = text
            reset()
            return .invalid(
                invalid
            )
        }

        reset()
        return .command(
            command
        )
    }

    private mutating func insert(
        _ value: String
    ) {
        let index = text.index(
            text.startIndex,
            offsetBy: cursorOffset
        )

        text.insert(
            contentsOf: value,
            at: index
        )
        cursorOffset += value.count
    }

    private mutating func deleteBackward() {
        guard cursorOffset > 0 else {
            return
        }

        let end = text.index(
            text.startIndex,
            offsetBy: cursorOffset
        )
        let start = text.index(
            before: end
        )

        text.removeSubrange(
            start..<end
        )
        cursorOffset -= 1
    }

    private mutating func deleteForward() {
        guard cursorOffset < text.count else {
            return
        }

        let start = text.index(
            text.startIndex,
            offsetBy: cursorOffset
        )
        let end = text.index(
            after: start
        )

        text.removeSubrange(
            start..<end
        )
    }
}
