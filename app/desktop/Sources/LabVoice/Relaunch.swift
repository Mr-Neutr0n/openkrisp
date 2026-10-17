import Foundation
import AppKit

enum AppExitIntent { case quit, relaunch }
enum RelaunchOutcome: Equatable {
    case confirmed
    case failed(String)
    case uncertain(String)
}
struct RelaunchApplication {
    let pid: pid_t
    let bundleURL: URL?
    let executableURL: URL?
    let terminated: Bool
}
enum RelaunchAttempt {
    case application(RelaunchApplication)
    case failed(String)
    case uncertain(String)
}
// The opener is injectable. Tests never call NSWorkspace or launch another app.
// A returned app with mismatched/absent identity is uncertain, not rolled back.
@MainActor struct OwnAppRelauncher {
    let bundleURL: URL
    let executableURL: URL
    let currentPID: pid_t
    let existingPIDs: () -> Set<pid_t>
    let open: (URL, Bool) async -> RelaunchAttempt
    private func canonical(_ url: URL) -> URL { url.standardizedFileURL.resolvingSymlinksInPath() }
    func launch() async -> RelaunchOutcome {
        guard bundleURL.isFileURL, executableURL.isFileURL, bundleURL.pathExtension == "app",
              canonical(executableURL).path.hasPrefix(canonical(bundleURL).path + "/Contents/MacOS/") else {
            return .failed("The current application bundle is unavailable for relaunch.")
        }
        let previous = existingPIDs().union([currentPID])
        switch await open(bundleURL, true) {
        case .failed(let reason): return .failed(reason)
        case .uncertain(let reason): return .uncertain(reason)
        case .application(let application):
            guard application.pid > 1, !previous.contains(application.pid), !application.terminated,
                  let actualBundle = application.bundleURL,
                  canonical(actualBundle) == canonical(bundleURL) else {
                return .uncertain("The launch returned an application without confirmed new-instance identity.")
            }
            if let actualExecutable = application.executableURL, canonical(actualExecutable) != canonical(executableURL) {
                return .uncertain("The launched application reported a different executable.")
            }
            return .confirmed
        }
    }
    static func current() -> OwnAppRelauncher? {
        guard let executable = Bundle.main.executableURL else { return nil }
        return OwnAppRelauncher(bundleURL: Bundle.main.bundleURL, executableURL: executable, currentPID: getpid(),
            existingPIDs: { Set(NSWorkspace.shared.runningApplications.map(\.processIdentifier)) }, open: { url, fresh in
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.createsNewApplicationInstance = fresh
                configuration.allowsRunningApplicationSubstitution = false
                configuration.promptsUserIfNeeded = false
                // No resume arguments: the replacement never resumes audio or recording.
                configuration.arguments = []
                let result: (NSRunningApplication?, Error?) = await withCheckedContinuation { continuation in
                    NSWorkspace.shared.openApplication(at: url, configuration: configuration) { application, error in
                        continuation.resume(returning: (application, error))
                    }
                }
                guard let application = result.0 else {
                    if let error = result.1 { return .failed(error.localizedDescription) }
                    return .uncertain("Launch Services returned neither an application nor a launch error.")
                }
                if let error = result.1 {
                    return .uncertain("Launch Services returned an application and an error: " + error.localizedDescription)
                }
                // Bundle metadata may settle just after the launch callback. Do not
                // reject a real new app merely because executableURL is absent.
                for _ in 0..<20 where application.bundleURL == nil && !application.isTerminated {
                    try? await Task.sleep(nanoseconds: 25_000_000)
                }
                return .application(RelaunchApplication(pid: application.processIdentifier, bundleURL: application.bundleURL,
                    executableURL: application.executableURL, terminated: application.isTerminated))
            })
    }
}
