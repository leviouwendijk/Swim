import Position
import SwimInterpreter

extension SwimEditor {
    mutating func handleCommand(
        _ command: SwimInterpreter.Command,
        context: SwimEditorContext
    ) -> SwimEditorEvent? {
        switch command {
        case .motion(
            let motion,
            count: let count
        ):
            return handleMotion(
                motion,
                count: count,
                context: context
            )
                ? .changed
                : nil

        case .operate(
            let operation,
            target: let target
        ):
            return handleOperator(
                operation,
                target: target,
                context: context
            )

        case .paste(
            let placement,
            count: let count
        ):
            guard let value = registers.unnamed else {
                return nil
            }

            let mapping = context.displayColumns.mapping(
                for: buffer.text
            )

            return SwimRegisterPaste.apply(
                value,
                placement: placement,
                count: count,
                to: &buffer,
                displayColumns: mapping
            )
                ? .changed
                : nil

        case .edit(let edit):
            return handleEdit(
                edit
            )

        case .replaceCharacters(
            let replacement,
            count: let count
        ):
            return buffer.replaceCharactersOnLine(
                count: count,
                with: replacement
            )
                ? .changed
                : nil

        case .joinLines(let count):
            return buffer.joinLines(
                count: count
            )
                ? .changed
                : nil

        case .toggleCase(let count):
            return buffer.toggleCaseOnLine(
                count: count
            )
                ? .changed
                : nil
        }
    }

    mutating func handleEdit(
        _ edit: SwimInterpreter.EditCommand
    ) -> SwimEditorEvent {
        blockInsertSession = nil
        replaceSession = nil
        selection = nil

        switch edit {
        case .insertAtFirstNonWhitespace:
            _ = buffer.moveToFirstNonWhitespaceOnLine()

        case .appendAtLineEnd:
            _ = buffer.moveToLineEnd()

        case .openLineBelow:
            _ = buffer.openLineBelow()

        case .openLineAbove:
            _ = buffer.openLineAbove()

        case .enterReplaceMode:
            replaceSession = SwimReplaceSession(
                start: buffer.cursor
            )
            interaction.setMode(
                .replace
            )
            return .changed
        }

        interaction.setMode(
            .insert
        )
        return .changed
    }

    mutating func handleMotion(
        _ motion: SwimInterpreter.Motion,
        count rawCount: Int = 1,
        context: SwimEditorContext
    ) -> Bool {
        let count = max(
            1,
            rawCount
        )
        let changed: Bool

        if selection?.kind == .block {
            switch motion {
            case .up:
                changed = moveBlockVertically(
                    by: -count,
                    context: context
                )

            case .down:
                changed = moveBlockVertically(
                    by: count,
                    context: context
                )

            default:
                changed = buffer.move(
                    motion,
                    count: count,
                    pageRows: context.pageRows
                )
            }
        } else {
            changed = buffer.move(
                motion,
                count: count,
                pageRows: context.pageRows
            )
        }

        if var selection {
            selection.cursor = buffer.cursor

            if selection.kind == .block,
               motion != .up,
               motion != .down {
                let mapping = context.displayColumns.mapping(
                    for: buffer.text
                )
                selection.blockPreferredColumn = mapping.column(
                    at: buffer.cursor
                )
            }

            self.selection = selection
        }

        return changed
    }

    mutating func moveBlockVertically(
        by lines: Int,
        context: SwimEditorContext
    ) -> Bool {
        let table = LineTable(
            text: buffer.text
        )
        let current = table.indices.clamped(
            buffer.cursor
        )
        let currentLine = table.lines.number(
            containing: current
        )
        let (
            requestedLine,
            overflow
        ) = currentLine.addingReportingOverflow(
            lines
        )
        let targetLine = table.lines.clamped(
            overflow
                ? (
                    lines < 0
                    ? Int.min
                    : Int.max
                )
                : requestedLine
        )

        let mapping = context.displayColumns.mapping(
            for: buffer.text
        )
        let preferredColumn =
            selection?.blockPreferredColumn
            ?? mapping.column(
                at: current
            )
        let target = mapping.index(
            line: targetLine,
            column: preferredColumn
        )

        return buffer.move(
            to: target
        )
    }

    mutating func handleOperator(
        _ operation: SwimInterpreter.Operator,
        target: SwimInterpreter.CommandTarget,
        context: SwimEditorContext
    ) -> SwimEditorEvent? {
        if operation == .shiftLeft
            || operation == .shiftRight
        {
            guard let resolved = SwimTextTargetResolver.resolve(
                target,
                in: buffer,
                pageRows: context.pageRows
            ) else {
                return nil
            }

            let direction: SwimInterpreter.IndentationShift =
                operation == .shiftRight
                ? .right
                : .left

            return buffer.shiftLines(
                in: resolved.range.offsets,
                direction: direction,
                width: shiftWidth
            )
                ? .changed
                : nil
        }

        if operation == .change,
           buffer.isEmpty,
           case .line = target
        {
            registers.writeUnnamed(
                .line(
                    ""
                )
            )
            selection = nil
            interaction.setMode(
                .insert
            )
            return .changed
        }

        guard let resolved = SwimTextTargetResolver.resolve(
            target,
            for: operation,
            in: buffer,
            pageRows: context.pageRows
        ),
        let registerValue = SwimRegisterValue(
            capturing: resolved,
            in: buffer
        ) else {
            return nil
        }

        switch operation {
        case .delete:
            guard buffer.delete(
                resolved.range
            ) else {
                return nil
            }

            registers.writeUnnamed(
                registerValue
            )
            return .changed

        case .yank:
            registers.writeUnnamed(
                registerValue
            )

            return copyEvent(
                value: registerValue,
                sourceRanges: [
                    resolved.range,
                ]
            )

        case .change:
            guard applyChange(
                resolved,
                registerValue: registerValue
            ) else {
                return nil
            }

            registers.writeUnnamed(
                registerValue
            )
            selection = nil
            interaction.setMode(
                .insert
            )
            return .changed

        case .shiftLeft,
             .shiftRight:
            return nil
        }
    }

    @discardableResult
    mutating func applyChange(
        _ resolved: SwimResolvedTextTarget,
        registerValue: SwimRegisterValue
    ) -> Bool {
        switch resolved.kind {
        case .character:
            return buffer.delete(
                resolved.range
            )

        case .line:
            let start = resolved.range.start
            let replacement = registerValue.text.hasSuffix(
                "\n"
            )
                ? "\n"
                : ""
            let changed = buffer.replace(
                resolved.range,
                with: replacement
            )

            if changed {
                _ = buffer.setCursor(
                    start
                )
            }

            return changed
        }
    }

    mutating func deleteSelectionOrCharacter(
        context: SwimEditorContext
    ) -> SwimEditorEvent? {
        if selection != nil {
            let resolved = resolvedSelection(
                context: context
            )

            selection = nil
            interaction.setMode(
                .normal
            )

            guard let resolved,
                  let registerValue = SwimRegisterValue(
                    capturing: resolved,
                    in: buffer
                  ) else {
                return .changed
            }

            guard delete(
                resolved
            ) else {
                return .changed
            }

            registers.writeUnnamed(
                registerValue
            )
            return .changed
        }

        guard buffer.cursor < PositionIndex(
            buffer.characterCount
        ) else {
            return nil
        }

        let range = PositionRange(
            uncheckedStart: buffer.cursor,
            uncheckedEnd: buffer.cursor.advanced(
                by: 1
            )
        )
        let registerValue = SwimRegisterValue.character(
            buffer.text(
                in: range
            )
        )

        guard buffer.delete(
            range
        ) else {
            return nil
        }

        registers.writeUnnamed(
            registerValue
        )
        return .changed
    }

    @discardableResult
    mutating func delete(
        _ selection: SwimResolvedSelection
    ) -> Bool {
        switch selection {
        case .contiguous(let range, _):
            return buffer.delete(
                range
            )

        case .block(let block):
            var changed = false

            for range in block.sourceRanges.sorted(
                by: {
                    $0.start > $1.start
                }
            ) {
                changed =
                    buffer.delete(
                        range
                    )
                    || changed
            }

            return changed
        }
    }

    mutating func changeSelection(
        context: SwimEditorContext
    ) -> SwimEditorEvent? {
        guard let selection,
              selection.kind != .block,
              let resolved = resolvedSelection(
                context: context
              ),
              let registerValue = SwimRegisterValue(
                capturing: resolved,
                in: buffer
              ) else {
            return nil
        }

        guard case .contiguous(
            let range,
            let kind
        ) = resolved else {
            return nil
        }

        let changed: Bool

        switch kind {
        case .character:
            let start = range.start
            changed = buffer.delete(
                range
            )

            if changed {
                _ = buffer.setCursor(
                    start
                )
            }

        case .line:
            let start = range.start
            let replacement = registerValue.text.hasSuffix(
                "\n"
            )
                ? "\n"
                : ""
            changed = buffer.replace(
                range,
                with: replacement
            )

            if changed {
                _ = buffer.setCursor(
                    start
                )
            }

        case .block:
            return nil
        }

        guard changed else {
            return nil
        }

        registers.writeUnnamed(
            registerValue
        )
        self.selection = nil
        interaction.setMode(
            .insert
        )
        return .changed
    }

    mutating func copySelectionOrCharacter(
        context: SwimEditorContext
    ) -> SwimEditorEvent? {
        let resolved: SwimResolvedSelection?

        if selection != nil {
            resolved = resolvedSelection(
                context: context
            )
        } else if buffer.cursor < PositionIndex(
            buffer.characterCount
        ) {
            resolved = .contiguous(
                range: PositionRange(
                    uncheckedStart: buffer.cursor,
                    uncheckedEnd: buffer.cursor.advanced(
                        by: 1
                    )
                ),
                kind: .character
            )
        } else {
            resolved = nil
        }

        selection = nil
        interaction.setMode(
            .normal
        )

        guard let resolved,
              let registerValue = SwimRegisterValue(
                capturing: resolved,
                in: buffer
              ) else {
            return .changed
        }

        registers.writeUnnamed(
            registerValue
        )

        return copyEvent(
            value: registerValue,
            sourceRanges: resolved.sourceRanges
        )
    }

    func copyEvent(
        value: SwimRegisterValue,
        sourceRanges: [PositionRange]
    ) -> SwimEditorEvent {
        .copyRequested(
            SwimEditorCopy(
                value: value,
                sourceRanges: sourceRanges
            )
        )
    }
}
