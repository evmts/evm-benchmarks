# EVM Benchmark Suite

A high-performance benchmarking framework for comparing Ethereum Virtual Machine (EVM) implementations, built with Rust and Clap.

## Benchmark Results

Latest benchmark results comparing Guillotine and Revm EVMs (10 iterations):

### erc20_approval_bench
*Benchmark ERC20 approval and transfer operations*

| EVM | Mean (s) | Std Dev | Min (s) | Max (s) | Median (s) |
|-----|----------|---------|---------|---------|------------|
| ⚡ guillotine | 0.0475 | 0.0011 | 0.0463 | 0.0502 | 0.0474 |
| revm | 0.0526 | 0.0004 | 0.0518 | 0.0531 | 0.0528 |

**Performance**: guillotine is 1.11x faster than revm

### ten_thousand_hashes
*Execute 10,000 keccak256 hash operations*

| EVM | Mean (s) | Std Dev | Min (s) | Max (s) | Median (s) |
|-----|----------|---------|---------|---------|------------|
| ⚡ guillotine | 0.0531 | 0.0004 | 0.0524 | 0.0539 | 0.0531 |
| revm | 0.0805 | 0.0118 | 0.0758 | 0.1141 | 0.0786 |

**Performance**: guillotine is 1.52x faster than revm

### erc20_transfer_bench
*Benchmark ERC20 transfer operations*

| EVM | Mean (s) | Std Dev | Min (s) | Max (s) | Median (s) |
|-----|----------|---------|---------|---------|------------|
| ⚡ guillotine | 0.0560 | 0.0016 | 0.0542 | 0.0589 | 0.0558 |
| revm | 0.0629 | 0.0004 | 0.0623 | 0.0636 | 0.0631 |

**Performance**: guillotine is 1.12x faster than revm

### erc20_mint_bench
*Benchmark ERC20 minting operations*

| EVM | Mean (s) | Std Dev | Min (s) | Max (s) | Median (s) |
|-----|----------|---------|---------|---------|------------|
| ⚡ guillotine | 0.0395 | 0.0007 | 0.0387 | 0.0410 | 0.0393 |
| revm | 0.0418 | 0.0013 | 0.0410 | 0.0454 | 0.0416 |

**Performance**: guillotine is 1.06x faster than revm

### snailtracer
*Ray tracing benchmark (compute intensive, 1B gas)*

| EVM | Mean (s) | Std Dev | Min (s) | Max (s) | Median (s) |
|-----|----------|---------|---------|---------|------------|
| ⚡ guillotine | 0.2314 | 0.0008 | 0.2301 | 0.2327 | 0.2314 |
| revm | 0.2886 | 0.0061 | 0.2833 | 0.3041 | 0.2868 |

**Performance**: guillotine is 1.25x faster than revm

## Features

- **Multiple EVM Support**: Compare Guillotine (Zig-based) and Revm (Rust-based) implementations
- **Statistical Analysis**: Powered by Hyperfine for accurate, reproducible measurements
- **Matrix Benchmarking**: Run benchmarks across multiple EVMs simultaneously
- **Comprehensive Test Suite**: Includes compute-intensive and token operation benchmarks
- **JSON Export**: Detailed results with statistical analysis

## Architecture

### Benchmark Setup

The benchmarking framework is designed to provide fair, reproducible comparisons between different EVM implementations:

1. **Unified Interface**: All EVMs implement a common `EvmExecutor` trait, ensuring identical benchmark conditions
2. **Native Integration**: EVMs are integrated at the library level for minimal overhead
3. **Statistical Rigor**: Each benchmark runs multiple iterations with warmup rounds, using Hyperfine for statistical analysis
4. **Transparent Compilation**: Solidity contracts are compiled on-demand using the foundry-compilers crate

### EVM Integrations

#### Guillotine
- **Implementation**: High-performance Zig core with Rust SDK wrapper
- **Integration**: Uses `guillotine-rs` crate which provides FFI bindings to the native Zig library
- **Architecture**: The Rust SDK (`guillotine-rs`) wraps the Zig implementation, providing a safe Rust interface while maintaining the performance benefits of the Zig core
- **Build**: Requires building the Zig library first, then linking via the Rust SDK

#### Revm
- **Implementation**: Pure Rust EVM implementation
- **Integration**: Direct crate dependency via Cargo
- **Architecture**: Native Rust with no FFI overhead
- **Version**: Uses revm v14.0 for compatibility with guillotine-rs requirements

## Quick Start

```bash
# Clone repository with submodules
git clone --recursive https://github.com/williamcory/bench.git
cd bench

# Build and run
cargo build --release
cargo run --release -- run
```

## Manual Installation

### Prerequisites

```bash
# Install Hyperfine (benchmarking tool)
brew install hyperfine        # macOS
apt install hyperfine         # Linux
cargo install hyperfine       # Cross-platform

# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Install Foundry (for Solidity compilation)
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### Build

```bash
# Build the Rust CLI
cargo build --release

# Build Guillotine (optional, if using Guillotine EVM)
cd evms/guillotine
zig build
cd apps/cli && go build -o guillotine-bench .
```

## Usage

### Basic Commands

```bash
# Run all benchmarks on default EVM
./target/release/evm-bench run

# Run specific benchmark
./target/release/evm-bench run ten_thousand_hashes

# List available benchmarks
./target/release/evm-bench list

# Show help
./target/release/evm-bench --help
```

### Advanced Options

```bash
# Run on specific EVM
./target/release/evm-bench run --evm guillotine
./target/release/evm-bench run --evm revm

# Run on multiple EVMs (matrix mode)
./target/release/evm-bench run --evms guillotine,revm
./target/release/evm-bench run --all

# Customize iterations and warmup
./target/release/evm-bench run --iterations 20 --warmup 5

# Export results
./target/release/evm-bench run --output results.json
./target/release/evm-bench run --export-json detailed.json

# Verbose output
./target/release/evm-bench run -v
```

### Compare EVMs

```bash
# Compare multiple implementations
./target/release/evm-bench compare guillotine revm

# Full matrix benchmark
./target/release/evm-bench run --all --output matrix_results.json
```

## Available Benchmarks

### Compute-Intensive
- **ten_thousand_hashes**: Execute 10,000 keccak256 hash operations
- **snailtracer**: Ray tracing benchmark (1B gas limit)

### Token Operations  
- **erc20_transfer_bench**: ERC20 transfer operations
- **erc20_mint_bench**: ERC20 minting operations
- **erc20_approval_bench**: ERC20 approval and transferFrom operations

## Supported EVMs

### Guillotine
- **Type**: Zig-based EVM with Rust SDK wrapper
- **Integration**: Via `guillotine-rs` crate (FFI bindings to Zig library)
- **Performance**: Optimized for speed via native Zig core
- **SDK Path**: `evms/guillotine/sdks/rust`

### Revm
- **Type**: Pure Rust EVM implementation
- **Integration**: Direct crate dependency (revm v14.0)
- **Performance**: Production-ready, high-performance implementation

## Output Format

Results are exported as JSON with comprehensive statistics:

```json
{
  "benchmark": "ten_thousand_hashes",
  "evm": "revm",
  "results": {
    "mean": 0.123,
    "stddev": 0.005,
    "median": 0.122,
    "min": 0.118,
    "max": 0.130,
    "times": [0.118, 0.122, ...]
  }
}
```

## Development

### Adding New Benchmarks

1. Create Solidity contract in `benchmarks/solidity/`
2. Add to benchmark configuration in `src/benchmarks.rs`
3. Test with `cargo run --release -- run <benchmark_name>`

### Project Structure

```
bench/
├── src/                    # Rust source code
│   ├── main.rs            # CLI entry point
│   ├── cli.rs             # Clap CLI definitions
│   ├── benchmarks.rs      # Benchmark configurations
│   ├── evms/              # EVM implementations
│   └── runner.rs          # Benchmark execution logic
├── benchmarks/            # Benchmark contracts
│   └── solidity/          # Solidity contracts
├── evms/                  # EVM submodules
│   └── guillotine/        # Guillotine implementation
└── out/                   # Compiled contracts
```

## Troubleshooting

### Hyperfine not found
```bash
# Install via package manager or cargo
brew install hyperfine     # macOS
cargo install hyperfine    # Cross-platform
```

### Guillotine not found
```bash
# Build from source
cd evms/guillotine
zig build
cd apps/cli && go build -o guillotine-bench .
```

### Benchmark compilation issues
```bash
# Clean and rebuild
cargo clean
cargo build --release
```

## Performance Tips

- Use `--warmup` flag to stabilize measurements
- Increase `--iterations` for more accurate results
- Run benchmarks on a quiet system for consistency
- Close unnecessary applications to reduce noise

## Contributing

Contributions are welcome! Please ensure:
- All benchmarks use real implementations (no mocks)
- Code follows Rust best practices
- Tests pass with `cargo test`
- Benchmarks are reproducible

## License

MIT License - see LICENSE file for details