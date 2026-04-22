# MacOS Host Companion Packaging Plan

This note captures the packaging and repo-integration path for the Mac host companion as a separate but related project in the `Codex Remote` repo.

## Project Boundary

The Mac app stays in its own product directory:

`macos/CodexRemoteHost`

That directory is the source-of-truth for the companion app. The companion should remain adjacent to the iPhone app and Windows host direction, but it should not be folded into the main mobile targets.

Keep these boundaries intact:

- do not rewrite the relay protocol
- do not change the pairing deep-link format
- do not change the courier pod identity
- do not edit files under `macos/CodexRemoteHost/Sources/**` for packaging-only work

## Current Packaging Shape

The current Mac host already follows a useful split:

- `Package.swift` defines the SwiftPM target
- `script/build_and_run.sh` builds a local app bundle under `dist/`
- `dist/Codex Remote Host.app` is a developer convenience artifact, not a release package

That is a good development loop. The next step is to add repo-facing packaging guidance without changing app behavior.

## Packaging Plan

### Phase 1: Document the project as a sibling app

Update the repo docs so the Mac host is described as:

- a separate desktop companion project
- built from its own Swift package
- aligned to the same relay contract as the Windows launcher and iPhone client

Recommended doc touch points:

- `README.md`
- `docs/macos-host-companion.md`
- `docs/product-direction.md`

### Phase 2: Keep the local bundle workflow

Retain the current `script/build_and_run.sh` flow for day-to-day development.

Recommended behavior:

- build with SwiftPM
- assemble the `.app` bundle locally
- preserve the current `--verify`, `--logs`, and `--telemetry` modes
- treat `dist/` as disposable build output

### Phase 3: Add release packaging

When the file list for packaging changes is final, add a release-oriented package path that produces one of:

- a zipped `.app`
- a signed `.app` archive
- a `.dmg` if distribution polish is needed later

Start with the simplest artifact that is easy to verify in GitHub Actions. Notarization can wait until the release path is otherwise stable.

### Phase 4: Keep versioning and bundle identity stable

Make sure the packaging layer continues to reflect the same app identity:

- display name: `Codex Remote Host`
- executable name: `CodexRemoteHost`
- bundle id: keep the current identifier unless a coordinated rename is planned

This avoids splitting the repo story from the app story.

## Recommended GitHub Actions Next

When the final local file list is ready, the next GitHub actions should be:

1. Open or update a draft PR for the docs-only packaging boundary changes first.
2. Push the Mac packaging updates in a follow-up commit once the file list is finalized.
3. Add a workflow that runs on `pull_request` and `workflow_dispatch` to execute:
   - `swift test`
   - `./script/build_and_run.sh --verify`
4. Add a separate release workflow for tagged builds that:
   - archives the `.app`
   - uploads it as a GitHub release asset
   - keeps the release artifact distinct from the source tree

## Practical Handoff

If the goal is only documentation prep, stop after Phase 1.

If the goal includes packaging, the next file list should identify:

- any new workflow files under `.github/workflows/`
- any release metadata files
- any doc files that need to point at the packaging workflow

That keeps the Mac companion cleanly separable from the active source work while still making it easy to publish later.
