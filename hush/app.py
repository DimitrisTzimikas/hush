import logging
import AppKit
import subprocess
import threading
import pyperclip
import rumps
from pynput.keyboard import Controller, Key

logging.basicConfig(level=logging.DEBUG, format="%(asctime)s [%(levelname)s] %(message)s")
log = logging.getLogger("hush")

# Hide Dock icon — Hush is a menu bar-only app
AppKit.NSApplication.sharedApplication().setActivationPolicy_(
    AppKit.NSApplicationActivationPolicyAccessory
)

from hush.config import load_config, save_config, hotkey_display, MODIFIER_FLAGS, KEY_CODES
from hush.recorder import Recorder
from hush.transcriber import Transcriber
from hush.hotkey import HotkeyListener


def _check_accessibility():
    """Check if the app has Accessibility permission on macOS."""
    import ctypes
    import ctypes.util
    lib = ctypes.cdll.LoadLibrary(ctypes.util.find_library("ApplicationServices"))
    return lib.AXIsProcessTrusted()


class HushApp(rumps.App):
    def __init__(self):
        super().__init__("Hush", title="🎙")
        self._config = load_config()
        self._shortcut_item = rumps.MenuItem(f"Shortcut: {hotkey_display(self._config)}")
        self._change_shortcut_item = rumps.MenuItem("Change Shortcut...", callback=self._change_shortcut)

        # Language menu
        self._languages = [
            ("Auto-detect", None),
            ("English", "en"),
            ("Greek", "el"),
        ]
        self._language_menu = rumps.MenuItem("Language")
        for name, code in self._languages:
            item = rumps.MenuItem(name, callback=self._set_language)
            if code == self._config.get("language"):
                item.state = 1
            elif code is None and "language" not in self._config:
                item.state = 1
            self._language_menu[name] = item

        self.menu = [
            rumps.MenuItem("Status: Checking permissions..."),
            None,
            self._shortcut_item,
            self._change_shortcut_item,
            self._language_menu,
            None,
        ]
        self._recorder = Recorder()
        self._transcriber = Transcriber()
        self._transcriber.language = self._config.get("language")
        self._keyboard = Controller()
        self._hotkey = HotkeyListener(
            on_press_callback=self._on_hotkey_press,
            on_release_callback=self._on_hotkey_release,
            config=self._config,
        )
        self._status_item = self.menu["Status: Checking permissions..."]
        self._model_loaded = False

    @rumps.timer(1)
    def _startup_check(self, sender):
        """Runs once on the main thread after the app starts."""
        sender.stop()  # Only run once
        log.info("Checking accessibility...")
        accessible = _check_accessibility()
        log.info(f"Accessibility granted: {accessible}")
        if not accessible:
            self._set_status("⚠️ Needs Accessibility")
            response = rumps.alert(
                title="Hush needs Accessibility permission",
                message=(
                    "Hush uses a global hotkey (Ctrl+Shift+Space) to start and stop recording. "
                    "macOS requires Accessibility permission for apps that listen to keyboard events.\n\n"
                    "Click 'Open Settings', then add and enable your terminal app "
                    "under Privacy & Security → Accessibility.\n\n"
                    "After granting permission, restart Hush."
                ),
                ok="Open Settings",
                cancel="Later",
            )
            if response == 1:
                subprocess.Popen(
                    ["open", "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"]
                )
            return
        # Permission granted — start hotkey on main thread, load model in background
        log.info("Starting hotkey listener on main thread...")
        self._hotkey.start()
        log.info("Hotkey listener started!")
        self._set_status("Loading model...")
        threading.Thread(target=self._load_model, daemon=True).start()

    def _load_model(self):
        log.info("Loading Whisper model...")
        self._transcriber.load_model()
        self._model_loaded = True
        log.info("Model loaded. Ready!")
        self._set_status("Ready")

    def _set_status(self, status):
        self._status_item.title = f"Status: {status}"

    def _on_hotkey_press(self):
        log.info(">>> HOTKEY PRESSED — recording started")
        self._set_status("Recording...")
        self.title = "🔴"
        self._recorder.start()

    def _on_hotkey_release(self):
        log.info(">>> HOTKEY RELEASED — stopping recording")
        self._set_status("Transcribing...")
        self.title = "⏳"
        audio = self._recorder.stop()
        log.info(f"Audio captured: {len(audio)} samples, {len(audio)/16000:.1f}s")
        threading.Thread(target=self._transcribe_and_paste, args=(audio,), daemon=True).start()

    def _transcribe_and_paste(self, audio):
        log.info("Transcribing...")
        text = self._transcriber.transcribe(audio)
        log.info(f"Transcription result: '{text}'")
        if text:
            pyperclip.copy(text)
            self._keyboard.press(Key.cmd)
            self._keyboard.press('v')
            self._keyboard.release('v')
            self._keyboard.release(Key.cmd)
            log.info("Pasted to cursor")
        self._set_status("Ready")
        self.title = "🎙"


    def _set_language(self, sender):
        # Uncheck all, check selected
        for name, code in self._languages:
            self._language_menu[name].state = 0
        sender.state = 1
        # Find the code for this language
        code = None
        for name, c in self._languages:
            if name == sender.title:
                code = c
                break
        self._transcriber.language = code
        if code:
            self._config["language"] = code
        else:
            self._config.pop("language", None)
        save_config(self._config)
        lang_name = sender.title
        log.info(f"Language set to: {lang_name} ({code})")

    def _change_shortcut(self, _):
        modifiers = list(MODIFIER_FLAGS.keys())
        keys = sorted(KEY_CODES.keys())

        # Build modifier choices
        mod_choices = ["ctrl", "shift", "cmd", "option",
                       "ctrl+shift", "ctrl+option", "cmd+shift", "cmd+option"]

        response = rumps.alert(
            title="Change Shortcut",
            message=(
                f"Current shortcut: {hotkey_display(self._config)}\n\n"
                f"Enter new shortcut below.\n"
                f"Format: modifier+key (e.g. ctrl+space, cmd+shift+s)\n\n"
                f"Modifiers: ctrl, shift, cmd, option\n"
                f"Keys: space, a-z, 0-9, f1-f12"
            ),
            ok="Save",
            cancel="Cancel",
        )
        if response != 1:
            return

        # Use a Window to get text input
        window = rumps.Window(
            message="Enter shortcut (e.g. ctrl+space, cmd+shift+s):",
            title="Set Shortcut",
            default_text=hotkey_display(self._config).lower(),
            ok="Save",
            cancel="Cancel",
            dimensions=(300, 24),
        )
        result = window.run()
        if not result.clicked:
            return

        text = result.text.strip().lower()
        parts = [p.strip() for p in text.split("+")]
        if len(parts) < 2:
            rumps.alert("Invalid shortcut", "Need at least one modifier + a key (e.g. ctrl+space)")
            return

        key = parts[-1]
        mods = parts[:-1]

        # Validate
        for mod in mods:
            if mod not in MODIFIER_FLAGS:
                rumps.alert("Invalid modifier", f"Unknown modifier: '{mod}'\nUse: ctrl, shift, cmd, option")
                return
        if key not in KEY_CODES:
            rumps.alert("Invalid key", f"Unknown key: '{key}'\nUse: space, a-z, 0-9, f1-f12")
            return

        self._config = {"modifiers": mods, "key": key}
        save_config(self._config)
        self._hotkey.set_hotkey(self._config)
        self._shortcut_item.title = f"Shortcut: {hotkey_display(self._config)}"
        log.info(f"Shortcut changed to: {hotkey_display(self._config)}")
        rumps.notification("Hush", "Shortcut updated", f"New shortcut: {hotkey_display(self._config)}")


def _ensure_single_instance():
    """Kill any other running Hush instances."""
    import os
    import signal
    my_pid = os.getpid()
    for line in os.popen("pgrep -f 'python.*-m hush'").read().strip().split("\n"):
        if line.strip() and int(line.strip()) != my_pid:
            log.info(f"Killing existing Hush instance (pid {line.strip()})")
            os.kill(int(line.strip()), signal.SIGTERM)


def main():
    _ensure_single_instance()
    HushApp().run()


if __name__ == "__main__":
    main()
