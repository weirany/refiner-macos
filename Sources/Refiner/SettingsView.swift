import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var launchAtLoginManager: LaunchAtLoginManager
    @ObservedObject var availabilityMonitor: AvailabilityMonitor

    @State private var promptDraft = ""
    @State private var apiKeyDraft = ""
    @State private var modelDraft = ""
    @State private var validationMessage: String?
    @State private var apiKeyMessage: String?
    @State private var modelMessage: String?
    @State private var accessibilityGranted = AccessibilityTextService.hasAccessibilityPermission()

    private let appIdentity = AppIdentity()

    var body: some View {
        ScrollView {
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

                GroupBox("Startup") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(
                            "Launch Refiner when you log in",
                            isOn: Binding(
                                get: { launchAtLoginManager.isEnabled },
                                set: { launchAtLoginManager.setEnabled($0) }
                            )
                        )

                        Text(launchAtLoginManager.statusMessage)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("OpenAI") {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(availabilityMonitor.state.message, systemImage: availabilitySymbolName)
                            .foregroundStyle(availabilityColor)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("API Key")
                                .font(.headline)

                            HStack {
                                SecureField("sk-…", text: $apiKeyDraft)
                                    .textFieldStyle(.roundedBorder)

                                Button("Save Key") {
                                    saveOpenAIAPIKey()
                                }

                                if let apiKeyMessage {
                                    Text(apiKeyMessage)
                                        .foregroundStyle(apiKeyMessage.contains("saved") ? .green : .red)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Model")
                                .font(.headline)

                            HStack {
                                TextField(SettingsStore.defaultOpenAIModel, text: $modelDraft)
                                    .textFieldStyle(.roundedBorder)

                                Button("Save Model") {
                                    saveOpenAIModel()
                                }

                                Button("Restore") {
                                    modelDraft = SettingsStore.defaultOpenAIModel
                                    saveOpenAIModel()
                                }

                                if let modelMessage {
                                    Text(modelMessage)
                                        .foregroundStyle(modelMessage.contains("saved") ? .green : .red)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Accessibility") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(accessibilityMessage)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Current process: \(appIdentity.primaryLabel)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack {
                            Button("Request Permission") {
                                _ = AccessibilityTextService.requestAccessibilityPermission()
                                refreshAccessibilityPermission()
                            }

                            Button("Open Accessibility Settings") {
                                openAccessibilitySettings()
                            }

                            Button("Refresh Permission Status") {
                                refreshAccessibilityPermission()
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
                            .frame(minHeight: 220)
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
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            promptDraft = settingsStore.promptTemplate.rawValue
            apiKeyDraft = settingsStore.openAIAPIKey
            modelDraft = settingsStore.openAIModel
            launchAtLoginManager.refreshStatus()
            availabilityMonitor.refresh()
            refreshAccessibilityPermission()
        }
    }

    private var accessibilityMessage: String {
        accessibilityGranted
            ? "Accessibility permission is enabled."
            : "Grant Accessibility permission so Refiner can read and replace the selected text in the focused editable field."
    }

    private var availabilitySymbolName: String {
        switch availabilityMonitor.state {
        case .available:
            "checkmark.circle.fill"
        case .missingAPIKey:
            "exclamationmark.triangle.fill"
        }
    }

    private var availabilityColor: Color {
        switch availabilityMonitor.state {
        case .available:
            .green
        case .missingAPIKey:
            .orange
        }
    }

    private func saveOpenAIAPIKey() {
        do {
            try settingsStore.saveOpenAIAPIKey(apiKeyDraft)
            apiKeyMessage = settingsStore.hasOpenAIAPIKey ? "Key saved." : "Key cleared."
            availabilityMonitor.refresh()
        } catch {
            apiKeyMessage = "Key could not be saved."
        }
    }

    private func saveOpenAIModel() {
        settingsStore.saveOpenAIModel(modelDraft)
        if modelDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            modelDraft = settingsStore.openAIModel
        }
        modelMessage = "Model saved."
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

    private func refreshAccessibilityPermission() {
        accessibilityGranted = AccessibilityTextService.hasAccessibilityPermission()
    }
}
