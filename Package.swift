// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "swift-dub-kit",
    // macOS 26: the speech recogniser and Apple's on-device translation are
    // both macOS 26 frameworks. Nothing here needs a window.
    platforms: [
        .macOS(.v26), .iOS(.v26)
    ],
    products: [
        .library(name: "DubKit", targets: ["DubKit"]),
    ],
    dependencies: [
        // Hearing the original: word timings, on this machine.
        .package(url: "https://github.com/arraypress/swift-speech-transcriber.git", from: "1.4.0"),
        // Turning it into another language: on-device where the pair is installed.
        .package(url: "https://github.com/arraypress/swift-translate.git", from: "1.2.1"),
        // Saying it: any TTSEngine — Apple's voices, Kokoro, PocketTTS.
        .package(url: "https://github.com/arraypress/swift-tts.git", from: "1.2.0"),
        // Checking it: the second listen is scored as a word diff.
        .package(url: "https://github.com/arraypress/swift-text-diff.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "DubKit",
            dependencies: [
                .product(name: "SpeechTranscriber", package: "swift-speech-transcriber"),
                .product(name: "Translate", package: "swift-translate"),
                .product(name: "SpeechSynthesizer", package: "swift-tts"),
                .product(name: "TextDiff", package: "swift-text-diff"),
            ]
        ),
        .testTarget(name: "DubKitTests", dependencies: ["DubKit"]),
    ]
)
