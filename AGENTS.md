# Repository Guidelines

## Project Structure

- `Sources/MapClusteringCore/` contains coordinates, spatial indexing, and clustering algorithms. Keep SwiftUI and MapKit integration in `Sources/MapClustering/`, which depends on the core target.
- `Sources/MapClustering/MapClustering.docc/` contains API guides. The string catalog is in `Sources/MapClustering/Resources/`.
- `Tests/MapClusteringCoreTests/` and `Tests/MapClusteringTests/` mirror the library targets. `Benchmarks/` contains device performance tests. `Examples/Toronto/` contains the demo app.

## Build and Run

- Run `swift build` from the repository root to compile both library targets on macOS with a Swift 6 toolchain.
- Open `Examples/Toronto.xcodeproj` in Xcode, select the shared **Toronto** scheme, then run on an iOS 17+ simulator or a Mac running macOS 14+. Use the demo to inspect map interactions and annotation changes.

## Swift Style

Use four spaces for indentation, UpperCamelCase for types, and lowerCamelCase for functions and properties. Match nearby access control and concurrency annotations. Keep platform-independent clustering changes in the core target and update the DocC guide when public usage changes.

## Testing

Use Swift Testing with `@Test` and `#expect`. Name tests after the behavior they cover, such as `newerOffRequestWins`. Parameterize cases when multiple algorithms should satisfy the same expectation.

Obtain explicit user approval immediately before each specific Xcode unit or UI test run. Run the package suites with `swift test`. Use the shared **DeviceBenchmarks** scheme for device performance checks, subject to the Xcode test approval rule. Without approval, use builds and static checks and report that tests were not run.

## Commits and Pull Requests

Use short, imperative commit subjects. The repository has no commits to establish a house convention yet. In pull requests, describe the behavior change, summarize verification, link related issues when available, and include screenshots for visible demo changes. Use the GitHub CLI (`gh`) for all GitHub access.
