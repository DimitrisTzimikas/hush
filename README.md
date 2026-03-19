# Hush — Voice-to-Text for macOS

Local voice-to-text using whisper.cpp. Press-and-hold a hotkey, speak, release — text appears at your cursor. No API costs, no data leaves your machine.

## Install

Download the latest `Hush.dmg` from the [build](build/) folder, open it, and drag Hush to Applications.

On first launch, right-click the app → **Open** (to bypass Gatekeeper).

## Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon (M1/M2/M3/M4)

## Usage

Launch Hush from Applications. A microphone icon appears in your menu bar.

**Hold `Ctrl+Space`**, speak, then **release** — transcribed text is pasted at your cursor.

### Menu bar options

- **Status** — Ready / Recording / Transcribing
- **Accessibility** / **Microphone** — permission status with click-to-fix
- **Shortcut** — shows current hotkey, with option to change
- **Language** — Auto-detect, English, or Greek

### Menu bar icon states

- 🎤 Ready
- ⏺ Recording...
- ⏳ Transcribing...

## macOS Permissions

Hush needs two permissions (prompted on first use):

- **Accessibility** — for global hotkey capture and simulating Cmd+V paste
- **Microphone** — for audio recording

Go to **System Settings → Privacy & Security** to manage these. The menu bar shows permission status and lets you click to open Settings directly.

## How It Works

1. Global hotkey listener (Quartz CGEvent tap) detects Ctrl+Space
2. AVAudioEngine streams mic audio at 16kHz mono into a buffer
3. On release, audio is transcribed by whisper.cpp (base model, CPU with Accelerate/BLAS)
4. Language auto-detected between English and Greek (or forced via menu)
5. Transcribed text is copied to clipboard and pasted via Cmd+V

## Tech Stack

- **Swift** / SwiftUI — native macOS menu bar app
- **whisper.cpp** — local speech-to-text (base model, ~141MB)
- **AVAudioEngine** — microphone recording
- **Quartz CGEvent** — global hotkey and keyboard simulation
- **Accelerate / BLAS** — optimized CPU inference on Apple Silicon

## Building from Source

```bash
# Clone with submodule
git clone --recursive https://github.com/DimitrisTzimikas/hush.git
cd hush

# Build whisper.cpp static libraries
cd whisper.cpp && mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DWHISPER_BUILD_EXAMPLES=OFF -DWHISPER_BUILD_TESTS=OFF -DGGML_METAL=OFF -DBUILD_SHARED_LIBS=OFF
make -j8 whisper
cd ../..

# Generate Xcode project and build
brew install xcodegen
xcodegen generate
xcodebuild -project Hush.xcodeproj -scheme Hush -configuration Release build
```

Place `ggml-base.bin` model in the app bundle's Resources or in `~/Library/Application Support/Hush/models/`.

Download the model:

```bash
mkdir -p ~/Library/Application\ Support/Hush/models
curl -L -o ~/Library/Application\ Support/Hush/models/ggml-base.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin
```
