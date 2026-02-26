# Babushka - Development Guide

## Project Overview
macOS SwiftUI app for inspecting and editing MKV files using mkvtoolnix CLI tools (`mkvmerge`, `mkvpropedit`, `mkvextract`).

## Build & Test Commands
```bash
# Build
xcodebuild -project Babushka.xcodeproj -scheme Babushka build

# Run tests
xcodebuild -project Babushka.xcodeproj -scheme Babushka test

# Build for testing only
xcodebuild -project Babushka.xcodeproj -scheme Babushka build-for-testing
```

## Architecture
- **Pattern**: MVVM with Service Layer
- **Data flow**: `mkvmerge -J` → JSON → `MKVToolnixService` → `MKVIdentification` → `FileViewModel` → Views
- **Editing flow**: User edits → `TrackPropertyEdits` → `PendingChangeset` → `ResolvedChangeset` → mkvpropedit/mkvmerge
- **Services**: `actor` types for thread-safe Process execution
- **Models**: `Codable`, `Sendable` structs with nested grouping (`TrackProperties.Flags`, `.VideoInfo`, `.AudioInfo`)
- **ViewModels**: `@Observable`, `@MainActor`
- **Navigation**: Selection-driven via `NavigationSplitView`

## Key Files
- `Babushka/BabushkaApp.swift` — App entry point
- `Babushka/Services/MKVToolnixService.swift` — Core service (runs mkvmerge, mkvpropedit, mkvextract)
- `Babushka/Models/MKVTrack.swift` — Track model with nested Flags/VideoInfo/AudioInfo and dynamic tag_* decoding
- `Babushka/Models/TrackPropertyEdits.swift` — Mutable edit state with nested FlagEdits/CropEdits
- `Babushka/Models/PendingChangeset.swift` — Ordered operation queue with merge-and-diff resolution
- `Babushka/ViewModels/FileViewModel.swift` — Per-file state, sidebar tree, changeset management, effective values
- `Babushka/ViewModels/AppViewModel.swift` — App-level state and navigation
- `Babushka/ViewModels/JobsViewModel.swift` — Background job execution and monitoring

## Dependencies
- **mkvtoolnix** (`mkvmerge`, `mkvpropedit`, `mkvextract`): Required at runtime. Install via `brew install mkvtoolnix`
- No third-party Swift packages

## Testing
- Uses Swift Testing framework (`import Testing`)
- Tests download real MKV files from github.com/ietf-wg-cellar/matroska-test-files
- `TestFileManager` caches downloads in system temp directory
- Tests require mkvmerge to be installed locally
- Round-trip encoding test validates JSON compatibility of nested model structs

## Conventions
- Swift 6 strict concurrency
- Sandbox disabled (needs Process execution and file access)
- Deployment target: macOS 15.0
- `TrackProperties` uses custom Codable to flatten nested structs to/from mkvmerge's flat JSON
- Structs with 8+ properties group related fields into nested types (Flags, VideoInfo, AudioInfo, FlagEdits, CropEdits)
