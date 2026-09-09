import Foundation
import Position
import SwimIO

public struct SwimEditSnapshot:
    Sendable,
    Codable,
    Hashable
{
    public var buffer: SwimTextBuffer

    public init(
        buffer: SwimTextBuffer
    ) {
        self.buffer = buffer
    }

    public init(
        persisted snapshot: SwimUndoSnapshot
    ) {
        buffer = SwimTextBuffer(
            text: snapshot.text,
            cursor: PositionIndex(
                snapshot.cursorOffset
            )
        )
    }

    public var persisted: SwimUndoSnapshot {
        SwimUndoSnapshot(
            text: buffer.text,
            cursorOffset: buffer.cursor.offset
        )
    }
}

public struct SwimEditEntry:
    Sendable,
    Codable,
    Hashable,
    Identifiable
{
    public let id: UUID
    public let createdAt: Date
    public let before: SwimEditSnapshot
    public let after: SwimEditSnapshot

    public init(
        id: UUID = .init(),
        createdAt: Date = .init(),
        before: SwimEditSnapshot,
        after: SwimEditSnapshot
    ) {
        self.id = id
        self.createdAt = createdAt
        self.before = before
        self.after = after
    }

    public init(
        persisted entry: SwimUndoEntry
    ) {
        id = entry.id
        createdAt = entry.createdAt
        before = SwimEditSnapshot(
            persisted: entry.before
        )
        after = SwimEditSnapshot(
            persisted: entry.after
        )
    }

    public var persisted: SwimUndoEntry {
        SwimUndoEntry(
            id: id,
            createdAt: createdAt,
            before: before.persisted,
            after: after.persisted
        )
    }
}

public struct SwimEditHistory:
    Sendable,
    Codable,
    Hashable
{
    public private(set) var limit: Int
    public private(set) var position: Int

    private var entries: [SwimEditEntry]
    private var pending: SwimEditSnapshot?

    public init(
        limit: Int = 100
    ) {
        self.limit = max(
            0,
            limit
        )
        position = 0
        entries = []
        pending = nil
    }

    public init(
        archive: SwimUndoArchive,
        limit: Int = 100
    ) {
        self.init(
            limit: limit
        )
        restore(
            archive
        )
    }

    public var canUndo: Bool {
        position > 0
    }

    public var canRedo: Bool {
        position < entries.count
    }

    public var undoDepth: Int {
        position
    }

    public var redoDepth: Int {
        entries.count - position
    }

    public var entryCount: Int {
        entries.count
    }

    public var hasPendingTransaction: Bool {
        pending != nil
    }

    public mutating func reset() {
        entries.removeAll()
        position = 0
        pending = nil
    }

    @discardableResult
    public mutating func begin(
        with buffer: SwimTextBuffer
    ) -> Bool {
        guard pending == nil else {
            return false
        }

        pending = SwimEditSnapshot(
            buffer: buffer
        )
        return true
    }

    @discardableResult
    public mutating func cancel() -> Bool {
        guard pending != nil else {
            return false
        }

        pending = nil
        return true
    }

    @discardableResult
    public mutating func commit(
        current: SwimTextBuffer
    ) -> Bool {
        guard let before = pending else {
            return false
        }

        pending = nil

        return record(
            before: before.buffer,
            after: current
        )
    }

    @discardableResult
    public mutating func record(
        before: SwimTextBuffer,
        after: SwimTextBuffer
    ) -> Bool {
        guard before.text != after.text else {
            return false
        }

        pending = nil

        guard limit > 0 else {
            entries.removeAll()
            position = 0
            return false
        }

        if position < entries.count {
            entries.removeSubrange(
                position..<entries.count
            )
        }

        entries.append(
            SwimEditEntry(
                before: SwimEditSnapshot(
                    buffer: before
                ),
                after: SwimEditSnapshot(
                    buffer: after
                )
            )
        )
        position = entries.count

        enforceLimit()
        return true
    }

    public mutating func undo(
        current: SwimTextBuffer
    ) -> SwimTextBuffer? {
        if pending != nil {
            _ = commit(
                current: current
            )
        }

        guard position > 0 else {
            return nil
        }

        position -= 1
        return entries[position].before.buffer
    }

    public mutating func redo() -> SwimTextBuffer? {
        guard pending == nil,
              position < entries.count else {
            return nil
        }

        let restored = entries[position].after.buffer
        position += 1
        return restored
    }

    public func archive(
        bufferID: UUID,
        updatedAt: Date = .init()
    ) -> SwimUndoArchive {
        SwimUndoArchive(
            bufferID: bufferID,
            updatedAt: updatedAt,
            entries: entries.map(\.persisted),
            position: position
        )
    }

    public mutating func restore(
        _ archive: SwimUndoArchive
    ) {
        entries = archive.entries.map {
            SwimEditEntry(
                persisted: $0
            )
        }
        position = min(
            max(
                0,
                archive.position
            ),
            entries.count
        )
        pending = nil

        enforceLimit()
    }

    private mutating func enforceLimit() {
        guard entries.count > limit else {
            position = min(
                position,
                entries.count
            )
            return
        }

        let removedCount = entries.count - limit

        entries.removeFirst(
            removedCount
        )
        position = max(
            0,
            position - removedCount
        )
        position = min(
            position,
            entries.count
        )
    }
}
