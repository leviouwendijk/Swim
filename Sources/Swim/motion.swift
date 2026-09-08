public enum Motion:
    Sendable,
    Codable,
    Hashable
{
    case left
    case right
    case up
    case down
    case wordBackward
    case wordForward
    case wordEnd
    case lineStart
    case lineEnd
    case documentStart
    case documentEnd
    case pageUp
    case pageDown
}
