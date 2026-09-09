public protocol SwimDisplayColumnMappingProviding:
    Sendable
{
    func mapping(
        for text: String
    ) -> any SwimDisplayColumnMapping
}

public struct SwimHeadlessDisplayColumnMappingProvider:
    SwimDisplayColumnMappingProviding,
    Sendable
{
    public let tabWidth: Int

    private let characterWidth:
        @Sendable (Character) -> Int

    public init(
        tabWidth: Int = 4,
        characterWidth: @escaping @Sendable (Character) -> Int = { _ in 1 }
    ) {
        self.tabWidth = max(
            1,
            tabWidth
        )
        self.characterWidth = characterWidth
    }

    public func mapping(
        for text: String
    ) -> any SwimDisplayColumnMapping {
        SwimHeadlessDisplayColumnMapping(
            text: text,
            tabWidth: tabWidth,
            characterWidth: characterWidth
        )
    }
}
