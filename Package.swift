// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NBLMobile",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "NBLMobile",
            targets: ["NBLMobile"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/plaid/plaid-link-ios-spm.git", from: "6.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "NBLMobile"
        ),
        .testTarget(
            name: "NBLMobileTests",
            dependencies: ["NBLMobile"]
        ),
    ],
    swiftLanguageModes: [.v6]
)

