# Codex Remote iMessage Extension Handoff

Verified against Apple documentation on April 20, 2026.

## Goal

Convert the current `Codex Remote` iPhone app into a two-surface product:

- a slim containing iPhone app for setup, pairing, connection defaults, and fallback control
- an iMessage extension for day-to-day Codex control inside Messages

The desktop relay remains the same core product. The Messages work is an iOS-side restructuring, not a protocol rewrite.

## Apple-Documented Constraints

These are the platform facts this implementation should treat as fixed unless re-verified:

1. Apple supports iMessage apps as either standalone apps or as app extensions inside an iOS/iPadOS app.
   - https://developer.apple.com/imessage/
   - https://developer.apple.com/design/human-interface-guidelines/imessage-apps-and-stickers

2. Xcode supports adding an app extension target to an existing app project, and the extension ships inside the containing app.
   - https://developer.apple.com/documentation/technologyoverviews/app-extensions

3. App extensions run in a separate process and do not automatically share storage/resources/permissions with the containing app.
   - Use an App Group for shared non-secret data.
   - https://developer.apple.com/documentation/technologyoverviews/app-extensions
   - https://developer.apple.com/documentation/xcode/configuring-app-groups

4. If app and extension need to share credentials securely, use Keychain Sharing across both targets.
   - https://developer.apple.com/documentation/security/sharing-access-to-keychain-items-among-a-collection-of-apps
   - https://developer.apple.com/documentation/xcode/configuring-keychain-sharing

5. Apple recommends putting shared app/extension service code into a shared framework or otherwise shared code module.
   - https://developer.apple.com/documentation/sirikit/structuring-your-code-to-support-app-extensions

6. iMessage apps have compact and expanded presentation styles. Expanded mode is the right place for anything with real input or more complex controls.
   - https://developer.apple.com/documentation/messages/msmessagesappviewcontroller/presentationstyle
   - https://developer.apple.com/documentation/messages/icecreambuilder-building-an-imessage-extension

7. Apple explicitly notes that iMessage apps support text input in expanded presentation style.
   - Do not build the main prompt composer around compact mode.
   - https://developer.apple.com/library/archive/qa/qa1932/_index.html

8. Default context should stay in the normal Messages context, not the broader media context.
   - The media context has extra limitations and is not the right fit for Codex control.
   - https://developer.apple.com/documentation/messages/msmessagesappviewcontroller/presentationcontext
   - https://developer.apple.com/documentation/messages/msmessagesapppresentationcontext/media

9. App Store packaging note: if an already-shipped standalone iMessage app is converted into an extension of an iOS app or vice versa, Apple says that change requires a new app record.
   - This is only relevant if/when App Store packaging is involved.
   - https://developer.apple.com/help/app-store-connect/create-an-app-record/add-imessage-app-information/

## Current Repo Reuse Map

The next implementation pass should reuse these pieces instead of re-deriving them:

### Keep as-is or nearly as-is

- `desktop/`
  - `codex_remote_desktop.py`
  - `start_codex_remote.bat`
  - `stop_codex_remote.bat`
  - `install_shortcut.ps1`
  - `tests/test_codex_remote_desktop.py`
- `ios/CodexRemote/CodexRemote/Support/AppSettings.swift`
- `ios/CodexRemote/CodexRemote/Support/ConnectionProfileStore.swift`
- `ios/CodexRemote/CodexRemote/Models/CodexModels.swift`
- `ios/CodexRemote/CodexRemote/Services/CodexRemoteClient.swift`
- parts of `ios/CodexRemote/CodexRemote/Services/CodexRemoteStore.swift`
  - websocket lifecycle
  - model loading
  - thread loading
  - turn start / interrupt
  - approval handling
  - prompt handling
- `ios/CodexRemote/CodexRemote/Views/CourierPodView.swift`

### Keep conceptually but split/refactor

- `CodexRemoteStore.swift`
  - split into shared session/controller logic plus target-specific presentation state
- `RootView.swift`
  - reuse design language selectively, but the current full standalone shell should not be the Messages UI
- `SessionDetailView.swift`
  - salvage the timeline rendering ideas and the diff block
- `ConnectionSheetView.swift`
  - salvage settings fields, but the containing app should become a calmer setup surface

### Treat as provisional / likely to shrink

- the current host app’s full-screen thread browser as the primary product surface
- any host-app-only UI complexity that duplicates what the Messages extension will become

## Recommended Architecture

### Product Shape

- `Codex Remote` containing app
  - setup
  - pairing
  - websocket URL
  - token management
  - default workspace/model/reasoning/approval options
  - “Open Messages” guidance
  - fallback full app control only if worth keeping

- `Codex Remote Messages Extension`
  - quick access inside Messages
  - compact view for status and shortcuts
  - expanded view for real control

### Target Layout

Recommended destination structure:

- `CodexRemote` app target
- `CodexRemoteMessagesExtension` target
- shared code module used by both

Preferred implementation shape:

1. Shared module / framework
   - `ConnectionProfile`
   - `ConnectionProfileStore`
   - `CodexRemoteClient`
   - shared models
   - app/extension-safe session controller logic

2. Host app target
   - setup and settings UI

3. Messages extension target
   - `MSMessagesAppViewController` root
   - host SwiftUI view(s) via a UIKit bridge
   - compact and expanded experiences

If creating a separate internal framework is too much friction in one pass, shared source files added to both targets is acceptable as an intermediate step. The important thing is a clean split between reusable control logic and target-specific UI.

### Shared Storage

Use two layers:

- App Group:
  - websocket URL
  - default workspace
  - default model
  - reasoning preference
  - approval preference
  - last selected thread metadata if desired

- Keychain Sharing:
  - capability token

Do not leave the token only in plain `UserDefaults` once both targets exist.

## UX Recommendation

### Compact Messages UI

One job only: fast orientation and action.

Include:

- connection badge
- current target desktop/workspace label
- active thread name or “No active thread”
- buttons:
  - `Resume`
  - `New Thread`
  - `Connect`
  - `Settings`

If the user taps into prompt entry or advanced controls, request `.expanded`.

### Expanded Messages UI

This should be the real control surface.

Include:

- courier pod header/status
- prompt field
- send button
- interrupt button
- thread picker or recent threads
- model picker
- reasoning effort picker
- approval policy picker if still worth exposing
- “new thread” button
- recent timeline output
- approval/request-user-input surfaces

### Containing App UI

Reduce it to setup + fallback, not a second heavyweight primary app.

Recommended host app sections:

- relay connection
- token / pairing status
- defaults
- test connection button
- “Use in Messages” explainer
- optional advanced diagnostics

## Implementation Sequence

### Phase 1. Restructure for shared code

1. Add a new iMessage Extension target to the Xcode project.
2. Introduce a shared code module/framework or a shared source group used by both targets.
3. Move transport/state code into the shared layer.
4. Keep target-specific UI state out of the reusable transport layer.

Definition of done:

- both targets build against the same connection/profile/client code
- no duplicate websocket client implementations

### Phase 2. Add shared persistence

1. Add an App Group entitlement to both targets.
2. Move non-secret profile/defaults persistence to the shared app group container.
3. Add Keychain Sharing for the capability token.
4. Migrate old standard-`UserDefaults` values forward if they exist.

Definition of done:

- changing defaults in the host app is visible to the extension
- token is readable from both targets through one secure path

### Phase 3. Build the Messages extension shell

1. Create `MSMessagesAppViewController` subclass for the extension.
2. Host SwiftUI content inside it.
3. Implement compact and expanded layouts.
4. Request expanded mode before entering prompt text.

Definition of done:

- extension opens from the Messages app drawer
- compact mode works
- expanded mode works

### Phase 4. Implement Codex controls in the extension

1. Connect/disconnect to desktop relay.
2. Load recent threads.
3. Start new thread.
4. Resume existing thread.
5. Send turn input.
6. Interrupt active turn.
7. Change model.
8. Change reasoning effort.

Definition of done:

- the extension can perform every action the user explicitly asked about:
  - change model
  - change reasoning effort
  - start new thread

### Phase 5. Port approval and prompt flows

1. Surface command/file/permission approvals inside the extension.
2. Surface request-user-input prompts.
3. Make approval UX safe in compact and usable in expanded.

Definition of done:

- approval-required turns do not strand the user
- user input requests can be answered inside Messages

### Phase 6. Simplify the containing app

1. Keep setup and diagnostics.
2. Remove or downgrade duplicated “primary control surface” UI if it no longer earns its keep.
3. Make the host app clearly complementary to Messages, not a competing product surface.

Definition of done:

- host app feels like setup/fallback
- Messages feels like primary quick-control experience

### Phase 7. Validation

1. Desktop relay tests:
   - `py -3 -m unittest discover -s .\desktop\tests -v`
   - live launch/status/pairing smoke
2. iOS host app validation:
   - build
   - save defaults
   - verify shared persistence
3. Messages extension validation:
   - launch in simulator/device from Messages drawer
   - compact to expanded transition
   - connect to relay
   - new thread
   - send prompt
   - interrupt
   - change model
   - change reasoning
   - handle approval

## Important Risks

1. Xcode target creation is the biggest structural step.
   - If this work is being done outside a Mac/Xcode environment, manual `project.pbxproj` editing becomes the riskiest part of the whole task.

2. Extension lifecycle is more constrained than a normal app.
   - Reconnect logic should be defensive.
   - Avoid assuming the extension stays alive long-term.

3. Compact mode is not the place for the main composer.
   - Use compact for launch/status/shortcuts.
   - Use expanded for real interaction.

4. Shared state must be explicit.
   - App Group for defaults.
   - Keychain sharing for token.

5. Do not overbuild the containing app before the extension is working.
   - The user wants less bloat, not two heavyweight clients.

## Recommended Cleanup During Implementation

When the extension is working, delete or reduce:

- duplicate standalone-only UI that no longer earns its keep
- settings screens duplicated in both targets without a clear reason
- any temporary extension bootstrap code that exists only to get the first build running

Do not delete:

- desktop relay
- pairing/deep link path
- courier pod identity
- shared Codex protocol client logic

## Acceptance Criteria

The work is complete when all of the following are true:

1. The iOS app still installs and launches.
2. The app contains an iMessage extension target that appears in Messages.
3. The Messages extension can connect to the desktop relay.
4. The Messages extension can:
   - start a new thread
   - resume a thread
   - send a turn
   - interrupt a turn
   - change model
   - change reasoning effort
5. Shared defaults persist between the host app and extension.
6. Sensitive token storage is not left in plain non-shared `UserDefaults`.
7. The host app is simplified to setup/fallback instead of duplicating the full product.

## Paste-Ready Prompt for the Next Thread

Use this as the starting prompt in the next high-reasoning thread:

```text
You are working in:
C:\Users\raymo_w9whwcn\Documents\Codex\2026-04-19-this-is-the-official-chatgpt-ios\codex-remote

Repo:
https://github.com/rays-page/codex-remote

Current branch:
main

Goal:
Turn Codex Remote into an iOS containing app plus an iMessage extension, with the Messages extension becoming the primary lightweight control surface for Codex. Keep the desktop relay architecture. Reuse as much existing code as possible, delete excess UI complexity, and push the updated repo when done.

Important context:
- Apple docs verified April 20, 2026 support iMessage apps as app extensions inside an iOS app.
- App extensions run in a separate process, so shared defaults must use an App Group.
- Shared secrets/token should use Keychain Sharing.
- iMessage text input belongs in expanded presentation style.
- Keep this in the normal Messages context, not the media context.

Primary repo-specific reuse targets:
- desktop/codex_remote_desktop.py
- ios/CodexRemote/CodexRemote/Support/AppSettings.swift
- ios/CodexRemote/CodexRemote/Support/ConnectionProfileStore.swift
- ios/CodexRemote/CodexRemote/Models/CodexModels.swift
- ios/CodexRemote/CodexRemote/Services/CodexRemoteClient.swift
- relevant parts of ios/CodexRemote/CodexRemote/Services/CodexRemoteStore.swift
- ios/CodexRemote/CodexRemote/Views/CourierPodView.swift

Read first:
- docs/imessage-extension-handoff.md
- README.md

What to implement:
1. Add an iMessage extension target to the existing Xcode project.
2. Split shared logic cleanly between host app and extension.
3. Add App Group sharing for non-secret settings/defaults.
4. Add Keychain Sharing for the capability token.
5. Build compact and expanded Messages UIs.
6. Support inside Messages:
   - connect/disconnect
   - start new thread
   - resume existing thread
   - send turn
   - interrupt turn
   - change model
   - change reasoning effort
   - approval/prompt flows
7. Simplify the containing app to setup/fallback instead of a second heavyweight control surface.
8. Delete excess UI/scaffolding that no longer serves the new architecture.
9. Validate what you can locally, explain what could not be validated, commit, and push.

Constraints:
- Do not rewrite the desktop protocol.
- Do not remove the courier pod identity.
- Prefer shared code over duplicate app/extension implementations.
- Be conservative with project.pbxproj edits and keep the repo coherent if Xcode is unavailable.
```
