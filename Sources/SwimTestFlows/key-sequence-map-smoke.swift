import Swim
import SwimInterpreter

enum SwimKeySequenceMapSmoke {
    private enum Action: Sendable { case showWork }
    enum Failure: Error {
        case leaderDidNotMatch
        case pendingPrefixLost
        case insertConsumedText
        case unmatchedInputsLost
        case timedOutInputLost
        case escapeDidNotCancel
        case configurableLeaderFailed
        case expirationDidNotReplay
    }

    static func run() throws {
        var map = SwimKeySequenceMap<Action>(timeout: .milliseconds(750))
        map.bind([.leader, .char("p"), .char("v")], to: .showWork)
        let one = map.handle(.space, mode: .normal, atNanoseconds: 0)
        let two = map.handle(.char("p"), mode: .normal, atNanoseconds: 200_000_000)
        let three = map.handle(.char("v"), mode: .normal, atNanoseconds: 500_000_000)
        guard one.isPending, two.isPending,
              one.replay.isEmpty, two.replay.isEmpty,
              three.action == .showWork, three.replay.isEmpty
        else { throw Failure.leaderDidNotMatch }

        let insert = map.handle(.space, mode: .insert, atNanoseconds: 600_000_000)
        guard insert.action == nil, insert.replay == [.space], !insert.isPending
        else { throw Failure.insertConsumedText }

        _ = map.handle(.space, mode: .normal, atNanoseconds: 700_000_000)
        _ = map.handle(.char("p"), mode: .normal, atNanoseconds: 800_000_000)
        let invalid = map.handle(.char("x"), mode: .normal, atNanoseconds: 900_000_000)
        guard invalid.replay == [.space, .char("p"), .char("x")], invalid.action == nil
        else { throw Failure.unmatchedInputsLost }

        _ = map.handle(.space, mode: .normal, atNanoseconds: 1_000_000_000)
        let expired = map.handle(.char("p"), mode: .normal, atNanoseconds: 2_000_000_000)
        guard expired.replay == [.space, .char("p")], !expired.isPending
        else { throw Failure.timedOutInputLost }

        _ = map.handle(.space, mode: .normal, atNanoseconds: 3_000_000_000)
        let escaped = map.handle(.escape, mode: .normal, atNanoseconds: 3_100_000_000)
        guard !escaped.isPending, escaped.replay.isEmpty, escaped.action == nil
        else { throw Failure.escapeDidNotCancel }

        _ = map.handle(.space, mode: .normal, atNanoseconds: 4_000_000_000)
        let replay = map.expire(atNanoseconds: 4_800_000_000)
        guard replay == [.space] else { throw Failure.expirationDidNotReplay }

        var custom = SwimKeySequenceMap<Action>(leader: .char(","), timeout: .milliseconds(600))
        custom.bind([.leader, .char("p"), .char("v")], to: .showWork)
        _ = custom.handle(.char(","), mode: .normal, atNanoseconds: 0)
        _ = custom.handle(.char("p"), mode: .normal, atNanoseconds: 200_000_000)
        guard custom.handle(.char("v"), mode: .normal, atNanoseconds: 500_000_000).action == .showWork
        else { throw Failure.configurableLeaderFailed }
    }
}
