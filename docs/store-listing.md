# Chrome Web Store listing — MuteBar

Everything needed for the developer dashboard submission.

## Store listing copy

- **Name**: MuteBar
- **Summary** (132 chars max): Mute Google Meet from anywhere with one global hotkey. Companion extension for the MuteBar macOS app.
- **Category**: Productivity
- **Website**: https://github.com/sfdye/mute-bar

**Detailed description** (draft, single long lines — GitHub renders these fine but the store field is plain text):

> MuteBar gives you a single global hotkey that toggles your microphone in Google Meet — from any app, at any time, even when your browser is buried under windows or the Meet tab is in the background.
>
> Unlike device-level mute tools, MuteBar clicks Meet's own mute button. Your microphone keeps working for speech-to-text dictation, and the meeting participant list shows you as muted, so everyone can tell at a glance.
>
> REQUIREMENT: this extension is a companion to the MuteBar macOS menu bar app and does nothing without it. Download the app from https://github.com/sfdye/mute-bar, run it once, and the hotkey works. macOS only.
>
> Works in Google Meet on Chrome, Arc, Brave, Edge, and other Chromium browsers. Configure the hotkey from the MuteBar menu bar icon (default F6).
>
> Open source (MIT). No accounts, no telemetry, no data collection.

## Review form

**Single purpose**: Toggle the microphone in Google Meet via the user's global hotkey, in coordination with the companion macOS app.

**Permission justifications**:

- `nativeMessaging` — the extension's only job is to relay hotkey presses and mute state between the local MuteBar macOS app and the Meet page, over the Chrome native messaging API. Nothing is sent over the network; the native host is a local process installed by the MuteBar app.
- `https://meet.google.com/*` (host permission + content script) — required to read the in-call mute state from the mic button's accessibility labels and to click that button when the hotkey is pressed. No other sites are accessed.

**Privacy practices** (dashboard data disclosures): no data collected, no data used, no authentication. All messaging is local (content script ↔ service worker ↔ local native host). The website fields can state: "MuteBar does not collect or transmit any user data."

**Distribution**: unlisted (link-only) initially, while the companion app is in early access.

## Pre-upload checklist

- [x] `scripts/package-extension.sh` → `dist/mutebar-extension-<version>.zip` (dev `key` stripped; store assigns a new ID)
- [ ] Screenshots: at least 1, 1280×800 or 640×400 (suggested: menubar icon states + F6 toggling a real Meet call)
- [ ] Small promo tile 440×280 (optional)
- [ ] Privacy justification text pasted from above
- [ ] One-time $5 developer registration fee (if the account has never published)

## After first upload

1. Note the **store-assigned extension ID** from the dashboard.
2. Add it to `scripts/install.sh` so the native host manifest lists BOTH origins:
   - dev: `chrome-extension://iggmpoondbifidlpilegncmifabajbep/*`
   - store: `chrome-extension://<STORE_ID>/*`
   (Chrome 151+ requires `allowed_origins` in the host manifest.)
3. Cut an app release with the updated `install.sh` and re-run it locally.
4. **Do not install the dev and store versions at the same time** — both content scripts would run in Meet tabs and every hotkey press would toggle twice. Uninstall the unpacked dev copy before installing from the store.
