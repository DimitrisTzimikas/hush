import AppKit

enum SingleInstanceGuard {
    static func ensureSingle() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        let others = running.filter { $0 != .current }
        others.forEach { $0.terminate() }
    }
}
