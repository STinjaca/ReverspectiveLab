// swift-tools-version: 6.0
//
// Paquete solo para correr `swift test` sobre el núcleo puro desde la
// terminal. La app no lo usa: Xcode compila los mismos archivos de
// `ReverspectiveLab/Core` a través de la carpeta sincronizada.

import PackageDescription

let package = Package(
    name: "ReverspectiveCore",
    targets: [
        // Solo matemática (simd/Foundation): nada de Metal, para poder
        // probarla sin GPU y sin abrir la app.
        .target(name: "ReverspectiveCore", path: "ReverspectiveLab/Core"),
        .testTarget(name: "ReverspectiveCoreTests",
                    dependencies: ["ReverspectiveCore"],
                    path: "Tests/ReverspectiveCoreTests"),
    ],
    // El mismo modo de lenguaje que la app (SWIFT_VERSION = 5.0).
    swiftLanguageModes: [.v5]
)
