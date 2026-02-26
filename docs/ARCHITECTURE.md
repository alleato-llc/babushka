# Architecture

## Overview

Babushka is a macOS SwiftUI application that inspects and edits MKV files by leveraging mkvtoolnix's CLI tools (`mkvmerge`, `mkvpropedit`, `mkvextract`).

## Data Flow

### Inspection
```
mkvmerge -J <file> → JSON → MKVToolnixService → MKVIdentification → FileViewModel → Views
```

### Editing
```
User edits → TrackPropertyEdits → PendingChangeset → ResolvedChangeset → MKVToolnixService
                                                                          ├─ mkvpropedit (property-only)
                                                                          └─ mkvmerge -o  (structural)
```

1. User opens an MKV file
2. `MKVToolnixService` spawns `mkvmerge -J` as a child process
3. JSON output is decoded into `MKVIdentification` model tree
4. `FileViewModel` constructs a sidebar tree (groups tracks by type)
5. Views render the data via NavigationSplitView
6. User edits accumulate in `PendingChangeset` as `ChangesetOperation` entries
7. On apply, the changeset resolves and dispatches to the appropriate mkvtoolnix tool

## Layers

### Models (`Babushka/Models/`)

Pure data types, all `Codable` and `Sendable`:

- **MKVIdentification** — Root type for mkvmerge JSON output
- **MKVContainer / ContainerProperties** — File container metadata (duration, muxing app, dates)
- **MKVTrack / TrackProperties** — Track data with nested grouping:
  - `TrackProperties.Flags` — default, enabled, forced, original, visual impaired, commentary
  - `TrackProperties.VideoInfo` — pixel/display dimensions, crop values, stereo mode, packetizer
  - `TrackProperties.AudioInfo` — channels, sampling frequency, bits per sample
- **MKVAttachment / AttachmentProperties** — Embedded file attachments
- **MKVTags** — Global and per-track tag metadata
- **SidebarItem** — Enum representing sidebar tree nodes
- **TrackPropertyEdits** — Mutable edit state with nested grouping:
  - `TrackPropertyEdits.FlagEdits` — flag changes
  - `TrackPropertyEdits.CropEdits` — pixel crop changes
- **PendingChangeset / ResolvedChangeset** — Ordered operation queue with merge-and-diff resolution
- **TrackFileAddition** — Data for adding external tracks
- **ExportJob** — Background job state machine (pending → running → completed/failed)
- **OutputMode** — Backup original, overwrite in place, or choose location
- **CropPreset** — Aspect ratio presets for pixel crop editing
- **CodecExtensionMap** — Codec ID → file extension lookup for track export
- **TrackPropertyKey** — Enum of editable property identifiers

`TrackProperties` uses a custom `init(from: Decoder)` with `DynamicCodingKeys` to capture all `tag_*` JSON keys into a `[String: String]` dictionary. The custom Codable implementation flattens nested structs to/from the flat JSON format that mkvmerge produces.

### Services (`Babushka/Services/`)

Actor-isolated types for safe concurrent access:

- **MKVToolnixLocator** — Finds mkvmerge/mkvpropedit/mkvextract binaries by searching known paths (`/opt/homebrew/bin`, `/usr/local/bin`) and falling back to `which`. Validates executability and parses version strings.
- **MKVToolnixService** — Executes mkvtoolnix commands:
  - `identify()` — runs `mkvmerge -J`, decodes JSON
  - `applyChangeset()` — routes to mkvpropedit (property-only) or mkvmerge (structural changes)
  - `extractTrack()` / `extractAttachment()` — runs mkvextract

### ViewModels (`Babushka/ViewModels/`)

`@Observable`, `@MainActor` classes:

- **AppViewModel** — App-wide state: tool availability, open files, navigation selection, NSOpenPanel, export operations, undo/redo
- **FileViewModel** — Per-file state: loading state machine, parsed identification data, sidebar tree construction, changeset management, effective value queries (merges pending edits with original values), property modification tracking
- **JobsViewModel** — Background job queue: execution, status monitoring, completion callbacks

### Views (`Babushka/Views/`)

SwiftUI views with no business logic:

- **BabushkaApp** — `@main` entry, `WindowGroup`, Cmd+O command, About window, Settings window
- **ContentView** — `NavigationSplitView` with sidebar/detail split, drag-and-drop, detail router
- **SidebarView** — List with DisclosureGroups for track type groups
- **FileSummaryView** — Container info, clickable track list, global tags
- **TrackDetailView** — Full property inspector with type-specific sections, inline editing for flags/name/language/crop
- **TrackRowView** — Reusable track summary (icon, codec, language badge, flag badges)
- **TrackReorderView** — Drag-to-reorder track list
- **AttachmentDetailView** — Attachment metadata with image preview
- **PendingChangesBar** — Sticky bar showing pending change count with cancel/apply actions
- **WelcomeView** — Shown when no file is open
- **AboutView** — App info, mkvtoolnix status, license
- **SettingsView** — Output mode configuration
- **JobsPopoverView** — Background job status popover

## Navigation

Navigation is selection-driven:

1. `AppViewModel.selectedSidebarItem` is bound to the sidebar's `List(selection:)`
2. `ContentView` uses a detail router that switches on the selected `SidebarItem`
3. Clicking a track row in `FileSummaryView` updates `selectedSidebarItem`, which navigates both the sidebar and detail

## Editing Pipeline

1. User toggles a flag or changes a value in `TrackDetailView`
2. An `onChange` handler creates a `TrackPropertyEdits` with just the changed field
3. `FileViewModel.editTrackProperties()` appends a `.editProperties` operation to the `PendingChangeset`
4. `resolvedChangeset` merges all operations chronologically — last write wins per field
5. `effective*` methods on `FileViewModel` return the merged value (edit ?? original) for display
6. `isPropertyModified` checks whether a field has a pending edit (shown as an orange dot)
7. On apply, `ResolvedChangeset` diffs merged edits against originals, discarding no-ops
8. `MKVToolnixService` routes to mkvpropedit (property-only) or mkvmerge (structural changes like remove/add/reorder)

## Concurrency

- Services use `actor` isolation for thread-safe Process execution
- ViewModels are `@MainActor` for safe UI updates
- Models are `Sendable` structs
- Async/await is used throughout (no callbacks or Combine)

## Testing

Tests use Swift Testing (`import Testing`) with real MKV files:

- `TestFileManager` downloads and caches test files from the matroska-test-files GitHub repo
- `MKVIdentificationTests` — JSON parsing with embedded sample data, round-trip encoding
- `MKVToolnixLocatorTests` — Binary location verification
- `MKVToolnixServiceTests` — End-to-end identification against real MKV files
- `FileViewModelTests` — Sidebar tree construction and state transitions
- `CropPresetTests` — Aspect ratio crop value calculations
