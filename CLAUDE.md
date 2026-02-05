# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
# Build for iOS Simulator (iPhone 17)
xcodebuild -project ExcuseMaster.xcodeproj -scheme ExcuseMaster \
  -destination 'platform=iOS Simulator,name=iPhone 17' build

# Install and launch on booted simulator
xcrun simctl install booted <path-to-DerivedData>/Build/Products/Debug-iphonesimulator/ExcuseMaster.app
xcrun simctl launch booted com.excusemaster.ExcuseMaster

# Open in Xcode
open ExcuseMaster.xcodeproj
```

No external dependencies (no SPM, CocoaPods, or Carthage). No test targets exist yet.

## Architecture

**Pure SwiftUI iOS app** (no UIKit views) with a single-target Xcode project. Three source files:

- **ExcuseMasterApp.swift** — `@main` entry point, creates a `WindowGroup` with `ContentView`.
- **ContentView.swift** — All UI, models, and enums in one file. Contains three tabs (Generate, History, Settings) split into computed properties (`generateTab`, `historyTab`, `settingsTab`). Also defines all data types: `Category`, `Tone`, `AIModel`, `Excuse` struct, and the reusable `ExcuseRowView`.
- **ExcuseGeneratorService.swift** — API client for x.ai's OpenAI-compatible `/v1/chat/completions` endpoint. Handles request construction, network error mapping, and heuristic parsing of the LLM's free-text response into structured `Excuse` objects.

## Data Flow

`ContentView` creates `ExcuseGeneratorService` as a computed property using `@AppStorage`-backed `apiKey` and `selectedModel`. Generation is triggered via `Task {}` blocks. Results flow back into `@State` properties and are persisted to `UserDefaults` as JSON-encoded `[Excuse]` under the key `"excuseHistory"`.

## Key Conventions

- **Persistence**: `@AppStorage` for settings (`apiKey`, `selectedModel`), `UserDefaults` with manual JSON encoding for history. No Core Data or SwiftData.
- **Networking**: Raw `URLSession` with `JSONSerialization` (no Codable for API request/response). Custom `ExcuseGeneratorError` enum with `LocalizedError` conformance provides user-friendly messages for HTTP 401/403/429/5xx and network failures.
- **Parsing**: The LLM response is free-text, not JSON. `parseExcuses(from:)` uses heuristic block splitting and line-by-line keyword matching. It falls back to returning raw content as a single `Excuse` if structured parsing fails.
- **Share sheet**: Uses `UIActivityViewController` presented via `UIApplication.shared.connectedScenes` (the only UIKit dependency).
- **Adding new source files**: Must be manually added to `project.pbxproj` in four places: `PBXBuildFile`, `PBXFileReference`, the `ExcuseMaster` `PBXGroup` children list, and the `PBXSourcesBuildPhase` files list.

## Build Configuration

- **Bundle ID**: `com.excusemaster.ExcuseMaster`
- **Deployment Target**: iOS 26.0
- **Swift Version**: 5.0
- **Supported Devices**: iPhone and iPad (universal)
- **Code Signing**: Automatic
