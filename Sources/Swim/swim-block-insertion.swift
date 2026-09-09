import Position
import SwimInterpreter

extension SwimBlockInsertSession {
    public static func begin(
        operation: SwimInterpreter.BlockInsertOperation,
        selection: SwimResolvedBlockSelection,
        in buffer: inout SwimTextBuffer,
        registers: inout SwimRegisterBank,
        displayColumns: any SwimDisplayColumnMappingProviding
    ) -> Self? {
        guard let session = Self(
            operation: operation,
            selection: selection
        ) else {
            return nil
        }

        if operation == .change {
            let resolved = SwimResolvedSelection.block(
                selection
            )
            let registerValue = SwimRegisterValue(
                capturing: resolved,
                in: buffer
            )

            for range in selection.sourceRanges.sorted(
                by: {
                    $0.start > $1.start
                }
            ) {
                _ = buffer.delete(
                    range
                )
            }

            if let registerValue {
                registers.writeUnnamed(
                    registerValue
                )
            }
        }

        let mapping = displayColumns.mapping(
            for: buffer.text
        )

        guard session.preparePrimaryInsertion(
            in: &buffer,
            displayColumns: mapping
        ) else {
            return nil
        }

        return session
    }

    public init?(
        operation: SwimInterpreter.BlockInsertOperation,
        selection: SwimResolvedBlockSelection
    ) {
        guard let primaryRow = selection.rows.first else {
            return nil
        }

        let insertionColumn =
            operation == .insertAfter
            ? selection.columns.upperBound
            : selection.columns.lowerBound

        self.init(
            operation: operation,
            lines: selection.rows.map(\.line),
            insertionColumn: insertionColumn,
            primaryLine: primaryRow.line
        )
    }

    /// Positions the live insertion cursor on the primary line.
    ///
    /// If the requested display column lies beyond textual content, spaces are
    /// inserted so subsequent text begins at the requested display column.
    /// The supplied mapping must describe the buffer state at method entry.
    @discardableResult
    public func preparePrimaryInsertion(
        in buffer: inout SwimTextBuffer,
        displayColumns: any SwimDisplayColumnMapping
    ) -> Bool {
        guard primaryLine <= buffer.lineCount else {
            return false
        }

        let width = displayColumns.width(
            ofLine: primaryLine
        )
        let index = Self.insertionIndex(
            line: primaryLine,
            column: insertionColumn,
            displayColumns: displayColumns
        )
        let paddingCount = max(
            0,
            insertionColumn - width
        )

        _ = buffer.setCursor(
            index
        )

        if paddingCount > 0 {
            guard buffer.insert(
                String(
                    repeating: " ",
                    count: paddingCount
                )
            ) else {
                return false
            }
        }

        return true
    }

    /// Replicates the text already inserted live on the primary line to every
    /// other logical line in the block.
    ///
    /// The supplied mapping must describe the current buffer after the primary
    /// insertion has completed and before replication begins.
    @discardableResult
    public func replicateInsertedText(
        in buffer: inout SwimTextBuffer,
        displayColumns: any SwimDisplayColumnMapping
    ) -> Bool {
        guard !insertedText.isEmpty else {
            return false
        }

        struct Insertion {
            let index: PositionIndex
            let text: String
        }

        let primaryCursor = buffer.cursor
        var insertions: [Insertion] = []

        for line in lines
        where line != primaryLine {
            guard line <= buffer.lineCount else {
                continue
            }

            let width = displayColumns.width(
                ofLine: line
            )
            let index = Self.insertionIndex(
                line: line,
                column: insertionColumn,
                displayColumns: displayColumns
            )
            let paddingCount = max(
                0,
                insertionColumn - width
            )
            let padding = String(
                repeating: " ",
                count: paddingCount
            )

            insertions.append(
                Insertion(
                    index: index,
                    text: padding + insertedText
                )
            )
        }

        guard !insertions.isEmpty else {
            return false
        }

        let primaryShift = insertions.reduce(
            0
        ) { partialResult, insertion in
            insertion.index <= primaryCursor
                ? partialResult + insertion.text.count
                : partialResult
        }
        var changed = false

        for insertion in insertions.sorted(
            by: {
                $0.index > $1.index
            }
        ) {
            _ = buffer.setCursor(
                insertion.index
            )

            changed = buffer.insert(
                insertion.text
            ) || changed
        }

        _ = buffer.setCursor(
            primaryCursor.advanced(
                by: primaryShift
            )
        )

        return changed
    }

    private static func insertionIndex(
        line: Int,
        column: Int,
        displayColumns: any SwimDisplayColumnMapping
    ) -> PositionIndex {
        let index = displayColumns.index(
            line: line,
            column: column
        )
        let resolvedColumn = displayColumns.column(
            at: index
        )
        let lineWidth = displayColumns.width(
            ofLine: line
        )

        if resolvedColumn < column,
           column <= lineWidth
        {
            return index.advanced(
                by: 1
            )
        }

        return index
    }
}
