import AppKit
import Foundation
import SkillboxKit
import SwiftUI

enum OnboardingState: String {
    case notStarted
    case inProgress
    case deferred
    case completed
}

enum ManualSyncAction {
    case onboarding
    case settings
    case sync
}

@MainActor
final class AppState: ObservableObject {
    // Settings mirror — the single source the UI binds to; persist via applySettings.
    @Published private(set) var settings: AppSettings

    // Sync state
    @Published var isSyncing = false
    @Published var syncStatus: SyncStatus = AppState.restoreSyncStatus()
    @Published var lastSyncAt: Date? = UserDefaults.standard.object(forKey: "lastSyncAt") as? Date
    @Published var lastErrorMessage: String? = UserDefaults.standard.string(forKey: "lastErrorMessage")
    @Published var lastSummary: InstallSummary?
    @Published var isAwaitingAuthSetup = false

    // Catalog / installed state
    @Published var catalog: Catalog = .empty
    @Published var lockfile: Lockfile
    @Published var localSkills: [LocalSkill] = []

    // Setup check
    @Published var isRunningSetupCheck = false
    @Published var setupCheckPassed: Bool? = UserDefaults.standard.object(forKey: "setupCheckPassed") as? Bool
    @Published var setupCheckLines: [String] = []
    @Published var lastSetupCheckAt: Date?

    // Self-update
    @Published var updateAvailable: UpdateInfo?
    @Published var isCheckingForUpdate = false
    @Published var isDownloadingUpdate = false
    @Published var updateError: String?

    // Onboarding
    @Published var onboardingState: OnboardingState
    @Published private(set) var onboardingPresentationRequestID = 0

    let settingsStore: SettingsStore
    let logStore: LogStore
    let targetRegistry = TargetRegistry()

    private let syncService: SyncService
    private let setupChecker = SetupChecker()
    private let updateChecker = UpdateChecker()
    private let lockfileStore = LockfileStore()
    private let shouldDisableBackgroundJobs: Bool

    private var autoSyncTimer: Timer?
    private var updateCheckTimer: Timer?
    private var toggleSyncTask: Task<Void, Never>?

    init(settingsStore: SettingsStore = SettingsStore(), logStore: LogStore = LogStore()) {
        self.settingsStore = settingsStore
        self.logStore = logStore
        self.settings = settingsStore.settings
        self.lockfile = lockfileStore.load()
        self.syncService = SyncService(registry: targetRegistry, lockfileStore: lockfileStore)
        self.onboardingState = Self.restoreOnboardingState(settings: settingsStore.settings)
        self.shouldDisableBackgroundJobs = ProcessInfo.processInfo.environment["SKILLBOX_DISABLE_BACKGROUND_JOBS"] == "1"

        configureAutoSyncTimer()
        logStore.append(.info, "Skillbox started.")
        refreshCatalog()

        if !shouldDisableBackgroundJobs {
            // Run setup check shortly after launch if remote is configured
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                guard let self else { return }
                let remote = self.settings.remoteGitURL.trimmed
                if !remote.isEmpty && GitClient.isGitHubRemote(remote) {
                    self.runSetupCheck()
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                self?.checkForUpdate()
            }
            configureUpdateCheckTimer()
        }

        if UserDefaults.standard.string(forKey: Self.onboardingStateKey) == nil {
            persistOnboardingState()
        }
    }

    // No deinit: AppState is the app-root StateObject and lives for the
    // process lifetime; timers hold only weak references back to it.

    // MARK: - Derived state

    var menuIconName: String {
        switch syncStatus {
        case .idle: return "shippingbox"
        case .syncing: return "shippingbox.circle.fill"
        case .succeeded: return "shippingbox.fill"
        case .failed: return "exclamationmark.circle.fill"
        }
    }

    var statusLine: String {
        switch syncStatus {
        case .idle: return "Idle"
        case .syncing: return "Syncing"
        case .succeeded: return "Last sync succeeded"
        case .failed: return "Last sync failed"
        }
    }

    var hasCompletedOnboarding: Bool {
        onboardingState == .completed
    }

    var requiresOnboarding: Bool {
        guard onboardingState != .completed else { return false }
        return settings.remoteGitURL.trimmed.isEmpty
    }

    var manualSyncAction: ManualSyncAction {
        if requiresOnboarding { return .onboarding }
        if settings.remoteGitURL.trimmed.isEmpty { return .settings }
        return .sync
    }

    var enabledTargets: [Target] {
        targetRegistry.enabled(settings: settings, home: FileManager.default.homeDirectoryForCurrentUser)
    }

    var detectedTargetIDs: Set<String> {
        Set(targetRegistry.detected(home: FileManager.default.homeDirectoryForCurrentUser).map(\.id))
    }

    func isSkillInstalled(_ skill: CatalogSkill) -> Bool {
        lockfile.installedSkills.contains(skill.id)
    }

    func isSkillEnabled(_ skill: CatalogSkill) -> Bool {
        Planner.isSkillEnabled(skill, settings: settings)
    }

    // MARK: - Settings

    func applySettings(_ newSettings: AppSettings, runSetupCheckIfNeeded: Bool = true) {
        let remoteChanged = newSettings.remoteGitURL != settings.remoteGitURL
        settingsStore.replace(with: newSettings)
        settings = newSettings
        configureAutoSyncTimer()
        logStore.append(.info, "Settings saved.")
        Analytics.track(.settingsSaved(
            autoSyncEnabled: newSettings.autoSyncEnabled,
            intervalMinutes: newSettings.autoSyncIntervalMinutes
        ))

        if remoteChanged {
            setupCheckPassed = nil
            persistSetupCheckPassed()
            setupCheckLines = []
        }

        let remote = newSettings.remoteGitURL.trimmed
        if runSetupCheckIfNeeded && remoteChanged && !remote.isEmpty && GitClient.isGitHubRemote(remote) {
            runSetupCheck()
        }
    }

    /// Mutates settings without the save-side effects (used by toggles).
    private func mutateSettings(_ mutate: (inout AppSettings) -> Void) {
        var updated = settings
        mutate(&updated)
        settingsStore.replace(with: updated)
        settings = updated
    }

    // MARK: - Skill & target toggles

    func setSkillEnabled(_ skill: CatalogSkill, _ enabled: Bool) {
        mutateSettings { settings in
            if skill.isPlayground {
                if enabled {
                    settings.enabledPlaygroundSkills.insert(skill.id)
                } else {
                    settings.enabledPlaygroundSkills.remove(skill.id)
                }
            } else {
                if enabled {
                    settings.disabledSkills.remove(skill.id)
                } else {
                    settings.disabledSkills.insert(skill.id)
                }
            }
        }
        Analytics.track(.skillToggled(skill: skill.id, enabled: enabled, isPlayground: skill.isPlayground))
        scheduleToggleSync()
    }

    func setTargetEnabled(_ target: Target, _ enabled: Bool) {
        let detected = detectedTargetIDs.contains(target.id) || target.alwaysOn
        mutateSettings { settings in
            if enabled {
                settings.disabledTargets.remove(target.id)
                if !detected {
                    settings.extraTargets.insert(target.id)
                }
            } else {
                settings.disabledTargets.insert(target.id)
                settings.extraTargets.remove(target.id)
            }
        }
        Analytics.track(.targetToggled(target: target.id, enabled: enabled))
        scheduleToggleSync()
    }

    /// Toggles fire a sync after a short quiet period so flipping several
    /// switches results in one git pull, not five.
    private func scheduleToggleSync() {
        toggleSyncTask?.cancel()
        toggleSyncTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1200))
            guard !Task.isCancelled else { return }
            self?.syncNow(trigger: "toggle")
        }
    }

    // MARK: - Sync

    func syncNow(trigger: String) {
        if isSyncing {
            logStore.append(.warn, "Sync already running. Ignoring trigger: \(trigger)")
            return
        }

        let currentSettings = settings
        if currentSettings.remoteGitURL.trimmed.isEmpty {
            syncStatus = .failed
            lastSyncAt = Date()
            lastErrorMessage = "Connect a GitHub repo in Settings before syncing."
            persistSyncState()
            logStore.append(.error, "Sync blocked: missing remote GitHub repo URL.")
            return
        }

        isAwaitingAuthSetup = false
        isSyncing = true
        syncStatus = .syncing
        lastErrorMessage = nil
        logStore.append(.info, "Starting sync (trigger: \(trigger))")
        Analytics.track(.syncStarted(trigger: trigger))

        let syncStartedAt = Date()
        let service = syncService
        let logStore = logStore
        let setupChecker = setupChecker
        let checkAuthFirst = trigger == "manual"

        Task.detached(priority: .userInitiated) {
            // For manual syncs, probe git auth first so we can offer the fix
            // flow instead of a raw git error.
            if checkAuthFirst,
               setupChecker.authProbeFailure(remote: currentSettings.remoteGitURL.trimmed) != nil {
                await MainActor.run { [weak self] in
                    self?.handleAuthProbeFailure(remote: currentSettings.remoteGitURL.trimmed)
                }
                return
            }

            do {
                let outcome = try service.run(settings: currentSettings) { level, message in
                    logStore.append(level, message)
                }
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.isSyncing = false
                    self.syncStatus = .succeeded
                    self.lastSyncAt = Date()
                    self.lastSummary = outcome.summary
                    self.lastErrorMessage = nil
                    self.setupCheckPassed = true
                    self.catalog = outcome.catalog
                    self.lockfile = self.lockfileStore.load()
                    self.refreshLocalSkills()
                    self.persistSyncState()
                    let durationMs = Int(Date().timeIntervalSince(syncStartedAt) * 1000)
                    Analytics.track(.syncCompleted(
                        trigger: trigger,
                        fileCount: outcome.summary.managedFileCount,
                        added: outcome.summary.added,
                        removed: outcome.summary.removed,
                        durationMs: durationMs
                    ))
                }
            } catch {
                let message = error.localizedDescription
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.isSyncing = false
                    self.syncStatus = .failed
                    self.lastSyncAt = Date()
                    self.lastErrorMessage = message
                    self.logStore.append(.error, message)
                    self.persistSyncState()
                    let durationMs = Int(Date().timeIntervalSince(syncStartedAt) * 1000)
                    Analytics.track(.syncFailed(trigger: trigger, error: message, durationMs: durationMs))
                }
            }
        }
    }

    /// Reloads catalog + local skills from disk without touching git.
    func refreshCatalog() {
        let service = syncService
        let currentSettings = settings
        Task.detached(priority: .userInitiated) {
            let catalog = service.loadCatalog(settings: currentSettings)
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.catalog = catalog
                self.refreshLocalSkills()
            }
        }
    }

    private func refreshLocalSkills() {
        let scanner = LocalSkillScanner(registry: targetRegistry)
        let currentLockfile = lockfile
        Task.detached(priority: .utility) {
            let skills = scanner.scan(
                home: FileManager.default.homeDirectoryForCurrentUser,
                lockfile: currentLockfile
            )
            await MainActor.run { [weak self] in
                self?.localSkills = skills
            }
        }
    }

    // MARK: - Setup check

    func runSetupCheck() {
        if isRunningSetupCheck { return }

        let remote = settings.remoteGitURL
        isRunningSetupCheck = true
        setupCheckLines = []
        setupCheckPassed = nil
        logStore.append(.info, "Running setup check.")

        let checker = setupChecker
        Task.detached(priority: .userInitiated) {
            let result = checker.run(remoteGitURL: remote)
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.isRunningSetupCheck = false
                self.setupCheckPassed = result.passed
                self.setupCheckLines = result.lines
                self.lastSetupCheckAt = result.checkedAt
                self.logStore.append(result.passed ? .info : .warn, result.passed ? "Setup check passed." : "Setup check failed.")
                self.persistSetupCheckPassed()
                Analytics.track(.setupCheckRun(passed: result.passed))
            }
        }
    }

    // MARK: - Git auth auto-fix

    private func handleAuthProbeFailure(remote: String) {
        logStore.append(.warn, "Git auth probe failed. Attempting auto-fix via GitHub CLI.")

        let fixCommand: String
        if GitHubCLI().isInstalled() {
            fixCommand = "gh auth login --web -p https && gh auth setup-git"
        } else {
            fixCommand = "brew install gh && gh auth login --web -p https && gh auth setup-git"
        }

        openTerminalWithCommand(fixCommand)

        isSyncing = false
        isAwaitingAuthSetup = true
        syncStatus = .failed
        lastErrorMessage = "Setting up Git credentials — complete setup in Terminal, then click Sync again."
        persistSyncState()
        logStore.append(.info, "Opened Terminal with: \(fixCommand)")
    }

    func openTerminalWithCommand(_ command: String) {
        let escaped = command.replacingOccurrences(of: "\"", with: "\\\"")
        let script = "tell application \"Terminal\" to do script \"\(escaped)\"\ntell application \"Terminal\" to activate"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try? process.run()
    }

    // MARK: - Onboarding

    func beginOnboarding() {
        guard onboardingState != .completed, onboardingState != .inProgress else { return }
        onboardingState = .inProgress
        persistOnboardingState()
    }

    func requestOnboardingPresentation() {
        beginOnboarding()
        onboardingPresentationRequestID &+= 1
    }

    func deferOnboardingIfNeeded() {
        guard onboardingState == .inProgress else { return }
        onboardingState = .deferred
        persistOnboardingState()
    }

    func completeOnboarding() {
        guard onboardingState != .completed else { return }
        onboardingState = .completed
        persistOnboardingState()
        Analytics.track(.onboardingCompleted)
        Analytics.identify(properties: [
            "has_completed_onboarding": true,
            "auto_sync_enabled": settings.autoSyncEnabled,
        ])
    }

    // MARK: - Update

    func checkForUpdate() {
        guard !isCheckingForUpdate else { return }
        isCheckingForUpdate = true
        updateError = nil

        Task { [updateChecker] in
            let info = await updateChecker.checkForUpdate()
            self.isCheckingForUpdate = false
            self.updateAvailable = info
            if let info {
                self.logStore.append(.info, "Update available: v\(info.version)")
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
                self.isDownloadingUpdate = false
                self.updateError = error.localizedDescription
                self.logStore.append(.error, "Update failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Misc

    func openLogsFile() {
        NSWorkspace.shared.activateFileViewerSelecting([logStore.logFileURL])
    }

    func openCheckoutFolder() {
        let url = URL(fileURLWithPath: settings.checkoutPath.expandingTildePath)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    // MARK: - Persistence

    private static let onboardingStateKey = "onboardingState"

    private static func restoreSyncStatus() -> SyncStatus {
        guard let raw = UserDefaults.standard.string(forKey: "lastSyncStatus") else { return .idle }
        switch raw {
        case "succeeded": return .succeeded
        case "failed": return .failed
        default: return .idle
        }
    }

    private func persistSyncState() {
        let defaults = UserDefaults.standard
        defaults.set(lastSyncAt, forKey: "lastSyncAt")
        defaults.set(lastErrorMessage, forKey: "lastErrorMessage")
        switch syncStatus {
        case .succeeded: defaults.set("succeeded", forKey: "lastSyncStatus")
        case .failed: defaults.set("failed", forKey: "lastSyncStatus")
        default: defaults.removeObject(forKey: "lastSyncStatus")
        }
    }

    private func persistSetupCheckPassed() {
        if let passed = setupCheckPassed {
            UserDefaults.standard.set(passed, forKey: "setupCheckPassed")
        } else {
            UserDefaults.standard.removeObject(forKey: "setupCheckPassed")
        }
    }

    private static func restoreOnboardingState(settings: AppSettings) -> OnboardingState {
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: onboardingStateKey),
           let state = OnboardingState(rawValue: raw) {
            return state
        }
        // A configured remote means the user has already set up.
        if !settings.remoteGitURL.trimmed.isEmpty {
            return .completed
        }
        return .notStarted
    }

    private func persistOnboardingState() {
        UserDefaults.standard.set(onboardingState.rawValue, forKey: Self.onboardingStateKey)
    }

    // MARK: - Timers

    private func configureAutoSyncTimer() {
        autoSyncTimer?.invalidate()
        if shouldDisableBackgroundJobs { return }

        guard settings.autoSyncEnabled else {
            logStore.append(.info, "Auto-sync disabled")
            return
        }

        let minutes = max(5, settings.autoSyncIntervalMinutes)
        autoSyncTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(minutes * 60), repeats: true) { _ in
            Task { @MainActor [weak self] in
                self?.syncNow(trigger: "auto")
            }
        }
        logStore.append(.info, "Auto-sync enabled every \(minutes) minutes")
    }

    private func configureUpdateCheckTimer() {
        updateCheckTimer?.invalidate()
        if shouldDisableBackgroundJobs { return }
        updateCheckTimer = Timer.scheduledTimer(withTimeInterval: 4 * 60 * 60, repeats: true) { _ in
            Task { @MainActor [weak self] in
                self?.checkForUpdate()
            }
        }
    }
}
