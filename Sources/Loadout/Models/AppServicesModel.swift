import AppKit
import Foundation
import Observation
import ServiceManagement
import LoadoutKit

/// App-lifecycle services: self-update, launch-at-login, log access.
@MainActor
@Observable
final class AppServicesModel {
    private(set) var updateAvailable: UpdateInfo?
    private(set) var isCheckingForUpdate = false
    private(set) var isDownloadingUpdate = false
    private(set) var updateError: String?

    let logStore = LogStore()

    private let updateChecker = UpdateChecker()
    private let backgroundJobsDisabled =
        ProcessInfo.processInfo.environment["LOADOUT_DISABLE_BACKGROUND_JOBS"] == "1"

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }

    private var backgroundTask: Task<Void, Never>?

    /// Kicks off the initial + recurring update checks (4h cadence).
    /// Idempotent — window reopens must not stack loops.
    func startBackgroundWork() {
        guard !backgroundJobsDisabled, backgroundTask == nil else { return }
        backgroundTask = Task {
            try? await Task.sleep(for: .seconds(5))
            while !Task.isCancelled {
                checkForUpdate()
                try? await Task.sleep(for: .seconds(4 * 60 * 60))
            }
        }
    }

    func checkForUpdate() {
        guard !isCheckingForUpdate else { return }
        isCheckingForUpdate = true
        updateError = nil

        Task { [updateChecker] in
            let info = await updateChecker.checkForUpdate()
            isCheckingForUpdate = false
            updateAvailable = info
            if let info {
                logStore.append(.info, "Update available: v\(info.version)")
                Analytics.track(.updateShown(version: info.version))
            }
        }
    }

    func installUpdate() {
        guard let update = updateAvailable, !isDownloadingUpdate else { return }
        isDownloadingUpdate = true
        updateError = nil
        logStore.append(.info, "Downloading update v\(update.version)...")
        Analytics.track(.updateStarted(version: update.version))

        Task { [updateChecker] in
            do {
                try await updateChecker.downloadAndInstall(from: update.downloadURL)
            } catch {
                isDownloadingUpdate = false
                updateError = error.localizedDescription
                logStore.append(.error, "Update failed: \(error.localizedDescription)")
            }
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        if enabled {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
    }

    func openLogsFile() {
        NSWorkspace.shared.activateFileViewerSelecting([logStore.logFileURL])
    }
}
