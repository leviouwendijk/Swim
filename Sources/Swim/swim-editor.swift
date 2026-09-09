import Position
import SwimInterpreter

public struct SwimEditor:
    Sendable,
    Hashable
{
    public internal(set) var buffer: SwimTextBuffer
    public internal(set) var interaction: SwimInterpreter.ModalInteraction
    public internal(set) var selection: SwimSelection?
    public internal(set) var blockInsertSession: SwimBlockInsertSession?
    public internal(set) var replaceSession: SwimReplaceSession?
    public internal(set) var registers: SwimRegisterBank
    public var shiftWidth: Int
    public internal(set) var history: SwimEditHistory

    public init(
        text: String = "",
        cursor: PositionIndex? = nil,
        mode: SwimInterpreter.Mode = .normal,
        shiftWidth: Int = 4,
        registers: SwimRegisterBank = .init(),
        history: SwimEditHistory = .init()
    ) {
        buffer = SwimTextBuffer(
            text: text,
            cursor: cursor
        )
        interaction = SwimInterpreter.ModalInteraction(
            mode: mode
        )
        selection = mode == .visual
            ? SwimSelection(
                anchor: buffer.cursor,
                cursor: buffer.cursor,
                kind: .character
            )
            : nil
        blockInsertSession = nil
        replaceSession = mode == .replace
            ? SwimReplaceSession(
                start: buffer.cursor
            )
            : nil
        self.registers = registers
        self.shiftWidth = max(
            1,
            shiftWidth
        )
        self.history = history
    }

    public var mode: SwimInterpreter.Mode {
        interaction.mode
    }

    public func resolvedSelection(
        context: SwimEditorContext = .init()
    ) -> SwimResolvedSelection? {
        guard let selection else {
            return nil
        }

        guard selection.kind == .block else {
            return selection.resolved(
                in: buffer
            )
        }

        let mapping = context.displayColumns.mapping(
            for: buffer.text
        )

        return selection.resolved(
            in: buffer,
            displayColumns: mapping
        )
    }

    public func selectionRange(
        context: SwimEditorContext = .init()
    ) -> PositionRange? {
        resolvedSelection(
            context: context
        )?.contiguousRange
    }

    public func selectionRanges(
        context: SwimEditorContext = .init()
    ) -> [PositionRange] {
        resolvedSelection(
            context: context
        )?.sourceRanges ?? []
    }

    public mutating func replace(
        with text: String,
        cursor: PositionIndex? = nil
    ) {
        buffer.replace(
            with: text,
            cursor: cursor
        )
        selection = nil
        blockInsertSession = nil
        replaceSession = nil
        history.reset()
    }

    public mutating func setMode(
        _ mode: SwimInterpreter.Mode
    ) {
        let previousMode = interaction.mode

        if !isEditingMode(
            previousMode
        ),
        isEditingMode(
            mode
        ) {
            _ = history.begin(
                with: buffer
            )
        }

        interaction.setMode(
            mode
        )
        replaceSession = mode == .replace
            ? SwimReplaceSession(
                start: buffer.cursor
            )
            : nil

        if mode != .visual {
            selection = nil
        } else if selection == nil {
            selection = SwimSelection(
                anchor: buffer.cursor,
                cursor: buffer.cursor,
                kind:
                    interaction.visualSelectionKind
                    ?? .character
            )
        }

        if isEditingMode(
            previousMode
        ),
        !isEditingMode(
            mode
        ) {
            _ = history.commit(
                current: buffer
            )
        }
    }

    public mutating func handle(
        _ input: SwimInterpreter.Input,
        context: SwimEditorContext = .init()
    ) -> SwimEditorEvent? {
        let before = buffer
        let modeBefore = mode

        switch interaction.handle(
            input
        ) {
        case .consumed:
            return nil

        case .unhandled:
            if case .escape = input {
                return .cancelRequested
            }

            return nil

        case .action(let action):
            let event = apply(
                action,
                context: context
            )

            if !isHistoryNavigation(
                action
            ) {
                reconcileHistory(
                    before: before,
                    modeBefore: modeBefore
                )
            }

            return event
        }
    }

    public mutating func paste(
        _ text: String,
        context: SwimEditorContext = .init()
    ) -> SwimEditorEvent? {
        let before = buffer
        let modeBefore = mode
        let event = insertPastedText(
            text,
            context: context
        )

        reconcileHistory(
            before: before,
            modeBefore: modeBefore
        )
        return event
    }

    private func isHistoryNavigation(
        _ action: SwimInterpreter.InteractionAction
    ) -> Bool {
        switch action {
        case .undo,
             .redo:
            return true

        default:
            return false
        }
    }

    private func isEditingMode(
        _ mode: SwimInterpreter.Mode
    ) -> Bool {
        mode == .insert
            || mode == .replace
    }

    private mutating func reconcileHistory(
        before: SwimTextBuffer,
        modeBefore: SwimInterpreter.Mode
    ) {
        let modeAfter = mode
        let enteredEditing =
            !isEditingMode(
                modeBefore
            )
            && isEditingMode(
                modeAfter
            )
        let leftEditing =
            isEditingMode(
                modeBefore
            )
            && !isEditingMode(
                modeAfter
            )
        let textChanged =
            before.text != buffer.text

        if enteredEditing {
            _ = history.begin(
                with: before
            )
        }

        if textChanged,
           !history.hasPendingTransaction {
            if isEditingMode(
                modeAfter
            ) {
                _ = history.begin(
                    with: before
                )
            } else {
                _ = history.record(
                    before: before,
                    after: buffer
                )
            }
        }

        if leftEditing {
            _ = history.commit(
                current: buffer
            )
        }
    }

    mutating func undoHistory() -> SwimEditorEvent? {
        guard let restored = history.undo(
            current: buffer
        ) else {
            return nil
        }

        restoreHistoryBuffer(
            restored
        )
        return .changed
    }

    mutating func redoHistory() -> SwimEditorEvent? {
        guard let restored = history.redo() else {
            return nil
        }

        restoreHistoryBuffer(
            restored
        )
        return .changed
    }

    mutating func restoreHistoryBuffer(
        _ restored: SwimTextBuffer
    ) {
        buffer = restored
        interaction.setMode(
            .normal
        )
        selection = nil
        blockInsertSession = nil
        replaceSession = nil
    }
}
