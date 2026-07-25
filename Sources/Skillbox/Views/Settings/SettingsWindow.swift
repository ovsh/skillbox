import ServiceManagement
import SkillboxKit
import SwiftUI

/// Deliberately small: launch at login, updates, logs. Team/registry settings
/// return when team mode ships.
struct SettingsWindow: View {
    @Environment(AppServicesModel.self) private var services

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            identity

            Card {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Launch at login")
                            .font(Theme.body)
                            .foregroundStyle(Theme.ink)
                        Text("Loadout sits in the menu bar from the moment you log in.")
                            .font(Theme.meta)
                            .foregroundStyle(Theme.inkTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    LoadoutToggle(isOn: launchAtLogin) { newValue in
                        launchAtLogin = newValue
                        services.setLaunchAtLogin(newValue)
                    }
                }
                .padding(14)
            }

            Card {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Version \(services.appVersion)")
                                .font(Theme.body)
                                .foregroundStyle(Theme.ink)
                            Text(updateStatus)
                                .font(Theme.meta)
                                .foregroundStyle(Theme.inkTertiary)
                        }
                        Spacer(minLength: 8)
                        // The app's own button language, not AppKit's default
                        // pill — this window is part of the same world.
                        if services.updateAvailable != nil {
                            ActionButton(
                                title: services.isDownloadingUpdate ? "Updating…" : "Update",
                                style: .affirm,
                                isEnabled: !services.isDownloadingUpdate,
                                isWide: false
                            ) {
                                services.installUpdate()
                            }
                        } else {
                            Button(services.isCheckingForUpdate ? "Checking…" : "Check for Updates") {
                                services.checkForUpdate()
                            }
                            .buttonStyle(QuietButtonStyle())
                            .disabled(services.isCheckingForUpdate)
                        }
                    }
                    if let error = services.updateError {
                        Text(error)
                            .font(Theme.meta)
                            .foregroundStyle(Theme.danger)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(14)
            }

            HStack {
                Button("Open Logs") { services.openLogsFile() }
                    .buttonStyle(QuietButtonStyle())
                Spacer()
            }
        }
        .padding(20)
        .frame(width: 400)
        .background(Theme.canvas)
    }

    private var identity: some View {
        HStack(spacing: 12) {
            AppIconView(size: 40)
            VStack(alignment: .leading, spacing: 1) {
                Text("Loadout")
                    .font(Theme.heading)
                    .foregroundStyle(Theme.ink)
                Text("Skill manager for AI coding tools")
                    .font(Theme.meta)
                    .foregroundStyle(Theme.inkTertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(.bottom, 2)
    }

    private var updateStatus: String {
        if let update = services.updateAvailable {
            return "v\(update.version) available"
        }
        return services.isCheckingForUpdate ? "Checking…" : "Up to date"
    }
}
