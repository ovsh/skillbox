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

        // Enable launch at login by default on first run unless explicitly disabled
        if env["LOADOUT_SKIP_LOGIN_ITEM"] != "1" {
            let launchKey = "hasRegisteredLoginItem"
            if !UserDefaults.standard.bool(forKey: launchKey) {
                try? SMAppService.mainApp.register()
                UserDefaults.standard.set(true, forKey: launchKey)
            }
        }

        if env["LOADOUT_DISABLE_ANALYTICS"] != "1" {
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
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(systemName: "backpack")
            .onAppear {
                WindowCoordinator.shared.register(openWindow: openWindow)
            }
    }
}

// MARK: - App

struct LoadoutApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var library = SkillLibraryModel()
    @State private var prompts = PromptEditorModel()
    @State private var services = AppServicesModel()

    var body: some Scene {
        MenuBarExtra {
            MenuPopover()
                .environment(library)
        } label: {
            MenuBarLabel()
        }
        .menuBarExtraStyle(.window)

        Window("Loadout", id: "library") {
            LibraryWindow()
                .environment(library)
                .environment(prompts)
                .task {
                    services.startBackgroundWork()
                }
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 980, height: 640)
        .windowStyle(.hiddenTitleBar)

        Window("Loadout Settings", id: "settings") {
            SettingsWindow()
                .environment(services)
        }
        .windowResizability(.contentSize)
    }
}
