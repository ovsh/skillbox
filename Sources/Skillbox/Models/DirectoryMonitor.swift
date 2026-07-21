import Foundation

/// Watches a set of directories for writes/renames/deletes and fires one
/// coalesced callback per burst. Keeps the always-on popover and library
/// honest without polling.
///
/// Uses kqueue-backed DispatchSources on the directories themselves, so
/// atomic-replace writes inside them (settings.json, SKILL.md saves, folder
/// moves) all register as parent-directory events. Directories that don't
/// exist at start are skipped — the app-active refresh is the backstop.
final class DirectoryMonitor: @unchecked Sendable {
    private let queue = DispatchQueue(label: "skillbox.dirmonitor", qos: .utility)
    private var sources: [DispatchSourceFileSystemObject] = []
    private var pendingNotify: DispatchWorkItem?
    private let debounce: TimeInterval
    private let onChange: @Sendable () -> Void

    init(directories: [URL], debounce: TimeInterval = 0.3, onChange: @escaping @Sendable () -> Void) {
        self.debounce = debounce
        self.onChange = onChange

        for directory in directories {
            let fd = open(directory.path, O_EVTONLY)
            guard fd >= 0 else { continue }

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .rename, .delete, .link, .extend],
                queue: queue
            )
            source.setEventHandler { [weak self] in
                self?.scheduleNotify()
            }
            source.setCancelHandler {
                close(fd)
            }
            source.resume()
            sources.append(source)
        }
    }

    deinit {
        for source in sources {
            source.cancel()
        }
    }

    private func scheduleNotify() {
        pendingNotify?.cancel()
        let work = DispatchWorkItem { [onChange] in onChange() }
        pendingNotify = work
        queue.asyncAfter(deadline: .now() + debounce, execute: work)
    }
}
