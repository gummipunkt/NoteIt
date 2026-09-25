// swift-tools-version:5.10
import PackageDescription

var products: [Product] = [
    .library(name: "NoteItCore", targets: ["NoteItCore"]),
]

var targets: [Target] = [
    // Platform-independent logic: file storage, search, wiki links,
    // Markdown rendering and Simplenote sync. Builds and tests on Linux too.
    .target(
        name: "NoteItCore",
        dependencies: [
            .product(name: "Markdown", package: "swift-markdown"),
        ]
    ),
    .testTarget(
        name: "NoteItCoreTests",
        dependencies: ["NoteItCore"]
    ),
]

#if os(macOS)
// The SwiftUI/AppKit application itself only exists on macOS.
products.append(.executable(name: "NoteIt", targets: ["NoteIt"]))
targets.append(
    .executableTarget(
        name: "NoteIt",
        dependencies: ["NoteItCore"]
    )
)
#endif

let package = Package(
    name: "NoteIt",
    platforms: [
        .macOS(.v14),
    ],
    products: products,
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.6.0"),
    ],
    targets: targets
)
