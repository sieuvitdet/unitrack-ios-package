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

#### Firebase modules — Messaging / Crashlytics / RemoteConfig

`UniTrackFirebase` ships helpers for the three other Firebase modules so the
app can keep one analytics façade. Each helper compiles to a no-op when the
corresponding module isn't linked, so you only pay for what you import.

**Messaging — keep your delegate, add one line per callback:**

```swift
import UniTrackFirebase
import FirebaseMessaging
import UserNotifications

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        UniTrackFirebaseMessaging.handleTokenUpdate(fcmToken)  // fires fcm_token_updated
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ c: UNUserNotificationCenter,
                                 didReceive response: UNNotificationResponse,
                                 withCompletionHandler done: @escaping () -> Void) {
        UniTrackFirebaseMessaging.handleNotificationClicked(response)
        done()
    }
    func userNotificationCenter(_ c: UNUserNotificationCenter,
                                 willPresent n: UNNotification,
                                 withCompletionHandler done: @escaping (UNNotificationPresentationOptions) -> Void) {
        UniTrackFirebaseMessaging.handleNotificationReceivedForeground(n)
        done([.banner, .sound])
    }
}
```

For silent / background pushes:

```swift
func application(_ app: UIApplication,
                 didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                 fetchCompletionHandler handler: @escaping (UIBackgroundFetchResult) -> Void) {
    UniTrackFirebaseMessaging.handleSilentPush(userInfo)
    handler(.newData)
}
```

**Crashlytics — record non-fatal errors + breadcrumbs:**

```swift
do {
    try checkoutService.submit()
} catch {
    UniTrackFirebaseCrashlytics.recordError(error, userInfo: ["step": "submit"])
}

UniTrackFirebaseCrashlytics.log("entered checkout step 2")
UniTrackFirebaseCrashlytics.setCustomKey("cart_size", 3)
```

`recordError` calls `Crashlytics.record(error:)` AND fires `application_error`
through UniTrack, so the portal + Snowplow see the same incident.
`UniTrack.identify(userId:)` automatically syncs to `Crashlytics.setUserID`.

> dSYM upload is the app's responsibility — add a "Run script" Build Phase
> that calls `${PODS_ROOT}/FirebaseCrashlytics/run` (or the SPM equivalent
> `${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run`)
> and configure `Debug Information Format = DWARF with dSYM File` for Release.

**RemoteConfig — one API, portal first, Firebase RC fallback:**

```swift
// At app startup, after UniTrack.initialize:
FirebaseProvider.fetchRemoteConfig { _ in
    // RC values now in memory; UniTrack.getRemoteValue can read them.
}

// Anywhere in the app:
let copy: String  = UniTrack.getRemoteValue("home_banner_copy", default: "Welcome")
let bucket: Int   = UniTrack.getRemoteValue("ab_bucket", default: 0)
let enabled: Bool = UniTrack.getRemoteValue("feature_x", default: false)
```

Resolve order: portal `sdk_config.custom_values[key]` → Firebase RemoteConfig
→ `defaultValue`. Edit the portal bag under **Config → Custom values** with
one `key=value` per line — typed booleans (`true`/`false`), integers, and
decimals are coerced automatically, everything else is a string.

> Call `UniTrackRemoteConfig.primeLatest(apiKey:)` once before the first
> `getRemoteValue` query if you want portal values served from the on-disk
> cache during the cold-start window (before the async fetch returns).

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
