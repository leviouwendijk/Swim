public enum SelectionKind:
    String,
    Sendable,
    Codable,
    Hashable,
    CaseIterable
{
    case character
    case line
    case block
}
