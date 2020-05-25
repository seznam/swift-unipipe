// swift-tools-version:5.2

import PackageDescription

let package = Package(
	name: "UniPipe",
	products: [
		.library(name: "UniPipe", targets: ["UniPipe"])
	],
	targets: [
		.target(name: "UniPipe"),
		.testTarget(name: "UniPipeTests", dependencies: ["UniPipe"])
	],
	swiftLanguageVersions: [.v4, .v4_2, .v5]
)
