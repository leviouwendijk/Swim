import Position
import SwimInterpreter

public enum SwimRegisterPaste {
    public static let maximumInsertedCharacterCount =
        1_000_000

    @discardableResult
    public static func apply(
        _ value: SwimRegisterValue,
        placement: SwimInterpreter.PastePlacement,
        count rawCount: Int = 1,
        to buffer: inout SwimTextBuffer,
        displayColumns: (any SwimDisplayColumnMapping)? = nil
    ) -> Bool {
        let count = max(
            1,
            rawCount
        )

        switch value {
        case .character(let text):
            return pasteCharacter(
                text,
                placement: placement,
                count: count,
                to: &buffer
            )

        case .line(let text):
            return pasteLine(
                text,
                placement: placement,
                count: count,
                to: &buffer
            )

        case .block(let rows):
            guard let displayColumns else {
                return false
            }

            return pasteBlock(
                rows,
                placement: placement,
                count: count,
                to: &buffer,
                displayColumns: displayColumns
            )
        }
    }

    private static func pasteCharacter(
        _ text: String,
        placement: SwimInterpreter.PastePlacement,
        count: Int,
        to buffer: inout SwimTextBuffer
    ) -> Bool {
        guard let payload = repeated(
            text,
            count: count
        ),
        !payload.isEmpty else {
            return false
        }

        let insertionOffset: Int

        switch placement {
        case .beforeCursor:
            insertionOffset = buffer.cursor.offset

        case .afterCursor:
            insertionOffset = buffer.cursor.offset
                < buffer.characterCount
                ? buffer.cursor.offset + 1
                : buffer.characterCount
        }

        _ = buffer.setCursor(
            PositionIndex(
                insertionOffset
            )
        )

        guard buffer.insert(
            payload
        ) else {
            return false
        }

        _ = buffer.setCursor(
            PositionIndex(
                insertionOffset
                + payload.count
                - 1
            )
        )

        return true
    }

    private static func pasteLine(
        _ text: String,
        placement: SwimInterpreter.PastePlacement,
        count: Int,
        to buffer: inout SwimTextBuffer
    ) -> Bool {
        let line = text.hasSuffix(
            "\n"
        )
            ? text
            : text + "\n"

        guard let payload = repeated(
            line,
            count: count
        ) else {
            return false
        }

        if buffer.isEmpty {
            _ = buffer.setCursor(
                PositionIndex(0)
            )

            guard buffer.insert(
                payload
            ) else {
                return false
            }

            _ = buffer.setCursor(
                PositionIndex(0)
            )
            return true
        }

        let table = LineTable(
            text: buffer.text
        )
        let cursor = table.indices.clamped(
            buffer.cursor
        )
        let currentLine = table.lines.number(
            containing: cursor
        )

        guard let currentStart = table.lines.start(
            currentLine
        ),
        let currentContentEnd = table.lines.contentEnd(
            currentLine
        ),
        let currentStructuralEnd = table.lines.end(
            currentLine
        ) else {
            return false
        }

        let hasTerminatingNewline =
            currentStructuralEnd > currentContentEnd
        let insertionOffset: Int
        let insertion: String
        let cursorOffset: Int

        switch placement {
        case .beforeCursor:
            insertionOffset = currentStart.offset
            insertion = payload
            cursorOffset = currentStart.offset

        case .afterCursor:
            if hasTerminatingNewline {
                insertionOffset = currentStructuralEnd.offset
                insertion = payload
                cursorOffset = insertionOffset
            } else {
                insertionOffset = currentContentEnd.offset
                insertion = "\n" + payload
                cursorOffset = insertionOffset + 1
            }
        }

        guard insertion.count
            <= maximumInsertedCharacterCount else {
            return false
        }

        _ = buffer.setCursor(
            PositionIndex(
                insertionOffset
            )
        )

        guard buffer.insert(
            insertion
        ) else {
            return false
        }

        _ = buffer.setCursor(
            PositionIndex(
                cursorOffset
            )
        )
        return true
    }

    private static func pasteBlock(
        _ rows: [String],
        placement: SwimInterpreter.PastePlacement,
        count: Int,
        to buffer: inout SwimTextBuffer,
        displayColumns: any SwimDisplayColumnMapping
    ) -> Bool {
        guard !rows.isEmpty else {
            return false
        }

        let repeatedRows = rows.compactMap { row in
            repeated(
                row,
                count: count
            )
        }

        guard repeatedRows.count == rows.count else {
            return false
        }

        let originalTable = LineTable(
            text: buffer.text
        )
        let sourceIndex = originalTable.indices.clamped(
            buffer.cursor
        )
        let sourceLine = originalTable.lines.number(
            containing: sourceIndex
        )
        let sourceColumn = displayColumns.column(
            at: sourceIndex
        )
        let insertionColumn: Int

        switch placement {
        case .beforeCursor:
            insertionColumn = sourceColumn

        case .afterCursor:
            insertionColumn = endpointColumn(
                at: sourceIndex,
                line: sourceLine,
                table: originalTable,
                displayColumns: displayColumns
            )
        }

        let originalLineCount = originalTable.lines.count
        let requiredLineCount =
            sourceLine
            + repeatedRows.count
            - 1

        if originalLineCount < requiredLineCount {
            let missing =
                requiredLineCount
                - originalLineCount

            _ = buffer.setCursor(
                originalTable.indices.end
            )

            guard buffer.insert(
                String(
                    repeating: "\n",
                    count: missing
                )
            ) else {
                return false
            }
        }

        let table = LineTable(
            text: buffer.text
        )
        var insertions: [
            (
                offset: PositionIndex,
                text: String,
                cursor: PositionIndex
            )
        ] = []
        var insertedCharacterCount = 0

        for (
            rowIndex,
            fragment
        ) in repeatedRows.enumerated() {
            guard !fragment.isEmpty else {
                continue
            }

            let line = sourceLine + rowIndex

            guard let content = table.lines.ranges.content(
                line
            ) else {
                return false
            }

            let lineWidth: Int
            let offset: PositionIndex

            if line <= originalLineCount {
                lineWidth = displayColumns.width(
                    ofLine: line
                )
                offset = insertionIndex(
                    atColumn: insertionColumn,
                    line: line,
                    content: content,
                    displayColumns: displayColumns
                )
            } else {
                lineWidth = 0
                offset = content.start
            }

            let paddingCount = max(
                0,
                insertionColumn - lineWidth
            )
            let padding = String(
                repeating: " ",
                count: paddingCount
            )
            let insertion = padding + fragment
            let (
                nextInsertedCharacterCount,
                overflow
            ) = insertedCharacterCount
                .addingReportingOverflow(
                    insertion.count
                )

            guard !overflow,
                  nextInsertedCharacterCount
                    <= maximumInsertedCharacterCount else {
                return false
            }

            insertedCharacterCount =
                nextInsertedCharacterCount

            insertions.append(
                (
                    offset: offset,
                    text: insertion,
                    cursor: PositionIndex(
                        offset.offset + paddingCount
                    )
                )
            )
        }

        guard !insertions.isEmpty else {
            return false
        }

        for insertion in insertions.reversed() {
            _ = buffer.setCursor(
                insertion.offset
            )
            _ = buffer.insert(
                insertion.text
            )
        }

        _ = buffer.setCursor(
            insertions[0].cursor
        )

        return true
    }

    private static func repeated(
        _ text: String,
        count: Int
    ) -> String? {
        let (
            characterCount,
            overflow
        ) = text.count.multipliedReportingOverflow(
            by: count
        )

        guard !overflow,
              characterCount
                <= maximumInsertedCharacterCount else {
            return nil
        }

        return String(
            repeating: text,
            count: count
        )
    }

    private static func endpointColumn(
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

    private static func insertionIndex(
        atColumn column: Int,
        line: Int,
        content: PositionRange,
        displayColumns: any SwimDisplayColumnMapping
    ) -> PositionIndex {
        let index = displayColumns.index(
            line: line,
            column: column
        )
        let resolvedColumn = displayColumns.column(
            at: index
        )

        if resolvedColumn < column,
           index < content.end {
            return PositionIndex(
                index.offset + 1
            )
        }

        return index
    }
}
