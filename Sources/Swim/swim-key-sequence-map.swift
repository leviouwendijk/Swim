import Dispatch
import SwimInterpreter

/// A client-configured modal key binding. `.leader` resolves against this map's
/// configurable leader input, rather than baking Space into each binding.
public enum SwimKeySequenceToken: Sendable, Hashable {
    case leader
    case char(String)
    case key(SwimInterpreter.Input)
}

public struct SwimKeySequenceResolution<Action: Sendable>: Sendable {
    public let action: Action?
    /// Inputs that were not part of a successful mapping, in original order.
    /// Clients must forward these to their ordinary modal editor.
    public let replay: [SwimInterpreter.Input]
    public let isPending: Bool

    public init(action: Action? = nil, replay: [SwimInterpreter.Input] = [], isPending: Bool = false) {
        self.action = action
        self.replay = replay
        self.isPending = isPending
    }
}

/// Pure, deterministic prefix resolver; keeps editor buffers and view actions
/// outside the keymap. Only mapped modes intercept sequences. All other input
/// passes through unchanged. Deadline is refreshed after each matched stroke.
public struct SwimKeySequenceMap<Action: Sendable>: Sendable {
    private struct Binding: Sendable {
        let inputs: [SwimInterpreter.Input]
        let modes: Set<SwimInterpreter.Mode>
        let action: Action
    }

    public let leader: SwimInterpreter.Input
    public let timeout: Duration
    private var bindings: [Binding] = []
    private var pending: [SwimInterpreter.Input] = []
    private var lastStrokeAt: UInt64?

    public init(
        leader: SwimInterpreter.Input = .space,
        timeout: Duration = .milliseconds(750)
    ) {
        self.leader = leader
        self.timeout = timeout
    }

    public mutating func bind(
        _ sequence: [SwimKeySequenceToken],
        to action: Action,
        modes: Set<SwimInterpreter.Mode> = [.normal]
    ) {
        let inputs = sequence.map { token -> SwimInterpreter.Input in
            switch token {
            case .leader: return leader
            case .char(let text): return .char(text)
            case .key(let input): return input
            }
        }
        guard !inputs.isEmpty, !modes.isEmpty else { return }
        bindings.removeAll { $0.inputs == inputs && $0.modes == modes }
        bindings.append(.init(inputs: inputs, modes: modes, action: action))
    }

    /// Cancels a pending prefix. Call when changing editor focus or mode.
    @discardableResult
    public mutating func reset() -> [SwimInterpreter.Input] {
        let previous = pending
        pending = []
        lastStrokeAt = nil
        return previous
    }

    /// Makes timeout observable even when no new key arrives (e.g. UI polls).
    @discardableResult
    public mutating func expire(
        atNanoseconds now: UInt64 = DispatchTime.now().uptimeNanoseconds
    ) -> [SwimInterpreter.Input] {
        guard let lastStrokeAt, !pending.isEmpty,
              now >= lastStrokeAt,
              now - lastStrokeAt >= timeoutNanoseconds
        else { return [] }
        return reset()
    }

    public mutating func handle(
        _ input: SwimInterpreter.Input,
        mode: SwimInterpreter.Mode,
        atNanoseconds now: UInt64 = DispatchTime.now().uptimeNanoseconds
    ) -> SwimKeySequenceResolution<Action> {
        let expired = expire(atNanoseconds: now)
        guard mode == .normal || bindings.contains(where: { $0.modes.contains(mode) }) else {
            _ = reset()
            return .init(replay: expired + [input])
        }
        // Escape cancels the prefix without issuing a navigation action.
        if input == .escape, !pending.isEmpty {
            _ = reset()
            return .init(replay: expired)
        }
        let candidate = pending + [input]
        let matching = bindings.filter { binding in
            binding.modes.contains(mode)
                && binding.inputs.starts(with: candidate)
        }
        if let exact = matching.first(where: { $0.inputs == candidate }) {
            _ = reset()
            return .init(action: exact.action, replay: expired)
        }
        if !matching.isEmpty {
            pending = candidate
            lastStrokeAt = now
            return .init(replay: expired, isPending: true)
        }
        let unmatched = pending
        _ = reset()
        // After a mismatch, a fresh leader can immediately begin a new map.
        let fresh = bindings.filter { $0.modes.contains(mode) && $0.inputs.starts(with: [input]) }
        if let exact = fresh.first(where: { $0.inputs.count == 1 }) {
            return .init(action: exact.action, replay: expired + unmatched)
        }
        if !fresh.isEmpty {
            pending = [input]
            lastStrokeAt = now
            return .init(replay: expired + unmatched, isPending: true)
        }
        return .init(replay: expired + unmatched + [input])
    }

    private var timeoutNanoseconds: UInt64 {
        let parts = timeout.components
        let value = Double(parts.seconds) * 1_000_000_000
            + Double(parts.attoseconds) / 1_000_000_000
        guard value.isFinite, value > 0 else { return 0 }
        return UInt64(min(value, Double(UInt64.max - 1)))
    }
}
