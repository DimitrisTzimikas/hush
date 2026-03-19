import json
import os
import logging

log = logging.getLogger("hush.config")

CONFIG_DIR = os.path.expanduser("~/.config/hush")
CONFIG_FILE = os.path.join(CONFIG_DIR, "config.json")

# Modifier name -> Quartz flag
MODIFIER_FLAGS = {
    "ctrl": 0x00040000,
    "shift": 0x00020000,
    "cmd": 0x00100000,
    "option": 0x00080000,
}

# Key name -> macOS keycode
KEY_CODES = {
    "space": 49,
    "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5,
    "h": 4, "i": 34, "j": 38, "k": 40, "l": 37, "m": 46, "n": 45,
    "o": 31, "p": 35, "q": 12, "r": 15, "s": 1, "t": 17, "u": 32,
    "v": 9, "w": 13, "x": 7, "y": 16, "z": 6,
    "1": 18, "2": 19, "3": 20, "4": 21, "5": 23, "6": 22,
    "7": 26, "8": 28, "9": 25, "0": 29,
    "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97,
    "f7": 98, "f8": 100, "f9": 101, "f10": 109, "f11": 103, "f12": 111,
}

DEFAULT_CONFIG = {
    "modifiers": ["ctrl"],
    "key": "space",
}


def load_config():
    if os.path.exists(CONFIG_FILE):
        try:
            with open(CONFIG_FILE) as f:
                cfg = json.load(f)
            # Validate
            for mod in cfg.get("modifiers", []):
                if mod not in MODIFIER_FLAGS:
                    raise ValueError(f"Unknown modifier: {mod}")
            if cfg.get("key") not in KEY_CODES:
                raise ValueError(f"Unknown key: {cfg.get('key')}")
            return cfg
        except Exception as e:
            log.warning(f"Invalid config, using defaults: {e}")
    return DEFAULT_CONFIG.copy()


def save_config(config):
    os.makedirs(CONFIG_DIR, exist_ok=True)
    with open(CONFIG_FILE, "w") as f:
        json.dump(config, f, indent=2)
    log.info(f"Config saved: {config}")


def hotkey_display(config):
    """Return human-readable hotkey string like 'Ctrl+Space'."""
    parts = [mod.capitalize() for mod in config["modifiers"]]
    parts.append(config["key"].capitalize())
    return "+".join(parts)
