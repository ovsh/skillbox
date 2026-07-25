import LoadoutKit
import SwiftUI

/// Full-width editor for the selected system prompt file. File selection
/// lives in the sidebar; this pane is all editing surface.
struct PromptEditor: View {
    @Environment(PromptEditorModel.self) private var prompts

    var body: some View {
        @Bindable var prompts = prompts

        Group {
            if let file = prompts.selectedFile {
                VStack(alignment: .leading, spacing: 0) {
                    editorHeader(file)

                    if prompts.hasDiskConflict {
                        conflictBanner
                    }

                    // A well sunk into the canvas — no border, just a tone step
                    // and the shadow the text sits inside.
                    TextEditor(text: $prompts.text)
                        .font(Theme.editor)
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(5)
                        .scrollContentBackground(.hidden)
                        .padding(16)
                        .background(Theme.raised, in: .rect(cornerRadius: Theme.radius))
                        .padding(.horizontal, Theme.paneInset)
                        .padding(.bottom, Theme.paneInset)
                        .disabled(prompts.readFailed)
                }
                // A column, not a wall. Header and well share the same measure
                // so the pane reads as one document however wide the window is.
                .frame(maxWidth: Theme.editorWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            } else {
                EmptyState(
                    systemImage: "text.alignleft",
                    title: "Select a system prompt",
                    message: "Your global agent instructions, editable in place."
                )
            }
        }
        .background(Theme.canvas)
        .onDisappear {
            prompts.flushPendingSave()
        }
    }

    private func editorHeader(_ file: PromptFile) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(file.displayShortName)
                    .font(Theme.display)
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                Text("\(prompts.text.count) chars")
                    .font(Theme.meta)
                    .foregroundStyle(Theme.inkTertiary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                // Autosave already runs; the button is for people who want to
                // commit now. It only exists when there is something to commit,
                // so the header never carries a dead gray pill.
                Button("Save") { prompts.save() }
                    .buttonStyle(QuietButtonStyle())
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(!prompts.isDirty || !prompts.canSave)
                    .opacity(prompts.isDirty && prompts.canSave ? 1 : 0)
            }

            HStack(spacing: 8) {
                Text(abbreviatedPath(file))
                    .font(Theme.mono)
                    .foregroundStyle(Theme.inkTertiary)
                Text("·")
                    .font(Theme.meta)
                    .foregroundStyle(Theme.inkTertiary)
                Text(file.readerDescription)
                    .font(Theme.meta)
                    .foregroundStyle(Theme.inkTertiary)
                Spacer(minLength: 12)
                saveStatusLabel
            }
        }
        .padding(.horizontal, Theme.paneInset)
        .padding(.top, Theme.titleBar)
        .padding(.bottom, 16)
    }

    /// Autosave status. A dot in the state palette carries it — amber while
    /// there's unsaved work, green once disk matches the buffer.
    private var saveStatusLabel: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusTint)
                .frame(width: 6, height: 6)
            Text(saveStatus)
                .font(Theme.meta)
                .foregroundStyle(statusTint == Theme.danger ? Theme.danger : Theme.inkSecondary)
                .lineLimit(1)
        }
        .animation(Theme.fade, value: prompts.isDirty)
    }

    private var statusTint: Color {
        if prompts.lastError != nil || prompts.hasDiskConflict { return Theme.danger }
        return prompts.isDirty ? Theme.partial : Theme.live
    }

    private var conflictBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(Theme.partial)
            Text("This file changed on disk while you were editing.")
                .font(Theme.body)
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 12)
            Button("Reload File") { prompts.reloadFromDisk() }
                .buttonStyle(QuietButtonStyle())
            Button("Keep Mine") { prompts.overwriteDisk() }
                .buttonStyle(QuietButtonStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Theme.partial.opacity(0.13), in: .rect(cornerRadius: Theme.radiusSmall))
        .padding(.horizontal, Theme.paneInset)
        .padding(.bottom, 12)
    }

    private var saveStatus: String {
        if let error = prompts.lastError { return error }
        if prompts.hasDiskConflict { return "Conflict: resolve above" }
        if prompts.isDirty { return "Unsaved. Autosaves shortly" }
        if let saved = prompts.lastSavedAt { return "Saved \(RelativeDateText.string(for: saved))" }
        return prompts.selectedFile?.exists == true ? "Saved" : "Not created yet. Saving creates it"
    }

    private func abbreviatedPath(_ file: PromptFile) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return file.path.hasPrefix(home) ? "~" + file.path.dropFirst(home.count) : file.path
    }
}

extension PromptFile {
    /// "CLAUDE.md — Claude Code" → "Claude Code & Agent SDK read this file."
    var readerDescription: String {
        let owner = displayName.components(separatedBy: " — ").last ?? ""
        return owner == "Claude Code" ? "Read by Claude Code & Agent SDK" : "Read by \(owner)"
    }
}
