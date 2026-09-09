public struct SwimEditorRejection:
    Sendable,
    Codable,
    Hashable
{
    public enum Reason:
        String,
        Sendable,
        Codable,
        Hashable,
        CaseIterable
    {
        case bufferNonmodifiable = "buffer_nonmodifiable"
    }

    public let reason: Reason

    public init(
        reason: Reason
    ) {
        self.reason = reason
    }
}
