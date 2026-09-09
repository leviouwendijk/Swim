import Foundation
import SwimInterpreter

extension SwimEditor {
    mutating func apply(
        _ action: SwimInterpreter.InteractionAction,
        context: SwimEditorContext
    ) -> SwimEditorEvent? {
        switch action {
        case .literal(let input):
            return handleLiteral(
                input,
                context: context
            )

        case .motion(let motion):
            let finalized = finalizeBlockInsertSession(
                context: context
            )
            let moved = handleMotion(
                motion,
                context: context
            )

            if moved,
               replaceSession != nil {
                replaceSession = SwimReplaceSession(
                    start: buffer.cursor
                )
            }

            return finalized || moved
                ? .changed
                : nil

        case .command(let command):
            return handleCommand(
                command,
                context: context
            )

        case .enterInsert(let placement):
            blockInsertSession = nil
            replaceSession = nil
            selection = nil

            if placement == .afterCursor {
                _ = buffer.moveRight()
            }

            return .changed

        case .enterBlockInsert(let operation):
            replaceSession = nil
            return beginBlockInsert(
                operation,
                context: context
            )

        case .enterVisual(let kind):
            blockInsertSession = nil
            replaceSession = nil
            var selection =
                self.selection
                ?? SwimSelection(
                    anchor: buffer.cursor,
                    cursor: buffer.cursor,
                    kind: kind
                )

            selection.cursor = buffer.cursor
            selection.kind = kind

            if kind == .block {
                let mapping = context.displayColumns.mapping(
                    for: buffer.text
                )
                selection.blockPreferredColumn = mapping.column(
                    at: buffer.cursor
                )
            } else {
                selection.blockPreferredColumn = nil
            }

            self.selection = selection
            return .changed

        case .enterCommandLine:
            return .commandLineRequested

        case .returnToNormal:
            _ = finalizeBlockInsertSession(
                context: context
            )
            replaceSession = nil
            selection = nil
            return .changed

        case .activate:
            return nil

        case .delete:
            return deleteSelectionOrCharacter(
                context: context
            )

        case .copy:
            return copySelectionOrCharacter(
                context: context
            )

        case .change:
            return changeSelection(
                context: context
            )

        case .undo:
            return undoHistory()

        case .redo:
            return redoHistory()
        }
    }

    mutating func insertPastedText(
        _ text: String,
        context: SwimEditorContext
    ) -> SwimEditorEvent? {
        if replaceSession != nil {
            return handleReplacePastedText(
                text
            )
        }

        if blockInsertSession != nil {
            return handleBlockInsertPastedText(
                text,
                context: context
            )
        }

        if selection?.kind == .block {
            return nil
        }

        if let range = selectionRange(
            context: context
        ) {
            _ = buffer.replace(
                range,
                with: text
            )
            selection = nil
            interaction.setMode(
                .insert
            )
            return .changed
        }

        return buffer.insert(
            text
        )
            ? .changed
            : nil
    }

    mutating func handleLiteral(
        _ input: SwimInterpreter.Input,
        context: SwimEditorContext
    ) -> SwimEditorEvent? {
        if replaceSession != nil {
            return handleReplaceLiteral(
                input
            )
        }

        if blockInsertSession != nil {
            return handleBlockInsertLiteral(
                input,
                context: context
            )
        }

        let changed: Bool

        switch input {
        case .char(let text):
            changed = buffer.insert(
                text
            )

        case .space:
            changed = buffer.insert(
                " "
            )

        case .tab:
            changed = buffer.insert(
                "\t"
            )

        case .enter:
            changed = buffer.insertNewline()

        case .backspace,
             .control("H"):
            changed = buffer.deleteBackward()

        case .delete:
            changed = buffer.deleteForward()

        default:
            return nil
        }

        return changed
            ? .changed
            : nil
    }

    mutating func handleReplaceLiteral(
        _ input: SwimInterpreter.Input
    ) -> SwimEditorEvent? {
        guard var session = replaceSession else {
            return nil
        }

        let changed: Bool

        switch input {
        case .char(let text):
            changed = session.apply(
                text,
                to: &buffer
            )

        case .space:
            changed = session.apply(
                " ",
                to: &buffer
            )

        case .tab:
            changed = session.apply(
                "\t",
                to: &buffer
            )

        case .enter:
            changed = session.apply(
                "\n",
                to: &buffer
            )

        case .backspace,
             .control("H"):
            changed = session.restoreLast(
                in: &buffer
            )

        case .delete:
            changed = buffer.deleteForward()

            if changed {
                session = SwimReplaceSession(
                    start: buffer.cursor
                )
            }

        default:
            return nil
        }

        replaceSession = session

        return changed
            ? .changed
            : nil
    }

    mutating func handleReplacePastedText(
        _ text: String
    ) -> SwimEditorEvent? {
        guard var session = replaceSession else {
            return nil
        }

        let normalized = text
            .replacingOccurrences(
                of: "\r\n",
                with: "\n"
            )
            .replacingOccurrences(
                of: "\r",
                with: "\n"
            )

        guard !normalized.isEmpty else {
            return nil
        }

        var changed = false

        for character in normalized {
            changed =
                session.apply(
                    String(
                        character
                    ),
                    to: &buffer
                )
                || changed
        }

        replaceSession = session

        return changed
            ? .changed
            : nil
    }

    mutating func handleBlockInsertLiteral(
        _ input: SwimInterpreter.Input,
        context: SwimEditorContext
    ) -> SwimEditorEvent? {
        switch input {
        case .char(let text):
            return appendBlockInsertText(
                text
            )

        case .space:
            return appendBlockInsertText(
                " "
            )

        case .tab:
            return appendBlockInsertText(
                "\t"
            )

        case .backspace,
             .control("H"):
            guard var session = blockInsertSession,
                  !session.insertedText.isEmpty else {
                _ = finalizeBlockInsertSession(
                    context: context
                )

                return buffer.deleteBackward()
                    ? .changed
                    : nil
            }

            guard buffer.deleteBackward() else {
                return nil
            }

            _ = session.removeLastCharacter()
            blockInsertSession = session
            return .changed

        case .enter:
            _ = finalizeBlockInsertSession(
                context: context
            )

            return buffer.insertNewline()
                ? .changed
                : nil

        case .delete:
            _ = finalizeBlockInsertSession(
                context: context
            )

            return buffer.deleteForward()
                ? .changed
                : nil

        default:
            return nil
        }
    }

    mutating func handleBlockInsertPastedText(
        _ text: String,
        context: SwimEditorContext
    ) -> SwimEditorEvent? {
        guard !text.contains(
            "\n"
        ),
        !text.contains(
            "\r"
        ) else {
            _ = finalizeBlockInsertSession(
                context: context
            )

            return buffer.insert(
                text
            )
                ? .changed
                : nil
        }

        return appendBlockInsertText(
            text
        )
    }

    mutating func appendBlockInsertText(
        _ text: String
    ) -> SwimEditorEvent? {
        guard var session = blockInsertSession,
              !text.isEmpty,
              buffer.insert(
                text
              ) else {
            return nil
        }

        session.append(
            text
        )
        blockInsertSession = session
        return .changed
    }

    mutating func beginBlockInsert(
        _ operation: SwimInterpreter.BlockInsertOperation,
        context: SwimEditorContext
    ) -> SwimEditorEvent? {
        guard let selection,
              selection.kind == .block else {
            return nil
        }

        let mapping = context.displayColumns.mapping(
            for: buffer.text
        )

        guard case .block(let block)? = selection.resolved(
            in: buffer,
            displayColumns: mapping
        ),
        let session = SwimBlockInsertSession.begin(
            operation: operation,
            selection: block,
            in: &buffer,
            registers: &registers,
            displayColumns: context.displayColumns
        ) else {
            return nil
        }

        self.selection = nil
        interaction.setMode(
            .insert
        )
        blockInsertSession = session
        return .changed
    }

    @discardableResult
    mutating func finalizeBlockInsertSession(
        context: SwimEditorContext
    ) -> Bool {
        guard let session = blockInsertSession else {
            return false
        }

        blockInsertSession = nil

        guard !session.insertedText.isEmpty else {
            return false
        }

        let mapping = context.displayColumns.mapping(
            for: buffer.text
        )

        return session.replicateInsertedText(
            in: &buffer,
            displayColumns: mapping
        )
    }
}
