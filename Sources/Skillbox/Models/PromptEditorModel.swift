import Foundation
import Observation
import SkillboxKit

/// State for the global prompt editor: which files exist, the loaded buffer,
/// dirty tracking, and debounced autosave.
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
    /// Autosave pauses; the user chooses Reload or Overwrite.
    private(set) var hasDiskConflict = false

    private var loadedText = ""
    private var autosaveTask: Task<Void, Never>?
    private var monitor: DirectoryMonitor?
    private let store = PromptFileStore(home: FileManager.default.homeDirectoryForCurrentUser)

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        monitor = DirectoryMonitor(directories: [
            home.appendingPathComponent(".claude"),
            home.appendingPathComponent(".codex"),
        ]) { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleExternalChange()
            }
        }
    }

    /// Another process wrote near our files: reload clean buffers silently;
    /// flag a conflict instead of clobbering dirty ones.
    private func handleExternalChange() {
        let previousSelection = selectedFile
        files = store.discover()
        guard let selected = previousSelection,
              let updated = files.first(where: { $0.path == selected.path }) else { return }
        selectedFile = updated
        guard updated.modifiedAt != selected.modifiedAt else { return }
        if isDirty {
            hasDiskConflict = true
            autosaveTask?.cancel()
        } else {
            loadedText = (try? store.read(updated)) ?? loadedText
            text = loadedText
            isDirty = false
        }
    }

    /// Conflict resolution: take the disk version, dropping buffer edits.
    func reloadFromDisk() {
        hasDiskConflict = false
        isDirty = false
        select(selectedFile)
    }

    /// Conflict resolution: keep the buffer, overwriting the disk version.
    func overwriteDisk() {
        hasDiskConflict = false
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

    func select(_ file: PromptFile?) {
        flushPendingSave()
        hasDiskConflict = false
        selectedFile = file
        guard let file else {
            loadedText = ""
            text = ""
            return
        }
        loadedText = (try? store.read(file)) ?? ""
        text = loadedText
        isDirty = false
        lastError = nil
    }

    // MARK: - Saving

    func save() {
        autosaveTask?.cancel()
        guard !hasDiskConflict else { return }
        guard let file = selectedFile, isDirty else { return }
        do {
            try store.write(text, to: file)
            loadedText = text
            isDirty = false
            lastSavedAt = Date()
            lastError = nil
            // Re-stat immediately so our own write isn't later mistaken for
            // an external change (which would raise a false conflict).
            files = store.discover()
            selectedFile = files.first { $0.path == file.path } ?? selectedFile
        } catch PromptFileError.changedOnDisk {
            // The store's revision guard caught an edit we hadn't seen.
            hasDiskConflict = true
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Saves any pending edit immediately (window close, file switch).
    func flushPendingSave() {
        if isDirty { save() }
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
