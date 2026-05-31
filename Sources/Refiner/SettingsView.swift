import AppKit
import Permiso
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
    @State private var permissionMonitorTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Allow Accessibility control")
                                    .font(.headline)

                                Text(accessibilityMessage)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer()

                            SwitchToggle(
                                isOn: accessibilityGranted,
                                action: toggleAccessibilityPermission
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox {
                    HStack {
                        Text("Keyboard Shortcut")
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
        .onDisappear {
            permissionMonitorTask?.cancel()
            permissionMonitorTask = nil
        }
    }

    private var accessibilityMessage: String {
        accessibilityGranted
            ? "Refiner can read and replace selected text in the focused editable field."
            : "Turn this on so Refiner can read and replace selected text in the focused editable field."
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
        settingsStore.saveOpenAIAPIKey(apiKeyDraft)
        apiKeyMessage = settingsStore.hasOpenAIAPIKey ? "Key saved." : "Key cleared."
        availabilityMonitor.refresh()
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

    private func requestAccessibilityPermission() {
        if AccessibilityTextService.hasAccessibilityPermission() {
            PermisoAssistant.shared.dismiss()
            refreshAccessibilityPermission()
            return
        }

        PermisoAssistant.shared.present(panel: .accessibility)
        monitorAccessibilityPermission(until: true, dismissPermisoWhenMatched: true)
        refreshAccessibilityPermission()
    }

    private func openAccessibilityPermissionSettingsForRevocation() {
        NSWorkspace.shared.open(PermisoPanel.accessibility.settingsURL)
        monitorAccessibilityPermission(until: false, dismissPermisoWhenMatched: false)
        refreshAccessibilityPermission()
    }

    private func toggleAccessibilityPermission() {
        if accessibilityGranted {
            openAccessibilityPermissionSettingsForRevocation()
        } else {
            requestAccessibilityPermission()
        }
    }

    private func refreshAccessibilityPermission() {
        accessibilityGranted = AccessibilityTextService.hasAccessibilityPermission()
        if accessibilityGranted {
            PermisoAssistant.shared.dismiss()
        }
    }

    private func monitorAccessibilityPermission(
        until expectedValue: Bool,
        dismissPermisoWhenMatched: Bool
    ) {
        permissionMonitorTask?.cancel()
        permissionMonitorTask = Task { @MainActor in
            for _ in 0..<240 {
                guard !Task.isCancelled else {
                    return
                }

                if AccessibilityTextService.hasAccessibilityPermission() == expectedValue {
                    refreshAccessibilityPermission()
                    if dismissPermisoWhenMatched {
                        PermisoAssistant.shared.dismiss()
                    }
                    return
                }

                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }
}

private struct SwitchToggle: View {
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? Color.accentColor : Color(nsColor: .tertiaryLabelColor).opacity(0.35))

                Circle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.22), radius: 1, x: 0, y: 1)
                    .padding(3)
            }
            .frame(width: 52, height: 30)
            .animation(.snappy(duration: 0.18), value: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Allow Accessibility control")
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isButton)
    }
}
