# EVM Benchmark Suite

A comprehensive benchmark suite for comparing different EVM (Ethereum Virtual Machine) implementations across various workloads.

## Overview

This project benchmarks multiple EVM implementations across different languages:

### Primary EVMs:
- **REVM** - High-performance Rust-based EVM implementation
- **ethrex** - Alternative Rust EVM implementation
- **Guillotine** - Zig-based EVM with multiple language bindings:
  - Native Zig implementation
  - Rust bindings
  - TypeScript/Bun bindings
  - Python bindings
  - Go bindings

### Additional EVMs (with startup overhead measurement):
- **Geth** - Go Ethereum reference implementation
- **py-evm** - Python EVM implementation
- **ethereumjs** - JavaScript/Node.js implementation

The suite compiles Solidity contracts using the Guillotine compiler and measures execution performance across all EVMs using Hyperfine for precise, statistically rigorous benchmarking.

## Quick Start

```bash
# Setup and run all benchmarks
./run.sh

# Or just setup without running benchmarks
./run.sh setup

# Run a specific benchmark
./run.sh factorial
```

The `run.sh` script will:
1. Check for prerequisites (Zig, Rust, Hyperfine)
2. Build the entire project
3. Run benchmarks and generate results

📊 **[View Latest Benchmark Results](./results.md)**

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

The suite includes 34 comprehensive benchmarks covering various EVM operations:

#### Computation & Algorithms
| Benchmark | Description |
|-----------|-------------|
| `factorial` | Iterative factorial calculation |
| `factorial-recursive` | Recursive factorial calculation |
| `fibonacci` | Iterative Fibonacci sequence |
| `fibonacci-recursive` | Recursive Fibonacci sequence |
| `bubblesort` | Bubble sort algorithm |
| `snailtracer` | Ray tracing benchmark |

#### Cryptographic Operations
| Benchmark | Description |
|-----------|-------------|
| `hashing` | Basic keccak256 operations |
| `manyhashes` | Multiple keccak256 hash operations |
| `ten-thousand-hashes` | 10,000 hash operations |

#### Memory & Storage
| Benchmark | Description |
|-----------|-------------|
| `push` | Stack push operations |
| `mstore` | Memory store operations |
| `sstore` | Storage operations |
| `memory` | Memory operations benchmark |
| `storage` | Storage access patterns |

#### ERC20 Token Operations
| Benchmark | Description |
|-----------|-------------|
| `erc20transfer` | ERC20 token transfer |
| `erc20mint` | ERC20 token minting |
| `erc20approval` | ERC20 approval operations |

#### EVM Operations
| Benchmark | Description |
|-----------|-------------|
| `arithmetic` | Arithmetic operations |
| `bitwise` | Bitwise operations |
| `blockinfo` | Block information access |
| `calldata` | Calldata operations |
| `codecopy` | Code copy operations |
| `comparison` | Comparison operations |
| `context` | Execution context operations |
| `controlflow` | Control flow operations |
| `contractcalls` | Inter-contract calls |
| `contractcreation` | Contract creation |
| `externalcode` | External code access |
| `jumpdest` | Jump destination analysis |
| `logs` | Event logging |
| `selfdestruct` | Self-destruct operations |
| `sha3` | SHA3 hashing operations |
| `stackops` | Stack operations |

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
  Time (mean ± σ):       1.6 ms ±   0.0 ms    [User: 0.9 ms, System: 0.6 ms]
  Range (min … max):     1.5 ms …   1.7 ms    5 runs

Benchmark 2: ethrex
  Time (mean ± σ):       1.6 ms ±   0.1 ms    [User: 0.9 ms, System: 0.6 ms]
  Range (min … max):     1.5 ms …   1.8 ms    5 runs

Benchmark 3: guillotine
  Time (mean ± σ):       2.3 ms ±   0.1 ms    [User: 1.2 ms, System: 0.9 ms]
  Range (min … max):     2.2 ms …   2.5 ms    5 runs

Benchmark 4: guillotine-rust
  Time (mean ± σ):       2.1 ms ±   0.1 ms    [User: 1.1 ms, System: 0.8 ms]
  Range (min … max):     2.0 ms …   2.3 ms    5 runs

Benchmark 5: guillotine-bun
  Time (mean ± σ):      12.5 ms ±   0.3 ms    [User: 10.2 ms, System: 2.1 ms]
  Range (min … max):    12.0 ms …  13.1 ms    5 runs

Benchmark 6: guillotine-python
  Time (mean ± σ):      18.3 ms ±   0.5 ms    [User: 15.8 ms, System: 2.3 ms]
  Range (min … max):    17.5 ms …  19.2 ms    5 runs

Benchmark 7: guillotine-go
  Time (mean ± σ):       3.2 ms ±   0.2 ms    [User: 2.1 ms, System: 0.9 ms]
  Range (min … max):     3.0 ms …   3.5 ms    5 runs

Summary
  'revm' ran
    1.00 ± 0.07 times faster than 'ethrex'
    1.31 ± 0.08 times faster than 'guillotine-rust'
    1.44 ± 0.09 times faster than 'guillotine'
    2.00 ± 0.14 times faster than 'guillotine-go'
    7.81 ± 0.28 times faster than 'guillotine-bun'
   11.44 ± 0.42 times faster than 'guillotine-python'
```

### Metrics explained

- **Time (mean ± σ)**: Average execution time ± standard deviation
- **User/System time**: CPU time spent in user mode vs kernel mode
- **Range**: Minimum and maximum execution times observed
- **Summary**: Relative performance comparison with confidence intervals
- **Gas usage**: Varies between implementations based on their gas metering approach

### Performance Notes

- Native implementations (Rust, Zig, Go) typically show the best performance
- Language bindings add overhead, especially for interpreted languages
- Startup overhead is measured separately and subtracted from benchmark times
- Multiple runs with warmup ensure statistically significant results

## Project Structure

```
evm-benchmarks/
├── src/
│   ├── main.zig                   # Main benchmark orchestrator
│   ├── fixture.zig                # Fixture parsing
│   ├── root.zig                   # Library exports
│   │
│   ├── main.rs                    # Rust runner entry point
│   ├── evm.rs                     # EVM executor trait
│   ├── revm_executor.rs           # REVM implementation
│   ├── ethrex_executor.rs         # ethrex implementation
│   │
│   ├── guillotine_runner.zig      # Guillotine Zig runner
│   ├── guillotine_runner.rs       # Guillotine Rust runner
│   ├── guillotine_bun_runner.ts   # Guillotine TypeScript/Bun runner
│   ├── guillotine_python_runner.py # Guillotine Python runner
│   ├── guillotine_go_runner.go    # Guillotine Go runner
│   │
│   ├── geth_runner.go              # Geth runner
│   ├── py_evm_runner.py            # py-evm runner
│   ├── ethereumjs_runner.js        # ethereumjs runner
│   └── pyrevm_runner.py            # pyrevm runner (not yet integrated)
├── fixtures/
│   ├── *.sol                      # 34 Solidity contracts
│   └── *.json                     # 34 benchmark configurations
├── build.zig                      # Zig build configuration
├── build.zig.zon                  # Zig dependencies
├── Cargo.toml                     # Rust dependencies
├── run.sh                         # Setup and benchmark runner
├── results.md                     # Benchmark results (auto-generated)
└── submodules/
    ├── geth/                      # Go Ethereum
    ├── revm/                      # REVM
    ├── ethrex/                    # ethrex
    ├── ethereumjs/                # EthereumJS
    ├── py-evm/                    # Python EVM
    └── guillotine/                # Guillotine tools
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
./run.sh mybenchmark
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
3. **Startup overhead measurement**: Each runner's startup time is measured and subtracted from results
4. **Execution**: Each EVM implementation executes the bytecode with provided calldata
5. **Internal batching**: Runners can execute multiple iterations internally to amortize startup costs
6. **Measurement**: Hyperfine performs multiple runs with warmup to ensure accurate timing
7. **Statistical analysis**: Results include mean, standard deviation, and confidence intervals
8. **Comparison**: Results are aggregated and compared across implementations

### Key features

- **Fair comparison**: All EVMs execute the same deployed bytecode
- **Statistical rigor**: Multiple runs with warmup ensure accurate measurements
- **Startup overhead correction**: Measures and subtracts initialization time
- **Internal run batching**: Reduces measurement noise for fast operations
- **Multiple language support**: Tests EVMs across Rust, Zig, Go, JavaScript, and Python
- **Comprehensive benchmarks**: 34 different test scenarios covering all EVM operations
- **Extensible**: Easy to add new benchmarks or EVM implementations

### Benchmark Categories

1. **Core Operations**: Basic EVM opcodes and arithmetic
2. **Memory & Storage**: State and memory manipulation
3. **Cryptographic**: Hashing and signature operations
4. **Contract Interactions**: Calls, creates, and deployments
5. **Complex Algorithms**: Sorting, recursion, and computation-heavy tasks
6. **Real-world Scenarios**: ERC20 operations and typical smart contract patterns

## Contributing

To contribute:
1. Add new benchmarks following the structure above
2. Ensure all benchmarks pass on all three EVMs
3. Update this README if adding new features

## License

[License information here]