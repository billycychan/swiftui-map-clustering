# SwiftUI Map SDK check

On November 26, 2026, the project checked Xcode 27.2 (27B48) and the iPhoneOS 27.2 SDK. The public arm64e Swift interface for `_MapKit_SwiftUI` exposed `MapContent` and `onMapCameraChange`, with no public clustering declaration for SwiftUI `Map` in that SDK.

To repeat the inspection, confirm the toolchain and locate the interface:

```sh
xcodebuild -version
xcrun --sdk iphoneos --show-sdk-version
sdk="$(xcrun --sdk iphoneos --show-sdk-path)"
find "$sdk/System/Library/Frameworks" -path '*/_MapKit_SwiftUI.swiftmodule/arm64e-apple-ios.swiftinterface' -print
```

Search the returned public interface for `cluster` and review any matches for declarations available to SwiftUI `Map` clients.
