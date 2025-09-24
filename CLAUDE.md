# EVM Benchmark Suite

## CRITICAL: BENCHMARK INTEGRITY

**ABSOLUTELY NO PLACEHOLDERS OR FAKE DATA ARE ACCEPTABLE IN BENCHMARKS**

Benchmarks MUST use real, measured data. Any placeholder values, hardcoded results, or fake timing data completely destroys the integrity and trustworthiness of the entire benchmark suite. 

**NEVER**:
- Use placeholder timing values
- Hardcode benchmark results
- Return fake data "for testing"
- Implement "temporary" solutions with made-up values

**ALWAYS**:
- Use actual measured performance data
- Parse real benchmark output
- Fail loudly if real data cannot be obtained
- Maintain complete integrity in all measurements

## Project Overview

This project is a comprehensive EVM (Ethereum Virtual Machine) benchmark suite that tests various EVM implementations across different languages. It uses a Zig-based harness to compile Solidity contracts and benchmark their execution using different EVM backends.

## Architecture

### Components

1. **Zig Benchmark Harness** (`src/main.zig`)
   - Main entry point for the benchmark system
   - Handles fixture loading and orchestration
   - Integrates with the Guillotine Solidity compiler
   - Uses Hyperfine for precise benchmark measurements

2. **REVM Runner** (Rust - `src/main.rs`)
   - Rust-based EVM executor using the REVM library
   - Accepts bytecode and calldata as command-line arguments
   - Returns execution results including gas usage

3. **Fixtures** (`fixtures/`)
   - JSON configuration files defining benchmark scenarios
   - Solidity contracts for testing different EVM operations
   - Current fixtures:
     - `bubblesort.json` - Bubble sort algorithm benchmark
     - `snailtracer.json` - Ray tracing benchmark
     - `ten-thousand-hashes.json` - Hashing operations benchmark

### Dependencies

- **Zig** - Main build system and benchmark orchestrator
- **Rust/Cargo** - For building the REVM runner
- **Hyperfine** - For precise benchmark measurements
- **Guillotine Compiler** - Solidity compilation via FFI

## Building the Project

```bash
# Build everything (Zig + Rust components)
zig build

# Build only the REVM runner
cargo build --release

# Build only Zig components
zig build -Dskip-cargo
```

## Running Benchmarks

```bash
# Run all benchmarks (recommended)
./run.sh

# Or using Zig directly
zig build benchmark

# Run a specific benchmark
zig build run -- -f bubblesort

# Compile contracts only (no benchmarking)
zig build run -- -c
```

## Fixture Format

Each fixture is a JSON file with the following structure:

```json
{
  "name": "benchmark-name",
  "num_runs": 5,
  "solc_version": "0.8.20",
  "contract": "Contract.sol",
  "calldata": "0x...",
  "warmup": 2,
  "gas_limit": 30000000
}
```

- `name`: Identifier for the benchmark
- `num_runs`: Number of benchmark iterations
- `solc_version`: Solidity compiler version (informational)
- `contract`: Relative path to Solidity contract file
- `calldata`: Hex-encoded function call data
- `warmup`: Number of warmup runs before measurement
- `gas_limit`: Maximum gas for execution

## Adding New Benchmarks

1. Create a new Solidity contract in `fixtures/`
2. Create a corresponding JSON fixture file
3. Run `./zig-out/bin/bench -f your-fixture` to test

## Testing Commands

```bash
# Run tests
zig build test

# Run with verbose output
zig build run -- --help

# Check compilation only
./zig-out/bin/bench --compile-only
```

## Project Structure

```
bench/
├── src/
│   ├── main.zig           # Main benchmark orchestrator
│   ├── fixture.zig        # Fixture parsing logic
│   ├── root.zig          # Library exports
│   ├── main.rs           # REVM runner entry point
│   ├── evm.rs            # EVM executor trait
│   └── revm_executor.rs  # REVM implementation
├── fixtures/
│   ├── *.json            # Benchmark configurations
│   └── *.sol             # Solidity contracts
├── build.zig             # Zig build configuration
├── build.zig.zon         # Zig dependencies
├── Cargo.toml            # Rust dependencies
└── CLAUDE.md             # This file

```

## Submodules

The project includes several EVM implementation submodules for comparison:
- `geth` - Go Ethereum implementation
- `revm` - Rust EVM implementation
- `ethrex` - Alternative Rust implementation
- `ethereumjs` - JavaScript implementation
- `py-evm` - Python implementation
- `guillotine` - Zig-based tools and compiler integration

## Development Notes

- The project uses Zig's build system to coordinate both Zig and Rust compilation
- Hyperfine is required for benchmarking (installation instructions provided if missing)
- The Guillotine compiler is used via FFI for on-demand Solidity compilation
- Benchmark results show gas usage and execution time for each fixture

## Common Issues & Solutions

1. **Hyperfine not found**: Install via `brew install hyperfine` (macOS) or `cargo install hyperfine`
2. **Compilation errors**: Ensure all submodules are initialized: `git submodule update --init --recursive`
3. **Rust build fails**: Make sure you have Rust installed and run `cargo build --release`
4. **Zig build fails**: Ensure you have Zig 0.13.0 or later installed