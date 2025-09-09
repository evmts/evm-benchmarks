# EVM Benchmark Repository

## Project Overview
This repository contains benchmarking tools for comparing Ethereum Virtual Machine (EVM) implementations. The primary goal is to provide accurate, reproducible performance measurements across different EVM implementations including **geth**, **guillotine**, and **revm**.

## Implementation Language
This project is implemented in **Go** with an interactive TUI built using Bubble Tea. The previous Python implementation has been deprecated in favor of better performance and a richer user experience.

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
├── cmd/bench/                 # CLI entry point
│   └── main.go               # Main application with urfave/cli
├── internal/
│   ├── benchmark/            # Core benchmark logic
│   │   ├── evm.go           # EVM benchmark definitions
│   │   └── runner.go        # Benchmark execution
│   └── tui/                 # Bubble Tea TUI components
│       ├── model.go         # TUI state management
│       └── styles.go        # Lipgloss styling
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
├── go.mod                   # Go module definition
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

### Basic Usage
```bash
# Build the Go CLI
make build-go

# Run all benchmarks with TUI
./bench run

# Run specific benchmark
./bench run ten_thousand_hashes

# Run without TUI
./bench run --no-tui

# Run on specific EVM
./bench run --evm guillotine --no-tui

# Run matrix benchmark across multiple EVMs
./bench run --evms geth,guillotine
./bench run --all  # Run on all available EVMs
```

### Advanced Options
```bash
# Customize iterations and warmup
./bench run --iterations 20 --warmup 5 --no-tui

# Export results
./bench run --output results.json --export-json hyperfine.json

# Verbose output
./bench run -v --no-tui
```

### Matrix Benchmarking
The CLI supports running benchmarks across multiple EVM implementations simultaneously:
```bash
# Compare geth and guillotine
./bench run --evms geth,guillotine

# Run all benchmarks on all EVMs
./bench run --all --no-tui

# Compare implementations
./bench compare geth guillotine revm

# Save matrix results
./bench run --all --output full_matrix.json
```

Matrix results include:
- Side-by-side performance comparison
- Relative speed differences
- Gas consumption metrics
- Success/failure status per benchmark

## Key Features

### 1. Interactive TUI (Bubble Tea)
The Go implementation features a beautiful terminal UI:
- Real-time progress tracking
- Keyboard navigation (↑/↓, j/k, Enter, a, q)
- Color-coded status indicators
- Live benchmark results

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
3. Add configuration in `internal/benchmark/evm.go`:
```go
if bytecode, err := GetContractBytecode("ContractName"); err == nil {
    benchmarks["new_benchmark"] = &Benchmark{
        Name:        "new_benchmark",
        Description: "Description of benchmark",
        Category:    "compute|token|storage",
        Type:        "evm",
        Bytecode:    bytecode,
        Calldata:    GetFunctionSelector("functionName()"),
        Gas:         30000000,
    }
}
```

### Adding New EVM Implementation
1. Add binary finder function in `internal/benchmark/evm.go`:
```go
func FindNewEVMBinary() (string, error) {
    // Logic to locate the EVM binary
}
```

2. Add runner function in `internal/benchmark/runner.go`:
```go
func runNewEVMBenchmark(bench *Benchmark, iterations int, useHyperfine bool, verbose bool) (*BenchmarkResult, error) {
    // Implementation-specific execution logic
}
```

3. Update `RunEVMBenchmark()` to route to new implementation

### Testing
```bash
# Run Go tests
make test-go

# Run with verbose output
go test -v ./...

# Run Solidity tests
forge test

# Format code
go fmt ./...

# Run vet
go vet ./...

# Run a quick benchmark test
./bench run ten_thousand_hashes --iterations 3 --no-tui
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

6. **TUI not working**
   - Use `--no-tui` flag for non-interactive mode
   - Ensure terminal supports ANSI escape codes
   - Check that TERM environment variable is set

7. **Build errors**
   - Update dependencies: `go mod tidy`
   - Clear module cache: `go clean -modcache`

## Recent Updates

### Go Implementation (v3.0)
- Complete rewrite in Go for better performance
- Interactive TUI with Bubble Tea
- Improved error handling and type safety
- Concurrent benchmark execution support

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