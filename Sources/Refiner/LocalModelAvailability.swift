import Foundation
import FoundationModels

enum LocalModelAvailabilityState: Equatable, Sendable {
    case available
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady

    var message: String {
        switch self {
        case .available:
            "Apple Intelligence is available on this Mac."
        case .deviceNotEligible:
            "This Mac does not support Apple Intelligence."
        case .appleIntelligenceNotEnabled:
            "Apple Intelligence is turned off. Enable it in System Settings to use Refiner."
        case .modelNotReady:
            "Apple Intelligence is not ready yet. Wait for setup to finish and try again."
        }
    }
}

enum LocalModelAvailabilityStateMapper {
    static func map(
        _ reason: SystemLanguageModel.Availability.UnavailableReason
    ) -> LocalModelAvailabilityState {
        switch reason {
        case .deviceNotEligible:
            .deviceNotEligible
        case .appleIntelligenceNotEnabled:
            .appleIntelligenceNotEnabled
        case .modelNotReady:
            .modelNotReady
        @unknown default:
            .modelNotReady
        }
    }

    static func map(
        _ availability: SystemLanguageModel.Availability
    ) -> LocalModelAvailabilityState {
        switch availability {
        case .available:
            .available
        case .unavailable(let reason):
            map(reason)
        @unknown default:
            .modelNotReady
        }
    }
}
