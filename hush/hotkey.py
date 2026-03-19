import logging
import Quartz

from hush.config import MODIFIER_FLAGS, KEY_CODES

log = logging.getLogger("hush.hotkey")


class HotkeyListener:
    """Listens for a configurable hold-to-talk hotkey using Quartz event tap on main run loop."""

    def __init__(self, on_press_callback, on_release_callback, config=None):
        self._on_press = on_press_callback
        self._on_release = on_release_callback
        self._active = False
        self._tap = None
        self._source = None
        self.set_hotkey(config or {"modifiers": ["ctrl"], "key": "space"})

    def set_hotkey(self, config):
        self._modifier_mask = 0
        for mod in config["modifiers"]:
            self._modifier_mask |= MODIFIER_FLAGS[mod]
        self._keycode = KEY_CODES[config["key"]]
        self._modifier_names = config["modifiers"]

    def _check_modifiers(self, flags):
        for mod in self._modifier_names:
            if not (flags & MODIFIER_FLAGS[mod]):
                return False
        return True

    def _callback(self, proxy, event_type, event, refcon):
        keycode = Quartz.CGEventGetIntegerValueField(event, Quartz.kCGKeyboardEventKeycode)
        flags = Quartz.CGEventGetFlags(event)
        mods_held = self._check_modifiers(flags)

        if keycode == self._keycode and event_type == Quartz.kCGEventKeyDown and mods_held:
            if not self._active:
                log.info("Hotkey DOWN detected")
                self._active = True
                self._on_press()
        elif self._active:
            if (keycode == self._keycode and event_type == Quartz.kCGEventKeyUp) or \
               (event_type == Quartz.kCGEventFlagsChanged and not mods_held):
                log.info("Hotkey RELEASED")
                self._active = False
                self._on_release()

        return event

    def start(self):
        """Create event tap and add to the MAIN run loop (must be called from main thread)."""
        mask = (
            Quartz.CGEventMaskBit(Quartz.kCGEventFlagsChanged)
            | Quartz.CGEventMaskBit(Quartz.kCGEventKeyDown)
            | Quartz.CGEventMaskBit(Quartz.kCGEventKeyUp)
        )
        self._tap = Quartz.CGEventTapCreate(
            Quartz.kCGSessionEventTap,
            Quartz.kCGHeadInsertEventTap,
            Quartz.kCGEventTapOptionListenOnly,
            mask,
            self._callback,
            None,
        )
        if self._tap is None:
            log.error("Failed to create event tap — Accessibility permission missing!")
            raise RuntimeError("Failed to create event tap")
        log.info("Event tap created successfully")

        self._source = Quartz.CFMachPortCreateRunLoopSource(None, self._tap, 0)
        main_loop = Quartz.CFRunLoopGetMain()
        Quartz.CFRunLoopAddSource(main_loop, self._source, Quartz.kCFRunLoopCommonModes)
        Quartz.CGEventTapEnable(self._tap, True)
        log.info("Event tap added to main run loop")

    def stop(self):
        if self._tap:
            Quartz.CGEventTapEnable(self._tap, False)
