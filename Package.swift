import PackageDescription

// swift-tools-version:4.0

let package = Package(
    name: "Lumina",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "Lumina",
            targets: ["Lumina"]),
    ],
)
