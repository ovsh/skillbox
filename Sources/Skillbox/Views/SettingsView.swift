import ServiceManagement
import SkillboxKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    @State private var remoteGitURL = ""
    @State private var autoSyncEnabled = true
    @State private var autoSyncIntervalMinutes = 60
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var didLoad = false

    private var hasUnsavedRepoChange: Bool {
        remoteGitURL.trimmed != appState.settings.remoteGitURL.trimmed
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                repositoryCard
                targetsCard
                syncCard
                setupCheckCard
                footer
            }
            .padding(Space.xl)
        }
        .frame(width: 460, height: 620)
        .onAppear(perform: loadFromSettings)
    }

    private func loadFromSettings() {
        guard !didLoad else { return }
        didLoad = true
        remoteGitURL = appState.settings.remoteGitURL
        autoSyncEnabled = appState.settings.autoSyncEnabled
        autoSyncIntervalMinutes = appState.settings.autoSyncIntervalMinutes
    }

    private func save() {
        var updated = appState.settings
        updated.remoteGitURL = remoteGitURL.trimmed
        updated.autoSyncEnabled = autoSyncEnabled
        updated.autoSyncIntervalMinutes = autoSyncIntervalMinutes
        appState.applySettings(updated)
    }

    // MARK: Repository

    private var repositoryCard: some View {
        BoxCard {
            CardHeader(systemImage: "books.vertical", title: "Registry Repository")

            FieldLabel("GitHub URL (HTTPS or SSH)") {
                TextField("https://github.com/org/skills-registry", text: $remoteGitURL)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                    .autocorrectionDisabled()
            }

            HStack {
                Text("Skills and rules are pulled from the main branch.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Save") { save() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(!hasUnsavedRepoChange)
            }
        }
    }

    // MARK: Targets

    private var targetsCard: some View {
        BoxCard {
            CardHeader(systemImage: "wrench.and.screwdriver", title: "Tools")

            ForEach(appState.targetRegistry.targets) { target in
                let isDetected = appState.detectedTargetIDs.contains(target.id)
                let isEnabled = appState.enabledTargets.contains { $0.id == target.id }

                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(target.displayName)
                            .font(.system(size: 12, weight: .medium))
                        Text(targetPathSummary(target) + (isDetected ? "" : "  ·  not detected"))
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { isEnabled },
                        set: { appState.setTargetEnabled(target, $0) }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
                }
                .padding(.vertical, 2)
            }

            Text("Toggling a tool off removes Skillbox-managed files from it on the next sync.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }

    private func targetPathSummary(_ target: Target) -> String {
        [target.skillsPath, target.rulesPath]
            .compactMap { $0 }
            .map { "~/\($0)" }
            .joined(separator: "  ·  ")
    }

    // MARK: Auto-sync

    private var syncCard: some View {
        BoxCard {
            CardHeader(systemImage: "clock.arrow.2.circlepath", title: "Auto Sync")

            Toggle(isOn: $autoSyncEnabled) {
                Text("Sync automatically in the background")
                    .font(.system(size: 12))
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .onChange(of: autoSyncEnabled) { save() }

            if autoSyncEnabled {
                Picker("Every", selection: $autoSyncIntervalMinutes) {
                    Text("15 minutes").tag(15)
                    Text("30 minutes").tag(30)
                    Text("1 hour").tag(60)
                    Text("4 hours").tag(240)
                }
                .pickerStyle(.menu)
                .controlSize(.small)
                .frame(maxWidth: 220, alignment: .leading)
                .onChange(of: autoSyncIntervalMinutes) { save() }
            }
        }
    }

    // MARK: Setup check

    private var setupCheckCard: some View {
        BoxCard {
            HStack {
                CardHeader(systemImage: "stethoscope", title: "Setup Check")
                Spacer()
                if appState.isRunningSetupCheck {
                    ProgressView().controlSize(.small)
                } else {
                    Button("Run Check") { appState.runSetupCheck() }
                        .controlSize(.small)
                }
            }

            if let passed = appState.setupCheckPassed {
                HStack(spacing: 5) {
                    Image(systemName: passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(passed ? .green : .red)
                        .font(.system(size: 11))
                    Text(passed ? "Everything looks good." : "Something needs attention:")
                        .font(.system(size: 12, weight: .medium))
                }
            }

            ForEach(Array(appState.setupCheckLines.enumerated()), id: \.offset) { _, line in
                Text("• \(line)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        BoxCard {
            Toggle(isOn: $launchAtLogin) {
                Text("Launch at login")
                    .font(.system(size: 12))
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .onChange(of: launchAtLogin) {
                if launchAtLogin {
                    try? SMAppService.mainApp.register()
                } else {
                    try? SMAppService.mainApp.unregister()
                }
            }

            Divider().opacity(0.4)

            HStack(spacing: Space.md) {
                Button("Open Logs") { appState.openLogsFile() }
                    .controlSize(.small)
                Button("Open Registry Checkout") { appState.openCheckoutFolder() }
                    .controlSize(.small)
                Spacer()
                Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev")")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
