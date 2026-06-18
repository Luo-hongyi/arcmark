# Fork Changes

## Scope

This document records all changes made in this fork after diverging from the upstream baseline on the current repository.

- Upstream baseline: `18e1b4b731f9f60d493e8d55b9d67b6be0c5ce51` (`Release v0.1.14`)
- Current branch: `codex/imports-and-readonly`
- This document includes:
  - commits reachable from `codex/imports-and-readonly` after the baseline
  - one additional fork-only branch not merged into the current branch
- This document does not count untracked `AGENTS.md` as a project change

> Branch history: this branch was originally named `codex/icloud-arc-overwrite`. It
> was renamed to `codex/imports-and-readonly` because the scope grew beyond the
> iCloud work to cover multiple importers and a workspace-creation robustness fix.
> The old remote branch was deleted; commits and history are unchanged.

## Current Branch: committed changes

The branch groups four related themes: iCloud readonly sync, an Arc import
rewrite (with workspace icons), a Tabbit importer, and a workspace-creation
robustness fix. Commits are listed below in chronological order.

### Commit `b2fb09d871b0168226d69ed10792015de40f1e73`

Subject: `Add iCloud readonly sync mode and Arc import fixes`

Main behavior changes:

- Added a sync-role concept with `primary` and `secondary` modes through `SyncRole`.
- `secondary` mode is effectively readonly for shared iCloud-backed data:
  - local shared-data writes are blocked
  - the device reads from iCloud and treats iCloud as the source of truth
  - UI state that does not mutate shared data can still work
- Settings gained a readonly toggle and import controls now respect write capability.
- Data store logic was updated so readonly iCloud devices do not create or overwrite the shared `data.json`.
- App model gained shared-data write guards and a `replaceAllWorkspaces(with:)` path used by import/overwrite flows.
- Arc import behavior was tightened so repeat imports replace workspace content instead of merging old and new data.
- Related UI behavior was adjusted so readonly mode disables import actions and keeps the app usable without pretending writes will succeed.

Primary implementation areas:

- Sync role and persistence rules:
  - `Sources/ArcmarkCore/Constants.swift`
  - `Sources/ArcmarkCore/DataStore.swift`
  - `Sources/ArcmarkCore/AppModel.swift`
  - `Sources/ArcmarkCore/Notes/NoteStorage.swift`
- Settings and readonly UI behavior:
  - `Sources/ArcmarkCore/SettingsContentViewController.swift`
  - `Sources/ArcmarkCore/Components/Buttons/SettingsActionButton.swift`
  - `Sources/ArcmarkCore/WorkspaceSwitcherView.swift`
  - `Sources/ArcmarkCore/NodeRowView.swift`
- Arc import and workspace overwrite flow:
  - `Sources/ArcmarkCore/ArcImportService.swift`
  - `Sources/ArcmarkCore/MainViewController.swift`
  - `Sources/ArcmarkCore/ViewControllers/NodeListViewController.swift`
- Model and filtering support:
  - `Sources/ArcmarkCore/Models.swift`
  - `Sources/ArcmarkCore/NodeFiltering.swift`
  - `Sources/ArcmarkCore/ScheduledLinkFiltering.swift`
  - `Sources/ArcmarkCore/NodeCollectionViewItem.swift`
  - `Sources/ArcmarkCore/Notes/NoteServer.swift`
  - `Sources/ArcmarkCore/AppDelegate.swift`
  - `Sources/ArcmarkCore/ChromeImportService.swift`

Tests added or updated in this commit:

- `Tests/ArcmarkTests/ArcImportTests.swift`
- `Tests/ArcmarkTests/DataStoreBackupTests.swift`
- `Tests/ArcmarkTests/ModelTests.swift`
- `Tests/ArcmarkTests/NoteStorageTests.swift`

### Commit `8a96283cf8672a009c51a750d1600451cf41708e`

Subject: `Import Arc workspace icons and fix updates`

Main behavior changes:

- Arc workspace import now reads workspace icons from Arc data and maps them into `Workspace.customIcon`.
- Emoji workspace icons imported from Arc are rendered in both the top workspace switcher and the Settings workspace list.
- The workspace icon display path was extended beyond link/note icons so workspace rows and workspace chips can render imported emoji icons correctly.
- Packaging/build configuration was updated so the new emoji icon view is part of the package build.

Primary implementation areas:

- Arc workspace icon extraction:
  - `Sources/ArcmarkCore/ArcImportService.swift`
  - `Sources/ArcmarkCore/Models.swift`
  - `Tests/ArcmarkTests/ArcImportTests.swift`
- Workspace icon rendering:
  - `Sources/ArcmarkCore/Components/EmojiIconView.swift`
  - `Sources/ArcmarkCore/WorkspaceRowView.swift`
  - `Sources/ArcmarkCore/WorkspaceSwitcherView.swift`
  - `Sources/ArcmarkCore/WorkspaceCollectionViewItem.swift`
  - `Sources/ArcmarkCore/MainViewController.swift`
- Packaging and minor integration:
  - `Package.swift`
  - `Sources/ArcmarkCore/SettingsContentViewController.swift`
  - `Sources/ArcmarkCore/ChromeImportService.swift`
  - `Tests/ArcmarkTests/ModelTests.swift`

### Commit `e25e5ed` — Tabbit importer

Subject: `Add Tabbit import from live Chromium session`

Behavior added:

- Settings now exposes `Import from Tabbit Pages`.
- Import is blocked in readonly mode using the same shared-data write gate as Arc import.
- Import writes into a special workspace named `Tabbit`.
- Re-import replaces the existing `Tabbit` workspace content instead of merging old and new pages.

Implementation notes:

- The first Tabbit importer attempt used the wrong data sources: generic session-string scanning and sync LevelDB fragments. That approach mixed stale history, sync artifacts, and current tabs, so group names and page membership were wrong.
- The committed implementation no longer depends on those unstable sources. It parses the latest `Library/Application Support/Tabbit/Default/Sessions/Session_*` file directly as Chromium session commands:
  - group metadata from session command `27`
  - tab-to-group binding from session command `25`
  - tab ordering from session command `2`
  - selected/current navigation entry per tab from session command `7`
  - navigation records from session command `6`
- It filters out Tabbit internal pages such as `group-home` and `newtab` while keeping real `session/<id>` pages when they are actual open tabs.

Files involved:

- `Sources/ArcmarkCore/TabbitImportService.swift` (new)
- `Sources/ArcmarkCore/SettingsContentViewController.swift`

### Commit `15597e4` — workspace creation robustness + stale test fix

Subject: `Make workspace creation robust and fix stale note-server test`

Behavior changes:

- `AppModel.createWorkspace` now takes an optional `items:` parameter (default `[]`) so import flows can build a workspace in one shot instead of relying on the implicit "create then mutate the newly selected workspace" dance.
- `SettingsContentViewController.applyChromeImport` is converted to use the new `items:` parameter, which also fixes the old path silently dropping `.note` and `.separator` nodes — the previous `addNodeToWorkspace` helper had no case for them.
- The now-unused `addNodeToWorkspace` helper is removed.

Relationship to `codex/arc-import-batch-workspaces`:

- That branch fixed the same underlying fragility in the old Arc import path by giving `createWorkspace` an `items:` parameter. It is **not** merged into this branch.
- The Arc import path on this branch no longer touches that code at all: it was rewritten to build `Workspace` values directly and apply them via `replaceAllWorkspaces`, so the original bug does not reproduce for Arc imports.
- This commit applies the equivalent hardening directly (rather than cherry-picking), and extends it to the Chrome import path and to `.note`/`.separator` nodes that the other branch's narrower fix did not cover. The other branch is intentionally left as a standalone fork branch.

Test fix:

- `NoteServerTests.testGetReturnsNoteJSON` was stale: it still asserted the pre-#54 `# Untitled` starter content after notes were changed (in `2636c48`, "show placeholder instead of starter content for new notes") to start empty with a CSS placeholder. The assertion is updated to expect empty content, matching the current behavior and the parallel assertion in `ModelTests.testCreateNoteAtRoot`.

Tests added:

- `ModelTests.testCreateWorkspaceWithInitialItemsPersistsTree` — pins that folders, links, notes, and separators all survive a create-with-items round trip.

Files involved:

- `Sources/ArcmarkCore/AppModel.swift`
- `Sources/ArcmarkCore/SettingsContentViewController.swift`
- `Tests/ArcmarkTests/ModelTests.swift`
- `Tests/ArcmarkTests/NoteServerTests.swift`

## Other fork-only branch not merged into current branch

### Branch `codex/arc-import-batch-workspaces`

Commit: `4f03f7bf5a401b55e4f3534ae24ec0c5f37649e4`

Subject: `Preserve imported workspace items when creating Arc workspaces`

What it changes:

- Adjusts Arc workspace creation/import flow so imported workspace items are preserved while the workspace is created.
- Removes redundant or conflicting item-reset behavior from the Settings import path.
- Adds model coverage for the corrected creation/import sequence.

Files involved:

- `Sources/ArcmarkCore/AppModel.swift`
- `Sources/ArcmarkCore/SettingsContentViewController.swift`
- `Tests/ArcmarkTests/ModelTests.swift`

This branch is not merged into `codex/imports-and-readonly`. As noted above, the
equivalent (and broader) hardening has been applied directly on the current
branch in commit `15597e4`. The standalone branch is kept for history.

## Verification status

Checks run after the most recent commit on this branch (`15597e4`):

- `swift build`: passed
- `swift test`: **113 / 113 tests passed** (0 failures)

The previously-failing `NoteServerTests.testGetReturnsNoteJSON` is now fixed.
