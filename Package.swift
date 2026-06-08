// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "UniTrack",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .macOS(.v11)
    ],
    products: [
        // Core SDK — auto screen/tap/network/crash/OOM tracking + offline queue.
        .library(name: "UniTrack", targets: ["UniTrack"]),
        // Optional providers. Each pulls in its vendor SDK, so keep them as
        // separate products an app opts into.
        .library(name: "UniTrackFirebase", targets: ["UniTrackFirebase"]),
        .library(name: "UniTrackSnowplow", targets: ["UniTrackSnowplow"]),
    ],
    dependencies: [
        // Firebase pinned to a range that matches the version FPT Life
        // already ships via CocoaPods (10.27.0). Without the pin, SwiftPM
        // would pull the latest 10.x (vd 10.29.0) and the app linker would
        // end up with TWO copies of every Firebase symbol — one from Pods,
        // one from .swiftpm/checkouts — bloating the binary by ~5-8 MB and
        // risking duplicate-symbol crashes (especially in the Crashlytics
        // signal handler).
        //
        // App-side requirement: pick ONE package manager for Firebase.
        //   • If CocoaPods owns Firebase → comment out the
        //     `.product(name: "FirebaseAnalytics", ...)` lines in the app's
        //     Xcode target's "Frameworks, Libraries, and Embedded Content"
        //     so the linker doesn't pull the SPM copy.
        //   • If SPM owns Firebase → remove the 4 `pod 'Firebase/...'`
        //     entries from the Podfile + `pod install`.
        // Never both at the same major version range.
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", "10.27.0"..<"10.30.0"),
        .package(url: "https://github.com/snowplow/snowplow-ios-tracker.git", from: "6.0.0"),
    ],
    targets: [
        // C/C++ core, vendored as real source files (copied from the monorepo's
        // core/ — not a symlink, so this package is self-contained when cloned
        // over SPM). SPM compiles the .cpp into the framework. Only include/
        // is exposed publicly (the ABI-stable C header).
        .target(
            name: "UniTrackCore",
            path: "Sources/UniTrackCore",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
                .headerSearchPath("src")
            ],
            cxxSettings: [
                .headerSearchPath("include"),
                .headerSearchPath("src")
            ],
            linkerSettings: [
                // The offline queue persists events to SQLite (system library).
                .linkedLibrary("sqlite3")
            ]
        ),
        .target(
            name: "UniTrack",
            dependencies: ["UniTrackCore"],
            path: "Sources/UniTrack"
            // No unsafeFlags here — SPM forbids downstream packages from depending
            // on a package that uses .unsafeFlags, so any app that imports this
            // package as a dependency (vd FPT Life) hits "cannot be used as a
            // dependency because it uses unsafe build flags". The
            // -alias-module-names-in-module-interface flag was only needed when
            // building an xcframework with BUILD_LIBRARY_FOR_DISTRIBUTION=YES;
            // for regular SPM consumption it's unnecessary.
        ),
        .target(
            name: "UniTrackFirebase",
            dependencies: [
                "UniTrack",
                .product(name: "FirebaseAnalytics", package: "firebase-ios-sdk"),
                // Optional Firebase modules — each helper inside this target is
                // wrapped in `#if canImport(...)` so an app that doesn't link a
                // given module still builds.
                .product(name: "FirebaseMessaging",    package: "firebase-ios-sdk"),
                .product(name: "FirebaseCrashlytics",  package: "firebase-ios-sdk"),
                .product(name: "FirebaseRemoteConfig", package: "firebase-ios-sdk"),
            ],
            path: "Sources/UniTrackFirebase"
        ),
        .target(
            name: "UniTrackSnowplow",
            dependencies: [
                "UniTrack",
                .product(name: "SnowplowTracker", package: "snowplow-ios-tracker"),
            ],
            path: "Sources/UniTrackSnowplow"
        ),
    ],
    cxxLanguageStandard: .cxx17
)
