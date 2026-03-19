# Hush — Voice-to-Text for macOS

Local voice-to-text using OpenAI's Whisper. Press-and-hold a hotkey, speak, release — text appears at your cursor. No API costs, no data leaves your machine.

## Install

```bash
cd hush
pip install -r requirements.txt
```

Or install as a package:

```bash
pip install -e .
```

The first run downloads the Whisper "base" model (~150MB). Subsequent launches load from cache.

## Usage

```bash
hush          # or: python -m hush
```

A microphone icon appears in your menu bar.

**Hold `Ctrl+Shift+Space`**, speak, then **release** — transcribed text is pasted at your cursor.

### Menu bar states
- 🎙 Ready
- 🔴 Recording...
- ⏳ Transcribing...

## macOS Permissions

You'll be prompted to grant these on first use:

- **Microphone** — for audio recording
- **Accessibility** — for global hotkey capture and simulating Cmd+V paste

Go to **System Settings → Privacy & Security** to manage these.

## How It Works

1. Global hotkey listener detects Ctrl+Shift+Space press
2. Microphone streams audio at 16kHz into a buffer
3. On release, audio is sent to Whisper (base model, runs locally on CPU)
4. Transcribed text is copied to clipboard and pasted via Cmd+V
