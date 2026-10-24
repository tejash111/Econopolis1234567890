// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "EconopolisCore",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [.library(name: "EconopolisCore", type: .static, targets: ["EconopolisCore"])],
    targets: [.target(name: "EconopolisCore"), .testTarget(name: "EconopolisCoreTests", dependencies: ["EconopolisCore"])],
    swiftLanguageModes: [.v6]
)
