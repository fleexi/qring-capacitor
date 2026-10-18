// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "WhespWirstbandCapacitor", platforms: [.iOS(.v15)], products: [.library(name: "WhespWirstbandCapacitor", targets: ["WristbandPlugin"])], dependencies: [.package(url: "https://github.com/ionic-team/capacitor-swift-pm.git", exact: "8.5.2")], targets: [
    .binaryTarget(name: "QCBandSDK", path: "ios/Vendor/QCBandSDK.xcframework"),
    .target(name: "WristbandVendor", dependencies: ["QCBandSDK"], path: "ios/Sources/WristbandVendor", publicHeadersPath: "include", linkerSettings: [.linkedFramework("CoreBluetooth"), .linkedFramework("UIKit"), .linkedLibrary("z"), .linkedLibrary("c++"), .unsafeFlags(["-Xlinker", "-ObjC"])]),
    .target(name: "WristbandPlugin", dependencies: ["WristbandVendor", .product(name: "Capacitor", package: "capacitor-swift-pm")], path: "ios/Sources/WristbandPlugin")
])
