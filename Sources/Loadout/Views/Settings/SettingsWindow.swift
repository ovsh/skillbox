import ServiceManagement
import LoadoutKit
import SwiftUI

/// Deliberately small: launch at login, updates, logs. Team/registry settings
/// return when team mode ships.
struct SettingsWindow: View {
    @Environment(AppServicesModel.self) private var services

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.gutter) {
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: $launchAtLogin) {
                        Text("Launch at login")
                            .font(Theme.body)
                            .foregroundStyle(Theme.ink)
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(Theme.accent)
                    .onChange(of: launchAtLogin) {
                        services.setLaunchAtLogin(launchAtLogin)
                    }
                }
                .padding(14)
            }

            Card {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Version \(services.appVersion)")
                                .font(Theme.body)
                                .foregroundStyle(Theme.ink)
                            Text(updateStatus)
                                .font(Theme.meta)
                                .foregroundStyle(Theme.inkTertiary)
                        }
                        Spacer()
                        if services.updateAvailable != nil {
                            Button(services.isDownloadingUpdate ? "Updating…" : "Update") {
                                services.installUpdate()
                            }
                            .controlSize(.small)
                            .disabled(services.isDownloadingUpdate)
                        } else {
                            Button("Check for Updates") {
                                services.checkForUpdate()
                            }
                            .controlSize(.small)
                            .disabled(services.isCheckingForUpdate)
                        }
                    }
                    if let error = services.updateError {
                        Text(error)
                            .font(Theme.meta)
                            .foregroundStyle(.red)
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
        .padding(Theme.gutter)
        .frame(width: 380)
        .background(Theme.canvas)
    }

    private var updateStatus: String {
        if let update = services.updateAvailable {
            return "v\(update.version) available"
        }
        return services.isCheckingForUpdate ? "Checking…" : "Up to date"
    }
}
