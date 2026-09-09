import Position
import SwimInterpreter

public struct SwimSelection:
    Sendable,
    Codable,
    Hashable
{
    public let anchor: PositionIndex
    public var cursor: PositionIndex
    public var kind: SwimInterpreter.SelectionKind
    public var blockPreferredColumn: Int?

    public init(
        anchor: PositionIndex,
        cursor: PositionIndex,
        kind: SwimInterpreter.SelectionKind = .character,
        blockPreferredColumn: Int? = nil
    ) {
        self.anchor = anchor
        self.cursor = cursor
        self.kind = kind
        self.blockPreferredColumn = blockPreferredColumn
    }

    /// Resolves this semantic selection against the supplied buffer.
    ///
    /// Characterwise and linewise selections are purely logical and do not
    /// require a display-column mapping. Blockwise selection requires one.
    public func resolved(
        in buffer: SwimTextBuffer,
        displayColumns: (any SwimDisplayColumnMapping)? = nil
    ) -> SwimResolvedSelection? {
        switch kind {
        case .character:
            guard let range = characterRange(
                characterCount: buffer.characterCount
            ) else {
                return nil
            }

            return .contiguous(
                range: range,
                kind: .character
            )

        case .line:
            guard let range = lineRange(
                in: buffer.text
            ) else {
                return nil
            }

            return .contiguous(
                range: range,
                kind: .line
            )

        case .block:
            guard let displayColumns else {
                return nil
            }

            return .block(
                blockSelection(
                    in: buffer,
                    displayColumns: displayColumns
                )
            )
        }
    }

    public func resolvedRange(
        in buffer: SwimTextBuffer
    ) -> PositionRange? {
        resolved(
            in: buffer
        )?.contiguousRange
    }

    private func characterRange(
        characterCount: Int
    ) -> PositionRange? {
        let anchor = min(
            max(
                0,
                anchor.offset
            ),
            characterCount
        )
        let cursor = min(
            max(
                0,
                cursor.offset
            ),
            characterCount
        )
        let lower = min(
            anchor,
            cursor
        )
        let upper = max(
            anchor,
            cursor
        )

        if lower == upper {
            guard lower < characterCount else {
                return nil
            }

            return PositionRange(
                lower..<(lower + 1)
            )
        }

        return PositionRange(
            lower..<min(
                characterCount,
                upper + 1
            )
        )
    }

    private func lineRange(
        in text: String
    ) -> PositionRange? {
        let table = LineTable(
            text: text
        )

        guard table.indices.count > 0 else {
            return nil
        }

        let lastSourceOffset = table.indices.count - 1
        let anchor = PositionIndex(
            min(
                max(
                    0,
                    self.anchor.offset
                ),
                lastSourceOffset
            )
        )
        let cursor = PositionIndex(
            min(
                max(
                    0,
                    self.cursor.offset
                ),
                lastSourceOffset
            )
        )
        let lowerLine = table.lines.number(
            containing: min(
                anchor,
                cursor
            )
        )
        let upperLine = table.lines.number(
            containing: max(
                anchor,
                cursor
            )
        )

        guard let lower = table.lines.start(
            lowerLine
        ),
        let upper = table.lines.end(
            upperLine
        ),
        lower < upper else {
            return nil
        }

        return PositionRange(
            uncheckedStart: lower,
            uncheckedEnd: upper
        )
    }

    private func blockSelection(
        in buffer: SwimTextBuffer,
        displayColumns: any SwimDisplayColumnMapping
    ) -> SwimResolvedBlockSelection {
        let table = LineTable(
            text: buffer.text
        )
        let anchor = table.indices.clamped(
            self.anchor
        )
        let cursor = table.indices.clamped(
            self.cursor
        )
        let anchorLine = table.lines.number(
            containing: anchor
        )
        let cursorLine = table.lines.number(
            containing: cursor
        )
        let anchorColumn = displayColumns.column(
            at: anchor
        )
        let cursorColumn = displayColumns.column(
            at: cursor
        )
        let anchorEndColumn = endpointEndColumn(
            at: anchor,
            line: anchorLine,
            table: table,
            displayColumns: displayColumns
        )
        let cursorEndColumn = endpointEndColumn(
            at: cursor,
            line: cursorLine,
            table: table,
            displayColumns: displayColumns
        )
        let lowerColumn = min(
            anchorColumn,
            cursorColumn
        )
        let upperColumn = max(
            anchorEndColumn,
            cursorEndColumn
        )
        let columns = lowerColumn..<upperColumn
        let lowerLine = min(
            anchorLine,
            cursorLine
        )
        let upperLine = max(
            anchorLine,
            cursorLine
        )
        let rows = (lowerLine...upperLine).map { line in
            SwimResolvedBlockRow(
                line: line,
                sourceRange: blockSourceRange(
                    line: line,
                    columns: columns,
                    table: table,
                    displayColumns: displayColumns
                )
            )
        }

        return SwimResolvedBlockSelection(
            columns: columns,
            rows: rows
        )
    }

    private func endpointEndColumn(
        at index: PositionIndex,
        line: Int,
        table: LineTable,
        displayColumns: any SwimDisplayColumnMapping
    ) -> Int {
        guard let content = table.lines.ranges.content(
            line
        ),
        content.contains(
            index
        ) else {
            return displayColumns.column(
                at: index
            )
        }

        return displayColumns.column(
            at: PositionIndex(
                min(
                    content.end.offset,
                    index.offset + 1
                )
            )
        )
    }

    private func blockSourceRange(
        line: Int,
        columns: Range<Int>,
        table: LineTable,
        displayColumns: any SwimDisplayColumnMapping
    ) -> PositionRange? {
        guard !columns.isEmpty,
              let content = table.lines.ranges.content(
                line
              ) else {
            return nil
        }

        let width = displayColumns.width(
            ofLine: line
        )

        guard columns.lowerBound < width else {
            return nil
        }

        let lowerIndex = displayColumns.index(
            line: line,
            column: columns.lowerBound
        )
        let lastIndex = displayColumns.index(
            line: line,
            column: min(
                columns.upperBound - 1,
                width - 1
            )
        )
        let lower = min(
            max(
                content.start.offset,
                lowerIndex.offset
            ),
            content.end.offset
        )
        let upper = min(
            content.end.offset,
            max(
                lower,
                lastIndex.offset + 1
            )
        )

        guard lower < upper else {
            return nil
        }

        return PositionRange(
            lower..<upper
        )
    }
}

public enum SwimResolvedSelection:
    Sendable,
    Codable,
    Hashable
{
    case contiguous(
        range: PositionRange,
        kind: SwimInterpreter.SelectionKind
    )
    case block(SwimResolvedBlockSelection)

    public var contiguousRange: PositionRange? {
        guard case .contiguous(
            let range,
            _
        ) = self else {
            return nil
        }

        return range
    }

    public var sourceRanges: [PositionRange] {
        switch self {
        case .contiguous(let range, _):
            return [
                range,
            ]

        case .block(let block):
            return block.sourceRanges
        }
    }
}

public struct SwimResolvedBlockSelection:
    Sendable,
    Codable,
    Hashable
{
    public var columns: Range<Int>
    public var rows: [SwimResolvedBlockRow]

    public init(
        columns: Range<Int>,
        rows: [SwimResolvedBlockRow]
    ) {
        self.columns = columns
        self.rows = rows
    }

    public var sourceRanges: [PositionRange] {
        rows.compactMap(
            \.sourceRange
        )
    }
}

public struct SwimResolvedBlockRow:
    Sendable,
    Codable,
    Hashable
{
    /// One-based logical source line.
    public var line: Int
    public var sourceRange: PositionRange?

    public init(
        line: Int,
        sourceRange: PositionRange?
    ) {
        self.line = line
        self.sourceRange = sourceRange
    }
}
