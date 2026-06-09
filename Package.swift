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
        // Firebase pinned tight to 10.27.x.
        //
        // SPM requires every imported module to have a declared target
        // dependency, even when wrapped in `#if canImport(...)` — so we
        // can't drop the Firebase package entirely. The tight pin keeps
        // the resolved version EXACTLY matching what FPT Life production
        // ships via CocoaPods (Firebase 10.27.0), so the linker doesn't
        // end up with two diverged Firebase trees and duplicate symbols.
        //
        // Earlier 0.3.19 used `..<"10.30.0"` which SwiftPM resolved up to
        // 10.29.0 — pulling in 14 transitive Google/abseil/gRPC packages
        // (visible in any consuming app's Package Dependencies pane).
        // 10.27.0 has a leaner tree + matches the Pods version exactly.
        //
        // App-side requirement: pick ONE package manager for Firebase.
        //   • If CocoaPods owns Firebase 10.27.0 → remove the 4 SPM
        //     Firebase products from the app target's "Frameworks,
        //     Libraries, and Embedded Content" so the linker uses Pods.
        //   • If SPM owns Firebase → remove the `pod 'Firebase/...'`
        //     entries from the Podfile.
        // Never both.
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", "10.27.0"..<"10.28.0"),
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
                // given module still builds. Apps DO need them as SPM product
                // links here so the modules are resolvable to the Swift
                // compiler (SwiftPM's import resolution doesn't honour
                // canImport — only the linker step does).
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
