public enum Mode:
    String,
    Sendable,
    Codable,
    Hashable,
    CaseIterable
{
    case normal
    case insert
    case replace
    case visual
}
