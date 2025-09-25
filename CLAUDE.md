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

This project is a comprehensive EVM (Ethereum Virtual Machine) benchmark suite that tests multiple EVM implementations across different programming languages. It uses a Zig-based harness to compile Solidity contracts via the Guillotine compiler and benchmark their execution using Hyperfine for precise, statistically rigorous measurements.

The suite currently benchmarks 10+ different EVM implementations/configurations including native implementations and various language bindings, with 34 different benchmark scenarios covering all major EVM operations.

## Architecture

### Components

1. **Zig Benchmark Harness** (`src/main.zig`)
   - Main entry point and orchestrator for the benchmark system
   - Handles fixture loading and benchmark execution
   - Integrates with the Guillotine Solidity compiler via FFI
   - Uses Hyperfine for precise benchmark measurements
   - Measures and subtracts startup overhead for accurate results
   - Supports internal run batching to reduce measurement noise

2. **EVM Runners**

   **Rust-based Runners:**
   - `src/main.rs`, `src/evm.rs` - Shared Rust runner infrastructure
   - `src/revm_executor.rs` - REVM implementation
   - `src/ethrex_executor.rs` - ethrex implementation
   - `src/guillotine_runner.rs` - Guillotine Rust bindings

   **Guillotine Language Bindings:**
   - `src/guillotine_runner.zig` - Native Zig implementation
   - `src/guillotine_bun_runner.ts` - TypeScript/Bun bindings
   - `src/guillotine_python_runner.py` - Python bindings
   - `src/guillotine_go_runner.go` - Go bindings

   **Other EVM Implementations:**
   - `src/geth_runner.go` - Go Ethereum (geth) runner
   - `src/py_evm_runner.py` - Python EVM implementation
   - `src/ethereumjs_runner.js` - EthereumJS implementation
   - `src/pyrevm_runner.py` - Python REVM bindings (not yet integrated)

3. **Fixtures** (`fixtures/`)
   - 34 JSON configuration files defining benchmark scenarios
   - 34 corresponding Solidity contracts testing different operations
   - Categories include:
     - Computational algorithms (factorial, fibonacci, sorting, ray tracing)
     - Cryptographic operations (hashing, SHA3)
     - Memory and storage operations
     - ERC20 token operations
     - Contract interactions (calls, creates, selfdestruct)
     - Core EVM operations (arithmetic, bitwise, control flow)

### Dependencies

- **Zig** (0.13.0+) - Main build system and benchmark orchestrator
- **Rust/Cargo** - For building Rust-based runners (REVM, ethrex, Guillotine-Rust)
- **Hyperfine** - For precise benchmark measurements with statistical analysis
- **Guillotine Compiler** - Solidity compilation via FFI
- **Bun** - For TypeScript/JavaScript Guillotine runner
- **Python 3** - For Python-based runners (py-evm, Guillotine-Python)
- **Go** - For Go-based runners (geth, Guillotine-Go)
- **Node.js** - For EthereumJS runner

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

- `name`: Identifier for the benchmark (must match filename without .json)
- `num_runs`: Number of benchmark iterations for statistical significance
- `solc_version`: Solidity compiler version (informational)
- `contract`: Relative path to Solidity contract file in fixtures/
- `calldata`: Hex-encoded function call data (function selector + ABI-encoded params)
- `warmup`: Number of warmup runs before measurement (reduces variance)
- `gas_limit`: Maximum gas for execution (set high enough to avoid out-of-gas)

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
evm-benchmarks/
├── src/
│   ├── main.zig                     # Main benchmark orchestrator
│   ├── fixture.zig                  # Fixture parsing logic
│   ├── root.zig                     # Library exports
│   ├── main.rs                      # Rust runner entry point
│   ├── evm.rs                       # EVM executor trait
│   ├── revm_executor.rs             # REVM implementation
│   ├── ethrex_executor.rs           # ethrex implementation
│   ├── guillotine_runner.zig        # Guillotine Zig runner
│   ├── guillotine_runner.rs         # Guillotine Rust runner
│   ├── guillotine_bun_runner.ts     # Guillotine TypeScript runner
│   ├── guillotine_python_runner.py  # Guillotine Python runner
│   ├── guillotine_go_runner.go      # Guillotine Go runner
│   ├── geth_runner.go                # Geth runner
│   ├── py_evm_runner.py              # py-evm runner
│   ├── ethereumjs_runner.js          # EthereumJS runner
│   └── pyrevm_runner.py              # PyREVM runner (pending)
├── fixtures/
│   ├── *.json                       # 34 benchmark configurations
│   └── *.sol                        # 34 Solidity contracts
├── build.zig                        # Zig build configuration
├── build.zig.zon                    # Zig dependencies
├── Cargo.toml                       # Rust dependencies
├── run.sh                           # Convenience runner script
├── results.md                       # Auto-generated results
└── CLAUDE.md                        # This file
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

### Build System
- The project uses Zig's build system to coordinate compilation of all components
- Rust components are built via Cargo integration in build.zig
- Go components are compiled to binaries in zig-out/bin/
- JavaScript/TypeScript runners execute directly via interpreters

### Benchmark Execution Flow
1. Fixture loading and validation
2. Solidity compilation via Guillotine FFI
3. Startup overhead measurement (if not cached)
4. Benchmark execution with Hyperfine
5. Results parsing and presentation
6. Optional results.md generation

### Performance Considerations
- Internal run batching reduces measurement noise for fast operations
- Startup overhead is measured once and cached
- Warmup runs eliminate cold-start effects
- Statistical analysis ensures reliable comparisons

### Adding New Runners
1. Create runner implementation in src/
2. Add command generation in main.zig (measureStartupOverhead and runBenchmarkForFixture)
3. Update build.zig if compilation is needed
4. Add to hyperfine command list in main.zig
5. Update BenchmarkResult struct if needed

## Common Issues & Solutions

1. **Hyperfine not found**: Install via `brew install hyperfine` (macOS) or `cargo install hyperfine`
2. **Compilation errors**: Ensure all submodules are initialized: `git submodule update --init --recursive`
3. **Rust build fails**: Make sure you have Rust installed and run `cargo build --release`
4. **Zig build fails**: Ensure you have Zig 0.13.0 or later installed
5. **Missing language runtimes**: Install required interpreters:
   - Bun: `curl -fsSL https://bun.sh/install | bash`
   - Python 3: Usually pre-installed, or use package manager
   - Node.js: Install from nodejs.org or use nvm
   - Go: Install from go.dev or use package manager
6. **Guillotine compiler errors**: Check that guillotine submodule is properly initialized
7. **Out of memory**: Some benchmarks (like snailtracer) require significant memory
8. **Inconsistent results**: Increase warmup and num_runs in fixture JSON for more stable measurements

## Known Limitations

- Some runners (geth, py-evm, ethereumjs) are only measured for startup overhead, not included in main benchmarks
- PyREVM runner exists but is not yet integrated into the benchmark suite
- Gas usage may vary between implementations due to different gas metering approaches
- Some language bindings have significant overhead compared to native implementations