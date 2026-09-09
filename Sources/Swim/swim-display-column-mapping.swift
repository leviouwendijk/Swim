import Position

/// Maps logical source character indices to display-cell columns.
///
/// Logical lines are one-based, matching `Position` and `LineTable`.
/// Display columns are zero-based.
///
/// A mapping instance must describe the same text being operated on by the
/// caller. The protocol deliberately contains no terminal, viewport, wrapping,
/// or rendering types.
public protocol SwimDisplayColumnMapping:
    Sendable
{
    /// Zero-based display column at the supplied source character index.
    func column(
        at index: PositionIndex
    ) -> Int

    /// Source character index occupying the requested zero-based display
    /// column on a one-based logical line.
    ///
    /// A column beyond textual content resolves to that line's content end.
    func index(
        line: Int,
        column: Int
    ) -> PositionIndex

    /// Display-cell width of textual content on a one-based logical line.
    func width(
        ofLine line: Int
    ) -> Int
}

/// Deterministic non-terminal display-column mapping.
///
/// Tabs advance to the next tab stop. Other characters use the supplied
/// character-width function, whose default treats every Swift `Character` as
/// one display cell. Consumers needing environment-specific Unicode widths
/// should provide another `SwimDisplayColumnMapping` implementation.
public struct SwimHeadlessDisplayColumnMapping:
    SwimDisplayColumnMapping
{
    public let tabWidth: Int

    private let characters: [Character]
    private let table: LineTable
    private let characterWidth: @Sendable (Character) -> Int

    public init(
        text: String,
        tabWidth: Int = 4,
        characterWidth: @escaping @Sendable (Character) -> Int = { _ in 1 }
    ) {
        self.tabWidth = max(
            1,
            tabWidth
        )
        characters = Array(
            text
        )
        table = LineTable(
            text: text
        )
        self.characterWidth = characterWidth
    }

    public func column(
        at requestedIndex: PositionIndex
    ) -> Int {
        let index = table.indices.clamped(
            requestedIndex
        )
        let line = table.lines.number(
            containing: index
        )

        guard let content = table.lines.ranges.content(
            line
        ) else {
            return 0
        }

        let end = min(
            index.offset,
            content.end.offset
        )

        return displayWidth(
            in: content.start.offset..<end
        )
    }

    public func index(
        line requestedLine: Int,
        column requestedColumn: Int
    ) -> PositionIndex {
        let line = min(
            max(
                1,
                requestedLine
            ),
            table.lines.count
        )

        guard let content = table.lines.ranges.content(
            line
        ) else {
            return table.indices.end
        }

        let requestedColumn = max(
            0,
            requestedColumn
        )
        var displayColumn = 0

        for offset in content.offsets {
            let width = displayWidth(
                of: characters[offset],
                at: displayColumn
            )
            let nextColumn = adding(
                width,
                to: displayColumn
            )

            if requestedColumn < nextColumn {
                return PositionIndex(
                    offset
                )
            }

            displayColumn = nextColumn
        }

        return content.end
    }

    public func width(
        ofLine requestedLine: Int
    ) -> Int {
        guard requestedLine >= 1,
              requestedLine <= table.lines.count,
              let content = table.lines.ranges.content(
                requestedLine
              ) else {
            return 0
        }

        return displayWidth(
            in: content.offsets
        )
    }

    private func displayWidth(
        in range: Range<Int>
    ) -> Int {
        var column = 0

        for offset in range {
            column = adding(
                displayWidth(
                    of: characters[offset],
                    at: column
                ),
                to: column
            )
        }

        return column
    }

    private func displayWidth(
        of character: Character,
        at column: Int
    ) -> Int {
        if character == "\t" {
            let remainder = column % tabWidth

            return remainder == 0
                ? tabWidth
                : tabWidth - remainder
        }

        return max(
            1,
            characterWidth(
                character
            )
        )
    }

    private func adding(
        _ amount: Int,
        to value: Int
    ) -> Int {
        let (
            result,
            overflow
        ) = value.addingReportingOverflow(
            amount
        )

        return overflow
            ? Int.max
            : result
    }
}
