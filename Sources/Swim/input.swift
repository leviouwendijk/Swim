public enum Input:
    Sendable,
    Codable,
    Hashable
{
    case up
    case down
    case left
    case right
    case home
    case end
    case pageUp
    case pageDown
    case insert
    case delete
    case enter
    case escape
    case backspace
    case tab
    case space
    case controlSpace
    case control(String)
    case char(String)
    case unknown
}
