@preconcurrency import PostHog
import Foundation

enum AnalyticsEvent {
    case appLaunched(isFirstLaunch: Bool)
    case skillToggled(skill: String, enabled: Bool)
    case skillDeleted(skill: String)
    case overrideChanged(skill: String, state: String)
    case toolPresenceToggled(target: String, enabled: Bool)
    case promptSaved(file: String)
    case updateShown(version: String)
    case updateStarted(version: String)

    var name: String {
        switch self {
        case .appLaunched: return "app_launched"
        case .skillToggled: return "skill_toggled"
        case .skillDeleted: return "skill_deleted"
        case .overrideChanged: return "override_changed"
        case .toolPresenceToggled: return "tool_presence_toggled"
        case .promptSaved: return "prompt_saved"
        case .updateShown: return "update_shown"
        case .updateStarted: return "update_started"
        }
    }

    var properties: [String: Any] {
        switch self {
        case .appLaunched(let isFirstLaunch):
            return ["is_first_launch": isFirstLaunch]
        case .skillToggled(let skill, let enabled):
            return ["skill": skill, "enabled": enabled]
        case .skillDeleted(let skill):
            return ["skill": skill]
        case .overrideChanged(let skill, let state):
            return ["skill": skill, "state": state]
        case .toolPresenceToggled(let target, let enabled):
            return ["target": target, "enabled": enabled]
        case .promptSaved(let file):
            return ["file": (file as NSString).lastPathComponent]
        case .updateShown(let version), .updateStarted(let version):
            return ["version": version]
        }
    }
}

enum Analytics {
    private static let anonIDKey = "analyticsAnonymousID"

    static func setup() {
        let config = PostHogConfig(apiKey: "phc_E7kSvw3qyxtjnXhHzOVIxsJ1w9Ol0i1g46yeyDOBAP")
        config.captureApplicationLifecycleEvents = false
        config.captureScreenViews = false
        PostHogSDK.shared.setup(config)
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
}
