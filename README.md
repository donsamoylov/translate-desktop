# Translate Desktop

A lightweight Mac app for Google Translate: the full translate.google.com website in its own native window.
Unofficial, not affiliated with Google.

- **Dark mode** — Google Translate's own dark theme, following the macOS appearance. Or pick Light / Dark in
  **Appearance**.
- **Your Google account** — sign in once, the session is kept.
- **Text, images and documents** — choose files to translate, translated documents go to Downloads;
  voice input asks macOS for the microphone the first time.
- **Links to other sites** open in your default browser.
- **Your language** — the app follows the macOS language (English and Russian).
- Native Swift, AppKit and WebKit, no Electron. macOS 14 or later, Apple Silicon and Intel.

## Build

Only the Command Line Tools are needed (`xcode-select --install`):

```bash
./build.sh            # → build/Translate Desktop.app
./build.sh --install  # and copy it to ~/Applications
```

`VERSION`, `BUILD` and `SIGN_ID` (signing certificate name) can be set in the environment; without a
certificate the app is signed ad hoc.

## License

MIT
