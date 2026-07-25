import Foundation

public struct SetupCheckResult: Sendable {
    public let passed: Bool
    public let lines: [String]
    public let checkedAt: Date
}

/// Diagnoses whether git/SSH/credentials are set up to reach the registry repo.
public struct SetupChecker: Sendable {
    private let runner = CommandRunner()

    public init() {}

    public func run(remoteGitURL: String) -> SetupCheckResult {
        var lines: [String] = []
        var passed = true
        let remote = remoteGitURL.trimmed
        let isHTTPS = GitClient.isHTTPSRemote(remote)

        if remote.isEmpty {
            lines.append("Set your GitHub repo URL in Settings.")
            passed = false
        } else if !GitClient.isGitHubRemote(remote) {
            lines.append("Remote must be a GitHub URL (HTTPS or SSH).")
            passed = false
        } else {
            lines.append("Remote format looks valid (\(isHTTPS ? "HTTPS" : "SSH")).")
        }

        // HTTPS credential info (diagnostic only — git ls-remote below is the real pass/fail)
        if isHTTPS {
            do {
                let credHelper = try runner.run(
                    command: "/usr/bin/env",
                    arguments: ["git", "config", "--global", "credential.helper"]
                )
                let helper = credHelper.stdout.trimmed
                if credHelper.exitCode == 0 && !helper.isEmpty {
                    lines.append("Git credential helper: \(helper)")
                } else {
                    lines.append("No explicit credential helper (macOS Keychain may provide credentials).")
                }
            } catch {
                lines.append("Could not check credential helper configuration.")
            }
        } else {
            do {
                let keys = try runner.run(command: "/usr/bin/env", arguments: ["ssh-add", "-l"])
                let stdout = keys.stdout.lowercased()
                let stderr = keys.stderr.lowercased()
                if keys.exitCode == 0 && !stdout.contains("no identities") && !stderr.contains("no identities") {
                    lines.append("SSH agent has at least one loaded key.")
                } else {
                    passed = false
                    lines.append("No keys loaded in ssh-agent. Run: ssh-add ~/.ssh/<your-key>")
                }
            } catch {
                passed = false
                lines.append("Could not run ssh-add. Ensure OpenSSH tools are installed.")
            }

            do {
                let ssh = try runner.run(
                    command: "/usr/bin/env",
                    arguments: ["ssh", "-T", "-o", "BatchMode=yes", "git@github.com"]
                )
                let combined = (ssh.stdout + "\n" + ssh.stderr).lowercased()
                if combined.contains("successfully authenticated") {
                    lines.append("GitHub SSH authentication works.")
                } else {
                    passed = false
                    if combined.contains("permission denied") {
                        lines.append("GitHub rejected your SSH key. Add the key to your GitHub account/org.")
                    } else {
                        lines.append("Could not verify GitHub SSH auth. Run: ssh -T git@github.com")
                    }
                }
            } catch {
                passed = false
                lines.append("Could not run ssh auth check against github.com.")
            }
        }

        if !remote.isEmpty && GitClient.isGitHubRemote(remote) {
            do {
                var env: [String: String] = [:]
                if !isHTTPS {
                    env["GIT_SSH_COMMAND"] = "ssh -o BatchMode=yes"
                }
                let ls = try runner.run(
                    command: "/usr/bin/env",
                    arguments: ["git", "ls-remote", remote, "main"],
                    extraEnvironment: env
                )
                if ls.exitCode == 0 {
                    lines.append("Repository access OK for main branch.")
                } else {
                    passed = false
                    let combined = (ls.stderr + "\n" + ls.stdout).lowercased()
                    if combined.contains("repository not found") {
                        lines.append("Repo not found or you do not have access.")
                    } else if combined.contains("permission denied") || combined.contains("authentication failed") {
                        lines.append("Authentication failed. Check your credentials.")
                    } else {
                        lines.append("Could not read repo main branch. Check URL and permissions.")
                    }
                }
            } catch {
                passed = false
                lines.append("Could not run git ls-remote check.")
            }
        }

        return SetupCheckResult(passed: passed, lines: lines, checkedAt: Date())
    }

    /// Probes the remote with `git ls-remote` and classifies auth failures.
    /// Returns nil when auth is fine (or the failure isn't auth-related).
    public func authProbeFailure(remote: String) -> String? {
        var env: [String: String] = [:]
        if !GitClient.isHTTPSRemote(remote) {
            env["GIT_SSH_COMMAND"] = "ssh -o BatchMode=yes"
        }

        guard let result = try? runner.run(
            command: "/usr/bin/env",
            arguments: ["git", "ls-remote", remote, "HEAD"],
            extraEnvironment: env
        ) else {
            return nil
        }
        guard result.exitCode != 0 else { return nil }

        let combined = (result.stderr + "\n" + result.stdout).lowercased()
        let isAuthError = combined.contains("could not read username")
            || combined.contains("authentication failed")
            || combined.contains("permission denied")
            || combined.contains("returned error: 401")
            || combined.contains("returned error: 403")
            || combined.contains("no such identity")
            || combined.contains("no identities")

        return isAuthError ? combined : nil
    }
}
