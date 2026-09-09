# MuteBar

<a href="https://chromewebstore.google.com/detail/mutebar/jdnohcgdlpndiinaklmckmaonpjimkfg"><img src="docs/badge-chrome-web-store.png" alt="Available in the Chrome Web Store"></a>

<!-- Hero screenshot TODO: capture the menu bar dropdown during a Meet call, save as docs/screenshot.png, then uncomment:
<img src="docs/screenshot.png" width="360" alt="MuteBar menu bar showing live Meet mute state">
-->

A macOS menu bar app + browser extension that gives you one **global hotkey (F6)** to mute/unmute **Google Meet** — at the *app level*, so your microphone keeps working for everything else (speech-to-text, dictation, recording).

## How it works

```
F6 (global hotkey)                    click Meet's own mute button
   │                                        ▲
   ▼                                        │
MuteBar.app ──unix socket── mutebar-host ──stdio── browser extension ── content script
   ▲                                                        │
   └──────────── state updates (muted / live / no meeting) ──┘
```

- **MuteBar.app** — menu bar agent (Swift). Owns the global hotkey and shows true Meet mute state.
- **mutebar-host** — native messaging host embedded in the app bundle; bridges the extension to the app.
- **Extension** — content script toggles Meet's own mic button (so the UI and participants see the real state); a MutationObserver pushes state changes back.

## Install (dev)

```bash
git clone <repo> && cd mute-bar
scripts/build-app.sh                  # swift build + assemble MuteBar.app
```

Then:
1. `chrome://extensions` (or `arc://extensions`) → Developer mode → **Load unpacked** → select `extension/`
2. Start `MuteBar.app` (registers the native host itself; `scripts/install.sh .build/app/MuteBar.app` does it manually if needed)
3. Join a Google Meet call, press **F6** (change it via the menu-bar "Change Shortcut…" item — press any combo to record it)

## Development

```bash
swift build                       # build app + host
scripts/build-app.sh              # assemble .build/app/MuteBar.app
scripts/smoke-test.sh             # app <-> host round trip, no browser needed
scripts/package-dmg.sh            # .build/MuteBar.dmg
swift scripts/gen-icons.swift      # regenerate extension icons into extension/icons/
scripts/package-extension.sh      # Chrome Web Store zip into dist/ (strips the dev key)
```

Signing and notarization are done locally (Developer ID + `notarytool`); releases are published manually. Store submission copy and checklist: [docs/store-listing.md](docs/store-listing.md).

## Roadmap

- [x] Configurable mute shortcut (press-to-record, any combo; letters need ⌘/⌥/⌃)
- [x] Launch at login (SMAppService)
- [ ] Chrome Web Store listing (unlisted first)
- [ ] More locales for Meet's mic-button labels
- [ ] Zoom / Teams web support (the extension already matches on meet.google.com only)

## Notes

- F6 as a raw function key requires "Use F1, F2, etc. keys as standard function keys" (or holding Fn), otherwise macOS may route it to a media function.
- Meet's in-call mic toggle is a `<button role="button" aria-label="Turn on/off microphone">`; the prejoin uses `div[role=button]`. The content script matches both, prefers the "turn on/off" label, and falls back to a broad localized regex.
- Meet removes the toolbar buttons from the DOM when controls auto-hide. The content script keeps the last observed mute state (sticky) and, if the button is missing on toggle, wakes the toolbar with a synthetic mousemove before clicking.
- The "You left the meeting" screen keeps the meeting URL; it is detected via its Rejoin / "Return to home screen" buttons.
- Chrome 151+ requires `allowed_origins` (chrome-extension URL patterns) in the native host manifest — `allowed_extensions` alone is rejected. `install.sh` writes both (Firefox needs `allowed_extensions`).
- State is aggregated across tabs in the service worker: any tab in a meeting wins, so a stale Meet tab can't clobber the live call's state.
- Meet's keyboard-shortcut state ("⌘ + d") is displayed in the button label; MuteBar clicks the button rather than synthesizing key events.
- Known edge: pressing F6 twice within ~300ms may land on muted (Meet's toggle lags the DOM label); debounce if it bothers you.
