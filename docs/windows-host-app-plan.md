# Windows Host App Plan

This plan is for the Windows-native companion that should sit on top of the existing launcher without replacing it.

## Recommendation

Build the first Windows host app as a native `.NET 8` WPF desktop app that shells the existing Python launcher.

Why this is the right first step:

- it keeps `desktop/codex_remote_desktop.py` as the backend source of truth
- it avoids a risky protocol rewrite
- it can ship and run un-packaged
- it gives enough control to make the UI genuinely better instead of just prettier

If the product later needs a deeper Windows 11 visual language, WinUI 3 can be a second pass. The first pass should optimize for reliability and handoff speed.

## Non-Negotiables

- keep `desktop/codex_remote_desktop.py`
- keep `%LOCALAPPDATA%\\CodexRemote`
- keep the current pairing deep-link format
- keep the capability-token file behavior
- keep the courier pod identity
- do not rewrite the relay process or websocket protocol

## What The Windows App Should Do

The job is intentionally narrow:

- show whether the relay is up
- start it
- stop it
- restart it
- show the pairing link and QR
- open logs
- reveal the state folder
- expose advanced config only when needed

It should not become a full Codex transcript browser.

## Backend Contract

Treat the existing Python launcher as the service adapter:

- `py -3 .\\desktop\\codex_remote_desktop.py launch`
- `py -3 .\\desktop\\codex_remote_desktop.py stop`
- `py -3 .\\desktop\\codex_remote_desktop.py status`
- `py -3 .\\desktop\\codex_remote_desktop.py pairing`
- `py -3 .\\desktop\\codex_remote_desktop.py doctor`

The native UI should read the same files the launcher already owns:

- `%LOCALAPPDATA%\\CodexRemote\\status.json`
- `%LOCALAPPDATA%\\CodexRemote\\pairing.json`
- `%LOCALAPPDATA%\\CodexRemote\\capability.token`
- `%LOCALAPPDATA%\\CodexRemote\\app-server.log`
- `%LOCALAPPDATA%\\CodexRemote\\app-server.pid`
- `%LOCALAPPDATA%\\CodexRemote\\config.json`

## UX Shape

Use the same machine-room model as macOS:

- one hero relay card
- one status lamp
- one primary action
- one quick action rail
- one pairing section
- advanced settings hidden by default

Recommended sections:

1. `Host`
2. `Pairing`
3. `Quick Actions`
4. `Advanced`

Recommended host states:

- `Relay live`
- `Relay asleep`
- `Relay stalled`
- `Relay needs attention`

## Visual Direction

Use the same brand direction as the Mac app:

- courier pod as the central icon and mascot
- soot black and graphite panels
- teal and pod-lime for live state
- amber only for warning
- monospaced metadata
- rounded industrial cards instead of generic flat admin panels

The app should feel like a relay dock, not a sysadmin dashboard.

## Suggested File Layout

Recommended Windows app folder:

`windows/CodexRemoteHost/`

Suggested internal shape:

- `App.xaml` and `App.xaml.cs`
- `MainWindow.xaml`
- `Views/`
- `ViewModels/`
- `Services/LauncherBridge.cs`
- `Services/StateFiles.cs`
- `Models/`
- `Assets/`

## Implementation Phases

### Phase 1

Create the native shell and backend bridge.

- add the WPF project
- create a `LauncherBridge` that invokes the existing Python launcher
- deserialize `status.json`, `pairing.json`, and `config.json`
- render a basic status-first window

Definition of done:

- the app can show current relay state
- the app can start and stop the relay

### Phase 2

Add the useful daily controls.

- restart
- copy pair link
- render QR code
- open logs
- reveal state folder

Definition of done:

- the user can recover a dead relay without touching PowerShell

### Phase 3

Add polish without changing the backend.

- tray icon or notification-area presence
- live polling
- calmer empty states
- stronger pod hero and icon usage
- settings disclosure for host, port, and public websocket override

Definition of done:

- the app feels intentional, not just functional

## Recommended Acceptance Criteria

The first Windows-native version is done when:

- it starts the existing Python launcher successfully
- it stops and restarts it successfully
- it reflects relay state from the same `%LOCALAPPDATA%\\CodexRemote` files
- it exposes the same pairing link the phone app already consumes
- it keeps the relay architecture unchanged
- it makes it obvious whether the user can step away and keep using the phone
