# Contributing to Babushka

## Development Setup

1. Install Xcode 16.2+ from the Mac App Store
2. Install mkvtoolnix: `brew install mkvtoolnix`
3. Clone the repository
4. Open `Babushka.xcodeproj` in Xcode
5. Build and run

## Code Style

- Swift 6 with strict concurrency checking
- MVVM architecture — no business logic in Views
- Services as `actor` types
- ViewModels as `@Observable` `@MainActor` classes
- Models as `Codable` `Sendable` structs
- Structs with 8+ properties group related fields into nested types

## Running Tests

```bash
xcodebuild -project Babushka.xcodeproj -scheme Babushka test
```

Tests require mkvtoolnix to be installed. Integration tests download MKV files from the matroska-test-files repository (cached in the system temp directory).

## Project Structure

```
Babushka/
├── BabushkaApp.swift          # App entry point
├── Models/                    # Codable data models
├── Services/                  # mkvtoolnix integration
├── ViewModels/                # Observable state management
└── Views/                     # SwiftUI views
BabushkaTests/
├── TestFileManager.swift      # Test file download/caching
├── Models/                    # Model parsing and preset tests
├── Services/                  # E2E service tests
└── ViewModels/                # ViewModel state tests
```

## Submitting Changes

1. Create a feature branch
2. Make your changes
3. Ensure all tests pass
4. Submit a pull request with a clear description
