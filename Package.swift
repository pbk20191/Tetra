// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Tetra",
    platforms: [
        .iOS(.v13),
        .macCatalyst(.v13),
        .tvOS(.v13),
        .macOS(.v10_15),
        .watchOS(.v6),
        .visionOS(.v1)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "Tetra",
            targets: ["Tetra"]
        ),
    ],
    // Opt-in trait for the SchedulingExecutor / RunLoopExecutor / MainExecutor SPI
    // conformances in `TetraRunLoopConcurrency`. Those protocols are only nameable on a
    // toolchain whose stdlib exposes them (a development snapshot); the release/standard
    // stdlib does not (`cannot find type 'SchedulingExecutor'`), and no `#if compiler(>=x)`
    // can tell the two apart. NOT in the default set → OFF by default, so release/standard
    // toolchains build cleanly. Enable with `swift build --traits SchedulingExecutorSPI` on
    // a toolchain that exposes the SPI; an enabled trait becomes the `#if SchedulingExecutorSPI`
    // compilation condition.
    traits: [
        .trait(
            name: "SchedulingExecutorSPI",
            description: "Conform StackBoundRunLoopExecutor to the SchedulingExecutor/RunLoopExecutor/MainExecutor _Concurrency SPI protocols (only compilable where the stdlib exposes them)."
        ),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(
            url: "https://github.com/apple/swift-collections.git",
                .upToNextMajor(from: "1.3.0"),
            traits: [
                .defaults,
//                .trait(name: "UnstableContainersPreview")
            ],
        ),
        .package(
            url: "https://github.com/apple/swift-atomics.git",
            .upToNextMajor(from: "1.3.0"),
            traits: [.defaults],
        ),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.1.5"),

    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "Namespace",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .target(
            name: "NamespaceExtension",
            dependencies: [
                "Namespace",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .target(
            name: "CriticalSection",
            dependencies: [
                .product(name: "Atomics", package: "swift-atomics"),
                
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableExperimentalFeature("StaticExclusiveOnly"),
                .enableExperimentalFeature("RawLayout"),
                .enableExperimentalFeature("BuiltinModule"),
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("LifetimeDependence"),
            ]
        ),
        .target(
            name: "BackportDiscardingTaskGroup",
            dependencies: [
                "Namespace",
                "CriticalSection",
            ],
            swiftSettings: [
                .enableUpcomingFeature("FullTypedThrows"),
                .enableExperimentalFeature("IsolatedAny"),
                .swiftLanguageMode(.v6)
            ]
        ),
        .target(
            name: "Tetra",
            dependencies: [
                .product(name: "DequeModule", package: "swift-collections"),
                .product(name: "HeapModule", package: "swift-collections"),

                "BackPortAsyncSequence",
                "CriticalSection",
                "BackportDiscardingTaskGroup",
                "Namespace",
                "NamespaceExtension", "TetraRunLoopConcurrency",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("FullTypedThrows"),
                .enableExperimentalFeature("IsolatedAny"),
                .swiftLanguageMode(.v6)
            ]
        ),

        .target(
            name: "TetraRunLoopConcurrency",
            dependencies: [
                "CriticalSection",
                .product(name: "Atomics", package: "swift-atomics"),
                .product(name: "HeapModule", package: "swift-collections"),
                .product(name: "BasicContainers", package: "swift-collections"),
                .product(name: "ContainersPreview", package:  "swift-collections"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableExperimentalFeature("BuiltinModule"),
            ]
        ),
        .target(
            name: "BackPortAsyncSequence",
            dependencies: [ "Namespace"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "TetraTests",
            dependencies: [
                "Tetra"
            ],
            resources: [.process("Resources")],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "TetraRunLoopConcurrencyTests",
            dependencies: ["TetraRunLoopConcurrency"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .unsafeFlags(["-Xfrontend", "-disable-availability-checking"]),
                
            ]
        ),
    ],
)
