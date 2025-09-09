# EVM Benchmark Suite

A modern benchmarking framework for comparing Ethereum Virtual Machine (EVM) implementations, built with Go and featuring an interactive terminal UI.

## Overview

This repository provides a standardized benchmarking suite for evaluating and comparing different EVM implementations including:
- **geth** (go-ethereum)
- **guillotine** (Zig-based EVM with Go SDK)
- **revm** (Rust-based EVM)

The framework measures real execution performance using production-grade test scenarios without any mocks, stubs, or simulated behavior.

## Features

- 🎨 **Interactive TUI**: Beautiful terminal UI built with [Bubble Tea](https://github.com/charmbracelet/bubbletea)
- 📊 **Matrix Benchmarking**: Compare multiple EVM implementations side-by-side
- 🚀 **High Performance**: Native Go implementation with concurrent execution
- 📈 **Statistical Analysis**: Hyperfine integration for rigorous performance measurements
- 🔧 **Multiple EVMs**: Support for Geth, Guillotine, and Revm
- ✅ **Real EVM Execution**: All benchmarks execute actual EVM bytecode on real implementations

## Quick Start

### Prerequisites

- Go 1.20+ ([install](https://golang.org/doc/install))
- [Hyperfine](https://github.com/sharkdp/hyperfine#installation) for statistical benchmarking
- [Foundry](https://book.getfoundry.sh/getting-started/installation) for Solidity compilation
- Make

### Installation

1. Clone the repository with submodules:
```bash
git clone --recursive https://github.com/williamcory/bench.git
cd bench
```

2. Install Go dependencies:
```bash
go mod download
```

3. Build the CLI:
```bash
make build-go
# or
go build -o bench cmd/bench/main.go
```

4. Build the Solidity contracts:
```bash
forge build
```

### Running Benchmarks

#### Interactive Mode (TUI)
```bash
# Run with interactive TUI
./bench run

# Run specific benchmark
./bench run ten_thousand_hashes
```

In TUI mode:
- `↑/↓` or `j/k`: Navigate benchmarks
- `Enter`: Run selected benchmark
- `a`: Run all benchmarks
- `q`: Quit

#### Command Line Mode
```bash
# Run without TUI
./bench run --no-tui

# Run with specific iterations
./bench run --iterations 20 --warmup 5 --no-tui

# Run on specific EVM
./bench run --evm geth --no-tui
./bench run --evm guillotine --no-tui
./bench run --evm revm --no-tui
```

#### Matrix Benchmarking
```bash
# Compare multiple EVMs
./bench run --evms geth,guillotine

# Run on all available EVMs
./bench run --all --no-tui

# Compare implementations
./bench compare geth guillotine revm

# Save results
./bench run --all --output matrix_results.json
```

## Available Benchmarks

### Computational Benchmarks
- **ten_thousand_hashes**: Execute 10,000 keccak256 hash operations
- **snailtracer**: Ray tracing benchmark (1B gas limit, extremely compute intensive)

### Token Operations
- **erc20_transfer_bench**: ERC20 token transfer performance
- **erc20_mint_bench**: Token minting operations
- **erc20_approval_bench**: Approval and transferFrom patterns

## Project Structure

```
bench/
├── cmd/bench/           # CLI entry point
│   └── main.go         # Main application with urfave/cli
├── internal/
│   ├── benchmark/      # Core benchmark logic
│   │   ├── evm.go     # EVM benchmark definitions
│   │   └── runner.go  # Benchmark execution
│   └── tui/           # Bubble Tea TUI components
│       ├── model.go   # TUI state management
│       └── styles.go  # Lipgloss styling
├── benchmarks/         # Solidity benchmark contracts
│   ├── solidity/      # Contract source files
│   └── snailtracer/   # Ray tracing benchmark
├── evms/              # EVM implementations (git submodules)
│   ├── go-ethereum/   # Geth
│   ├── guillotine-go-sdk/ # Guillotine
│   └── revm/          # Revm
├── out/               # Foundry build artifacts
├── go.mod             # Go module definition
├── Makefile           # Build automation
└── foundry.toml       # Foundry configuration
```

## Building EVM Implementations

### Geth
```bash
cd evms/go-ethereum
make geth
make evm  # Required for benchmarking
```

### Guillotine
```bash
cd evms/guillotine-go-sdk
zig build

# Build the benchmark CLI
cd apps/cli
go build -o guillotine-bench .
```

### Revm
```bash
cd evms/revm
cargo build --release -p revme
# Binary: evms/revm/target/release/revme
```

## Development

### Running Tests
```bash
# Run all Go tests
make test-go

# Run with verbose output
go test -v ./...

# Run Solidity tests
forge test
```

### Code Quality
```bash
# Format code
go fmt ./...

# Run go vet
go vet ./...

# Run linter (if installed)
golangci-lint run
```

### Adding New Benchmarks

1. Create Solidity contract in `benchmarks/solidity/`
2. Compile with Foundry: `forge build`
3. Add configuration in `internal/benchmark/evm.go`:

```go
if bytecode, err := GetContractBytecode("NewContract"); err == nil {
    benchmarks["new_benchmark"] = &Benchmark{
        Name:        "new_benchmark",
        Description: "Description here",
        Category:    "category",
        Type:        "evm",
        Bytecode:    bytecode,
        Calldata:    GetFunctionSelector("run()"),
        Gas:         30000000,
    }
}
```

## Makefile Targets

```bash
# Build and run
make build-go         # Build Go CLI
make run-go           # Run benchmarks
make test-go          # Run tests

# Benchmark specific EVMs
make bench-geth       # Run on geth
make bench-guillotine # Run on guillotine  
make bench-revm       # Run on revm
make bench-matrix     # Run matrix benchmark

# Maintenance
make clean            # Clean build artifacts
make setup-go         # Setup Go dependencies
make setup-foundry    # Install Foundry
```

## Benchmark Integrity

This framework maintains strict benchmark integrity by:
- **NO MOCKS**: Never using mock implementations
- **NO STUBS**: Avoiding stub functions or placeholders
- **NO FAKE DATA**: Using only real blockchain data or proper test vectors
- **NO SHORTCUTS**: Executing full implementation paths
- **NO APPROXIMATIONS**: Reporting actual measured performance

See [CLAUDE.md](./CLAUDE.md) for detailed integrity guidelines.

## Results Format

Results are exported in JSON format compatible with hyperfine:

```json
{
  "results": [
    {
      "command": "evm run ...",
      "mean": 0.123,
      "stddev": 0.005,
      "median": 0.122,
      "min": 0.118,
      "max": 0.130,
      "times": [0.118, 0.122, ...]
    }
  ]
}
```

## Troubleshooting

### Hyperfine not found
```bash
# macOS
brew install hyperfine

# Linux
apt install hyperfine

# Cargo
cargo install hyperfine
```

### Geth not found
```bash
cd evms/go-ethereum
make geth && make evm
```

### TUI not working
- Use `--no-tui` flag for non-interactive mode
- Ensure terminal supports ANSI escape codes

### Build errors
```bash
# Update dependencies
go mod tidy

# Clear module cache
go clean -modcache
```

## Contributing

We welcome contributions! Please ensure:
- Code passes all tests
- Benchmarks maintain integrity (no mocks/stubs)
- Documentation is updated
- Pull requests include test coverage

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [Bubble Tea](https://github.com/charmbracelet/bubbletea) for the TUI framework
- [Hyperfine](https://github.com/sharkdp/hyperfine) for statistical benchmarking
- [Foundry](https://github.com/foundry-rs/foundry) for Solidity tooling
- The Ethereum community for EVM implementations