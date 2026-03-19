from pynput import keyboard
import threading


class HotkeyListener:
    """Listens for Ctrl+Shift+Space hold-to-talk."""

    def __init__(self, on_press_callback, on_release_callback):
        self._on_press = on_press_callback
        self._on_release = on_release_callback
        self._pressed_keys = set()
        self._hotkey_active = False
        self._listener = None

    def _on_key_press(self, key):
        self._pressed_keys.add(key)
        if self._is_hotkey_combo() and not self._hotkey_active:
            self._hotkey_active = True
            self._on_press()

    def _on_key_release(self, key):
        if self._hotkey_active and key == keyboard.Key.space:
            self._hotkey_active = False
            self._on_release()
        self._pressed_keys.discard(key)

    def _is_hotkey_combo(self):
        return (
            keyboard.Key.ctrl_l in self._pressed_keys
            or keyboard.Key.ctrl_r in self._pressed_keys
        ) and (
            keyboard.Key.shift_l in self._pressed_keys
            or keyboard.Key.shift_r in self._pressed_keys
        ) and (
            keyboard.Key.space in self._pressed_keys
        )

    def start(self):
        self._listener = keyboard.Listener(
            on_press=self._on_key_press,
            on_release=self._on_key_release,
        )
        self._listener.daemon = True
        self._listener.start()

    def stop(self):
        if self._listener:
            self._listener.stop()
