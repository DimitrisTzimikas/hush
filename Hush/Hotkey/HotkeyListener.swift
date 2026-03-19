import CoreGraphics
import Foundation
import os

private let logger = Logger(subsystem: "com.hush.app", category: "HotkeyListener")

private let maxRecordingSeconds: Double = 120

final class HotkeyListener {
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?

    private var modifierMask: CGEventFlags = .maskControl
    private var keyCode: CGKeyCode = 49
    private var modifierNames: [String] = ["ctrl"]

    private var isActive = false
    private var activeSince: CFAbsoluteTime = 0
    private var tap: CFMachPort?

    func configure(modifiers: [String], key: String) {
        modifierMask = CGEventFlags()
        modifierNames = modifiers
        for mod in modifiers {
            if let flag = KeyCodes.modifierFlags[mod] {
                modifierMask.insert(flag)
            }
        }
        keyCode = KeyCodes.keyCodes[key] ?? 49
        logger.info("Hotkey configured: \(KeyCodes.displayString(modifiers: modifiers, key: key))")
    }

    func start() {
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)

        let unmanagedSelf = Unmanaged.passUnretained(self)

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo -> Unmanaged<CGEvent>? in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let listener = Unmanaged<HotkeyListener>.fromOpaque(userInfo).takeUnretainedValue()
                listener.handleEvent(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: unmanagedSelf.toOpaque()
        ) else {
            NSLog("[Hush] FAILED to create event tap — Accessibility not granted for this app!")
            logger.error("Failed to create event tap — check Accessibility permissions")
            return
        }

        self.tap = eventTap
        let source = CFMachPortCreateRunLoopSource(nil, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        NSLog("[Hush] Event tap created and started successfully")
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
    }

    private func checkModifiers(_ flags: CGEventFlags) -> Bool {
        for mod in modifierNames {
            guard let flag = KeyCodes.modifierFlags[mod] else { return false }
            if !flags.contains(flag) { return false }
        }
        return true
    }

    private func release(reason: String) {
        guard isActive else { return }
        logger.info("Hotkey released (\(reason))")
        isActive = false
        activeSince = 0
        onRelease?()
    }

    private func handleEvent(type: CGEventType, event: CGEvent) {
        let kc = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        if isActive && (CFAbsoluteTimeGetCurrent() - activeSince) > maxRecordingSeconds {
            release(reason: "timeout")
            return
        }

        let modsHeld = checkModifiers(flags)

        if kc == keyCode && type == .keyDown && modsHeld {
            if !isActive {
                logger.info("Hotkey pressed")
                isActive = true
                activeSince = CFAbsoluteTimeGetCurrent()
                onPress?()
            }
        } else if isActive {
            if kc == keyCode && type == .keyUp {
                release(reason: "key up")
            } else if type == .flagsChanged && !modsHeld {
                release(reason: "modifier released")
            }
        }
    }
}
