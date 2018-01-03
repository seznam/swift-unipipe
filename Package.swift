// swift-tools-version:4.0

import PackageDescription

let package = Package(
	name: "UniPipe",
	products: [
		.library(name: "UniPipe", targets: ["UniPipe"])
	],
	targets: [
		.target(name: "UniPipe")
	]
)
