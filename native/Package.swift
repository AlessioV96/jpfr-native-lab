// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "JPFRNativeContract",
    products: [.library(name: "NativeContract", targets: ["NativeContract"])],
    targets: [
        .target(name: "NativeContract", path: "Shared",
                exclude: ["AppleTranslator.swift"], sources: ["NativeContract.swift"]),
        .testTarget(name: "NativeContractTests", dependencies: ["NativeContract"],
                    path: "Tests", resources: [.copy("contract-vectors.json")])
    ]
)
