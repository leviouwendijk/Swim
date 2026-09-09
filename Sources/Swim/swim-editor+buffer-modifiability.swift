import SwimInterpreter

extension SwimEditor {
    func rejection(
        for action: SwimInterpreter.InteractionAction
    ) -> SwimEditorRejection? {
        guard bufferModifiability == .nonmodifiable,
              !allowsActionInNonmodifiableBuffer(
                action
              ) else {
            return nil
        }

        return bufferModificationRejection
    }

    var bufferModificationRejection: SwimEditorRejection? {
        guard bufferModifiability == .nonmodifiable else {
            return nil
        }

        return SwimEditorRejection(
            reason: .bufferNonmodifiable
        )
    }

    private func allowsActionInNonmodifiableBuffer(
        _ action: SwimInterpreter.InteractionAction
    ) -> Bool {
        switch action {
        case .motion,
             .enterVisual,
             .enterCommandLine,
             .returnToNormal,
             .activate,
             .copy:
            return true

        case .command(let command):
            return allowsBufferCommand(
                command
            )

        case .literal,
             .enterInsert,
             .enterBlockInsert,
             .delete,
             .change,
             .undo,
             .redo:
            return false
        }
    }

    mutating func normalizeAfterRejectedBufferModification() {
        if mode == .insert
            || mode == .replace
        {
            interaction.setMode(
                .normal
            )
        }

        if mode != .visual {
            selection = nil
        }

        blockInsertSession = nil
        replaceSession = nil
    }

    private func allowsBufferCommand(
        _ command: SwimInterpreter.Command
    ) -> Bool {
        switch command {
        case .motion:
            return true

        case .operate(
            let operation,
            target: _
        ):
            return operation == .yank

        case .paste,
             .edit,
             .replaceCharacters,
             .joinLines,
             .toggleCase:
            return false
        }
    }
}
