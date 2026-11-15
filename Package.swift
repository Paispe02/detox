// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Detox",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .executable(name: "detoxd", targets: ["detoxd"]),
        .executable(name: "Detox", targets: ["Detox"]),
    ],
    targets: [
        .target(name: "DetoxCore"),
        .target(name: "DetoxIPC", dependencies: ["DetoxCore"]),
        .target(name: "DetoxDaemonKit", dependencies: ["DetoxCore", "DetoxIPC"]),
        .executableTarget(name: "detoxd", dependencies: ["DetoxDaemonKit"]),
        .target(name: "DetoxAppKit", dependencies: ["DetoxCore", "DetoxIPC"]),
        .executableTarget(name: "Detox", dependencies: ["DetoxAppKit"]),
        .testTarget(name: "DetoxCoreTests", dependencies: ["DetoxCore"]),
        .testTarget(name: "DetoxIPCTests", dependencies: ["DetoxIPC"]),
        .testTarget(name: "DetoxDaemonKitTests", dependencies: ["DetoxDaemonKit"], resources: [.copy("Fixtures")]),
        .testTarget(name: "DetoxAppKitTests", dependencies: ["DetoxAppKit"]),
    ],
    swiftLanguageModes: [.v5]
)
