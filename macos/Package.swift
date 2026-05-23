// swift-tools-version: 5.9
import PackageDescription

// Tap (desktop) — three SPM products, same shape as alfred-swift,
// stats-swift, espresso-swift et al:
//
//   • `TapPane` (.dynamic) — the whole feature: store, API client,
//     keychain, SwiftUI popover. Embedded in `Tap.app/Contents/
//     Frameworks` so the MattsSoftware launcher can dlopen it and
//     show Tap as a pane in its unified menu-bar popover, with no
//     copy of the code in the launcher itself.
//
//   • `Tap` (.executable) — thin @main host shim that hosts that
//     same pane in its own NSStatusItem + transient NSPopover. This
//     is the standalone menu-bar app.
//
//   • `TapShared` (.library, .static) — App Group id, the codable
//     `SharedTapState` the host writes to the Group Container and
//     the widget reads, and the `AppIntent`s the widget triggers
//     (`RefreshIntent` / `ExecuteCommandIntent`). Consumed by both
//     `TapPane` (writes) and the widget extension at
//     `Widget/TapWidgets.xcodeproj` (reads + emits intents).
//
// The widget extension can't live in SwiftPM (SR-14944: SPM has no
// `productType = com.apple.product-type.app-extension`, so a
// SwiftPM-built widget binary fatal-errors in ExtensionFoundation
// at launch — see the deep-dive in alfred-swift/Package.swift).
// The Xcode subproject consumes `TapShared` via local package
// dependency so the widget shares one source of truth for the
// SharedState models + intent definitions.
let package = Package(
    name: "Tap",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Tap", targets: ["Tap"]),
        .library(name: "TapPane", type: .dynamic, targets: ["TapPane"]),
        .library(name: "TapShared", targets: ["TapShared"])
    ],
    dependencies: [
        .package(path: "../../suitekit-swift")
    ],
    targets: [
        .target(
            name: "TapShared",
            path: "Sources/TapShared"
        ),
        .target(
            name: "TapPane",
            dependencies: [
                "TapShared",
                .product(name: "SuiteKit", package: "suitekit-swift")
            ],
            path: "Sources/TapPane",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "Tap",
            dependencies: [
                "TapPane",
                "TapShared",
                .product(name: "SuiteKit", package: "suitekit-swift")
            ],
            path: "Sources/Tap"
        )
    ]
)
