// swift-tools-version: 6.2
import PackageDescription

// The modules of an open build. An official build overrides this package by name
// from the workspace in the private modules repository, so this manifest stays
// fixed and never looks at the disk (ADR 0057).
let package = Package(
    name: "TreewiseModuleCatalog",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "TreewiseModuleCatalog", targets: ["TreewiseModuleCatalog"])
    ],
    dependencies: [.package(path: "../TreewiseKit")],
    targets: [
        .target(
            name: "TreewiseModuleCatalog",
            dependencies: [
                .product(name: "TreewiseModuleInterface", package: "TreewiseKit"),
                .product(name: "TreewiseFreeModule", package: "TreewiseKit"),
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
