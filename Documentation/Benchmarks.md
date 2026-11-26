# Device benchmarks

## Run on an iPhone

Open `Examples/Toronto.xcodeproj` in Xcode, select the shared **DeviceBenchmarks** scheme, and choose a physical iOS device. Select the cases you want to measure in the Test navigator. For runs in this repository, obtain approval immediately before each run.

The scheme builds in Release, uses the Toronto app as its test host, and sets `MAP_CLUSTERING_BENCHMARK=1`. The suite covers Supercluster, DBSCAN, and K-means with eight clusters. Each algorithm runs at 50,000 and 100,000 points across four distributions.

## Benchmark scenarios

| Scenario | Distribution |
| --- | --- |
| Sparse, even | Points spread across a 0.5° square |
| Sparse, uneven | Same area with 80% of points concentrated in a hotspot one fifth as wide |
| Dense, even | Points spread across a 0.01° square |
| Dense, uneven | Same smaller area with 80% of points concentrated in a hotspot one fifth as wide |

## Recorded results

Averages of five XCTest measurements on an iPhone 17 running iOS 27.2.1, Release configuration. Each measurement includes creating the dataset from pre-generated coordinates, calculating cold membership at zoom 13, and running 25 warm viewport queries. Peak memory includes the Toronto app and the test harness. The timings cover the clustering workload and do not measure map frame pacing.

| Algorithm | Points | Scenario | Avg. time | Peak memory |
| --- | ---: | --- | ---: | ---: |
| Supercluster | 50,000 | Dense, even | 0.034 s | 242.0 MB |
| Supercluster | 50,000 | Dense, uneven | 0.034 s | 242.0 MB |
| Supercluster | 50,000 | Sparse, even | 0.193 s | 239.7 MB |
| Supercluster | 50,000 | Sparse, uneven | 0.097 s | 230.9 MB |
| Supercluster | 100,000 | Dense, even | 0.068 s | 213.0 MB |
| Supercluster | 100,000 | Dense, uneven | 0.075 s | 213.1 MB |
| Supercluster | 100,000 | Sparse, even | 0.356 s | 262.1 MB |
| Supercluster | 100,000 | Sparse, uneven | 0.188 s | 254.0 MB |
| DBSCAN | 50,000 | Dense, even | 0.248 s | 217.8 MB |
| DBSCAN | 50,000 | Dense, uneven | 0.551 s | 203.8 MB |
| DBSCAN | 50,000 | Sparse, even | 0.086 s | 201.4 MB |
| DBSCAN | 50,000 | Sparse, uneven | 0.113 s | 201.6 MB |
| DBSCAN | 100,000 | Dense, even | 0.709 s | 239.5 MB |
| DBSCAN | 100,000 | Dense, uneven | 1.631 s | 218.3 MB |
| DBSCAN | 100,000 | Sparse, even | 0.189 s | 213.7 MB |
| DBSCAN | 100,000 | Sparse, uneven | 0.262 s | 214.1 MB |
| K-means | 50,000 | Dense, even | 0.039 s | 210.9 MB |
| K-means | 50,000 | Dense, uneven | 0.026 s | 211.0 MB |
| K-means | 50,000 | Sparse, even | 0.039 s | 210.9 MB |
| K-means | 50,000 | Sparse, uneven | 0.025 s | 210.9 MB |
| K-means | 100,000 | Dense, even | 0.080 s | 211.2 MB |
| K-means | 100,000 | Dense, uneven | 0.075 s | 211.2 MB |
| K-means | 100,000 | Sparse, even | 0.078 s | 211.2 MB |
| K-means | 100,000 | Sparse, uneven | 0.063 s | 211.2 MB |
