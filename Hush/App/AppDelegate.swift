import AppKit
import os

private let logger = Logger(subsystem: "com.hush.app", category: "AppDelegate")

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var statusMenuItem: NSMenuItem!
    private var shortcutMenuItem: NSMenuItem!

    private let recorder = AudioRecorder()
    private let transcriptionService = TranscriptionService()
    private let hotkeyListener = HotkeyListener()
    private let settings = SettingsManager.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        SingleInstanceGuard.ensureSingle()
        setupMenuBar()

        Task { @MainActor in
            await checkPermissionsAndStart()
        }
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "Hush")
        }

        let menu = NSMenu()

        statusMenuItem = NSMenuItem(title: "Status: Starting...", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(.separator())

        shortcutMenuItem = NSMenuItem(
            title: "Shortcut: \(settings.hotkeyDisplayString)",
            action: nil, keyEquivalent: ""
        )
        shortcutMenuItem.isEnabled = false
        menu.addItem(shortcutMenuItem)

        menu.addItem(NSMenuItem(title: "Change Shortcut...", action: #selector(changeShortcut), keyEquivalent: ""))

        let langMenu = NSMenu()
        let langItem = NSMenuItem(title: "Language", action: nil, keyEquivalent: "")
        for (name, code) in [("Auto-detect", "auto"), ("English", "en"), ("Greek", "el")] {
            let item = NSMenuItem(title: name, action: #selector(setLanguage(_:)), keyEquivalent: "")
            item.representedObject = code
            item.target = self
            if settings.language == code {
                item.state = .on
            }
            langMenu.addItem(item)
        }
        langItem.submenu = langMenu
        menu.addItem(langItem)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Quit Hush", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    // MARK: - Permissions & Startup

    @MainActor
    private func checkPermissionsAndStart() async {
        if !PermissionChecker.checkAccessibility() {
            setStatus("Needs Accessibility")
            PermissionChecker.promptAccessibility()
            return
        }

        guard await PermissionChecker.requestMicrophoneAccess() else {
            setStatus("Needs Microphone")
            return
        }

        logger.info("Starting hotkey listener...")
        hotkeyListener.onPress = { [weak self] in self?.hotkeyPressed() }
        hotkeyListener.onRelease = { [weak self] in self?.hotkeyReleased() }
        hotkeyListener.configure(
            modifiers: settings.hotkeyModifiers,
            key: settings.hotkeyKey
        )
        hotkeyListener.start()

        setStatus("Loading model...")

        Task.detached { [weak self] in
            guard let self else { return }
            await self.transcriptionService.loadModel()
            await MainActor.run {
                self.setStatus("Ready")
                logger.info("Hush is ready")
            }
        }
    }

    // MARK: - Hotkey Callbacks

    private func hotkeyPressed() {
        logger.info("Hotkey pressed — recording")
        setStatus("Recording...")
        setIcon("record.circle.fill")
        recorder.start()
    }

    private func hotkeyReleased() {
        logger.info("Hotkey released — transcribing")
        setStatus("Transcribing...")
        setIcon("ellipsis.circle")
        let audio = recorder.stop()
        logger.info("Captured \(audio.count) samples (\(String(format: "%.1f", Float(audio.count) / 16000))s)")

        Task.detached { [weak self] in
            guard let self else { return }
            let lang = self.settings.language == "auto" ? nil : self.settings.language
            let text = await self.transcriptionService.transcribe(audio: audio, language: lang)
            await MainActor.run {
                if !text.isEmpty {
                    logger.info("Transcription: '\(text)'")
                    TextInjector.paste(text)
                }
                self.setStatus("Ready")
                self.setIcon("mic")
            }
        }
    }

    // MARK: - Menu Actions

    @objc private func setLanguage(_ sender: NSMenuItem) {
        guard let code = sender.representedObject as? String else { return }
        settings.language = code
        if let langItem = statusItem.menu?.item(withTitle: "Language"),
           let submenu = langItem.submenu {
            for item in submenu.items {
                item.state = (item.representedObject as? String) == code ? .on : .off
            }
        }
        logger.info("Language set to: \(code)")
    }

    @objc private func changeShortcut() {
        let alert = NSAlert()
        alert.messageText = "Change Shortcut"
        alert.informativeText = "Enter new shortcut (e.g. ctrl+space, cmd+shift+s)\n\nModifiers: ctrl, shift, cmd, option\nKeys: space, a-z, 0-9, f1-f12"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
        input.stringValue = settings.hotkeyDisplayString.lowercased()
        alert.accessoryView = input

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let text = input.stringValue.lowercased().trimmingCharacters(in: .whitespaces)
        let parts = text.split(separator: "+").map(String.init)
        guard parts.count >= 2 else {
            let err = NSAlert()
            err.messageText = "Invalid shortcut"
            err.informativeText = "Need at least one modifier + a key"
            err.runModal()
            return
        }

        let key = parts.last!
        let mods = Array(parts.dropLast())

        guard KeyCodes.validateModifiers(mods), KeyCodes.validateKey(key) else {
            let err = NSAlert()
            err.messageText = "Invalid shortcut"
            err.informativeText = "Unknown modifier or key. Use: ctrl/shift/cmd/option + space/a-z/0-9/f1-f12"
            err.runModal()
            return
        }

        settings.hotkeyModifiers = mods
        settings.hotkeyKey = key
        hotkeyListener.configure(modifiers: mods, key: key)
        shortcutMenuItem.title = "Shortcut: \(settings.hotkeyDisplayString)"
        let display = settings.hotkeyDisplayString
        logger.info("Shortcut changed to: \(display)")
    }

    // MARK: - Helpers

    private func setStatus(_ text: String) {
        DispatchQueue.main.async {
            self.statusMenuItem.title = "Status: \(text)"
        }
    }

    private func setIcon(_ symbolName: String) {
        DispatchQueue.main.async {
            self.statusItem.button?.image = NSImage(
                systemSymbolName: symbolName,
                accessibilityDescription: "Hush"
            )
        }
    }
}
