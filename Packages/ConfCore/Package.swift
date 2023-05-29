// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "ConfCore",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "ConfCore",
            type: .dynamic,
            targets: ["ConfCore"])
    ],
    dependencies: [
        .package(name: "Siesta", url: "https://github.com/bustoutsolutions/siesta", from: "1.5.2"),
        .package(name: "Realm", url: "https://github.com/realm/realm-swift", from: "10.0.0"),
        .package(url: "https://github.com/insidegui/CloudKitCodable", .branch("spm")),
        .package(path: "../Transcripts")
	],
    targets: [
        .target(
            name: "ConfCore",
            dependencies: [
				"CloudKitCodable",
                .product(name: "RealmSwift", package: "Realm"),
				"Siesta",
                "Transcripts"
			],
			path: "ConfCore/")
    ]
)
