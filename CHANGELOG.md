# Changelog

## 0.0.2

This release contains breaking changes to the public API.

- Replaced mutable clustering options with `ClusteringConfiguration` and algorithm-specific parameters.
- Simplified map setup and controller initialization, added item replacement, and improved cluster group inspection.
- Added customizable cluster badges and opt-in timing events.
- Reorganized the clustering algorithms into separate implementations.
- Expanded the Toronto example with 100 to 5,000 pins, selectable algorithms, live configuration, radius overlays, and map statistics.
- Added a physical-device benchmark matrix covering three algorithms, two dataset sizes, and four point distributions.

## 0.0.1

- Added the library targets and Toronto example project.
- Added shared-controller clustering with Supercluster, DBSCAN, experimental k-means, and off mode.
- Added opt-in timing diagnostics and seeded Toronto datasets of 100, 500, and 5,000 places.
