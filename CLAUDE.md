# EVM Benchmark Repository

## Project Overview
This repository contains benchmarking tools for comparing Ethereum Virtual Machine (EVM) implementations. The primary goal is to provide accurate, reproducible performance measurements across different EVM implementations including **geth**, **guillotine**, and **revm**.

## Implementation Language
This project is being migrated to **Rust** using the Clap framework for robust CLI functionality and superior performance.

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
│   └── main.rs              # Main CLI application
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
│   ├── go-ethereum/         # Geth EVM implementation (git submodule)
│   ├── guillotine-go-sdk/   # Guillotine EVM implementation (git submodule)
│   └── revm/                # Revm implementation (git submodule)
├── out/                     # Foundry build artifacts
├── Makefile                 # Build automation
└── results_*.json           # Benchmark results for each test
```

## Supported EVM Implementations

### 1. Geth (go-ethereum)
- **Binary**: `evms/go-ethereum/build/bin/evm` or system `evm`
- **Integration**: Uses the standalone `evm` tool for benchmark execution
- **Command**: `evm run --codefile <file> --gas <limit> --input <calldata>`

### 2. Guillotine
- **Binary**: `evms/guillotine-go-sdk/apps/cli/guillotine-bench`
- **Integration**: Custom Go CLI with Zig EVM core via FFI
- **Command**: `guillotine-bench run --codefile <file> --gas <limit> --input <calldata>`
- **Architecture**: Zig-based EVM with Go bindings, optimized for performance

### 3. Revm
- **Binary**: `evms/revm/target/release/revme` (built from source)
- **Integration**: Rust-based EVM using revme CLI tool
- **Command**: `revme evm --path <file> --gas-limit <limit> --input <calldata>`
- **Architecture**: High-performance Rust implementation, widely used in production
- **Build**: `cd evms/revm && cargo build --release -p revme`

## Available Benchmarks

### Compute-Intensive
1. **ten_thousand_hashes**: Execute 10,000 keccak256 hash operations
2. **snailtracer**: Ray tracing benchmark (extremely compute intensive, 1B gas)

### Token Operations
1. **erc20_transfer_bench**: Benchmark ERC20 transfer operations
2. **erc20_mint_bench**: Benchmark ERC20 minting operations
3. **erc20_approval_bench**: Benchmark ERC20 approval and transfer operations

## Running Benchmarks

### Basic Usage (Rust CLI)
```bash
# Build the Rust CLI
cargo build --release

# Run all benchmarks
./target/release/bench run

# Run specific benchmark
./target/release/bench run ten_thousand_hashes

# Run with custom iterations
./target/release/bench run --iterations 20 --warmup 5

# Run on specific EVM
./target/release/bench run --evm guillotine

# Run matrix benchmark across multiple EVMs
./target/release/bench run --evms geth,guillotine
./target/release/bench run --all  # Run on all available EVMs
```

### Advanced Options
```bash
# Customize iterations and warmup
./target/release/bench run --iterations 20 --warmup 5

# Export results
./target/release/bench run --output results.json --export-json hyperfine.json

# Verbose output
./target/release/bench run -v
```

### Matrix Benchmarking
The CLI supports running benchmarks across multiple EVM implementations simultaneously:
```bash
# Compare geth and guillotine
./target/release/bench run --evms geth,guillotine

# Run all benchmarks on all EVMs
./target/release/bench run --all

# Compare implementations
./target/release/bench compare geth guillotine revm

# Save matrix results
./target/release/bench run --all --output full_matrix.json
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

### 3. Dynamic Benchmark Discovery
- Automatically detects compiled Solidity contracts
- Loads bytecode from Foundry artifacts (`out/` directory)
- Validates EVM binary availability
- Skips unavailable benchmarks gracefully

### 4. Unified Benchmark Interface
All EVM implementations use the same benchmark execution flow:
1. Create temporary bytecode file
2. Execute with specified gas limit and calldata
3. Measure execution time via hyperfine
4. Parse and display results

## Building EVM Implementations

### Building Geth
```bash
cd evms/go-ethereum
make geth
make evm  # Required for benchmarking
```

### Building Guillotine
```bash
cd evms/guillotine-go-sdk
zig build

# Build the benchmark CLI
cd apps/cli
go build -o guillotine-bench .
```

### Building Revm
```bash
cd evms/revm
cargo build --release -p revme
# Binary will be at: evms/revm/target/release/revme
```

## Development Guidelines

### Adding New Benchmarks
1. Create Solidity contract in `benchmarks/solidity/`
2. Compile with Foundry: `forge build`
3. Add configuration in the Rust implementation to include the new benchmark

### Adding New EVM Implementation
1. Add binary finder logic in Rust implementation
2. Add runner function for the new EVM
3. Update benchmark runner to route to new implementation

### Testing
```bash
# Run Rust tests
cargo test

# Run Solidity tests
forge test

# Run a quick benchmark test
./target/release/bench run ten_thousand_hashes --iterations 3

# Test with verbose output
./target/release/bench run -v
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
  "results": [
    {
      "command": "evm run ...",
      "mean": 0.123,
      "stddev": 0.005,
      "median": 0.122,
      "user": 0.120,
      "system": 0.003,
      "min": 0.118,
      "max": 0.130,
      "times": [0.118, 0.122, ...]
    }
  ]
}
```

## Troubleshooting

### Common Issues

1. **"geth not found"**
   - Build geth: `cd evms/go-ethereum && make geth && make evm`
   - Or install system-wide: `brew install ethereum` (macOS)

2. **"guillotine-bench not found"**
   - Build Guillotine: `cd evms/guillotine-go-sdk && zig build`
   - Build CLI: `cd apps/cli && go build -o guillotine-bench .`

3. **"hyperfine not installed"**
   - macOS: `brew install hyperfine`
   - Linux: `apt install hyperfine`
   - Cargo: `cargo install hyperfine`

4. **Benchmark fails with "out of gas"**
   - Increase gas limit in benchmark configuration
   - Check if bytecode includes constructor vs runtime code

5. **No benchmarks available**
   - Run `forge build` to compile Solidity contracts
   - Check `out/` directory for compiled artifacts

6. **Rust CLI issues**
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