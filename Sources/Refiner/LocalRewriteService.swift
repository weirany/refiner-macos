import Foundation
import FoundationModels

struct LocalRewriteService: LocalRewriting {
    private let settingsStore: SettingsStore

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }

    func currentAvailability() -> LocalModelAvailabilityState {
        LocalModelAvailabilityStateMapper.map(SystemLanguageModel.default.availability)
    }

    func rewrite(_ context: RewriteContext) async -> Result<RewriteResult, LocalRewriteError> {
        let availability = currentAvailability()
        guard availability == .available else {
            return .failure(.modelUnavailable(availability))
        }

        let prompt = settingsStore.promptTemplate.render(with: context.selectedText)
        let model = SystemLanguageModel(
            useCase: .general,
            guardrails: .default
        )
        let session = LanguageModelSession(model: model)
        let options = GenerationOptions(
            temperature: 0.2,
            maximumResponseTokens: 512
        )

        do {
            let response = try await session.respond(to: prompt, options: options)
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !text.isEmpty else {
                return .failure(.emptyResponse)
            }

            return .success(RewriteResult(rewrittenText: text))
        } catch let error as LanguageModelSession.GenerationError {
            return .failure(.generationFailed(error.localizedDescription))
        } catch {
            return .failure(.generationFailed(error.localizedDescription))
        }
    }
}
