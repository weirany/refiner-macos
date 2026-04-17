import Testing
@testable import Refiner

@Test
func promptTemplateRejectsMissingPlaceholder() {
    #expect(throws: PromptTemplate.Error.self) {
        _ = try PromptTemplate(
            rawValue: "Rewrite the text below into natural English."
        )
    }
}

@Test
func promptTemplateSubstitutesOriginalText() throws {
    let template = try PromptTemplate(
        rawValue: """
        text to rewrite:
        {original_text}
        """
    )

    let rendered = template.render(with: "hello-world")

    #expect(rendered == """
    text to rewrite:
    hello-world
    """)
}

@Test
func availabilityMappingCoversAllUnavailableReasons() {
    #expect(
        LocalModelAvailabilityStateMapper.map(.deviceNotEligible)
        == .deviceNotEligible
    )
    #expect(
        LocalModelAvailabilityStateMapper.map(.appleIntelligenceNotEnabled)
        == .appleIntelligenceNotEnabled
    )
    #expect(
        LocalModelAvailabilityStateMapper.map(.modelNotReady)
        == .modelNotReady
    )
}
