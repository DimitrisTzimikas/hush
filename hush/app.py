import threading
import pyperclip
import rumps
from pynput.keyboard import Controller, Key

from hush.recorder import Recorder
from hush.transcriber import Transcriber
from hush.hotkey import HotkeyListener


class HushApp(rumps.App):
    def __init__(self):
        super().__init__("Hush", title="🎙")
        self.menu = [
            rumps.MenuItem("Status: Loading model..."),
            None,  # separator
        ]
        self._recorder = Recorder()
        self._transcriber = Transcriber()
        self._keyboard = Controller()
        self._hotkey = HotkeyListener(
            on_press_callback=self._on_hotkey_press,
            on_release_callback=self._on_hotkey_release,
        )
        self._status_item = self.menu["Status: Loading model..."]

        # Load model in background thread
        threading.Thread(target=self._load_model, daemon=True).start()

    def _load_model(self):
        self._transcriber.load_model()
        self._set_status("Ready")
        self._hotkey.start()

    def _set_status(self, status):
        self._status_item.title = f"Status: {status}"

    def _on_hotkey_press(self):
        self._set_status("Recording...")
        self.title = "🔴"
        self._recorder.start()

    def _on_hotkey_release(self):
        self._set_status("Transcribing...")
        self.title = "⏳"
        audio = self._recorder.stop()
        # Transcribe in background to not block the hotkey listener
        threading.Thread(target=self._transcribe_and_paste, args=(audio,), daemon=True).start()

    def _transcribe_and_paste(self, audio):
        text = self._transcriber.transcribe(audio)
        if text:
            pyperclip.copy(text)
            # Small delay to ensure clipboard is set
            self._keyboard.press(Key.cmd)
            self._keyboard.press('v')
            self._keyboard.release('v')
            self._keyboard.release(Key.cmd)
        self._set_status("Ready")
        self.title = "🎙"


def main():
    HushApp().run()


if __name__ == "__main__":
    main()
