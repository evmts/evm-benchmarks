# EVM Benchmark Suite

A comprehensive benchmark suite for comparing different EVM (Ethereum Virtual Machine) implementations across various workloads.

## Overview

This project benchmarks three EVM implementations:
- **REVM** - Rust-based EVM implementation
- **ethrex** - Alternative Rust EVM implementation  
- **Guillotine** - Zig-based EVM implementation

The suite compiles Solidity contracts and measures their execution performance across all three EVMs using precise benchmarking tools.

## Quick Start

The easiest way to get started is to run the automated setup script:

```bash
./getting-started.sh
```

This script will:
1. Check and install all prerequisites
2. Build the project
3. Run a sample benchmark to verify everything works

## Manual Setup

### Prerequisites

1. **Zig** (v0.13.0+)
   ```bash
   # macOS
   brew install zig
   
   # Linux - Download from https://ziglang.org/download/
   ```

2. **Rust**
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   ```

3. **Hyperfine** (benchmarking tool)
   ```bash
   # macOS
   brew install hyperfine
   
   # Linux/Other
   cargo install hyperfine
   ```

### Building

```bash
# Clone repository with submodules
git clone --recursive <repo-url>
# Or if already cloned:
git submodule update --init --recursive

# Build everything
zig build
```

## Running Benchmarks

### Run all benchmarks
```bash
./zig-out/bin/bench
```

### Run specific benchmark
```bash
./zig-out/bin/bench -f factorial
```

### Available benchmarks

| Benchmark | Description |
|-----------|-------------|
| `factorial` | Iterative factorial calculation |
| `factorial-recursive` | Recursive factorial calculation |
| `fibonacci` | Iterative Fibonacci sequence |
| `fibonacci-recursive` | Recursive Fibonacci sequence |
| `manyhashes` | Multiple keccak256 hash operations |
| `push` | Stack push operations |
| `mstore` | Memory store operations |
| `sstore` | Storage operations |
| `erc20transfer` | ERC20 token transfer |
| `erc20mint` | ERC20 token minting |
| `erc20approval` | ERC20 approval operations |
| `bubblesort` | Bubble sort algorithm |
| `snailtracer` | Ray tracing benchmark |
| `ten-thousand-hashes` | 10,000 hash operations |

### Command-line options

```bash
./zig-out/bin/bench [options]

Options:
  -h, --help              Display help
  -v, --version           Show version
  -f, --fixture <name>    Run specific benchmark
  -d, --dir <path>        Fixtures directory (default: ./fixtures)
  -c, --compile-only      Compile contracts without running benchmarks
```

## Understanding Output

When you run a benchmark, you'll see output like this:

```
=== Benchmark: factorial ===
Contract: Factorial.sol
Calldata: 0x239b51bf0000000000000000000000000000000000000000000000000000000000000014
Gas limit: 30000000
Warmup runs: 2
Benchmark runs: 5

Benchmark 1: revm
  Success: true
  Gas used: 33854
  Output: 0x00000000000000000000000000000000000000000000000021c3677c82b40000
  Time (mean ± σ):       1.6 ms ±   0.0 ms

Benchmark 2: ethrex
  Success: true
  Gas used: 33854
  Output: 0x00000000000000000000000000000000000000000000000021c3677c82b40000
  Time (mean ± σ):       1.6 ms ±   0.1 ms

Benchmark 3: guillotine
  Success: true
  Gas used: 29226
  Output: 0x00000000000000000000000000000000000000000000000021c3677c82b40000
  Time (mean ± σ):       2.3 ms ±   0.1 ms

Summary
  ethrex ran
    1.00 ± 0.07 times faster than revm
    1.44 ± 0.07 times faster than guillotine
```

### Metrics explained

- **Success**: Whether the EVM execution completed successfully
- **Gas used**: Amount of gas consumed during execution
- **Output**: The return value from the contract function
- **Time**: Execution time with statistical variance
- **Summary**: Relative performance comparison between EVMs

## Project Structure

```
bench/
├── src/
│   ├── main.zig           # Main benchmark orchestrator
│   ├── fixture.zig        # Fixture parsing
│   ├── guillotine_runner_c.zig  # Guillotine EVM runner
│   ├── main.rs           # Rust runner entry point
│   └── revm_executor.rs  # REVM implementation
├── fixtures/
│   ├── *.sol             # Solidity contracts
│   └── *.json            # Benchmark configurations
├── build.zig             # Build configuration
└── getting-started.sh    # Setup script
```

## Adding New Benchmarks

1. Create a Solidity contract in `fixtures/`:
```solidity
// fixtures/MyBenchmark.sol
pragma solidity ^0.8.0;

contract MyBenchmark {
    function Benchmark(uint256 n) public pure returns (uint256) {
        // Your benchmark code
        return n * 2;
    }
}
```

2. Create a JSON fixture configuration:
```json
{
  "name": "mybenchmark",
  "num_runs": 5,
  "solc_version": "0.8.0",
  "contract": "MyBenchmark.sol",
  "calldata": "0x239b51bf0000000000000000000000000000000000000000000000000000000000000005",
  "warmup": 2,
  "gas_limit": 30000000
}
```

Note: The calldata should include the function selector for `Benchmark(uint256)` which is `0x239b51bf` followed by the ABI-encoded parameter.

3. Run your benchmark:
```bash
./zig-out/bin/bench -f mybenchmark
```

## Troubleshooting

### Hyperfine not found
Install hyperfine using the package manager for your OS or `cargo install hyperfine`

### Build failures
Ensure all submodules are initialized:
```bash
git submodule update --init --recursive
```

### Compilation errors
Make sure you have:
- Zig 0.13.0 or later
- Rust toolchain installed
- All submodules properly initialized

### Benchmark failures
If benchmarks show "Success: false", check:
- The function selector in the calldata matches your contract function
- The contract compiles without errors
- Gas limit is sufficient

## Technical Details

### How it works

1. **Compilation**: Solidity contracts are compiled using the Guillotine compiler via FFI
2. **Bytecode extraction**: The deployed bytecode (runtime code) is extracted from compilation artifacts
3. **Execution**: Each EVM implementation executes the bytecode with provided calldata
4. **Measurement**: Hyperfine performs multiple runs with warmup to ensure accurate timing
5. **Comparison**: Results are aggregated and compared across implementations

### Key features

- **Fair comparison**: All EVMs execute the same deployed bytecode
- **Statistical rigor**: Multiple runs with warmup ensure accurate measurements  
- **Gas tracking**: Monitors gas consumption across implementations
- **Extensible**: Easy to add new benchmarks or EVM implementations

## Contributing

To contribute:
1. Add new benchmarks following the structure above
2. Ensure all benchmarks pass on all three EVMs
3. Update this README if adding new features

## License

[License information here]