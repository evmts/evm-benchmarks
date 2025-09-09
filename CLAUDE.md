# EVM Benchmark Repository

## Project Overview
This repository contains benchmarking tools for comparing Ethereum Virtual Machine (EVM) implementations. The primary goal is to provide accurate, reproducible performance measurements across different EVM implementations including **guillotine** and **revm**.

## Implementation Language
This project is implemented in **Rust** using the Clap framework for robust CLI functionality and superior performance.

## Critical Benchmark Integrity Rules

### ABSOLUTELY FORBIDDEN:
- **NO MOCKS**: Never use mock implementations or simulated behavior
- **NO STUBS**: Do not create stub functions or placeholder implementations
- **NO FAKE DATA**: All test data must be real blockchain data or properly generated test vectors
- **NO SHORTCUTS**: Every benchmark must execute the full, real implementation path
- **NO APPROXIMATIONS**: Results must reflect actual performance, not estimated or interpolated values

### Why This Matters
Benchmarks are only valuable if they measure real performance. Any compromise in benchmark integrity:
- Invalidates performance comparisons between implementations
- Misleads developers about actual performance characteristics
- Undermines trust in the benchmarking results
- Could lead to incorrect optimization decisions

## Repository Structure
```
bench/
├── src/                      # Rust source code
│   ├── main.rs              # Main CLI application
│   ├── cli.rs               # Clap CLI definitions
│   ├── benchmarks.rs        # Benchmark configurations
│   ├── compiler.rs          # Solidity compilation
│   ├── evm.rs               # EVM execution logic
│   ├── evms/                # EVM implementations
│   └── runner.rs            # Benchmark runner
├── Cargo.toml               # Rust package manifest
├── benchmarks/
│   ├── solidity/            # Solidity benchmark contracts
│   │   ├── TenThousandHashes.sol
│   │   ├── ERC20Transfer.sol
│   │   ├── ERC20Mint.sol
│   │   └── ERC20ApprovalTransfer.sol
│   └── snailtracer/         # Ray tracing benchmark
│       ├── snailtracer.sol  # Solidity 0.4.26 implementation
│       └── snailtracer_runtime.hex  # Compiled bytecode
├── evms/
│   ├── guillotine/          # Guillotine EVM implementation (git submodule)
│   └── revm/                # Revm implementation (git submodule)
└── results_*.json           # Benchmark results for each test
```

## Supported EVM Implementations

### 1. Guillotine
- **Binary**: `evms/guillotine/apps/cli/guillotine-bench`
- **Integration**: Custom Go CLI with Zig EVM core via FFI
- **Command**: `guillotine-bench run --codefile <file> --gas <limit> --input <calldata>`
- **Architecture**: Zig-based EVM with Go bindings, optimized for performance

### 2. Revm
- **Integration**: Native Rust integration via revm crate
- **Architecture**: High-performance Rust implementation, widely used in production
- **Note**: Built-in support, no external binary required

## Available Benchmarks

### Compute-Intensive
1. **ten_thousand_hashes**: Execute 10,000 keccak256 hash operations
2. **snailtracer**: Ray tracing benchmark (extremely compute intensive, 1B gas)

### Token Operations
1. **erc20_transfer_bench**: Benchmark ERC20 transfer operations
2. **erc20_mint_bench**: Benchmark ERC20 minting operations
3. **erc20_approval_bench**: Benchmark ERC20 approval and transfer operations

## Running Benchmarks

### Basic Usage
```bash
# Build the Rust CLI
cargo build --release

# Run all benchmarks
cargo run --release -- run

# Run specific benchmark
cargo run --release -- run ten_thousand_hashes

# List available benchmarks
cargo run --release -- list
```

### Advanced Options
```bash
# Run on specific EVM
cargo run --release -- run --evm guillotine
cargo run --release -- run --evm revm

# Run on multiple EVMs (matrix mode)
cargo run --release -- run --evms guillotine,revm
cargo run --release -- run --all

# Customize iterations and warmup
cargo run --release -- run --iterations 20 --warmup 5

# Export results
cargo run --release -- run --output results.json
cargo run --release -- run --export-json hyperfine.json

# Verbose output
cargo run --release -- run -v
```

### Matrix Benchmarking
The CLI supports running benchmarks across multiple EVM implementations simultaneously:
```bash
# Compare implementations
cargo run --release -- compare guillotine revm

# Run all benchmarks on all EVMs
cargo run --release -- run --all

# Save matrix results
cargo run --release -- run --all --output full_matrix.json
```

Matrix results include:
- Side-by-side performance comparison
- Relative speed differences
- Gas consumption metrics
- Success/failure status per benchmark

## Key Features

### 1. Robust CLI with Clap
The Rust implementation features:
- Type-safe command parsing with Clap
- High-performance execution
- Structured subcommands and options
- Cross-platform compatibility

### 2. Hyperfine Integration
All benchmarks use [hyperfine](https://github.com/sharkdp/hyperfine) for accurate measurements:
- Statistical analysis of multiple runs
- Warmup iterations to stabilize performance
- JSON export for detailed analysis
- Automatic outlier detection

### 3. Integrated Solidity Compilation
- Uses foundry-compilers crate for on-demand compilation
- No external Foundry installation required
- Transparent compilation before benchmark execution
- Automatic contract detection and loading

### 4. Unified Benchmark Interface
All EVM implementations use the same benchmark execution flow:
1. Compile contracts if needed
2. Execute with specified gas limit and calldata
3. Measure execution time via hyperfine
4. Parse and display results

## Building EVM Implementations

### Building Guillotine (Optional)
```bash
cd evms/guillotine
zig build

# Build the benchmark CLI
cd apps/cli
go build -o guillotine-bench .
```

### Revm
Revm is integrated directly via Cargo dependencies - no separate build required.

## Development Guidelines

### Adding New Benchmarks
1. Create Solidity contract in `benchmarks/solidity/`
2. Add configuration in `src/benchmarks.rs`
3. Test with `cargo run --release -- run <benchmark_name>`

### Adding New EVM Implementation
1. Add implementation in `src/evms/` module
2. Update runner logic in `src/runner.rs`
3. Add to CLI options in `src/cli.rs`

### Testing
```bash
# Run Rust tests
cargo test

# Run a quick benchmark test
cargo run --release -- run ten_thousand_hashes --iterations 3

# Test with verbose output
cargo run --release -- run -v
```

## Performance Considerations

### Gas Limits
- Standard benchmarks: 30M gas
- Snailtracer: 1B gas (compute intensive)
- Adjust based on benchmark complexity

### Iterations
- Default: 10 iterations with 3 warmup runs
- Increase for more stable results
- Decrease for quick testing

### Environment Variables
For Guillotine benchmarks, suppress debug output:
- `GUILLOTINE_LOG_LEVEL=error`
- `ZIG_LOG_LEVEL=error`

## Benchmark Results Format

Results are stored as JSON with hyperfine statistics:
```json
{
  "benchmark": "ten_thousand_hashes",
  "evm": "revm",
  "results": {
    "mean": 0.123,
    "stddev": 0.005,
    "median": 0.122,
    "user": 0.120,
    "system": 0.003,
    "min": 0.118,
    "max": 0.130,
    "times": [0.118, 0.122, ...]
  }
}
```

## Troubleshooting

### Common Issues

1. **"guillotine-bench not found"**
   - Build Guillotine: `cd evms/guillotine && zig build`
   - Build CLI: `cd apps/cli && go build -o guillotine-bench .`

2. **"hyperfine not installed"**
   - macOS: `brew install hyperfine`
   - Linux: `apt install hyperfine`
   - Cargo: `cargo install hyperfine`

3. **Benchmark fails with "out of gas"**
   - Increase gas limit in benchmark configuration
   - Check if bytecode includes constructor vs runtime code

4. **Rust CLI issues**
   - Build with: `cargo build --release`
   - Check Rust version: requires Rust 1.70+
   - Verify hyperfine is installed

## Recent Updates

### Foundry Compilers Integration (v6.0)
- Integrated foundry-compilers crate for Solidity compilation
- Removed dependency on external Foundry installation
- Contracts are compiled on-demand by the benchmarking orchestrator
- Compilation happens transparently before benchmark execution

### Rust Implementation (v5.0)
- Migrated to Rust with Clap for superior performance
- Type-safe CLI with structured commands
- Native performance for benchmark execution
- Cross-platform compatibility

### Matrix Benchmarking (v2.0)
- Compare multiple EVM implementations side-by-side
- Visual matrix summary with performance comparisons
- Support for `--evms` and `--all` flags

### Guillotine Integration (v1.5)
- Full support for Guillotine EVM benchmarking
- Custom runner for Zig-based implementation
- FFI bridge via Go SDK

### Snailtracer Benchmark (v1.0)
- Added compute-intensive ray tracing benchmark
- Tests extreme computation scenarios
- 1B gas limit for stress testing

Remember: The integrity of these benchmarks is paramount. When in doubt, choose accuracy over convenience.