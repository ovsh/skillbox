import AppKit
import SkillboxKit
import SwiftUI

// MARK: - Wizard Button

private struct WizardButton: View {
    let label: String
    var style: Style = .primary
    let action: () -> Void
    @State private var isHovered = false

    enum Style { case primary, secondary }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(style == .primary ? Color.white : Color.primary)
                .padding(.horizontal, 28)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            style == .primary
                                ? AnyShapeStyle(LinearGradient(
                                    colors: [isHovered ? Brand.indigoDim : Brand.indigo, Brand.indigoDim],
                                    startPoint: .top, endPoint: .bottom
                                ))
                                : AnyShapeStyle(Color.primary.opacity(isHovered ? 0.1 : 0.06))
                        )
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Onboarding

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0

    private let stepNames = ["welcome", "github", "repo", "sync"]

    var body: some View {
        VStack(spacing: 0) {
            // Close affordance
            HStack {
                Spacer()
                Button {
                    Analytics.track(.onboardingSkipped)
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding([.top, .horizontal], 16)

            Spacer()

            Group {
                switch currentStep {
                case 0: WelcomeStep { advance() }
                case 1: GitHubConnectStep { advance() }
                case 2: ChooseRepoStep { advance() }
                default: FirstSyncStep()
                }
            }
            .frame(maxWidth: .infinity)

            Spacer()

            // Step dots
            HStack(spacing: 6) {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(index == currentStep ? Brand.indigo : Color.primary.opacity(0.15))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.bottom, 24)
        }
        .frame(width: 560, height: 520)
        .onAppear {
            Analytics.track(.onboardingStepViewed(step: 0, stepName: stepNames[0]))
        }
    }

    private func advance() {
        withAnimation(.easeOut(duration: 0.2)) {
            currentStep = min(currentStep + 1, 3)
        }
        Analytics.track(.onboardingStepViewed(step: currentStep, stepName: stepNames[currentStep]))
    }
}

// MARK: - Step 1: Welcome

private struct WelcomeStep: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            AppIconView(size: 64)
                .padding(.bottom, 24)

            Text("Welcome to Skillbox")
                .font(.system(size: 26, weight: .bold))
                .padding(.bottom, 8)

            Text("One place to manage the skills and rules\nyour AI coding tools run on — synced from GitHub,\ninstalled everywhere they belong.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.bottom, 32)

            WizardButton(label: "Get Started", action: onContinue)
        }
    }
}

// MARK: - Step 2: GitHub connect

private struct GitHubConnectStep: View {
    let onContinue: () -> Void
    @EnvironmentObject var appState: AppState

    private enum GHState: Equatable {
        case checking, needsInstall, waitingForInstall, needsAuth, waitingForAuth, connected
    }

    @State private var ghState: GHState = .checking
    @State private var username: String?
    @State private var pollTask: Task<Void, Never>?

    private let ghCLI = GitHubCLI()

    private var isWaiting: Bool {
        ghState == .waitingForInstall || ghState == .waitingForAuth || ghState == .checking
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(ghState == .connected ? Color.green : Brand.indigo.opacity(0.12))
                    .frame(width: 72, height: 72)
                if isWaiting {
                    ProgressView().controlSize(.regular)
                } else if ghState == .connected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "person.badge.key")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(Brand.indigo)
                }
            }
            .padding(.bottom, 24)

            Text(titleText)
                .font(.system(size: 24, weight: .bold))
                .padding(.bottom, 8)

            Text(subtitleText)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .frame(width: 380)
                .padding(.bottom, 28)

            switch ghState {
            case .checking, .waitingForInstall, .waitingForAuth:
                Text("Complete the steps in Terminal — this updates automatically.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .opacity(ghState == .checking ? 0 : 1)
            case .needsInstall:
                WizardButton(label: "Install GitHub CLI") {
                    Analytics.track(.onboardingGHInstallStarted)
                    appState.openTerminalWithCommand("brew install gh")
                    ghState = .waitingForInstall
                }
            case .needsAuth:
                WizardButton(label: "Sign in to GitHub") {
                    Analytics.track(.onboardingGHAuthStarted)
                    appState.openTerminalWithCommand("gh auth login --web -p https && gh auth setup-git")
                    ghState = .waitingForAuth
                }
            case .connected:
                WizardButton(label: "Continue", action: onContinue)
            }
        }
        .onAppear {
            checkStatus()
            startPolling()
        }
        .onDisappear {
            pollTask?.cancel()
        }
    }

    private var titleText: String {
        switch ghState {
        case .checking: return "Checking…"
        case .needsInstall: return "One Quick Install"
        case .waitingForInstall: return "Installing…"
        case .needsAuth: return "Sign in to GitHub"
        case .waitingForAuth: return "Waiting for Sign-in…"
        case .connected:
            if let username { return "Hi, @\(username)!" }
            return "GitHub Connected"
        }
    }

    private var subtitleText: String {
        switch ghState {
        case .checking:
            return "Looking for the GitHub CLI on your Mac."
        case .needsInstall:
            return "Skillbox uses the GitHub CLI to connect your registry.\nWe'll open Terminal with the install command ready."
        case .waitingForInstall:
            return "Follow the prompts in Terminal. This screen updates when the install finishes."
        case .needsAuth:
            return "A browser window will open — sign in and approve access."
        case .waitingForAuth:
            return "Finish signing in via your browser or Terminal."
        case .connected:
            return "Your GitHub account is ready to go."
        }
    }

    private func checkStatus() {
        let cli = ghCLI
        Task.detached(priority: .userInitiated) {
            let installed = cli.isInstalled()
            let authed = installed && cli.isAuthenticated()
            let user = authed ? cli.currentUser() : nil
            await MainActor.run {
                username = user
                switch (installed, authed) {
                case (false, _):
                    if ghState != .waitingForInstall { ghState = .needsInstall }
                case (true, false):
                    if ghState == .waitingForInstall {
                        Analytics.track(.onboardingGHInstallCompleted)
                    }
                    if ghState != .waitingForAuth { ghState = .needsAuth }
                case (true, true):
                    if ghState != .connected {
                        Analytics.track(.onboardingGHAuthCompleted(hasUsername: user != nil))
                    }
                    ghState = .connected
                }
            }
        }
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                if ghState == .connected { return }
                checkStatus()
            }
        }
    }
}

// MARK: - Step 3: Choose repo

private struct ChooseRepoStep: View {
    let onContinue: () -> Void
    @EnvironmentObject var appState: AppState

    @State private var showExisting = false
    @State private var repoName = "ai-config"
    @State private var existingURL = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var repoAlreadyExists = false

    @State private var selectedOwner = ""
    @State private var owners: [String] = []

    private let ghCLI = GitHubCLI()
    nonisolated static let templateRepo = "ovsh/skillbox-template"

    var body: some View {
        VStack(spacing: 0) {
            if showExisting {
                existingFlow
            } else {
                createFlow
            }
        }
        .onAppear(perform: loadOwners)
    }

    private var createFlow: some View {
        VStack(spacing: 0) {
            Image(systemName: "books.vertical")
                .font(.system(size: 32))
                .foregroundStyle(Brand.indigo)
                .padding(.bottom, 20)

            Text("Create Your Registry")
                .font(.system(size: 24, weight: .bold))
                .padding(.bottom, 8)

            Text("We'll set up a shared space on GitHub\nwith starter skills and rules for your team.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.bottom, 32)

            VStack(alignment: .leading, spacing: 6) {
                Text("Name")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .tracking(0.3)

                HStack(spacing: 8) {
                    if owners.count > 1 {
                        Picker("", selection: $selectedOwner) {
                            ForEach(owners, id: \.self) { org in
                                Text(org).tag(org)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 130)

                        Text("/")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }

                    TextField("ai-config", text: $repoName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                }
            }
            .padding(.horizontal, 80)
            .padding(.bottom, 24)

            if repoAlreadyExists {
                VStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 14))
                        Text("\(selectedOwner)/\(repoName.trimmed) already exists")
                            .font(.system(size: 13, weight: .medium))
                    }

                    WizardButton(label: "Use It") {
                        saveAndContinue(url: "https://github.com/\(selectedOwner)/\(repoName.trimmed).git")
                    }
                    .padding(.bottom, 4)

                    Button {
                        repoAlreadyExists = false
                        repoName = ""
                    } label: {
                        Text("Try a different name")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .frame(width: 340)
                        .padding(.bottom, 12)
                }

                WizardButton(label: isWorking ? "Setting up…" : "Continue") { createRepo() }
                    .disabled(isWorking || repoName.trimmed.isEmpty)
                    .opacity(isWorking || repoName.trimmed.isEmpty ? 0.5 : 1)
                    .padding(.bottom, 20)

                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showExisting = true
                        errorMessage = nil
                    }
                } label: {
                    Text("My team already set one up")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var existingFlow: some View {
        VStack(spacing: 0) {
            Image(systemName: "link")
                .font(.system(size: 32))
                .foregroundStyle(Brand.indigo)
                .padding(.bottom, 20)

            Text("Connect Your Team's Registry")
                .font(.system(size: 24, weight: .bold))
                .padding(.bottom, 8)

            Text("Paste the GitHub link your team shared with you.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 32)

            VStack(alignment: .leading, spacing: 6) {
                Text("GitHub link")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .tracking(0.3)

                TextField("https://github.com/your-team/ai-config", text: $existingURL)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
            }
            .padding(.horizontal, 80)
            .padding(.bottom, 24)

            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(width: 340)
                    .padding(.bottom, 12)
            }

            WizardButton(label: isWorking ? "Connecting…" : "Continue") { validateExisting() }
                .disabled(isWorking || existingURL.trimmed.isEmpty)
                .opacity(isWorking || existingURL.trimmed.isEmpty ? 0.5 : 1)
                .padding(.bottom, 20)

            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    showExisting = false
                    errorMessage = nil
                }
            } label: {
                Text("Start fresh instead")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Actions

    private func loadOwners() {
        let cli = ghCLI
        Task.detached(priority: .userInitiated) {
            let user = cli.currentUser() ?? ""
            let orgs = cli.userOrgs()
            await MainActor.run {
                var all = [String]()
                if !user.isEmpty { all.append(user) }
                all.append(contentsOf: orgs.filter { $0 != user })
                owners = all
                if selectedOwner.isEmpty { selectedOwner = all.first ?? "" }
            }
        }
    }

    private func createRepo() {
        isWorking = true
        errorMessage = nil
        repoAlreadyExists = false
        let owner = selectedOwner
        let name = repoName.trimmed
        let cli = ghCLI

        Task.detached(priority: .userInitiated) {
            do {
                let url = try cli.createRepoFromTemplate(
                    owner: owner, name: name,
                    template: Self.templateRepo,
                    isPrivate: true
                )
                await MainActor.run {
                    isWorking = false
                    Analytics.track(.onboardingRepoCreated)
                    saveAndContinue(url: url)
                }
            } catch {
                let message = error.localizedDescription
                await MainActor.run {
                    isWorking = false
                    if message.contains("already exists") {
                        repoAlreadyExists = true
                    } else {
                        errorMessage = message
                    }
                }
            }
        }
    }

    private func validateExisting() {
        isWorking = true
        errorMessage = nil
        let url = existingURL.trimmed

        Task.detached(priority: .userInitiated) {
            let result = SetupChecker().run(remoteGitURL: url)
            await MainActor.run {
                isWorking = false
                if result.passed {
                    Analytics.track(.onboardingRepoConnected)
                    saveAndContinue(url: url)
                } else {
                    errorMessage = result.lines.last ?? "Couldn't connect. Check the link and try again."
                }
            }
        }
    }

    private func saveAndContinue(url: String) {
        var settings = appState.settings
        settings.remoteGitURL = url
        appState.applySettings(settings, runSetupCheckIfNeeded: false)
        onContinue()
    }
}

// MARK: - Step 4: First sync

@MainActor
private struct FirstSyncStep: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var didSync = false

    private var succeeded: Bool { appState.syncStatus == .succeeded && didSync }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(succeeded ? Color.green : Brand.indigo.opacity(0.1))
                    .frame(width: 80, height: 80)

                if appState.isSyncing {
                    ProgressView().controlSize(.regular)
                } else if succeeded {
                    Image(systemName: "checkmark")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(Brand.indigo)
                }
            }
            .padding(.bottom, 24)

            Text(succeeded ? "You're all set!" : appState.isSyncing ? "Syncing…" : "Ready to Sync")
                .font(.system(size: 24, weight: .bold))
                .padding(.bottom, 8)

            Text(subtitleText)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .frame(width: 360)
                .padding(.bottom, 20)

            if !succeeded {
                destinationsList
                    .padding(.bottom, 24)
            }

            if appState.syncStatus == .failed && didSync {
                if let error = appState.lastErrorMessage {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .frame(width: 340)
                        .padding(.bottom, 16)
                }

                WizardButton(label: "Try Again") {
                    appState.syncNow(trigger: "onboarding")
                }
            } else if succeeded {
                WizardButton(label: "Done", action: finish)
            } else if !appState.isSyncing {
                VStack(spacing: 12) {
                    WizardButton(label: "Sync Now") {
                        didSync = true
                        appState.syncNow(trigger: "onboarding")
                    }

                    Button {
                        Analytics.track(.onboardingSkipped)
                        finish()
                    } label: {
                        Text("I'll do this later")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var destinationsList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Installs to")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(0.5)

            ForEach(destinations, id: \.self) { path in
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Text(path)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: 300, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(Color.primary.opacity(0.03))
        )
    }

    private var destinations: [String] {
        appState.enabledTargets.map { target in
            let hasSkills = target.skillsPath != nil
            let hasRules = target.rulesPath != nil
            let suffix = hasSkills && hasRules ? "skills & rules" : hasSkills ? "skills" : "rules"
            let prefix = (target.skillsPath ?? target.rulesPath ?? "")
                .components(separatedBy: "/skills").first!
                .components(separatedBy: "/rules").first!
            return "~/\(prefix) — \(suffix)"
        }
    }

    private var subtitleText: String {
        if succeeded {
            return "Your AI tools are configured and syncing. Skillbox keeps everything up to date."
        }
        if appState.isSyncing {
            return "Installing your skills and rules…"
        }
        if appState.syncStatus == .failed && didSync {
            return "Something went wrong, but you can try again."
        }
        return "Skillbox will pull your registry and install its skills for Claude Code, Cursor, Codex, and more."
    }

    private func finish() {
        appState.completeOnboarding()
        dismiss()
    }
}
