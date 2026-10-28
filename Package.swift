// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Unzippy",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Unzippy", targets: ["Unzippy"]),
        .executable(name: "unzippy-cli", targets: ["UnzippyCLI"]),
        .library(name: "UnzippyCore", targets: ["UnzippyCore"]),
    ],
    targets: [
        .systemLibrary(name: "CArchive", path: "Sources/CArchive"),
        .target(
            name: "UnzippyCore",
            dependencies: ["CArchive"]
        ),
        .executableTarget(
            name: "Unzippy",
            dependencies: ["UnzippyCore"]
        ),
        .executableTarget(
            name: "UnzippyCLI",
            dependencies: ["UnzippyCore"]
        ),
    ]
)
