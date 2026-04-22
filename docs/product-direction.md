# Codex Remote Product Direction

`Codex Remote` works best when it feels less like a settings panel and more like a watchful dock for your remote sessions.

This direction keeps the relay architecture intact, keeps the courier pod identity intact, and makes the app easier to trust at a glance.

## Product Shape

The product should become three coordinated surfaces with clear roles:

- iPhone app: host oversight, pairing, fallback rescue, and quick compose
- Messages extension: the primary conversational cockpit
- desktop host app on macOS and Windows: open once, see if the relay is healthy, restart it fast, and step away confidently

The host apps should not become full thread browsers. They are machine-room surfaces.

Core flow:

- start the host app
- get a clear `ready / not ready` answer
- start or restart the relay if needed
- walk away from the desktop
- pick Codex back up from the phone whenever needed

## Visual Direction

Recommended brand direction: `Courier Pod Beacon`

Keep and strengthen what already feels distinctive:

- soot-black and graphite surfaces
- coolant teal and pod-lime as the primary live colors
- amber only for warnings, never as the default accent
- rounded industrial geometry instead of generic floating cards
- one expressive courier pod hero instead of lots of equally weighted panels
- system sans for human-facing headings and controls
- monospaced secondary text for relay paths, thread ids, models, timestamps, and status

Mood target:

- dependable
- slightly clandestine
- calm under pressure
- affectionate without becoming cutesy

## Icon Direction

Recommended icon: `Courier Pod Beacon`

Source concept:

- matte obsidian rounded-square tile
- centered courier-pod silhouette derived from the existing ASCII sprite
- one teal uplink arc
- one pod-lime glow
- one tiny amber alert spark for tension

Avoid:

- chat bubbles
- generic robot heads
- brains
- neon cyberpunk clutter
- over-literal terminal glyphs

## UX Priorities

The app needs a tighter hierarchy. The home surface should answer one question instantly:

`Can I walk away and keep using my phone?`

That means the root experience should become:

1. `Host`
2. `Needs You`
3. `Current Session`
4. `Quick Actions`

Setup, defaults, and diagnostics should move behind sheets or disclosure, not compete with the core status story.

## Pairing Flow

The primary pairing path should be a deep link, not manual entry.

Preferred order:

1. `Scan QR`
2. `Open Pair Link`
3. `Paste Link`
4. `Manual Setup`

The raw websocket URL and token fields should remain available, but they should feel like advanced rescue tools rather than the main onboarding flow.

## Host App Behavior

Both desktop host apps should present the same mental model:

- big relay state hero
- one obvious primary action
- start, stop, and restart
- pairing link ready when healthy
- logs and details nearby, but visually secondary

The right emotional state is:

- `Relay live`
- `Relay asleep`
- `Relay stalled`
- `Relay needs attention`

If the relay is healthy, the UI should explicitly say the user is safe to step away.

## iPhone App Changes

The iPhone app should stop leading with raw relay fields and start leading with `My Host`.

That home surface should show:

- host name
- host platform
- last heartbeat
- current thread label when available
- a single context-aware primary action

Pairing and manual connection details should move into setup or advanced settings.

## Messages Changes

Compact mode should stop showing a row of equal-weight buttons.

Instead, compact mode should show a smart primary action:

- `Resume Latest`
- `Handle Approval`
- `Reconnect`
- `Start New Thread`

Expanded mode should keep the courier pod visible and prioritize:

- urgent queue
- active thread
- sticky composer
- host pill

## Acceptance Signal

The redesign is working when the user can:

- glance at the desktop host and know if they can leave the machine
- pair from the phone without copying raw secrets around
- use Messages as the fast path
- fall back to the host app only when they need setup, rescue, or relay health control
