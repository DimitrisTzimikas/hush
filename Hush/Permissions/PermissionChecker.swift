import AppKit
import AVFoundation
import os

private let logger = Logger(subsystem: "com.hush.app", category: "Permissions")

enum PermissionChecker {

    static func checkAccessibility() -> Bool {
        let trusted = AXIsProcessTrusted()
        logger.info("Accessibility: \(trusted ? "granted" : "not granted")")
        return trusted
    }

    @MainActor
    static func promptAccessibility() {
        let alert = NSAlert()
        alert.messageText = "Hush needs Accessibility permission"
        alert.informativeText = """
            Hush uses a global hotkey to start and stop recording. \
            macOS requires Accessibility permission for apps that listen to keyboard events.

            Click "Open Settings", then add and enable Hush \
            under Privacy & Security → Accessibility.

            After granting permission, restart Hush.
            """
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    static func requestMicrophoneAccess() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            logger.info("Microphone: authorized")
            return true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            logger.info("Microphone: \(granted ? "granted" : "denied")")
            return granted
        case .denied, .restricted:
            logger.warning("Microphone: denied/restricted")
            await MainActor.run { promptMicrophone() }
            return false
        @unknown default:
            return false
        }
    }

    @MainActor
    private static func promptMicrophone() {
        let alert = NSAlert()
        alert.messageText = "Hush needs Microphone permission"
        alert.informativeText = "Go to System Settings → Privacy & Security → Microphone and enable Hush."
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
