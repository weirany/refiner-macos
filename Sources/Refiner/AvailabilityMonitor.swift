import Combine
import Foundation
import FoundationModels

@MainActor
final class AvailabilityMonitor: ObservableObject {
    @Published private(set) var state: LocalModelAvailabilityState = .available

    func refresh() {
        state = LocalModelAvailabilityStateMapper.map(
            SystemLanguageModel.default.availability
        )
    }
}
