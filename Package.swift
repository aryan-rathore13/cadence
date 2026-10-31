// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Cadence",
    platforms: [.macOS("14.2")],
    products: [.executable(name: "Cadence", targets: ["Cadence"])],
    targets: [
        .target(name: "AudioDSP", publicHeadersPath: "include", linkerSettings: [.linkedFramework("CoreAudio")]),
        .executableTarget(name: "Cadence", dependencies: ["AudioDSP"], linkerSettings: [
            .linkedFramework("AppKit"), .linkedFramework("CoreAudio"), .linkedFramework("ServiceManagement")
        ]),
        .testTarget(name: "CadenceTests", dependencies: ["Cadence", "AudioDSP"])
    ]
)
