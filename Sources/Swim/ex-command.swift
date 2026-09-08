public enum ExCommand:
    String,
    Sendable,
    Codable,
    Hashable,
    CaseIterable
{
    case write = "w"
    case quit = "q"
}

public enum ExCommandLineResult:
    Sendable,
    Codable,
    Hashable
{
    case editing
    case command(ExCommand)
    case cancelled
    case invalid(String)
    case inactive
}
