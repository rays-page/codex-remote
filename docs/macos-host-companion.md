# Codex Remote macOS Host Companion

This companion is the Mac-side dock for the existing `Codex Remote` phone flow.

It does not change the websocket protocol, the relay contract, or the courier identity. It wraps the local Codex runtime in a calmer, status-first native macOS surface.

The intended daily loop is:

- open the Mac app
- see immediately whether the relay is ready
- start or restart it if needed
- walk away from the Mac
- continue from the phone

## What It Does

- locates the installed `codex` runtime on macOS
- starts `codex app-server`
- stops and restarts it
- writes Windows-compatible relay artifacts:
  - `status.json`
  - `pairing.json`
  - `capability.token`
  - `app-server.log`
  - `app-server.pid`
  - `config.json`
- exposes the pairing deep link and QR code the iPhone app already understands
- shows whether the relay is healthy enough for the user to step away

## Source Layout

The companion lives in:

`macos/CodexRemoteHost`

Important files:

- `Package.swift`
- `Sources/CodexRemoteHost/App/CodexRemoteHostApp.swift`
- `Sources/CodexRemoteHost/Services/RelayController.swift`
- `Sources/CodexRemoteHost/Services/RelayStore.swift`
- `Sources/CodexRemoteHost/Views/ContentView.swift`
- `Sources/CodexRemoteHost/Views/CourierPodView.swift`
- `script/build_and_run.sh`

## Runtime State Path

On macOS the companion uses:

`~/Library/Application Support/CodexRemote`

The filenames intentionally mirror the Windows launcher so the iPhone side can continue to think in the same terms.

## Quick Start

From the repo root:

```bash
cd macos/CodexRemoteHost
./script/build_and_run.sh
```

The Codex app Run button can also use:

`./script/build_and_run.sh`

## Current Validation

Validated locally on April 22, 2026:

- the Swift package builds cleanly with Xcode-installed Swift
- the app bundle launches through `script/build_and_run.sh --verify`
- the relay lifecycle test passes and confirms the companion writes the Windows-compatible status and pairing files
- the real local Codex runtime on this Mac successfully starts `app-server` and accepts a TCP connection on a test port

Validation still not automated here:

- end-to-end clicking through the macOS UI
- direct phone pairing against the new Mac companion UI

## Intentional Constraints

- no protocol rewrite
- no relay re-architecture
- no change to the phone pairing deep-link format
- no change to the courier pod persona

This app exists to make the host healthier and easier to trust, not to turn the desktop into a second giant Codex client.
