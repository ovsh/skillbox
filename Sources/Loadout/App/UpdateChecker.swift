import AppKit
import Foundation

struct UpdateInfo: Sendable {
    let version: String
    let downloadURL: URL
    let releaseNotes: String
}

/// Checks GitHub Releases for a newer build and self-updates in place.
struct UpdateChecker: Sendable {
    static let repoOwner = "ovsh"
    // GitHub repo slug deliberately unchanged by the Loadout rebrand.
    static let repoName = "skillbox"
    static let zipAssetName = "Loadout-MacOS.zip"
    static let appBundleName = "Loadout.app"

    func checkForUpdate() async -> UpdateInfo? {
        let urlString = "https://api.github.com/repos/\(Self.repoOwner)/\(Self.repoName)/releases/latest"
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return nil
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tagName = json["tag_name"] as? String else {
            return nil
        }

        let remoteVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName

        guard let localVersion = currentAppVersion(),
              isNewerVersion(remote: remoteVersion, local: localVersion) else {
            return nil
        }

        guard let assets = json["assets"] as? [[String: Any]],
              let zipAsset = assets.first(where: { ($0["name"] as? String) == Self.zipAssetName }),
              let downloadURLString = zipAsset["browser_download_url"] as? String,
              let downloadURL = URL(string: downloadURLString) else {
            return nil
        }

        let releaseNotes = (json["body"] as? String) ?? ""
        return UpdateInfo(version: remoteVersion, downloadURL: downloadURL, releaseNotes: releaseNotes)
    }

    func downloadAndInstall(from url: URL) async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("loadout-update-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let (zipLocation, response) = try await URLSession.shared.download(for: URLRequest(url: url))
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw UpdateError.downloadFailed
        }

        let zipPath = tempDir.appendingPathComponent("update.zip")
        try FileManager.default.moveItem(at: zipLocation, to: zipPath)

        let unzipDir = tempDir.appendingPathComponent("unzipped")
        try FileManager.default.createDirectory(at: unzipDir, withIntermediateDirectories: true)

        let dittoProcess = Process()
        dittoProcess.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        dittoProcess.arguments = ["-x", "-k", zipPath.path, unzipDir.path]
        try dittoProcess.run()
        dittoProcess.waitUntilExit()
        guard dittoProcess.terminationStatus == 0 else {
            throw UpdateError.unzipFailed
        }

        let newAppPath = unzipDir.appendingPathComponent(Self.appBundleName)
        guard FileManager.default.fileExists(atPath: newAppPath.path) else {
            throw UpdateError.appNotFound
        }

        guard let currentAppPath = currentAppBundlePath() else {
            throw UpdateError.currentAppNotFound
        }
        let currentAppURL = URL(fileURLWithPath: currentAppPath)

        try FileManager.default.trashItem(at: currentAppURL, resultingItemURL: nil)
        try FileManager.default.moveItem(at: newAppPath, to: currentAppURL)

        let openProcess = Process()
        openProcess.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        openProcess.arguments = [currentAppURL.path]
        try openProcess.run()

        // Terminate this instance shortly after so the new one takes over.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApplication.shared.terminate(nil)
        }
    }

    // MARK: - Helpers

    func currentAppVersion() -> String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    private func currentAppBundlePath() -> String? {
        let path = Bundle.main.bundlePath
        guard path.hasSuffix(".app") else { return nil }
        return path
    }

    func isNewerVersion(remote: String, local: String) -> Bool {
        let remoteParts = remote.split(separator: ".").compactMap { Int($0) }
        let localParts = local.split(separator: ".").compactMap { Int($0) }

        let count = max(remoteParts.count, localParts.count)
        for i in 0..<count {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let l = i < localParts.count ? localParts[i] : 0
            if r > l { return true }
            if r < l { return false }
        }
        return false
    }
}

enum UpdateError: LocalizedError {
    case downloadFailed
    case unzipFailed
    case appNotFound
    case currentAppNotFound

    var errorDescription: String? {
        switch self {
        case .downloadFailed: return "Failed to download the update."
        case .unzipFailed: return "Failed to extract the update archive."
        case .appNotFound: return "Could not find Loadout.app in the update."
        case .currentAppNotFound: return "Could not determine the current app location."
        }
    }
}
