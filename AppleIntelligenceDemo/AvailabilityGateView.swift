import SwiftUI
import FoundationModels

struct AvailabilityGateView: View {
    @State private var isAvailable = false

    var body: some View {
        Group {
            if isAvailable {
                MainTabView()
                    .transition(.opacity)
            } else {
                UnavailableView()
            }
        }
        .onAppear {
            checkAvailability()
        }
    }

    private func checkAvailability() {
        switch SystemLanguageModel.default.availability {
        case .available:
            withAnimation(.easeInOut(duration: 0.4)) {
                isAvailable = true
            }
        case .unavailable:
            isAvailable = false
        }
    }
}

private struct UnavailableView: View {
    var body: some View {
        let reason = unavailabilityReason()
        ContentUnavailableView(
            reason.title,
            systemImage: reason.systemImage,
            description: Text(reason.description)
        )
    }

    private func unavailabilityReason() -> UnavailabilityInfo {
        switch SystemLanguageModel.default.availability {
        case .available:
            return UnavailabilityInfo(
                title: "Available",
                systemImage: "checkmark.circle",
                description: ""
            )
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return UnavailabilityInfo(
                    title: "Device Not Supported",
                    systemImage: "iphone.slash",
                    description: "Apple Intelligence requires an iPhone 15 Pro, iPhone 16 or later, or an iPad or Mac with M1 or later chip."
                )
            case .appleIntelligenceNotEnabled:
                return UnavailabilityInfo(
                    title: "Apple Intelligence Not Enabled",
                    systemImage: "brain.slash",
                    description: "Enable Apple Intelligence in Settings > Apple Intelligence & Siri to use this app."
                )
            case .modelNotReady:
                return UnavailabilityInfo(
                    title: "Model Not Ready",
                    systemImage: "arrow.down.circle",
                    description: "The on-device language model is still downloading. Please wait a few minutes, then reopen the app."
                )
            @unknown default:
                return UnavailabilityInfo(
                    title: "Unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: "Apple Intelligence is unavailable for an unrecognized reason. Check for an iOS update that may resolve this, or visit Settings > Apple Intelligence & Siri for more information."
                )
            }
        }
    }
}

private struct UnavailabilityInfo {
    let title: String
    let systemImage: String
    let description: String
}
