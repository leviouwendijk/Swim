import Position
import SwimInterpreter

public enum SwimTextTargetKind:
    String,
    Sendable,
    Codable,
    Hashable,
    CaseIterable
{
    case character
    case line
}

public struct SwimResolvedTextTarget:
    Sendable,
    Codable,
    Hashable
{
    public let range: PositionRange
    public let kind: SwimTextTargetKind

    public init(
        range: PositionRange,
        kind: SwimTextTargetKind
    ) {
        self.range = range
        self.kind = kind
    }

    init(
        range: Range<Int>,
        kind: SwimTextTargetKind
    ) {
        self.init(
            range: PositionRange(
                range
            ),
            kind: kind
        )
    }
}

public enum SwimTextTargetResolver {
    public static func resolve(
        _ target: SwimInterpreter.CommandTarget,
        for operation: SwimInterpreter.Operator,
        in buffer: SwimTextBuffer,
        pageRows rawPageRows: Int = 1
    ) -> SwimResolvedTextTarget? {
        guard let resolved = resolve(
            target,
            in: buffer,
            pageRows: rawPageRows
        ) else {
            return nil
        }

        guard operation == .change else {
            return resolved
        }

        return adjustedForChange(
            resolved,
            target: target,
            in: buffer
        )
    }

    public static func resolve(
        _ target: SwimInterpreter.CommandTarget,
        in buffer: SwimTextBuffer,
        pageRows rawPageRows: Int = 1
    ) -> SwimResolvedTextTarget? {
        let pageRows = max(
            1,
            rawPageRows
        )

        switch target {
        case .characters(let count):
            guard let range = characterRange(
                in: buffer,
                count: max(
                    1,
                    count
                )
            ) else {
                return nil
            }

            return SwimResolvedTextTarget(
                range: range,
                kind: .character
            )

        case .line(let count):
            guard let range = lineRange(
                in: buffer,
                fromLineContaining: buffer.cursor.offset,
                downwardLineCount: max(
                    1,
                    count
                )
            ) else {
                return nil
            }

            return SwimResolvedTextTarget(
                range: range,
                kind: .line
            )

        case .motion(
            let motion,
            count: let count
        ):
            return resolveMotion(
                motion,
                count: max(
                    1,
                    count
                ),
                in: buffer,
                pageRows: pageRows
            )
        }
    }

    private static func resolveMotion(
        _ motion: SwimInterpreter.Motion,
        count: Int,
        in buffer: SwimTextBuffer,
        pageRows: Int
    ) -> SwimResolvedTextTarget? {
        switch motion {
        case .up:
            return linewiseVerticalTarget(
                direction: -1,
                count: count,
                in: buffer
            )

        case .down:
            return linewiseVerticalTarget(
                direction: 1,
                count: count,
                in: buffer
            )

        case .documentStart:
            guard let current = lineRange(
                in: buffer,
                fromLineContaining: buffer.cursor.offset,
                downwardLineCount: 1
            ) else {
                return nil
            }

            return SwimResolvedTextTarget(
                range: 0..<current.upperBound,
                kind: .line
            )

        case .documentEnd:
            let lower = lineStart(
                in: buffer.text,
                containing: buffer.cursor.offset
            )

            guard lower < buffer.characterCount else {
                return nil
            }

            return SwimResolvedTextTarget(
                range: lower..<buffer.characterCount,
                kind: .line
            )

        case .pageUp:
            return linewiseVerticalTarget(
                direction: -1,
                count: multipliedCount(
                    count,
                    pageRows
                ),
                in: buffer
            )

        case .pageDown:
            return linewiseVerticalTarget(
                direction: 1,
                count: multipliedCount(
                    count,
                    pageRows
                ),
                in: buffer
            )

        case .left,
             .right,
             .wordBackward,
             .wordForward,
             .wordEnd,
             .lineStart,
             .lineEnd:
            var destination = buffer
            let origin = buffer.cursor.offset

            _ = destination.move(
                motion,
                count: count,
                pageRows: pageRows
            )

            let targetOffset = destination.cursor.offset

            guard targetOffset != origin else {
                return nil
            }

            return SwimResolvedTextTarget(
                range:
                    min(
                        origin,
                        targetOffset
                    )..<max(
                        origin,
                        targetOffset
                    ),
                kind: .character
            )
        }
    }

    private static func linewiseVerticalTarget(
        direction: Int,
        count: Int,
        in buffer: SwimTextBuffer
    ) -> SwimResolvedTextTarget? {
        let currentStart = lineStart(
            in: buffer.text,
            containing: buffer.cursor.offset
        )

        guard currentStart < buffer.characterCount else {
            return nil
        }

        if direction >= 0 {
            guard let range = lineRange(
                in: buffer,
                fromLineContaining: currentStart,
                downwardLineCount: count + 1
            ) else {
                return nil
            }

            return SwimResolvedTextTarget(
                range: range,
                kind: .line
            )
        }

        let lower = lineStartMovingUp(
            in: buffer.text,
            from: currentStart,
            count: count
        )
        guard let current = lineRange(
            in: buffer,
            fromLineContaining: currentStart,
            downwardLineCount: 1
        ) else {
            return nil
        }

        return SwimResolvedTextTarget(
            range: lower..<current.upperBound,
            kind: .line
        )
    }

    private static func characterRange(
        in buffer: SwimTextBuffer,
        count: Int
    ) -> Range<Int>? {
        let lower = buffer.cursor.offset
        let end = lineEnd(
            in: buffer.text,
            containing: lower
        )
        let available = max(
            0,
            end - lower
        )
        let length = min(
            max(
                1,
                count
            ),
            available
        )

        guard length > 0 else {
            return nil
        }

        return lower..<(lower + length)
    }

    private static func lineRange(
        in buffer: SwimTextBuffer,
        fromLineContaining offset: Int,
        downwardLineCount rawCount: Int
    ) -> Range<Int>? {
        guard !buffer.text.isEmpty else {
            return nil
        }

        let table = LineTable(
            text: buffer.text
        )
        let firstLine = table.lines.number(
            containing: PositionIndex(
                offset
            )
        )

        guard let lower = table.lines.start(
            firstLine
        ),
        lower.offset < buffer.characterCount else {
            return nil
        }

        let requestedAdvance = max(
            1,
            rawCount
        ) - 1
        let maximumAdvance = max(
            0,
            table.lines.count - firstLine
        )
        let lastLine = firstLine + min(
            requestedAdvance,
            maximumAdvance
        )

        guard let upper = table.lines.end(
            lastLine
        ) else {
            return nil
        }

        return lower.offset..<upper.offset
    }

    private static func lineEnd(
        in text: String,
        containing requestedOffset: Int
    ) -> Int {
        LineTable(
            text: text
        )
        .lines
        .contentEnd(
            containing: PositionIndex(
                requestedOffset
            )
        )
        .offset
    }

    private static func lineStart(
        in text: String,
        containing requestedOffset: Int
    ) -> Int {
        LineTable(
            text: text
        )
        .lines
        .start(
            containing: PositionIndex(
                requestedOffset
            )
        )
        .offset
    }

    private static func lineStartMovingUp(
        in text: String,
        from requestedStart: Int,
        count rawCount: Int
    ) -> Int {
        let table = LineTable(
            text: text
        )
        let currentLine = table.lines.number(
            containing: table.indices.clamped(
                PositionIndex(
                    requestedStart
                )
            )
        )
        let distance = min(
            max(
                0,
                rawCount
            ),
            max(
                0,
                currentLine - 1
            )
        )
        let targetLine = currentLine - distance

        return table.lines.start(
            targetLine
        )?.offset ?? 0
    }

    private static func adjustedForChange(
        _ resolved: SwimResolvedTextTarget,
        target: SwimInterpreter.CommandTarget,
        in buffer: SwimTextBuffer
    ) -> SwimResolvedTextTarget {
        guard case .motion(
            .wordForward,
            count: _
        ) = target,
        buffer.cursor.offset < buffer.characterCount else {
            return resolved
        }

        let characters = Array(
            buffer.text
        )

        guard !isWhitespace(
            characters[
                buffer.cursor.offset
            ]
        ) else {
            return resolved
        }

        var upper = resolved.range.end.offset

        while upper > resolved.range.start.offset,
              isWhitespace(
                characters[
                    upper - 1
                ]
              )
        {
            upper -= 1
        }

        guard upper > resolved.range.start.offset else {
            return resolved
        }

        return SwimResolvedTextTarget(
            range:
                resolved.range.start.offset..<upper,
            kind: resolved.kind
        )
    }

    private static func isWhitespace(
        _ character: Character
    ) -> Bool {
        character == " "
            || character == "\t"
            || character == "\n"
    }

    private static func multipliedCount(
        _ lhs: Int,
        _ rhs: Int
    ) -> Int {
        let (
            value,
            overflow
        ) = lhs.multipliedReportingOverflow(
            by: rhs
        )

        return overflow
            ? Int.max
            : max(
                1,
                value
            )
    }
}
