// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "FargeKjerne",
    defaultLocalization: "nb",
    platforms: [.iOS(.v26), .macOS(.v26), .visionOS(.v26)],
    products: [
        .library(name: "FargeKjerne", targets: ["FargeKjerne"]),
        .library(name: "FargeKI", targets: ["FargeKI"]),
    ],
    targets: [
        // Ren fargematematikk, paletter og eksport. Ingen UI-avhengigheter.
        .target(name: "FargeKjerne"),
        // Verdiord → fargeforslag (Foundation Models på enheten + leksikon-reserve).
        .target(name: "FargeKI", dependencies: ["FargeKjerne"]),
        // Utviklerverktøy for å prøve KI-promptene mot modellen på Macen: `swift run kiprove`.
        .executableTarget(name: "kiprove", dependencies: ["FargeKjerne", "FargeKI"], path: "Sources/KIProve"),
        .testTarget(name: "FargeKjerneTests", dependencies: ["FargeKjerne", "FargeKI"]),
    ]
)
