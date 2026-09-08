public enum BlockInsertOperation:
    Sendable,
    Codable,
    Hashable
{
    case insertBefore
    case insertAfter
    case change
}
