import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var availabilityMonitor: AvailabilityMonitor

    @State private var promptDraft = ""
    @State private var validationMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Refiner")
                .font(.system(size: 26, weight: .semibold, design: .rounded))

            GroupBox("Shortcut") {
                HStack {
                    Text("Refine selected text")
                    Spacer()
                    Text("Option+R")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            GroupBox("Apple Intelligence") {
                VStack(alignment: .leading, spacing: 8) {
                    Label(availabilityMonitor.state.message, systemImage: availabilitySymbolName)
                        .foregroundStyle(availabilityColor)

                    Text("Refiner is local-only and requires Apple’s on-device Foundation Models support.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button("Refresh Status") {
                        availabilityMonitor.refresh()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("Accessibility") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(accessibilityMessage)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        Button("Request Permission") {
                            _ = AccessibilityTextService.requestAccessibilityPermission()
                        }

                        Button("Open Accessibility Settings") {
                            openAccessibilitySettings()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("Prompt Template") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("The template must include `{original_text}`.")
                        .foregroundStyle(.secondary)

                    TextEditor(text: $promptDraft)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 180)
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(nsColor: .textBackgroundColor))
                        )

                    HStack {
                        Button("Restore Default") {
                            promptDraft = PromptTemplate.defaultValue
                            savePrompt()
                        }

                        Spacer()

                        if let validationMessage {
                            Text(validationMessage)
                                .foregroundStyle(validationMessage.contains("saved") ? .green : .red)
                        }

                        Button("Save Prompt") {
                            savePrompt()
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            promptDraft = settingsStore.promptTemplate.rawValue
            availabilityMonitor.refresh()
        }
    }

    private var accessibilityMessage: String {
        AccessibilityTextService.hasAccessibilityPermission()
            ? "Accessibility permission is enabled."
            : "Grant Accessibility permission so Refiner can read and replace the selected text in the focused editable field."
    }

    private var availabilitySymbolName: String {
        switch availabilityMonitor.state {
        case .available:
            "checkmark.circle.fill"
        case .deviceNotEligible, .appleIntelligenceNotEnabled, .modelNotReady:
            "exclamationmark.triangle.fill"
        }
    }

    private var availabilityColor: Color {
        switch availabilityMonitor.state {
        case .available:
            .green
        case .deviceNotEligible, .appleIntelligenceNotEnabled, .modelNotReady:
            .orange
        }
    }

    private func savePrompt() {
        do {
            try settingsStore.savePromptTemplate(promptDraft)
            validationMessage = "Prompt saved."
        } catch {
            validationMessage = "Prompt must include {original_text}."
        }
    }

    private func openAccessibilitySettings() {
        guard
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}
