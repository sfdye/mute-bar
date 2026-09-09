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
- [x] Screenshots: 2 × 1280×800 (Meet call window only, mic live + muted via F6)
- [x] Privacy justification text (single purpose, nativeMessaging, host permission, no remote code, no data collection, privacy policy at docs/privacy-policy.md)
- [x] Submitted for review: 2026-09-08, item `jdnohcgdlpndiinaklmckmaonpjimkfg`, unlisted, auto-publish after approval

## After approval / publication

1. Install the store version, then read its **extension ID** from `chrome://extensions` (only visible post-publication — the dashboard only shows the item ID).
2. The app's native-host manifest (`Sources/MuteBar/NativeHostRegistration.swift`) must list BOTH origins:
   - dev: `chrome-extension://iggmpoondbifidlpilegncmifabajbep/*`
   - store: `chrome-extension://<STORE_EXTENSION_ID>/*`
   (Chrome 151+ requires `allowed_origins` in the host manifest.)
3. Cut an app release and re-run it locally — the app re-registers the manifest on every launch.
4. **Uninstall the unpacked dev copy before installing from the store** — running both makes every hotkey press toggle twice.
