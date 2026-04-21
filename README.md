# NimbusMintegralKit

A Nimbus SDK extension for **Mintegral bidding and rendering**. It enriches Nimbus ad requests with Mintegral demand and handles ad rendering through the MintegralAd SDK when it wins the auction.

## Versioning

NimbusMintegralKit **major versions are kept in sync** with the MintegralAd SDK. For example, NimbusMintegralKit `7.x.x` depends on MintegralAd SDK `7.x.x`.
 
Minor and patch versions are independent — a NimbusMintegralKit patch release does not necessarily correspond to a MintegralAd SDK patch release, and vice versa.
 
| NimbusMintegralKit | MintegralAd SDK |
|---|---|
| 7.x.x | 7.x.x |

## Installation

### Swift Package Manager

#### Xcode Project

1. In Xcode, go to **File → Add Package Dependencies…**
2. Enter the repository URL:
   ```
   https://github.com/adsbynimbus/nimbus-ios-mintegral
   ```
3. Set the dependency rule to **Up to Next Major Version** and enter `7.0.0` as the minimum.
4. Click **Add Package** and select the **NimbusMintegralKit** library when prompted.

#### Package.swift

If you're managing dependencies through a `Package.swift` file, add the following:

```swift
dependencies: [
    .package(url: "https://github.com/adsbynimbus/nimbus-ios-mintegral", from: "7.0.0")
]
```

Then add the product to your target:

```swift
.product(name: "NimbusMintegralKit", package: "nimbus-ios-mintegral")
```

### CocoaPods

Add the following to your `Podfile`:

```ruby
pod 'NimbusMintegralKit'
```

Then run:

```sh
pod install
```

## Usage
 
Navigate to where you call `Nimbus.initialize` and register the `MintegralExtension`:
 
```swift
import NimbusMintegralKit
 
Nimbus.initialize(publisher: "<publisher>", apiKey: "<apiKey>") {
    MintegralExtension(appId: "<mintegralAppId>", appKey: "<mintegralAppKey>")
}
```

If you provide an app ID and app key, Nimbus will automatically initialize the MintegralAd SDK.

That's it — Mintegral is now enabled in all upcoming requests.

## Documentation

- [Nimbus iOS SDK Documentation](https://docs.adsbynimbus.com/docs/sdk/ios) — integration guides, configuration, and API reference.
- [DocC API Reference](https://iosdocs.adsbynimbus.com) — auto-generated documentation for the latest release.

## Sample App

See NimbusMintegralKit in action in our public [sample app repository](https://github.com/adsbynimbus/nimbus-ios-sample), which demonstrates end-to-end integration including setup, bid requests, and ad rendering.
