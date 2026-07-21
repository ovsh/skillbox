import SkillboxKit
import SwiftUI

/// Middle column when Prompts is focused: the global prompt files.
struct PromptFileList: View {
    @Environment(PromptEditorModel.self) private var prompts

    var body: some View {
        List(selection: Binding(
            get: { prompts.selectedFile?.id },
            set: { id in prompts.select(prompts.files.first { $0.id == id }) }
        )) {
            ForEach(prompts.files) { file in
                PromptFileRow(file: file, isSelected: prompts.selectedFile?.id == file.id)
                    .tag(file.id)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 1, leading: 8, bottom: 1, trailing: 8))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.canvas)
        .navigationTitle("Prompts")
    }
}

private struct PromptFileRow: View {
    let file: PromptFile
    var isSelected = false

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(file.displayName)
                    .font(Theme.bodyMedium)
                    .foregroundStyle(Theme.ink)
                Text(abbreviatedPath)
                    .font(Theme.mono)
                    .foregroundStyle(Theme.inkTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if file.exists {
                RelativeDateText(date: file.modifiedAt)
            } else {
                Chip(text: "Create", tint: Theme.accent)
            }
        }
        .rowChrome(isSelected: isSelected)
    }

    private var abbreviatedPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return file.path.hasPrefix(home)
            ? "~" + file.path.dropFirst(home.count)
            : file.path
    }
}

// MARK: - Editor

/// Detail column when Prompts is focused: inline editor for the selected file.
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

                    TextEditor(text: $prompts.text)
                        .font(Theme.editor)
                        .foregroundStyle(Theme.ink)
                        .scrollContentBackground(.hidden)
                        .padding(Theme.gutter - 6)
                        .background(Theme.well, in: .rect(cornerRadius: Theme.radius))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.radius)
                                .strokeBorder(Theme.border, lineWidth: 0.5)
                        )
                        .padding([.horizontal, .bottom], Theme.gutter)
                }
            } else {
                EmptyState(
                    systemImage: "text.alignleft",
                    title: "Select a prompt file",
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
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(file.displayName)
                    .font(Theme.title(15))
                    .foregroundStyle(Theme.ink)
                Text(saveStatus)
                    .font(Theme.meta)
                    .foregroundStyle(prompts.isDirty ? Theme.accent : Theme.inkTertiary)
                    .animation(Theme.fade, value: prompts.isDirty)
            }

            Spacer()

            Text("\(prompts.text.count) chars")
                .font(Theme.meta)
                .foregroundStyle(Theme.inkTertiary)
                .monospacedDigit()

            Button("Save") { prompts.save() }
                .keyboardShortcut("s", modifiers: .command)
                .controlSize(.small)
                .disabled(!prompts.isDirty)
        }
        .padding(Theme.gutter)
    }

    private var conflictBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(Theme.accent)
            Text("This file changed on disk while you were editing.")
                .font(Theme.secondary)
                .foregroundStyle(Theme.ink)
            Spacer()
            Button("Reload") { prompts.reloadFromDisk() }
                .controlSize(.small)
            Button("Keep Mine") { prompts.overwriteDisk() }
                .controlSize(.small)
        }
        .padding(10)
        .background(Theme.accent.opacity(0.08), in: .rect(cornerRadius: Theme.radiusSmall))
        .padding(.horizontal, Theme.gutter)
        .padding(.bottom, 10)
    }

    private var saveStatus: String {
        if prompts.hasDiskConflict { return "Changed on disk — resolve below" }
        if let error = prompts.lastError { return error }
        if prompts.isDirty { return "Unsaved — autosaves shortly" }
        if let saved = prompts.lastSavedAt { return "Saved \(RelativeDateText.string(for: saved))" }
        return prompts.selectedFile?.exists == true ? "Saved" : "Not created yet — saving creates it"
    }
}
