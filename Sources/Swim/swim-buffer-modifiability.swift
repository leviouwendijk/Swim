public enum SwimBufferModifiability:
    String,
    Sendable,
    Codable,
    Hashable,
    CaseIterable
{
    case modifiable
    case nonmodifiable
}
