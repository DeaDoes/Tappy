import AppKit
import UserNotifications

/// Asks the public download repo what the newest release is and compares it
/// with this build.
///
/// It only ever tells you; it never replaces the app. Downloading a DMG and
/// swapping the running bundle is what Sparkle exists for, and doing it by hand
/// on an ad-hoc signed app would hand every user a silent way to install
/// something unverified. The button opens the release page instead.
@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    /// The newest released version, once a check has found one newer than this
    /// build. nil means "nothing to offer" — either up to date or not checked.
    @Published private(set) var availableVersion: String?
    @Published private(set) var isChecking = false
    /// Set after a check that found nothing, so the menu can say so.
    @Published private(set) var lastCheckFoundNothing = false
    @Published private(set) var state: State = .idle

    /// The DMG attached to that release. nil when a release has no build
    /// attached yet, in which case the UI falls back to the release page.
    private(set) var downloadURL: URL?

    /// The version we came from, set for one launch after an update installed.
    /// A 1.4 MB download takes well under a second, so the progress bar is a
    /// flash and the app then quits — without this, an update is indis­
    /// tinguishable from Tappy crashing and restarting.
    @Published private(set) var justUpdatedFrom: String?

    private static let updatedFromKey = "updatedFromVersion"

    enum State: Equatable {
        case idle
        /// nil while the server hasn't told us the total size.
        case downloading(Double?)
        case installing
        case failed(String)

        var isBusy: Bool {
            switch self {
            case .downloading, .installing: return true
            case .idle, .failed: return false
            }
        }
    }

    static let releasesPage = URL(string: "https://github.com/DeaDoes/tappy-downloads/releases/latest")!
    private static let api = URL(string: "https://api.github.com/repos/DeaDoes/tappy-downloads/releases/latest")!
    private static let interval: TimeInterval = 60 * 60 * 24

    private var timer: Timer?

    // Reads the bundle and compares numbers; no state, so it needs no actor.
    nonisolated static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }


    /// Checks now and once a day after that. Silent: a failed check never
    /// interrupts anyone, it just tries again tomorrow.
    /// True when this launch is the one straight after an update installed, so
    /// the app can show the window and say so.
    @discardableResult
    func consumeUpdateResult() -> Bool {
        let defaults = UserDefaults.standard
        guard let from = defaults.string(forKey: Self.updatedFromKey) else { return false }
        defaults.removeObject(forKey: Self.updatedFromKey)
        // Only if the swap actually landed; a failed install leaves the key
        // behind and must not claim success.
        guard Self.isVersion(Self.currentVersion, newerThan: from) else { return false }
        justUpdatedFrom = from
        return true
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: Self.interval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.check() }
        }
        // Not at the instant of launch: logging in shouldn't mean a network
        // call while everything else on the Mac is still starting up.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            await check()
        }
    }

    /// `userInitiated` skips the "already told them about this one" guard, so
    /// picking Check for Updates always gives an answer.
    func check(userInitiated: Bool = false) async {
        guard userInitiated || AppConfig.shared.automaticUpdateChecks else { return }
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        guard let release = await fetchLatestRelease() else { return }
        let tag = release.tagName
        let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        downloadURL = release.assets
            .first { $0.name.hasSuffix(".dmg") }
            .flatMap { URL(string: $0.browserDownloadURL) }

        guard Self.isVersion(latest, newerThan: Self.currentVersion) else {
            availableVersion = nil
            lastCheckFoundNothing = true
            return
        }

        lastCheckFoundNothing = false
        availableVersion = latest
        if !userInitiated { await notifyOnce(about: latest) }
    }

    private func fetchLatestRelease() async -> Release? {
        var request = URLRequest(url: Self.api)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        return try? JSONDecoder().decode(Release.self, from: data)
    }

    private struct Release: Decodable {
        let tagName: String
        let assets: [Asset]

        struct Asset: Decodable {
            let name: String
            let browserDownloadURL: String
            enum CodingKeys: String, CodingKey {
                case name, browserDownloadURL = "browser_download_url"
            }
        }

        enum CodingKeys: String, CodingKey { case tagName = "tag_name", assets }
    }

    // MARK: - Installing

    /// Downloads the release DMG, checks it, replaces this app and relaunches.
    /// Falls back to opening the release page when there is no DMG to fetch.
    func downloadAndInstall() async {
        guard !state.isBusy else { return }
        guard let url = downloadURL else {
            NSWorkspace.shared.open(Self.releasesPage)
            return
        }

        state = .downloading(0)
        do {
            let dmg = try await UpdateInstaller.download(url) { [weak self] fraction in
                self?.state = .downloading(fraction)
            }
            state = .installing
            // hdiutil, ditto and codesign are synchronous and take seconds.
            // Run on the main actor they freeze the window mid-draw, which
            // leaves the progress bar looking stuck at whatever it had painted.
            let staged = try await Task.detached(priority: .userInitiated) {
                try UpdateInstaller.stageApp(fromDMG: dmg)
            }.value
            try? FileManager.default.removeItem(at: dmg)
            // Written before the swap, read by the next launch. Everything that
            // could fail has already succeeded by this point.
            UserDefaults.standard.set(Self.currentVersion, forKey: Self.updatedFromKey)
            try UpdateInstaller.installAndRelaunch(staged: staged)
        } catch {
            // Nothing has been replaced at this point — every failure path
            // above throws before the running bundle is touched.
            state = .failed(error.localizedDescription)
        }
    }

    // MARK: - Notification

    /// One notification per new version, not one per check — a daily timer
    /// would otherwise nag every day until the user updated.
    private func notifyOnce(about version: String) async {
        let key = "lastNotifiedVersion"
        guard UserDefaults.standard.string(forKey: key) != version else { return }

        let center = UNUserNotificationCenter.current()
        // Asked here, the first time there is actually something to say, rather
        // than at launch for a notification that may never come.
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
        UserDefaults.standard.set(version, forKey: key)

        let content = UNMutableNotificationContent()
        content.title = "Tappy \(version) is available"
        content.body = "You're on \(Self.currentVersion). Open Tappy to download it."
        try? await center.add(UNNotificationRequest(identifier: "tappy.update.\(version)",
                                                    content: content, trigger: nil))
    }

    // MARK: - Version comparison

    /// Numeric, component by component, with missing components read as zero so
    /// "1.3" beats "1.2.9" and "1.3" and "1.3.0" are the same release.
    nonisolated static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let a = parts(of: candidate), b = parts(of: current)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    nonisolated private static func parts(of version: String) -> [Int] {
        version.split(separator: ".").map { Int($0.filter(\.isNumber)) ?? 0 }
    }
}
