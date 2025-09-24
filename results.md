# Benchmark Results

> Auto-generated benchmark results comparing REVM, ethrex, and Guillotine EVM implementations.

## Summary Table

| Benchmark | REVM (ms) | ethrex (ms) | Guillotine (ms) | Fastest | Notes |
|-----------|-----------|-------------|-----------------|---------|-------|
| factorial | 1.6 | 1.5 | 2.4 | ethrex | ⚠️ Some failures |
| factorial-recursive | 1.7 | 1.7 | 3.0 | REVM | ⚠️ Some failures |
| fibonacci | 1.6 | 1.6 | 2.4 | REVM | ⚠️ Some failures |
| fibonacci-recursive | 1.9 | 2.4 | 9.5 | REVM | ⚠️ Some failures |
| manyhashes | 2.0 | 2.1 | 2.9 | REVM | ⚠️ Some failures |
| push | 9.1 | 9.1 | 10.8 | REVM | ⚠️ Some failures |
| mstore | 6.4 | 6.4 | 7.4 | REVM | ⚠️ Some failures |
| sstore | 5.8 | 5.1 | 5.9 | ethrex | ⚠️ Some failures |
| bubblesort | 2.3 | 1.7 | 2.4 | ethrex | ✅ All passed |
| snailtracer | 4.8 | 5.0 | 7.0 | REVM | ✅ All passed |
| ten-thousand-hashes | 10.2 | 12.7 | 10.9 | REVM | ⚠️ Some failures |
| erc20transfer | 2.4 | 2.6 | 3.5 | REVM | ⚠️ Some failures |
| erc20mint | 2.1 | 2.5 | 3.4 | REVM | ⚠️ Some failures |
| erc20approval | 3.2 | 3.8 | 3.9 | REVM | ⚠️ Some failures |

## Gas Usage Comparison

| Benchmark | REVM Gas | ethrex Gas | Guillotine Gas | Most Efficient |
|-----------|----------|------------|----------------|----------------|

## Benchmark Details

- **Date**: 2025-09-24 00:01:21
- **Platform**: Darwin arm64
- **CPU**: Apple M3 Max

### Configuration
- Warmup runs: 2
- Benchmark runs: 5
- Gas limit: 30,000,000

### Notes
- Times are in milliseconds (ms)
- Lower values are better for both execution time and gas usage
- ✅ indicates all EVMs executed successfully
- ⚠️ indicates some EVMs failed
- ❌ indicates benchmark failed to run

## How to Run

```bash
# Setup and run all benchmarks
./run.sh

# Run specific benchmark
./run.sh factorial

# Run all benchmarks (if already set up)
./run.sh all

# Just build without running benchmarks
./run.sh setup
```
