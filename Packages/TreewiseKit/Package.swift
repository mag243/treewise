// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TreewiseKit",
    defaultLocalization: "en",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "TreewiseCore", targets: ["TreewiseCore"]),
        .library(name: "TreewiseFileSystem", targets: ["TreewiseFileSystem"]),
        .library(name: "TreewiseUI", targets: ["TreewiseUI"]),
        .library(name: "TreewiseTestSupport", targets: ["TreewiseTestSupport"]),
        .library(name: "TreewiseModuleInterface", targets: ["TreewiseModuleInterface"]),
        .library(name: "TreewiseModuleXPC", targets: ["TreewiseModuleXPC"]),
    ],
    targets: [
        .target(name: "TreewiseCore", resources: [.process("Resources")]),
        .target(
            name: "TreewiseFileSystem",
            dependencies: ["TreewiseCore", "TreewiseModuleInterface"]
        ),
        .target(
            name: "TreewiseUI",
            dependencies: ["TreewiseCore", "TreewiseFileSystem"],
            resources: [.process("Resources")]
        ),
        .target(
            name: "TreewiseTestSupport",
            dependencies: ["TreewiseCore", "TreewiseModuleInterface"]
        ),
        .target(
            name: "TreewiseModuleInterface",
            dependencies: ["TreewiseCore"]
        ),
        .target(
            name: "TreewiseModuleXPC",
            dependencies: ["TreewiseCore", "TreewiseModuleInterface"]
        ),
        .testTarget(
            name: "TreewiseModuleXPCTests",
            dependencies: ["TreewiseModuleXPC"]
        ),
        .testTarget(
            name: "TreewiseModuleInterfaceTests",
            dependencies: ["TreewiseModuleInterface"]
        ),
        .testTarget(
            name: "TreewiseCoreTests",
            dependencies: ["TreewiseCore", "TreewiseTestSupport"]
        ),
        .testTarget(
            name: "TreewiseFileSystemTests",
            dependencies: ["TreewiseFileSystem", "TreewiseTestSupport"]
        ),
        .testTarget(
            name: "TreewiseUITests",
            dependencies: ["TreewiseUI", "TreewiseTestSupport"]
        ),
        .testTarget(
            name: "TreewiseTestSupportTests",
            dependencies: ["TreewiseTestSupport"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
