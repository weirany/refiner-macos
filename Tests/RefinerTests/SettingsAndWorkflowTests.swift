import Foundation
import Testing
@testable import Refiner

@Test
func settingsStorePersistsPromptTemplate() throws {
    let suiteName = "RefinerTests.Settings.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer {
        defaults.removePersistentDomain(forName: suiteName)
    }

    let store = SettingsStore(userDefaults: defaults)
    let updatedTemplate = """
    Rewrite politely:
    {original_text}
    """

    try store.savePromptTemplate(updatedTemplate)

    let reloaded = SettingsStore(userDefaults: defaults)

    #expect(reloaded.promptTemplate.rawValue == updatedTemplate)
}

@Test
func settingsStoreDefaultsLaunchAtLoginToEnabled() {
    let suiteName = "RefinerTests.LaunchAtLoginDefault.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer {
        defaults.removePersistentDomain(forName: suiteName)
    }

    let store = SettingsStore(userDefaults: defaults)

    #expect(store.launchAtLoginEnabled)
}

@Test
func settingsStorePersistsLaunchAtLoginPreference() {
    let suiteName = "RefinerTests.LaunchAtLoginPersist.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer {
        defaults.removePersistentDomain(forName: suiteName)
    }

    let store = SettingsStore(userDefaults: defaults)
    store.setLaunchAtLoginEnabled(false)

    let reloaded = SettingsStore(userDefaults: defaults)

    #expect(!reloaded.launchAtLoginEnabled)
}

@Test
func settingsStoreDefaultsOpenAIModel() {
    let suiteName = "RefinerTests.OpenAIModelDefault.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer {
        defaults.removePersistentDomain(forName: suiteName)
    }

    let store = SettingsStore(userDefaults: defaults)

    #expect(store.openAIModel == "gpt-5.4-nano")
}

@Test
func settingsStorePersistsOpenAIModel() {
    let suiteName = "RefinerTests.OpenAIModelPersist.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer {
        defaults.removePersistentDomain(forName: suiteName)
    }

    let store = SettingsStore(userDefaults: defaults)

    store.saveOpenAIModel("gpt-5.4-mini")

    let reloaded = SettingsStore(userDefaults: defaults)

    #expect(reloaded.openAIModel == "gpt-5.4-mini")
}

@Test
func settingsStorePersistsOpenAIAPIKeyInUserDefaults() {
    let suiteName = "RefinerTests.OpenAIAPIKeyPersist.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer {
        defaults.removePersistentDomain(forName: suiteName)
    }

    let store = SettingsStore(userDefaults: defaults)

    store.saveOpenAIAPIKey(" sk-test ")

    let reloaded = SettingsStore(userDefaults: defaults)

    #expect(reloaded.openAIAPIKey == "sk-test")
    #expect(reloaded.hasOpenAIAPIKey)
}

@Test
@MainActor
func workflowStopsWhenAPIKeyMissing() async {
    let selectionService = MockTextSelectionService(
        readResult: .success(
            RewriteContext(
                selectedText: "hello",
                bundleIdentifier: "com.example.app",
                elementDescription: "Text Field"
            )
        )
    )
    let rewriteService = MockRewriteService(
        availability: .missingAPIKey
    )
    let notifier = MockNotifier()
    let workflow = RefinementWorkflow(
        textService: selectionService,
        rewriteService: rewriteService,
        notifier: notifier
    )

    await workflow.refineSelection()

    #expect(selectionService.readCount == 0)
    #expect(notifier.events == [.error("OpenAI API key is missing. Open Settings and enter your API key.")])
}

@Test
@MainActor
func workflowReplacesTextAndShowsSuccess() async throws {
    let selectionService = MockTextSelectionService(
        readResult: .success(
            RewriteContext(
                selectedText: "helloworld",
                bundleIdentifier: "com.example.app",
                elementDescription: "Text Area"
            )
        )
    )
    let rewriteService = MockRewriteService(
        availability: .available,
        rewriteResult: .success(RewriteResult(rewrittenText: "hello world"))
    )
    let notifier = MockNotifier()
    let workflow = RefinementWorkflow(
        textService: selectionService,
        rewriteService: rewriteService,
        notifier: notifier
    )

    await workflow.refineSelection()

    #expect(selectionService.readCount == 1)
    #expect(selectionService.replacedText == "hello world")
    #expect(notifier.events == [.running, .success("Successfully Refined")])
}

@Test
@MainActor
func workflowLeavesTextUnchangedWhenRewriteFails() async {
    let selectionService = MockTextSelectionService(
        readResult: .success(
            RewriteContext(
                selectedText: "helloworld",
                bundleIdentifier: "com.example.app",
                elementDescription: "Text Area"
            )
        )
    )
    let rewriteService = MockRewriteService(
        availability: .available,
        rewriteResult: .failure(RewriteError.emptyResponse)
    )
    let notifier = MockNotifier()
    let workflow = RefinementWorkflow(
        textService: selectionService,
        rewriteService: rewriteService,
        notifier: notifier
    )

    await workflow.refineSelection()

    #expect(selectionService.replacedText == nil)
    #expect(notifier.events == [.running, .error("OpenAI returned an empty rewrite.")])
}

@MainActor
private final class MockTextSelectionService: TextSelectionHandling, @unchecked Sendable {
    private let readResult: Result<RewriteContext, TextSelectionError>
    private(set) var replacedText: String?
    private(set) var readCount = 0

    init(readResult: Result<RewriteContext, TextSelectionError>) {
        self.readResult = readResult
    }

    func readSelection() -> Result<RewriteContext, TextSelectionError> {
        readCount += 1
        return readResult
    }

    func replaceSelection(
        in context: RewriteContext,
        with refinedText: String
    ) -> Result<Void, TextSelectionError> {
        replacedText = refinedText
        return .success(())
    }
}

@MainActor
private struct MockRewriteService: Rewriting, Sendable {
    let availability: RewriteAvailabilityState
    var rewriteResult: Result<RewriteResult, RewriteError> = .success(
        RewriteResult(rewrittenText: "hello")
    )

    func currentAvailability() -> RewriteAvailabilityState {
        availability
    }

    func rewrite(_ context: RewriteContext) async -> Result<RewriteResult, RewriteError> {
        rewriteResult
    }
}

@MainActor
private final class MockNotifier: WorkflowNotifying, @unchecked Sendable {
    enum Event: Equatable {
        case running
        case success(String)
        case error(String)
    }

    private(set) var events: [Event] = []

    func showRunning() {
        events.append(.running)
    }

    func showSuccess(_ message: String) {
        events.append(.success(message))
    }

    func showError(_ message: String) {
        events.append(.error(message))
    }
}
