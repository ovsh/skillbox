import AppKit
import SwiftUI

/// Routes window presentation through one place so the menu bar, dock icon,
/// and launch flow all open the same windows reliably.
@MainActor
final class WindowCoordinator {
    static let shared = WindowCoordinator()

    enum AppWindow: String, CaseIterable {
        case library
        case settings

        var title: String {
            switch self {
            case .library: "Loadout"
            case .settings: "Loadout Settings"
            }
        }
    }

    private var openWindowAction: OpenWindowAction?
    private var pendingWindows: Set<AppWindow> = []
    private var didRequestInitialPresentation = false

    private init() {}

    func register(openWindow action: OpenWindowAction) {
        openWindowAction = action
        flushPendingWindows()
    }

    func requestInitialPresentation() {
        guard !didRequestInitialPresentation else { return }
        didRequestInitialPresentation = true
        showLibraryWindow()
    }

    func handleDockReopen(hasVisibleWindows: Bool) {
        guard !hasVisibleWindows else {
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        showLibraryWindow()
    }

    func showLibraryWindow() {
        show(.library)
    }

    func showSettingsWindow() {
        show(.settings)
    }

    private func show(_ target: AppWindow) {
        NSApp.activate(ignoringOtherApps: true)

        if let existingWindow = existingWindow(for: target) {
            if existingWindow.isMiniaturized {
                existingWindow.deminiaturize(nil)
            }
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }

        guard let openWindowAction else {
            pendingWindows.insert(target)
            return
        }

        openWindowAction(id: target.rawValue)
    }

    private func flushPendingWindows() {
        guard let openWindowAction else { return }
        let queued = pendingWindows
        pendingWindows.removeAll()

        for target in AppWindow.allCases where queued.contains(target) {
            openWindowAction(id: target.rawValue)
        }
    }

    private func existingWindow(for target: AppWindow) -> NSWindow? {
        NSApp.windows.first { window in
            let identifier = window.identifier?.rawValue ?? ""
            return identifier.contains(target.rawValue) || window.title == target.title
        }
    }
}
