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
                "AppConstants.swift",
                "PVApp.swift",
                "StartView.swift", 
                "ImageBrowserViewModel.swift",
                "ListView.swift",
                "SingleImageView.swift",
                "UnifiedCacheManager.swift",
                "UnifiedDataManager.swift",
                "UnifiedFocusManager.swift",
                "UnifiedWindowManager.swift",
                "ImageBrowserViewStyles.swift",
                "LayoutCalculatorJus.swift",
                "LayoutThumbView.swift",
                "LayoutCalculator.swift",
                "LayoutCalculatorProtocol.swift"
            ],
            resources: [
            ],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist", "-Xlinker", "Info.plist"])
            ]
        ),
    ]
)
