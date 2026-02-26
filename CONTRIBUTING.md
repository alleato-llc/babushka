# Contributing to Babushka

## Development Setup

1. Install Xcode 16.2+ from the Mac App Store
2. Install mkvtoolnix: `brew install mkvtoolnix`
3. Clone the repository
4. Run `./scripts/setup-hooks.sh` to enable commit message validation
5. Open `Babushka.xcodeproj` in Xcode
6. Build and run

## Code Style

- Swift 6 with strict concurrency checking
- MVVM architecture — no business logic in Views
- Services as `actor` types
- ViewModels as `@Observable` `@MainActor` classes
- Models as `Codable` `Sendable` structs
- Structs with 8+ properties group related fields into nested types
- If a folder reaches 8+ files, group related files into subfolders

## Running Tests

```bash
xcodebuild -project Babushka.xcodeproj -scheme Babushka test
```

Tests require mkvtoolnix to be installed. Integration tests download MKV files from the matroska-test-files repository (cached in the system temp directory).

## Project Structure

```
Babushka/
├── BabushkaApp.swift          # App entry point
├── Models/
│   ├── MKV/                   # MKV data models (Identification, Container, Track, Attachment, Tags)
│   ├── Changeset/             # Edit state and changeset pipeline
│   ├── SidebarItem.swift      # Sidebar tree node enum
│   ├── CodecExtensionMap.swift
│   ├── ExportJob.swift
│   ├── OutputMode.swift
│   └── CropPreset.swift
├── Services/
│   ├── MKVToolnix/            # mkvtoolnix integration (facade, sub-services, process runner)
│   ├── MkvmergeCommandBuilder.swift
│   ├── MkvpropeditCommandBuilder.swift
│   ├── FileDialogService.swift
│   └── FileOperationsService.swift
├── ViewModels/                # Observable state management
│   ├── AppViewModel.swift
│   ├── FileViewModel.swift
│   ├── JobsViewModel.swift
│   └── SidebarTreeBuilder.swift
└── Views/
    ├── Detail/                # Track, attachment, and file detail views
    ├── ContentView.swift
    ├── SidebarView.swift
    └── ...                    # Other top-level views
BabushkaTests/
├── TestFileManager.swift      # Test file download/caching
├── Models/                    # Model parsing and preset tests
├── Services/                  # E2E service tests and command builder tests
└── ViewModels/                # ViewModel state and sidebar builder tests
```

## Commit Messages

This project uses [Conventional Commits](https://www.conventionalcommits.org/). All commit messages must follow the format:

```
<type>[optional scope][optional !]: <description>
```

**Types:** `feat` `fix` `docs` `chore` `ci` `test` `refactor` `perf` `build` `style` `revert`

**Examples:**
```
feat: add batch export support
fix(parser): handle empty subtitle tracks
docs(readme): update install instructions
feat!: redesign track editing API
chore: update mkvtoolnix version requirement
```

The `hooks/commit-msg` hook validates this format automatically. Run `./scripts/setup-hooks.sh` to enable it.

## Submitting Changes

1. Create a feature branch
2. Make your changes using Conventional Commits format
3. Ensure all tests pass
4. Submit a pull request with a clear description

## Release Process

See [docs/RELEASE.md](docs/RELEASE.md) for the full release pipeline, configuration, and troubleshooting.
