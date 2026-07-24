import Foundation

public enum GitClientError: LocalizedError {
    case unsupportedRemote(String)
    case checkoutMissingGitDir(String)
    case cloneFailed(String)
    case gitFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedRemote(let remote):
            return "Only GitHub remotes (HTTPS or SSH) are supported. Invalid remote: \(remote)"
        case .checkoutMissingGitDir(let path):
            return "Checkout path exists but is not a git repo: \(path)"
        case .cloneFailed(let reason):
            return "Git clone failed: \(reason)"
        case .gitFailed(let reason):
            return "Git sync failed: \(reason)"
        }
    }
}

/// Clones or fast-forwards the registry repo into the local checkout.
public struct GitClient: Sendable {
    public static let fixedBranch = "main"

    private let runner = CommandRunner()

    public init() {}

    /// Ensures the checkout exists and is up to date. Returns the checkout URL.
    public func prepareCheckout(
        remote rawRemote: String,
        checkoutPath rawCheckoutPath: String,
        logger: Logger
    ) throws -> URL {
        let remote = rawRemote.trimmed
        guard Self.isGitHubRemote(remote) else {
            throw GitClientError.unsupportedRemote(remote)
        }

        let checkoutPath = rawCheckoutPath.trimmed.expandingTildePath
        let checkoutURL = URL(fileURLWithPath: checkoutPath)
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: checkoutURL.path) {
            let gitDir = checkoutURL.appendingPathComponent(".git")
            guard fileManager.fileExists(atPath: gitDir.path) else {
                throw GitClientError.checkoutMissingGitDir(checkoutURL.path)
            }

            logger(.info, "Fetching latest from \(remote) [branch: \(Self.fixedBranch)]")
            try runGit(["-C", checkoutURL.path, "fetch", "--prune", "origin"])
            try runGit(["-C", checkoutURL.path, "checkout", Self.fixedBranch])
            try runGit(["-C", checkoutURL.path, "pull", "--ff-only", "origin", Self.fixedBranch])
        } else {
            logger(.info, "Cloning registry from \(remote) [branch: \(Self.fixedBranch)]")
            try fileManager.createDirectory(
                at: checkoutURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            do {
                try runGit(["clone", "--branch", Self.fixedBranch, remote, checkoutURL.path])
            } catch let error as GitClientError {
                if case .gitFailed(let reason) = error {
                    throw GitClientError.cloneFailed(reason)
                }
                throw error
            }
        }

        return checkoutURL
    }

    /// HEAD commit hash of the checkout, or nil if unreadable.
    public func headCommit(checkout: URL) -> String? {
        guard let result = try? runner.run(
            command: "/usr/bin/env",
            arguments: ["git", "-C", checkout.path, "rev-parse", "HEAD"]
        ), result.exitCode == 0 else {
            return nil
        }
        let hash = result.stdout.trimmed
        return hash.isEmpty ? nil : hash
    }

    public static func isGitHubRemote(_ value: String) -> Bool {
        let lower = value.lowercased()
        return lower.hasPrefix("git@github.com:") ||
               lower.hasPrefix("ssh://git@github.com/") ||
               lower.hasPrefix("https://github.com/")
    }

    public static func isHTTPSRemote(_ value: String) -> Bool {
        value.lowercased().hasPrefix("https://")
    }

    private func runGit(_ args: [String]) throws {
        let result = try runner.run(command: "/usr/bin/env", arguments: ["git"] + args)
        guard result.exitCode == 0 else {
            let combined = (result.stderr.isEmpty ? result.stdout : result.stderr).trimmed
            throw GitClientError.gitFailed(Self.userFriendlyGitError(combined))
        }
    }

    /// Maps raw git stderr onto a short actionable message.
    static func userFriendlyGitError(_ raw: String) -> String {
        let lower = raw.lowercased()

        // HTTPS credential errors
        if lower.contains("could not read username") {
            return "Git credentials not configured. Click Sync again after setup completes."
        }
        if lower.contains("authentication failed") {
            return "GitHub auth expired or rejected. Run `gh auth login && gh auth setup-git` to re-authenticate."
        }
        if lower.contains("returned error: 403") || lower.contains("returned error: 401") {
            return "Access denied — GitHub rejected your credentials. Re-authenticate with `gh auth login && gh auth setup-git`."
        }

        // SSH errors
        if lower.contains("permission denied (publickey)") {
            return "GitHub SSH auth failed. Open Settings, run Setup Check, and ensure your SSH key has repo access."
        }
        if lower.contains("host key verification failed") {
            return "SSH host key verification failed. Run: ssh-keyscan github.com >> ~/.ssh/known_hosts"
        }
        if lower.contains("no such identity") || lower.contains("no identities") {
            return "No SSH key found. Add your key with: ssh-add ~/.ssh/<your-key>"
        }

        // Network errors
        if lower.contains("could not resolve hostname") {
            return "Cannot reach GitHub — check your internet connection."
        }
        if lower.contains("connection refused") {
            return "Connection refused by GitHub. Check your network or firewall settings."
        }
        if lower.contains("connection timed out") {
            return "Connection to GitHub timed out. Check your internet connection."
        }

        // Repo / branch errors
        if lower.contains("repository not found") {
            return "Repository not found or access denied. Verify your GitHub URL and org permissions."
        }
        if lower.contains("couldn't find remote ref") {
            return "Branch not found in repository. Check that the 'main' branch exists."
        }
        if lower.contains("not a git repository") {
            return "Local checkout is corrupt. Delete the checkout folder and sync again."
        }
        if lower.contains("unable to access") {
            return "Cannot access repository. Check your URL and credentials."
        }

        let detail = raw.count > 200 ? String(raw.prefix(200)) + "…" : raw
        return "Git error — open Settings and run Setup Check.\n\nDetail: \(detail)"
    }
}
