import Foundation
import Position
import Swim
import SwimIO

enum SwimEditHistorySmoke {
    enum Failure:
        Error
    {
        case unexpectedUndoRedo
        case unexpectedTransactionGrouping
        case unexpectedBranching
        case unexpectedLimit
        case unexpectedDisabledHistory
        case unexpectedNoopRecord
        case unexpectedPersistentRoundTrip
    }

    static func run() throws {
        try runUndoRedoProbe()
        try runTransactionProbe()
        try runBranchProbe()
        try runLimitProbe()
        try runDisabledHistoryProbe()
        try runPersistentRoundTripProbe()
    }

    private static func runUndoRedoProbe() throws {
        let a = buffer(
            "a"
        )
        let b = buffer(
            "ab"
        )
        let c = buffer(
            "abc"
        )
        var history = SwimEditHistory()

        guard history.record(
            before: a,
            after: b
        ),
        history.record(
            before: b,
            after: c
        ),
        history.undoDepth == 2,
        history.redoDepth == 0,
        history.undo(
            current: c
        ) == b,
        history.undo(
            current: b
        ) == a,
        !history.canUndo,
        history.redoDepth == 2,
        history.redo() == b,
        history.redo() == c,
        !history.canRedo else {
            throw Failure.unexpectedUndoRedo
        }
    }

    private static func runTransactionProbe() throws {
        let before = buffer(
            "alpha"
        )
        var current = before
        var history = SwimEditHistory()

        guard history.begin(
            with: before
        ),
        history.hasPendingTransaction else {
            throw Failure.unexpectedTransactionGrouping
        }

        current.replace(
            with: "alpha beta",
            cursor: PositionIndex(10)
        )
        current.replace(
            with: "alpha beta gamma",
            cursor: PositionIndex(16)
        )

        guard history.commit(
            current: current
        ),
        !history.hasPendingTransaction,
        history.undoDepth == 1,
        history.undo(
            current: current
        ) == before,
        history.redo() == current else {
            throw Failure.unexpectedTransactionGrouping
        }

        var cursorOnly = current
        _ = cursorOnly.setCursor(
            PositionIndex(0)
        )

        guard history.begin(
            with: current
        ),
        !history.commit(
            current: cursorOnly
        ),
        history.undoDepth == 1 else {
            throw Failure.unexpectedNoopRecord
        }
    }

    private static func runBranchProbe() throws {
        let a = buffer(
            "a"
        )
        let b = buffer(
            "ab"
        )
        let c = buffer(
            "abc"
        )
        let branch = buffer(
            "ab!"
        )
        var history = SwimEditHistory()

        _ = history.record(
            before: a,
            after: b
        )
        _ = history.record(
            before: b,
            after: c
        )

        guard history.undo(
            current: c
        ) == b,
        history.canRedo,
        history.record(
            before: b,
            after: branch
        ),
        !history.canRedo,
        history.redoDepth == 0,
        history.undo(
            current: branch
        ) == b else {
            throw Failure.unexpectedBranching
        }
    }

    private static func runLimitProbe() throws {
        let a = buffer(
            "a"
        )
        let b = buffer(
            "ab"
        )
        let c = buffer(
            "abc"
        )
        let d = buffer(
            "abcd"
        )
        var history = SwimEditHistory(
            limit: 2
        )

        _ = history.record(
            before: a,
            after: b
        )
        _ = history.record(
            before: b,
            after: c
        )
        _ = history.record(
            before: c,
            after: d
        )

        guard history.entryCount == 2,
        history.undoDepth == 2,
        history.undo(
            current: d
        ) == c,
        history.undo(
            current: c
        ) == b,
        history.undo(
            current: b
        ) == nil else {
            throw Failure.unexpectedLimit
        }
    }

    private static func runDisabledHistoryProbe() throws {
        let a = buffer(
            "a"
        )
        let b = buffer(
            "ab"
        )
        var history = SwimEditHistory(
            limit: 0
        )

        guard !history.record(
            before: a,
            after: b
        ),
        history.entryCount == 0,
        !history.canUndo,
        !history.canRedo else {
            throw Failure.unexpectedDisabledHistory
        }
    }

    private static func runPersistentRoundTripProbe() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "swim-edit-history-\(UUID().uuidString.lowercased())",
                isDirectory: true
            )
        defer {
            try? FileManager.default.removeItem(
                at: root
            )
        }

        let bufferID = UUID(
            uuidString: "00000000-0000-0000-0000-000000000401"
        )!
        let a = buffer(
            "a"
        )
        let b = buffer(
            "ab"
        )
        let c = buffer(
            "abc"
        )
        var history = SwimEditHistory()

        _ = history.record(
            before: a,
            after: b
        )
        _ = history.record(
            before: b,
            after: c
        )

        guard history.undo(
            current: c
        ) == b else {
            throw Failure.unexpectedPersistentRoundTrip
        }

        let store = SwimUndoStore(
            layout: SwimStorageLayout(
                rootURL: root
            ),
            configuration: SwimStorageConfiguration(
                maximumStoredBuffers: 10,
                maximumStoredUndoArchives: 10,
                maximumUndoEntriesPerArchive: 100
            )
        )
        let archive = history.archive(
            bufferID: bufferID,
            updatedAt: Date(
                timeIntervalSince1970: 400
            )
        )

        _ = try store.store(
            archive
        )

        guard let persisted = try store.load(
            bufferID: bufferID
        ) else {
            throw Failure.unexpectedPersistentRoundTrip
        }

        var restored = SwimEditHistory(
            archive: persisted
        )

        guard restored.undoDepth == 1,
        restored.redoDepth == 1,
        restored.canUndo,
        restored.canRedo,
        restored.redo() == c,
        restored.undoDepth == 2,
        restored.redoDepth == 0 else {
            throw Failure.unexpectedPersistentRoundTrip
        }
    }

    private static func buffer(
        _ text: String
    ) -> SwimTextBuffer {
        SwimTextBuffer(
            text: text,
            cursor: PositionIndex(
                text.count
            )
        )
    }
}
