// swift-tools-version: 5.6

import PackageDescription

let package = Package(
    name: "PV",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "PV",
            targets: ["PV"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "PV",
            dependencies: [],
            path: ".",
            exclude: [],
            sources: [
                "PVApp.swift",
                "StartView.swift", 
                "ImageBrowserViewModel.swift",
                "ListView.swift",
                "SingleImageView.swift",
                "SettingsView.swift",
                "UnifiedCacheManager.swift",
                "AppSettings.swift",
                "UnifiedFocusManager.swift",
                "UnifiedWindowManager.swift",
                "ImageBrowserHelpers.swift",
                "ViewStyles.swift"
            ],
            resources: [
            ],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist", "-Xlinker", "Info.plist"])
            ]
        )
    ]
)
