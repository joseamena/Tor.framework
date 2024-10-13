// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "Tor",
    platforms: [
        .iOS(.v12),
        .macOS(.v10_13),
    ],
    products: [
        .library(
            name: "Tor",
            targets: ["Core", "CTor", "GeoIP"]
        ),
        .library(
            name: "CTor",
            targets: ["CTor"]
        ),
        .library(
            name: "GeoIP",
            targets: ["GeoIP"]
        ),
    ],
    dependencies: [
        // Add any external dependencies if needed
    ],
    targets: [
        .target(
            name: "Core",
            dependencies: [],
            path: "Tor/Classes/Core",
            exclude: [],
            sources: ["**/*.swift", "**/*.m", "**/*.h"], // Include all Swift and Objective-C files
            cSettings: [
                .headerSearchPath("Tor/tor"),
                .headerSearchPath("Tor/openssl/include"),
                .headerSearchPath("Tor/libevent/include"),
            ]
        ),
        .target(
            name: "CTor",
            dependencies: ["Core"],
            path: "Tor/Classes/CTor",
            sources: ["**/*.swift", "**/*.m", "**/*.h"], // Include all Swift and Objective-C files
            cSettings: [
                .headerSearchPath("Tor/tor"),
                .headerSearchPath("Tor/openssl/include"),
                .headerSearchPath("Tor/libevent/include"),
            ]
        ),
        .target(
            name: "GeoIP",
            dependencies: ["CTor"],
            path: "Tor/tor/src/config",
            resources: [
                .process("geoip"),
                .process("geoip6")
            ]
        ),
        .testTarget(
            name: "TorTests",
            dependencies: ["Core", "CTor", "GeoIP"],
            path: "Tests",
            sources: ["**/*Tests.swift"]
        ),
    ]
)
