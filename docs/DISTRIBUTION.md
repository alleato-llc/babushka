# Distribution

## Overview

Babushka is distributed outside the Mac App Store via **Developer ID** signing and Apple notarization. This is required because the app executes external CLI tools (`mkvmerge`, `mkvpropedit`, `mkvextract`) via `Process`, which is incompatible with the App Store sandbox.

## Why Not the App Store?

The App Store requires `com.apple.security.app-sandbox` to be enabled. The sandbox blocks execution of binaries outside the app bundle, and there is no entitlement that permits running arbitrary CLI tools like mkvtoolnix. The alternatives (embedding GPL-licensed mkvtoolnix binaries, rewriting MKV parsing in Swift) are impractical.

## Build Configuration

The Xcode project is configured for Developer ID distribution:

| Setting | Value | Why |
|---------|-------|-----|
| `ENABLE_HARDENED_RUNTIME` | `YES` | Required for notarization |
| `com.apple.security.app-sandbox` | `false` | Allows `Process` execution of mkvtoolnix |
| `CODE_SIGN_STYLE` | `Automatic` | Uses Developer ID certificate from your Apple Developer account |
| `INFOPLIST_KEY_LSApplicationCategoryType` | `public.app-category.video` | App category metadata |

## Prerequisites

- An [Apple Developer Program](https://developer.apple.com/programs/) membership
- A **Developer ID Application** certificate installed in Keychain
- Xcode configured with your team (already set via `DEVELOPMENT_TEAM`)

## Manual Distribution

### 1. Archive

```bash
xcodebuild -project Babushka.xcodeproj \
  -scheme Babushka \
  -configuration Release \
  -archivePath build/Babushka.xcarchive \
  archive
```

### 2. Export

```bash
xcodebuild -exportArchive \
  -archivePath build/Babushka.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist ExportOptions.plist
```

Create `ExportOptions.plist` if it doesn't exist:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
</dict>
</plist>
```

### 3. Notarize

```bash
xcrun notarytool submit build/export/Babushka.app.zip \
  --apple-id YOUR_APPLE_ID \
  --team-id YOUR_TEAM_ID \
  --password YOUR_APP_SPECIFIC_PASSWORD \
  --wait
```

Generate an app-specific password at [appleid.apple.com](https://appleid.apple.com/account/manage) under **Sign-In and Security > App-Specific Passwords**.

### 4. Staple

```bash
xcrun stapler staple build/export/Babushka.app
```

Stapling attaches the notarization ticket to the app so it works offline without Gatekeeper needing to check Apple's servers.

### 5. Package

Create a `.dmg` for distribution:

```bash
hdiutil create -volname Babushka \
  -srcfolder build/export/Babushka.app \
  -ov -format UDZO \
  build/Babushka.dmg
```

## Automated Distribution

The GitHub Actions release workflow (`.github/workflows/release.yml`) builds and attaches a `.zip` artifact to each GitHub Release. See [RELEASE.md](RELEASE.md) for details on the automated pipeline.

To add notarization to the CI pipeline, store the following as GitHub Actions secrets:

| Secret | Value |
|--------|-------|
| `APPLE_ID` | Your Apple ID email |
| `APPLE_TEAM_ID` | `YOUR_TEAM_ID` |
| `APPLE_APP_PASSWORD` | App-specific password |
| `APPLE_CERTIFICATE_BASE64` | Developer ID certificate (base64-encoded .p12) |
| `APPLE_CERTIFICATE_PASSWORD` | Password for the .p12 file |

## Runtime Requirements

Users must have [mkvtoolnix](https://mkvtoolnix.download/) installed. The app locates the tools via `MKVToolnixLocator`, which searches common paths (`/opt/homebrew/bin`, `/usr/local/bin`).

```bash
brew install mkvtoolnix
```
