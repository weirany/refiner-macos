# Refiner

Refiner is a local-only macOS menu bar app that rewrites the selected text in the focused editable field using Apple's Foundation Models.

## Run as a proper app bundle

Launching the Swift package executable directly can produce AppKit warnings such as missing bundle identifier messages, because a plain executable is not a full `.app` bundle.

Build a real app bundle instead:

```bash
./scripts/build_app.sh
open ./dist/Refiner.app
```

The generated bundle includes an `Info.plist` with `CFBundleIdentifier` and `LSUIElement`, so it behaves like a normal menu bar app.
