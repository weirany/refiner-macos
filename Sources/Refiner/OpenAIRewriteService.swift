import Foundation

struct OpenAIRewriteService: Rewriting {
    private let settingsStore: SettingsStore
    private let urlSession: URLSession
    private let endpoint = URL(string: "https://api.openai.com/v1/responses")!

    init(
        settingsStore: SettingsStore,
        urlSession: URLSession = .shared
    ) {
        self.settingsStore = settingsStore
        self.urlSession = urlSession
    }

    func currentAvailability() -> RewriteAvailabilityState {
        settingsStore.hasOpenAIAPIKey ? .available : .missingAPIKey
    }

    func rewrite(_ context: RewriteContext) async -> Result<RewriteResult, RewriteError> {
        guard currentAvailability() == .available else {
            return .failure(.unavailable(.missingAPIKey))
        }

        let prompt = settingsStore.promptTemplate.render(with: context.selectedText)
        let requestBody = OpenAIResponsesRequest(
            model: settingsStore.openAIModel,
            input: prompt,
            temperature: 0.2,
            maxOutputTokens: 512
        )

        do {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("Bearer \(settingsStore.openAIAPIKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(requestBody)

            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.generationFailed("OpenAI returned an invalid response."))
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                return .failure(.generationFailed(openAIErrorMessage(from: data, statusCode: httpResponse.statusCode)))
            }

            let decodedResponse = try JSONDecoder().decode(OpenAIResponsesResponse.self, from: data)
            let text = decodedResponse.outputText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                return .failure(.emptyResponse)
            }

            return .success(RewriteResult(rewrittenText: text))
        } catch let error as DecodingError {
            return .failure(.generationFailed("OpenAI returned a response Refiner could not read: \(error.localizedDescription)"))
        } catch {
            return .failure(.generationFailed(error.localizedDescription))
        }
    }

    private func openAIErrorMessage(from data: Data, statusCode: Int) -> String {
        if let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
            return errorResponse.error.message
        }

        return "OpenAI request failed with status \(statusCode)."
    }
}

private struct OpenAIResponsesRequest: Encodable {
    let model: String
    let input: String
    let temperature: Double
    let maxOutputTokens: Int

    enum CodingKeys: String, CodingKey {
        case model
        case input
        case temperature
        case maxOutputTokens = "max_output_tokens"
    }
}

private struct OpenAIResponsesResponse: Decodable {
    let output: [OutputItem]

    var outputText: String {
        output
            .flatMap(\.content)
            .compactMap(\.text)
            .joined(separator: "\n")
    }

    struct OutputItem: Decodable {
        let content: [ContentItem]
    }

    struct ContentItem: Decodable {
        let text: String?
    }
}

private struct OpenAIErrorResponse: Decodable {
    let error: OpenAIError

    struct OpenAIError: Decodable {
        let message: String
    }
}
