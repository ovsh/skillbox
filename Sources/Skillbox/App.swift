import AppKit
import ServiceManagement
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Kill any already-running instance before setting up
        let previous = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
            .filter { $0 != NSRunningApplication.current }
        for old in previous {
            old.terminate()
        }

        NSApp.setActivationPolicy(.regular)

        if let iconData = IconGenerator.renderAppIconPNG(),
           let iconImage = NSImage(data: iconData) {
            NSApp.applicationIconImage = iconImage
        }

        let env = ProcessInfo.processInfo.environment
        let shouldSkipLoginItem = env["SKILLBOX_SKIP_LOGIN_ITEM"] == "1"
        let shouldDisableAnalytics = env["SKILLBOX_DISABLE_ANALYTICS"] == "1"

        // Enable launch at login by default on first run unless explicitly disabled
        if !shouldSkipLoginItem {
            let launchKey = "hasRegisteredLoginItem"
            if !UserDefaults.standard.bool(forKey: launchKey) {
                try? SMAppService.mainApp.register()
                UserDefaults.standard.set(true, forKey: launchKey)
            }
        }

        if !shouldDisableAnalytics {
            Analytics.setup()
        }

        Task { @MainActor in
            WindowCoordinator.shared.requestInitialPresentation()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Task { @MainActor in
            WindowCoordinator.shared.handleDockReopen(hasVisibleWindows: flag)
        }
        return true
    }
}

// MARK: - Menu Bar Label

/// The MenuBarExtra label view. It is rendered immediately at app launch
/// (unlike the popover content), so its `onAppear` reliably fires during
/// startup. We use this to capture SwiftUI's `openWindow` action.
private struct MenuBarLabel: View {
    let iconName: String
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(systemName: iconName)
            .onAppear {
                WindowCoordinator.shared.register(openWindow: openWindow)
            }
    }
}

// MARK: - App

struct SkillboxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environmentObject(appState)
        } label: {
            MenuBarLabel(iconName: appState.menuIconName)
        }
        .menuBarExtraStyle(.window)

        Window("Skillbox", id: "skills") {
            BrowserView()
                .environmentObject(appState)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 960, height: 640)
        .windowStyle(.hiddenTitleBar)

        Window("Skillbox Settings", id: "settings") {
            SettingsView()
                .environmentObject(appState)
        }
        .windowResizability(.contentSize)
    }
}
