# EVM Benchmark Suite - Go Version

A modern Go implementation of the EVM benchmark suite with an interactive TUI built using [Bubble Tea](https://github.com/charmbracelet/bubbletea) and [urfave/cli](https://github.com/urfave/cli).

## Features

- 🎨 **Interactive TUI**: Beautiful terminal UI with real-time progress tracking
- 📊 **Matrix Benchmarking**: Compare multiple EVM implementations side-by-side
- 🚀 **Fast & Efficient**: Native Go performance with concurrent benchmark execution
- 📈 **Hyperfine Integration**: Statistical analysis with multiple runs and warmup
- 🔧 **Multiple EVMs**: Support for Geth, Guillotine, and Revm

## Installation

### Prerequisites

1. **Go 1.20+**: Install from [golang.org](https://golang.org)
2. **Hyperfine**: Statistical benchmarking tool
   ```bash
   # macOS
   brew install hyperfine
   
   # Linux
   apt install hyperfine
   
   # Or via Cargo
   cargo install hyperfine
   ```

### Building from Source

```bash
# Clone the repository
git clone https://github.com/williamcory/bench
cd bench

# Install dependencies
go mod download

# Build the CLI
make build-go
# or
go build -o bench cmd/bench/main.go
```

## Usage

### Basic Commands

```bash
# List available benchmarks
./bench list

# Run all benchmarks with TUI (default)
./bench run

# Run specific benchmark
./bench run ten_thousand_hashes

# Run without TUI
./bench run --no-tui

# Run with specific iterations
./bench run --iterations 20 --warmup 5
```

### EVM Selection

```bash
# Run on specific EVM
./bench run --evm geth
./bench run --evm guillotine
./bench run --evm revm

# Run on multiple EVMs
./bench run --evms geth,guillotine

# Run on all available EVMs
./bench run --all
```

### Matrix Benchmarking

Compare multiple EVM implementations:

```bash
# Compare specific EVMs
./bench compare geth guillotine revm

# Run matrix benchmark with output
./bench run --all --output matrix_results.json

# Use Makefile target
make bench-matrix
```

### Output Formats

```bash
# Save results to JSON
./bench run --output results.json

# Export raw hyperfine data
./bench run --export-json hyperfine_data.json

# Export markdown report
./bench run --export-markdown report.md
```

## TUI Mode

The interactive TUI provides:

- **Visual Progress**: Real-time progress bars and status indicators
- **Keyboard Navigation**: 
  - `↑/↓` or `j/k`: Navigate benchmarks
  - `Enter`: Run selected benchmark
  - `a`: Run all benchmarks
  - `q`: Quit
- **Live Results**: See benchmark times as they complete
- **Color-coded Status**: Visual feedback for pending/running/complete/failed states

## Available Benchmarks

### Compute Intensive
- **ten_thousand_hashes**: Execute 10,000 keccak256 hash operations
- **snailtracer**: Ray tracing benchmark (1B gas limit)

### Token Operations
- **erc20_transfer_bench**: ERC20 transfer operations
- **erc20_mint_bench**: ERC20 minting operations
- **erc20_approval_bench**: ERC20 approval and transfer operations

## Makefile Targets

```bash
# Go CLI targets
make build-go         # Build Go CLI
make run-go           # Run Go CLI
make test-go          # Run Go tests
make bench-geth       # Run benchmarks on geth
make bench-guillotine # Run benchmarks on guillotine
make bench-revm       # Run benchmarks on revm
make bench-matrix     # Run matrix benchmark on all EVMs

# Setup
make setup-go         # Download Go dependencies
make clean           # Clean build artifacts
```

## Architecture

### Project Structure

```
bench/
├── cmd/bench/         # CLI entry point
│   └── main.go       # Main application with urfave/cli
├── internal/
│   ├── benchmark/    # Core benchmark logic
│   │   ├── evm.go    # EVM benchmark definitions
│   │   └── runner.go # Benchmark execution
│   └── tui/          # Bubble Tea TUI components
│       ├── model.go  # TUI state management
│       └── styles.go # Lipgloss styling
├── go.mod            # Go module definition
└── Makefile          # Build automation
```

### Key Components

1. **urfave/cli**: Command-line interface with subcommands and flags
2. **Bubble Tea**: Terminal UI framework for interactive mode
3. **Lipgloss**: Terminal styling and colors
4. **Hyperfine Integration**: Statistical benchmarking via subprocess

## Differences from Python Version

### Improvements
- ✅ **Better Performance**: Native compilation, faster startup
- ✅ **Interactive TUI**: Rich terminal UI with Bubble Tea
- ✅ **Type Safety**: Compile-time type checking
- ✅ **Concurrent Execution**: Go routines for parallel benchmarks
- ✅ **Better Error Handling**: Explicit error returns

### Trade-offs
- 📦 **Binary Size**: Larger than Python script
- 🔧 **Compilation Required**: Must build before running
- 📚 **Dependency Management**: Uses Go modules instead of pip

## Development

### Running Tests

```bash
# Run all tests
make test-go

# Run with verbose output
go test -v ./...

# Run specific package tests
go test -v ./internal/benchmark
```

### Code Quality

```bash
# Format code
go fmt ./...

# Run go vet
go vet ./...

# Run golangci-lint (if installed)
golangci-lint run
```

### Adding New Benchmarks

1. Add bytecode loading in `internal/benchmark/evm.go`:
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

2. Compile the Solidity contract:
```bash
forge build
```

3. Run the new benchmark:
```bash
./bench run new_benchmark
```

## Troubleshooting

### Common Issues

1. **"hyperfine not installed"**
   - Install hyperfine: `brew install hyperfine` (macOS)

2. **"geth not found"**
   - Build geth: `cd evms/go-ethereum && make geth && make evm`

3. **TUI not working**
   - Use `--no-tui` flag for non-interactive mode
   - Ensure terminal supports ANSI escape codes

4. **Build errors**
   - Update dependencies: `go mod tidy`
   - Clear module cache: `go clean -modcache`

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

Same as the main repository.

## Migration from Python

If you're migrating from the Python version:

1. **Command compatibility**: Most flags are the same
2. **Output format**: JSON output is compatible
3. **Benchmark names**: All benchmark names remain unchanged
4. **Results**: Hyperfine integration produces identical metrics

The Go version is designed as a drop-in replacement with enhanced features.