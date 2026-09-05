import AppKit

/// Downloads a released DMG and swaps the running app for the one inside it.
///
/// The replace itself can't happen in-process — a running bundle can't
/// overwrite itself — so the last step hands a tiny script to `/bin/sh`, which
/// waits for Tappy to quit, copies the new bundle over the old one and opens it.
enum UpdateInstaller {
    enum Failure: LocalizedError {
        case download, mount, noAppInDMG, notTappy, unsignedOrDamaged, install(String)

        var errorDescription: String? {
            switch self {
            case .download:          return "The download didn't finish."
            case .mount:             return "The downloaded disk image couldn't be opened."
            case .noAppInDMG:        return "The disk image didn't contain Tappy."
            case .notTappy:          return "The download wasn't a copy of Tappy."
            case .unsignedOrDamaged: return "The download failed its signature check, so it wasn't installed."
            case .install(let why):  return "Installing failed: \(why)"
            }
        }
    }

    /// Downloads to a temporary file, reporting 0...1 as it goes, or nil while
    /// the total size is unknown so the UI can show an indeterminate bar.
    ///
    /// A download task, not `URLSession.bytes`: that sequence yields one byte
    /// at a time, which for a multi-megabyte disk image is millions of async
    /// resumptions and reads on screen as a frozen progress bar.
    static func download(_ url: URL, progress: @escaping (Double?) -> Void) async throws -> URL {
        let delegate = DownloadDelegate(onProgress: progress)
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        return try await withCheckedThrowingContinuation { continuation in
            delegate.continuation = continuation
            session.downloadTask(with: url).resume()
        }
    }

    /// Reports progress and hands back a file that outlives the callback —
    /// URLSession deletes its own temporary file the moment the delegate
    /// returns, so the move has to happen inside the callback.
    private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
        private let onProgress: (Double?) -> Void
        var continuation: CheckedContinuation<URL, Error>?
        private var hasResumed = false

        init(onProgress: @escaping (Double?) -> Void) {
            self.onProgress = onProgress
        }

        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                        didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                        totalBytesExpectedToWrite totalBytesExpected: Int64) {
            // -1 when the server sends no Content-Length, which GitHub's asset
            // redirect sometimes doesn't. nil then, rather than a bar at zero.
            let fraction = totalBytesExpected > 0
                ? Double(totalBytesWritten) / Double(totalBytesExpected)
                : nil
            let report = onProgress
            DispatchQueue.main.async { report(fraction) }
        }

        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                        didFinishDownloadingTo location: URL) {
            guard (downloadTask.response as? HTTPURLResponse)?.statusCode == 200 else {
                return finish(.failure(Failure.download))
            }
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("Tappy-update-\(UUID().uuidString).dmg")
            do {
                try FileManager.default.moveItem(at: location, to: destination)
                finish(.success(destination))
            } catch {
                finish(.failure(Failure.download))
            }
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            if error != nil { finish(.failure(Failure.download)) }
        }

        // Both callbacks can fire for one task; the continuation takes one result.
        private func finish(_ result: Result<URL, Error>) {
            guard !hasResumed else { return }
            hasResumed = true
            continuation?.resume(with: result)
            continuation = nil
        }
    }

    /// Mounts the image, checks what's inside really is Tappy, and stages it.
    /// Returns the staged bundle, still outside /Applications.
    static func stageApp(fromDMG dmg: URL) throws -> URL {
        let mount = FileManager.default.temporaryDirectory
            .appendingPathComponent("tappy-update-\(UUID().uuidString)")

        guard run("/usr/bin/hdiutil",
                  ["attach", dmg.path, "-nobrowse", "-noautoopen", "-mountpoint", mount.path]).ok
        else { throw Failure.mount }
        defer { _ = run("/usr/bin/hdiutil", ["detach", mount.path, "-quiet"]) }

        let source = mount.appendingPathComponent("Tappy.app")
        guard FileManager.default.fileExists(atPath: source.path) else { throw Failure.noAppInDMG }

        // It has to actually be Tappy, or a wrong or tampered image could point
        // the replace step at something else entirely.
        guard let bundle = Bundle(url: source),
              bundle.bundleIdentifier == Bundle.main.bundleIdentifier
        else { throw Failure.notTappy }

        // Self-consistency only: with an ad-hoc signature there is no identity
        // to match against, so this catches a corrupt or truncated download,
        // not a substituted one. A Developer ID build would compare identities.
        guard run("/usr/bin/codesign", ["--verify", "--deep", source.path]).ok else {
            throw Failure.unsignedOrDamaged
        }

        let staged = FileManager.default.temporaryDirectory
            .appendingPathComponent("tappy-staged-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: staged, withIntermediateDirectories: true)
        let stagedApp = staged.appendingPathComponent("Tappy.app")
        guard run("/usr/bin/ditto", [source.path, stagedApp.path]).ok else {
            throw Failure.install("couldn't copy the new version out of the disk image")
        }
        return stagedApp
    }

    /// Replaces the running bundle with the staged one and relaunches. Does not
    /// return — the app is terminated so the script can overwrite it.
    static func installAndRelaunch(staged: URL) throws -> Never {
        let destination = Bundle.main.bundleURL
        let script = FileManager.default.temporaryDirectory
            .appendingPathComponent("tappy-update-\(UUID().uuidString).sh")

        // Waits for this process to exit before touching the bundle, or ditto
        // would be copying over a binary that is still mapped and running.
        let body = """
        #!/bin/sh
        while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.2; done
        rm -rf "\(destination.path)"
        /usr/bin/ditto "\(staged.path)" "\(destination.path)"
        # The download carries a quarantine flag; without clearing it the app
        # the user just chose to install is blocked on first launch.
        /usr/bin/xattr -dr com.apple.quarantine "\(destination.path)" 2>/dev/null
        rm -rf "\(staged.deletingLastPathComponent().path)"
        /usr/bin/open "\(destination.path)"
        rm -f "$0"
        """
        try body.write(to: script, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [script.path]
        do { try process.run() } catch {
            // Nothing was replaced yet, so failing here is safe to report.
            fatalErrorReporting(error)
        }
        NSApp.terminate(nil)
        // terminate() is asynchronous; this keeps the compiler happy and the
        // process alive until AppKit finishes tearing down.
        while true { RunLoop.current.run(until: .distantFuture) }
    }

    private static func fatalErrorReporting(_ error: Error) -> Never {
        let alert = NSAlert()
        alert.messageText = "Tappy couldn't start the installer"
        alert.informativeText = error.localizedDescription
        alert.runModal()
        exit(1)
    }

    @discardableResult
    private static func run(_ path: String, _ arguments: [String]) -> (ok: Bool, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do { try process.run() } catch { return (false, "\(error)") }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus == 0, String(data: data, encoding: .utf8) ?? "")
    }
}
