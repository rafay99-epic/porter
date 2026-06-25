import Foundation
import AppKit
import Observation
import PorterCore

/// Channel-aware GitHub-release updater.
///   • Stable  → newest full release; compares the numeric version `0.<n>`.
///   • Nightly → newest pre-release; compares the monotonic build number parsed
///     from the release title ("… build <n>").
///   • Dev     → disabled (`Channel.updatesEnabled == false`).
///
/// Checks the public Releases API (no auth). On install it downloads the channel's
/// DMG, mounts it, replaces the running bundle in place, and relaunches — falling
/// back to simply opening the DMG in Finder if an in-place replace isn't possible
/// (e.g. the app lives somewhere it can't write).
@MainActor
@Observable
final class Updater {
    /// `owner/repo` the releases are published to. Must match the GitHub repo.
    static let repoSlug = "rafay99-epic/porter"

    struct Available: Equatable {
        let version: String
        let title: String
        let dmgURL: URL
        let buildNumber: Int?
    }

    private(set) var available: Available?
    private(set) var isChecking = false
    private(set) var isInstalling = false
    private(set) var statusMessage: String?

    private let settings: PorterSettings
    private let log = AppInfo.logger("updater")

    init(settings: PorterSettings) {
        self.settings = settings
    }

    // MARK: - Version of the running app

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
    }

    static var currentBuildNumber: Int {
        Int(Bundle.main.infoDictionary?["PorterBuildNumber"] as? String ?? "") ?? 0
    }

    var isBusy: Bool { isChecking || isInstalling }

    // MARK: - Check

    func checkOnLaunch() {
        guard Channel.current.updatesEnabled, settings.autoCheckUpdates else { return }
        Task { await check() }
    }

    func check(userInitiated: Bool = false) async {
        guard Channel.current.updatesEnabled else {
            if userInitiated { statusMessage = "Updates are disabled for the Dev build." }
            return
        }
        guard !isBusy else { return }
        isChecking = true
        statusMessage = "Checking for updates…"
        defer { isChecking = false }

        do {
            let releases = try await fetchReleases()
            guard let best = pickBest(from: releases) else {
                statusMessage = userInitiated ? "You're on the latest version." : nil
                return
            }
            if isNewer(best) {
                available = best
                statusMessage = "Update available: \(best.version)"
                log.info("update available: \(best.version) (build \(best.buildNumber ?? -1))")
            } else {
                available = nil
                statusMessage = userInitiated ? "You're on the latest version." : nil
            }
        } catch {
            statusMessage = "Update check failed: \(error.localizedDescription)"
            log.error("update check failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Install

    func installAvailable() {
        guard let release = available else { return }
        Task { await install(release) }
    }

    private func install(_ release: Available) async {
        guard !isInstalling else { return }
        isInstalling = true
        statusMessage = "Downloading \(release.version)…"
        defer { isInstalling = false }

        do {
            // Download the asset via its API URL with octet-stream + auth, so this
            // works for the private repo (and public too).
            var request = URLRequest(url: release.dmgURL)
            request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
            if let token = await Self.githubToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            let (downloaded, _) = try await URLSession.shared.download(for: request)
            // Give it a .dmg extension so hdiutil is happy.
            let dmg = downloaded.deletingPathExtension().appendingPathExtension("dmg")
            try? FileManager.default.removeItem(at: dmg)
            try FileManager.default.moveItem(at: downloaded, to: dmg)

            statusMessage = "Installing…"
            if try replaceInPlace(fromDMG: dmg) {
                log.info("update installed: \(release.version) — relaunching")
                relaunch()
            } else {
                // Couldn't replace automatically — hand the DMG to the user.
                NSWorkspace.shared.open(dmg)
                statusMessage = "Opened the installer — drag Porter to Applications."
            }
        } catch {
            statusMessage = "Update failed: \(error.localizedDescription)"
            log.error("update install failed: \(error.localizedDescription)")
        }
    }

    // MARK: - GitHub API

    private func fetchReleases() async throws -> [GHRelease] {
        let url = URL(string: "https://api.github.com/repos/\(Self.repoSlug)/releases")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        if let token = await Self.githubToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([GHRelease].self, from: data)
    }

    /// A GitHub token from the `gh` CLI (`gh auth token`), used to reach the private
    /// repo's releases. Returns nil if `gh` isn't installed/authed — in which case
    /// the update check simply can't see the private releases (surfaced as a status
    /// message), mirroring how Crisp authenticates its updater.
    private static func githubToken() async -> String? {
        await Task.detached {
            let candidates = ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"]
            guard let gh = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
                return nil
            }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: gh)
            process.arguments = ["auth", "token"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            do { try process.run() } catch { return nil }
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let token = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (token?.isEmpty == false) ? token : nil
        }.value
    }

    /// The newest release matching this channel that ships the channel's DMG.
    private func pickBest(from releases: [GHRelease]) -> Available? {
        let wantPrerelease = Channel.current.isPrerelease
        let assetName = Channel.current.assetName
        for release in releases where release.prerelease == wantPrerelease {
            guard let asset = release.assets.first(where: { $0.name == assetName }) else { continue }
            let title = release.name ?? release.tagName ?? ""
            return Available(
                version: (release.tagName ?? title).replacingOccurrences(of: "v", with: ""),
                title: title,
                dmgURL: asset.url,
                buildNumber: Self.parseBuild(from: title))
        }
        return nil
    }

    private func isNewer(_ candidate: Available) -> Bool {
        if Channel.current.isPrerelease {
            guard let candidateBuild = candidate.buildNumber else { return false }
            return candidateBuild > Self.currentBuildNumber
        }
        return Self.compareNumeric(candidate.version, Self.currentVersion) > 0
    }

    // MARK: - Parsing helpers

    static func parseBuild(from title: String) -> Int? {
        guard let range = title.range(of: #"build\s+(\d+)"#, options: .regularExpression) else { return nil }
        return Int(title[range].filter(\.isNumber))
    }

    /// Compare `0.<n>`-style versions component-wise. Returns >0 if `a` is newer.
    static func compareNumeric(_ a: String, _ b: String) -> Int {
        func parts(_ s: String) -> [Int] {
            s.split(separator: "-").first.map(String.init)?
                .split(separator: ".").map { Int($0) ?? 0 } ?? []
        }
        let pa = parts(a), pb = parts(b)
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x > y ? 1 : -1 }
        }
        return 0
    }

    // MARK: - DMG install

    /// Mount the DMG, copy the contained `.app` over the running bundle, detach.
    /// Returns false (rather than throwing) when the destination isn't writable, so
    /// the caller can fall back to opening the DMG.
    private func replaceInPlace(fromDMG dmg: URL) throws -> Bool {
        let mountPoint = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("porter-update-\(UUID().uuidString)")
        try run("/usr/bin/hdiutil", ["attach", dmg.path, "-nobrowse", "-mountpoint", mountPoint.path])
        defer { _ = try? run("/usr/bin/hdiutil", ["detach", mountPoint.path, "-force"]) }

        let appName = "\(Channel.current.displayName).app"
        let newApp = mountPoint.appendingPathComponent(appName)
        guard FileManager.default.fileExists(atPath: newApp.path) else {
            log.error("DMG didn't contain \(appName)")
            return false
        }

        let dest = Bundle.main.bundleURL
        guard FileManager.default.isWritableFile(atPath: dest.deletingLastPathComponent().path) else {
            return false
        }
        let backup = dest.appendingPathExtension("old")
        try? FileManager.default.removeItem(at: backup)
        try? FileManager.default.moveItem(at: dest, to: backup)
        do {
            try run("/usr/bin/ditto", [newApp.path, dest.path])
            try? FileManager.default.removeItem(at: backup)
            return true
        } catch {
            // Roll back to the backup so we don't leave the user with no app.
            try? FileManager.default.removeItem(at: dest)
            try? FileManager.default.moveItem(at: backup, to: dest)
            throw error
        }
    }

    private func relaunch() {
        let path = Bundle.main.bundleURL.path
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", path]
        try? task.run()
        NSApp.terminate(nil)
    }

    @discardableResult
    private func run(_ launchPath: String, _ args: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "Updater", code: Int(process.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: "\(launchPath) failed: \(output)"])
        }
        return output
    }
}

// GitHub Releases API DTOs — file-scoped so their CodingKeys aren't nested too deep.
private struct GHRelease: Decodable {
    let name: String?
    let tagName: String?
    let prerelease: Bool
    let assets: [GHAsset]
    enum CodingKeys: String, CodingKey { case name, prerelease, assets, tagName = "tag_name" }
}

private struct GHAsset: Decodable {
    let name: String
    /// The API asset URL (`…/releases/assets/<id>`). For a *private* repo this is
    /// what you download from, with `Accept: application/octet-stream` + an auth
    /// header — `browser_download_url` won't work unauthenticated. It works for
    /// public repos too, so we always use it.
    let url: URL
}
