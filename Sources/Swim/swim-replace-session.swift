import Position

public struct SwimReplaceSession:
    Sendable,
    Codable,
    Hashable
{
    public struct Step:
        Sendable,
        Codable,
        Hashable
    {
        public let index: PositionIndex
        public let original: String?
        public let replacement: String

        public init(
            index: PositionIndex,
            original: String?,
            replacement: String
        ) {
            self.index = PositionIndex(
                max(
                    0,
                    index.offset
                )
            )
            self.original = original
            self.replacement = replacement
        }
    }

    public let start: PositionIndex
    public private(set) var steps: [Step]

    public init(
        start: PositionIndex,
        steps: [Step] = []
    ) {
        self.start = PositionIndex(
            max(
                0,
                start.offset
            )
        )
        self.steps = steps
    }

    @discardableResult
    public mutating func apply(
        _ rawReplacement: String,
        to buffer: inout SwimTextBuffer
    ) -> Bool {
        let replacement =
            rawReplacement == "\r"
            ? "\n"
            : rawReplacement

        guard replacement.count == 1 else {
            return false
        }

        let index = buffer.cursor

        if replacement == "\n" {
            guard buffer.insertNewline() else {
                return false
            }

            steps.append(
                Step(
                    index: index,
                    original: nil,
                    replacement: replacement
                )
            )
            return true
        }

        if index.offset < buffer.characterCount {
            let end = index.advanced(
                by: 1
            )
            let range = PositionRange(
                uncheckedStart: index,
                uncheckedEnd: end
            )
            let next = buffer.text(
                in: range
            )

            if next != "\n" {
                guard buffer.replace(
                    range,
                    with: replacement
                ) else {
                    return false
                }

                steps.append(
                    Step(
                        index: index,
                        original: next,
                        replacement: replacement
                    )
                )
                return true
            }
        }

        guard buffer.insert(
            replacement
        ) else {
            return false
        }

        steps.append(
            Step(
                index: index,
                original: nil,
                replacement: replacement
            )
        )
        return true
    }

    @discardableResult
    public mutating func restoreLast(
        in buffer: inout SwimTextBuffer
    ) -> Bool {
        guard let step = steps.last,
              buffer.cursor == step.index.advanced(
                by: step.replacement.count
              ) else {
            return false
        }

        let end = step.index.advanced(
            by: step.replacement.count
        )
        let range = PositionRange(
            uncheckedStart: step.index,
            uncheckedEnd: end
        )
        let changed: Bool

        if let original = step.original {
            changed = buffer.replace(
                range,
                with: original
            )

            if changed {
                _ = buffer.setCursor(
                    step.index
                )
            }
        } else {
            changed = buffer.delete(
                range
            )
        }

        guard changed else {
            return false
        }

        steps.removeLast()
        return true
    }
}
