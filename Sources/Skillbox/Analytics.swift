@preconcurrency import PostHog
import Foundation

// MARK: - Event Definitions

enum AnalyticsEvent {
    // Onboarding funnel
    case appLaunched(isFirstLaunch: Bool)
    case onboardingStepViewed(step: Int, stepName: String)
    case onboardingGHInstallStarted
    case onboardingGHInstallCompleted
    case onboardingGHAuthStarted
    case onboardingGHAuthCompleted(hasUsername: Bool)
    case onboardingRepoCreated
    case onboardingRepoConnected
    case onboardingCompleted
    case onboardingSkipped

    // Sync health
    case syncStarted(trigger: String)
    case syncCompleted(trigger: String, fileCount: Int, added: Int, removed: Int, durationMs: Int)
    case syncFailed(trigger: String, error: String, durationMs: Int)

    // Feature adoption
    case skillToggled(skill: String, enabled: Bool, isPlayground: Bool)
    case targetToggled(target: String, enabled: Bool)
    case settingsSaved(autoSyncEnabled: Bool, intervalMinutes: Int)
    case setupCheckRun(passed: Bool)

    // Growth & retention
    case updateShown(version: String)
    case updateStarted(version: String)

    var name: String {
        switch self {
        case .appLaunched: return "app_launched"
        case .onboardingStepViewed: return "onboarding_step_viewed"
        case .onboardingGHInstallStarted: return "onboarding_gh_install_started"
        case .onboardingGHInstallCompleted: return "onboarding_gh_install_completed"
        case .onboardingGHAuthStarted: return "onboarding_gh_auth_started"
        case .onboardingGHAuthCompleted: return "onboarding_gh_auth_completed"
        case .onboardingRepoCreated: return "onboarding_repo_created"
        case .onboardingRepoConnected: return "onboarding_repo_connected"
        case .onboardingCompleted: return "onboarding_completed"
        case .onboardingSkipped: return "onboarding_skipped"
        case .syncStarted: return "sync_started"
        case .syncCompleted: return "sync_completed"
        case .syncFailed: return "sync_failed"
        case .skillToggled: return "skill_toggled"
        case .targetToggled: return "target_toggled"
        case .settingsSaved: return "settings_saved"
        case .setupCheckRun: return "setup_check_run"
        case .updateShown: return "update_shown"
        case .updateStarted: return "update_started"
        }
    }

    var properties: [String: Any] {
        switch self {
        case .appLaunched(let isFirstLaunch):
            return ["is_first_launch": isFirstLaunch]
        case .onboardingStepViewed(let step, let stepName):
            return ["step": step, "step_name": stepName]
        case .onboardingGHAuthCompleted(let hasUsername):
            return ["has_username": hasUsername]
        case .syncStarted(let trigger):
            return ["trigger": trigger]
        case .syncCompleted(let trigger, let fileCount, let added, let removed, let durationMs):
            return [
                "trigger": trigger, "file_count": fileCount,
                "added": added, "removed": removed, "duration_ms": durationMs,
            ]
        case .syncFailed(let trigger, let error, let durationMs):
            return ["trigger": trigger, "error": String(error.prefix(200)), "duration_ms": durationMs]
        case .skillToggled(let skill, let enabled, let isPlayground):
            return ["skill": skill, "enabled": enabled, "is_playground": isPlayground]
        case .targetToggled(let target, let enabled):
            return ["target": target, "enabled": enabled]
        case .settingsSaved(let autoSyncEnabled, let intervalMinutes):
            return ["auto_sync_enabled": autoSyncEnabled, "interval_minutes": intervalMinutes]
        case .setupCheckRun(let passed):
            return ["passed": passed]
        case .updateShown(let version):
            return ["version": version]
        case .updateStarted(let version):
            return ["version": version]
        default:
            return [:]
        }
    }
}

// MARK: - Analytics Singleton

enum Analytics {
    private static let anonIDKey = "analyticsAnonymousID"

    static func setup() {
        let config = PostHogConfig(apiKey: "phc_E7kSvw3qyxtjnXhHzOVIxsJ1w9Ol0i1g46yeyDOBAP")
        config.captureApplicationLifecycleEvents = false
        config.captureScreenViews = false
        PostHogSDK.shared.setup(config)

        // Skillbox shares the PostHog project with its predecessor; the app
        // property keeps the two products separable in queries.
        PostHogSDK.shared.register(["app": "skillbox"])

        let defaults = UserDefaults.standard
        if defaults.string(forKey: anonIDKey) == nil {
            defaults.set(UUID().uuidString, forKey: anonIDKey)
        }
        let anonID = defaults.string(forKey: anonIDKey)!

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        PostHogSDK.shared.identify(anonID, userProperties: ["app_version": appVersion])

        let isFirstLaunch = !defaults.bool(forKey: "hasLaunchedBefore")
        if isFirstLaunch {
            defaults.set(true, forKey: "hasLaunchedBefore")
        }
        track(.appLaunched(isFirstLaunch: isFirstLaunch))
    }

    static func track(_ event: AnalyticsEvent) {
        PostHogSDK.shared.capture(event.name, properties: event.properties)
    }

    static func identify(properties: [String: Any]) {
        if let anonID = UserDefaults.standard.string(forKey: anonIDKey) {
            PostHogSDK.shared.identify(anonID, userProperties: properties)
        }
    }
}
