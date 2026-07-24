import Foundation
import Observation
import LoadoutKit

/// State for the global prompt editor: which files exist, the loaded buffer,
/// dirty tracking, and debounced autosave that never clobbers disk edits.
@MainActor
@Observable
final class PromptEditorModel {
    private(set) var files: [PromptFile] = []
    private(set) var selectedFile: PromptFile?
    private(set) var isDirty = false
    private(set) var lastSavedAt: Date?
    private(set) var lastError: String?

    /// The editor buffer. Views bind to this; edits mark the model dirty and
    /// arm the autosave timer.
    var text: String = "" {
        didSet {
            guard text != loadedText else { return }
            isDirty = true
            armAutosave()
        }
    }

    /// True when the file changed on disk while the buffer has unsaved edits.
    /// Autosave pauses; the user chooses Reload or Keep Mine.
    private(set) var hasDiskConflict = false
    /// True when the selected file exists but couldn't be read — saving is
    /// blocked so an empty buffer can't silently replace unreadable content.
    private(set) var readFailed = false

    var canSave: Bool {
        selectedFile != nil && !hasDiskConflict && !readFailed
    }

    private var loadedText = ""
    private var autosaveTask: Task<Void, Never>?
    private var monitor: DirectoryMonitor?
    private let store = PromptFileStore(home: FileManager.default.homeDirectoryForCurrentUser)

    init() {
        // Parents of every candidate prompt file; ~ itself covers ~/AGENTS.md.
        let home = FileManager.default.homeDirectoryForCurrentUser
        monitor = DirectoryMonitor(directories: [
            home.appendingPathComponent(".claude"),
            home.appendingPathComponent(".codex"),
            home.appendingPathComponent(".config/opencode"),
            home,
        ]) { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleExternalChange()
            }
        }
    }

    // MARK: - External changes

    /// Another process wrote near our files: reload clean buffers silently;
    /// flag a conflict instead of clobbering dirty ones. Also the app-active
    /// reconciliation backstop.
    func handleExternalChange() {
        let previousSelection = selectedFile
        files = store.discover()
        guard let selected = previousSelection,
              let updated = files.first(where: { $0.path == selected.path }) else { return }
        selectedFile = updated

        // Deleted externally: a clean buffer resets to "not created yet";
        // a dirty buffer becomes a conflict the user resolves.
        if selected.exists && !updated.exists {
            if isDirty {
                hasDiskConflict = true
                autosaveTask?.cancel()
            } else {
                loadBuffer(from: updated)
            }
            return
        }

        guard updated.modifiedAt != selected.modifiedAt else { return }
        if isDirty {
            hasDiskConflict = true
            autosaveTask?.cancel()
        } else {
            loadBuffer(from: updated)
        }
    }

    /// Conflict resolution: take the disk version, dropping buffer edits.
    func reloadFromDisk() {
        hasDiskConflict = false
        isDirty = false
        select(selectedFile)
    }

    /// Conflict resolution: keep the buffer. Re-stats first so the write
    /// compares against the revision that caused the conflict — otherwise the
    /// same conflict re-raises forever.
    func overwriteDisk() {
        guard let selected = selectedFile else { return }
        files = store.discover()
        selectedFile = files.first { $0.path == selected.path } ?? selected
        hasDiskConflict = false
        isDirty = true
        save()
    }

    // MARK: - Loading

    func refresh() {
        files = store.discover()
        // Keep the selection stable across refreshes; default to the first
        // existing file (CLAUDE.md on this machine).
        if let selected = selectedFile,
           let updated = files.first(where: { $0.path == selected.path }) {
            selectedFile = updated
        } else {
            select(files.first(where: \.exists) ?? files.first)
        }
    }

    /// Switches files. Aborts (keeping the current buffer and selection) if
    /// pending edits can't be saved — never discards unsaved work.
    func select(_ file: PromptFile?) {
        guard flushPendingSave() else { return }
        hasDiskConflict = false
        selectedFile = file
        guard let file else {
            loadedText = ""
            text = ""
            readFailed = false
            return
        }
        loadBuffer(from: file)
        lastError = readFailed ? lastError : nil
    }

    private func loadBuffer(from file: PromptFile) {
        if file.exists {
            if let content = try? store.read(file) {
                loadedText = content
                readFailed = false
            } else {
                loadedText = ""
                readFailed = true
                lastError = "Can't read \(file.displayName) — saving is disabled."
            }
        } else {
            loadedText = ""
            readFailed = false
        }
        text = loadedText
        isDirty = false
    }

    // MARK: - Saving

    /// Returns true when the buffer is safely on disk (or there was nothing
    /// to save). False means the edit is still only in memory.
    @discardableResult
    func save() -> Bool {
        autosaveTask?.cancel()
        guard canSave else { return false }
        guard let file = selectedFile, isDirty else { return true }
        do {
            try store.write(text, to: file, expectedModifiedAt: file.exists ? file.modifiedAt : nil)
            loadedText = text
            isDirty = false
            lastSavedAt = Date()
            lastError = nil
            Analytics.track(.promptSaved(file: file.path))
            // Re-stat immediately so our own write isn't later mistaken for
            // an external change (which would raise a false conflict).
            files = store.discover()
            selectedFile = files.first { $0.path == file.path } ?? selectedFile
            return true
        } catch PromptFileError.changedOnDisk {
            // The store's revision guard caught an edit we hadn't seen.
            hasDiskConflict = true
            return false
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// Saves any pending edit immediately (window close, file switch).
    /// Returns false when unsaved work remains.
    @discardableResult
    func flushPendingSave() -> Bool {
        isDirty ? save() : true
    }

    private func armAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            self?.save()
        }
    }
}
