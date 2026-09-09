import Position

public struct SwimEditorContext:
    Sendable
{
    public var pageRows: Int
    public var displayColumns: any SwimDisplayColumnMappingProviding

    public init(
        pageRows: Int = 1,
        displayColumns: any SwimDisplayColumnMappingProviding =
            SwimHeadlessDisplayColumnMappingProvider()
    ) {
        self.pageRows = max(
            1,
            pageRows
        )
        self.displayColumns = displayColumns
    }
}

public struct SwimEditorCopy:
    Sendable,
    Codable,
    Hashable
{
    public let value: SwimRegisterValue
    public let sourceRanges: [PositionRange]

    public init(
        value: SwimRegisterValue,
        sourceRanges: [PositionRange]
    ) {
        self.value = value
        self.sourceRanges = sourceRanges
    }

    public var text: String {
        value.text
    }
}

public enum SwimEditorEvent:
    Sendable,
    Codable,
    Hashable
{
    case changed
    case copyRequested(SwimEditorCopy)
    case commandLineRequested
    case cancelRequested
    case rejected(SwimEditorRejection)
}
