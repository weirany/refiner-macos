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
@MainActor
func workflowStopsWhenModelUnavailable() async {
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
        availability: .appleIntelligenceNotEnabled
    )
    let notifier = MockNotifier()
    let workflow = RefinementWorkflow(
        textService: selectionService,
        rewriteService: rewriteService,
        notifier: notifier
    )

    await workflow.refineSelection()

    #expect(selectionService.readCount == 0)
    #expect(notifier.events == [.error("Apple Intelligence is turned off. Enable it in System Settings to use Refiner.")])
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
        rewriteResult: .failure(LocalRewriteError.emptyResponse)
    )
    let notifier = MockNotifier()
    let workflow = RefinementWorkflow(
        textService: selectionService,
        rewriteService: rewriteService,
        notifier: notifier
    )

    await workflow.refineSelection()

    #expect(selectionService.replacedText == nil)
    #expect(notifier.events == [.running, .error("The local model returned an empty rewrite.")])
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
private struct MockRewriteService: LocalRewriting, Sendable {
    let availability: LocalModelAvailabilityState
    var rewriteResult: Result<RewriteResult, LocalRewriteError> = .success(
        RewriteResult(rewrittenText: "hello")
    )

    func currentAvailability() -> LocalModelAvailabilityState {
        availability
    }

    func rewrite(_ context: RewriteContext) async -> Result<RewriteResult, LocalRewriteError> {
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
