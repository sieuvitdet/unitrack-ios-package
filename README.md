# UniTrack — iOS Swift Package

Universal mobile analytics SDK for native iOS/tvOS/macOS apps. One init call gives
you automatic screen tracking, tap tracking, `URLSession` network tracking, memory
warning reports, JSON parse-error reports, crash reports, and offline event queueing.
The networking/queue/session logic is a shared C++ core (vendored as source);
the Swift layer handles auto-capture via swizzling.

## Installation (Swift Package Manager)

In Xcode: **File ▸ Add Package Dependencies…** and enter the repository URL:

```
https://github.com/<your-org>/UniTrack-iOS.git
```

Or in a `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/<your-org>/UniTrack-iOS.git", from: "1.0.0"),
]
```

Then add the product(s) you need to your target:

| Product            | When to add                                            |
| ------------------ | ------------------------------------------------------ |
| `UniTrack`         | Always — the core SDK.                                 |
| `UniTrackFirebase` | To forward events to Firebase Analytics.               |
| `UniTrackSnowplow` | To forward events to a Snowplow collector.             |

> The provider products pull in their vendor SDK (firebase-ios-sdk /
> snowplow-ios-tracker). Add a provider product only if you use it.

## Quick start

```swift
import UniTrack

// In application(_:didFinishLaunchingWithOptions:)
UniTrack.initialize(apiKey: "YOUR_API_KEY", endpoint: "https://your-ingest.example.com")
```

### With Firebase

```swift
import UniTrack
import UniTrackFirebase

UniTrack.addProvider(FirebaseProvider())   // requires GoogleService-Info.plist
UniTrack.initialize(apiKey: "YOUR_API_KEY")
```

### With Snowplow

```swift
import UniTrack
import UniTrackSnowplow

UniTrack.addProvider(SnowplowProvider(
    endpoint: "https://collector.example.com",
    appId: "701"))
UniTrack.initialize(apiKey: "YOUR_API_KEY")
```

## Requirements

- iOS 13+ / tvOS 13+ / macOS 11+
- Swift 5.7+
- Links the system `sqlite3` (offline queue) — no extra setup needed.

## Note on the C++ core

`Sources/UniTrackCore` is a **copy** of the shared C++ core from the UniTrack
monorepo (`core/`), vendored here as real files so the package is self-contained
over SPM. When the upstream core changes, re-sync with `scripts/sync_core.sh`.
