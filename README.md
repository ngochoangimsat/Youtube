# YouTube Viewer for iPhone

SwiftUI iOS 16+ app for playing YouTube videos through the official embedded player.

Features: paste YouTube links including Shorts, search with optional YouTube Data API v3 key, save favorites on device, share videos, light/dark mode.

## Build

Install XcodeGen on macOS (`brew install xcodegen`), then run:

```sh
xcodegen generate
xcodebuild -project YoutubeViewer.xcodeproj -scheme YoutubeViewer -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

GitHub Actions builds a Simulator-only ZIP. For installing on a physical iPhone, Apple code signing and a device build are required.

Search requires a Google Cloud project with YouTube Data API v3 enabled; enter its API key in Settings. Avoid distributing unrestricted keys. Playing pasted links does not require a key.

This app uses the embedded YouTube player and does not download or bypass video restrictions. Not affiliated with YouTube or Google.
