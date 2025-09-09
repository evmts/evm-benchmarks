# EVM Benchmark Suite

A comprehensive benchmarking framework for comparing Ethereum Virtual Machine (EVM) implementations with focus on performance accuracy and reproducibility.

## Overview

This repository provides a standardized benchmarking suite for evaluating and comparing different EVM implementations including:
- **geth** (go-ethereum)
- **reth** (Rust Ethereum)
- **evms** (Ethereum Virtual Machine in Zig)

The framework measures real execution performance using production-grade test scenarios without any mocks, stubs, or simulated behavior.

## Features

- **Real EVM Execution**: All benchmarks execute actual EVM bytecode on real implementations
- **Multiple Benchmark Categories**:
  - Computational benchmarks (keccak256 hashing)
  - Token operations (ERC20 transfers, minting, approvals)
  - Complex contract interactions
- **Hyperfine Integration**: Uses [hyperfine](https://github.com/sharkdp/hyperfine) for statistically rigorous performance measurements
- **Automated Testing**: Comprehensive test suite with CI/CD integration
- **Docker Support**: Containerized environment for reproducible benchmarking
- **Extensible Architecture**: Easy to add new benchmarks and EVM implementations

## Quick Start

### Prerequisites

- Python 3.7+
- [Foundry](https://book.getfoundry.sh/getting-started/installation) (for Solidity compilation)
- [Hyperfine](https://github.com/sharkdp/hyperfine#installation) (for benchmarking)
- Go 1.19+ (for building geth)
- Make

### Installation

1. Clone the repository with submodules:
```bash
git clone --recursive https://github.com/yourusername/evm-bench.git
cd evm-bench
```

2. Install the benchmarking framework:
```bash
make install
```

3. Install development dependencies and compile contracts:
```bash
make dev
```

4. Build the contracts:
```bash
make build
```

### Running Benchmarks

List available benchmarks:
```bash
evm-bench list
```

Run all benchmarks:
```bash
evm-bench run
```

Run specific benchmark:
```bash
evm-bench run ten_thousand_hashes
```

Run with custom iterations:
```bash
evm-bench run --iterations 20 --warmup 5
```

Export results:
```bash
evm-bench run --export-json results.json --export-markdown results.md
```

## Benchmark Categories

### Computational Benchmarks
- **ten_thousand_hashes**: Executes 20,000 keccak256 hash operations
- **snailtracer**: Complex computational workload

### Token Operations
- **erc20_transfer_bench**: Measures ERC20 token transfer performance
- **erc20_mint_bench**: Benchmarks token minting operations
- **erc20_approval_bench**: Tests approval and transferFrom patterns

## Project Structure

```
.
├── benchmarks/           # Solidity benchmark contracts
│   ├── erc20/           # ERC20 token benchmarks
│   └── ten-thousand-hashes/  # Hashing benchmarks
├── src/                 # Python benchmark runner
│   ├── cli.py          # CLI interface
│   └── evm_benchmarks.py  # EVM benchmark configurations
├── evms/               # Git submodule for evms implementation
├── tests/              # Unit tests
├── Makefile           # Build automation
├── foundry.toml       # Foundry configuration
└── Dockerfile         # Container definition
```

## Development

### Running Tests

Run all tests:
```bash
make test
```

Run Python tests only:
```bash
pytest tests/ -v
```

Run Solidity tests:
```bash
forge test
```

### Code Quality

Lint code:
```bash
make lint
```

Format code:
```bash
make format
```

### Building from Source

Build all components:
```bash
make all
```

Clean build artifacts:
```bash
make clean
```

## Docker Usage

Build Docker image:
```bash
make docker-build
```

Run benchmarks in container:
```bash
make docker-run
```

## Benchmark Integrity

This framework maintains strict benchmark integrity by:
- **NO MOCKS**: Never using mock implementations
- **NO STUBS**: Avoiding stub functions or placeholders
- **NO FAKE DATA**: Using only real blockchain data or proper test vectors
- **NO SHORTCUTS**: Executing full implementation paths
- **NO APPROXIMATIONS**: Reporting actual measured performance

See [CLAUDE.md](./CLAUDE.md) for detailed integrity guidelines.

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines on:
- Code style and standards
- Testing requirements
- Pull request process
- Issue reporting

## CI/CD

The project uses GitHub Actions for continuous integration:
- Automated testing on pull requests
- Code quality checks
- Benchmark regression detection
- Docker image building

## Results Analysis

Benchmark results are exported in JSON format compatible with hyperfine. To analyze results:

```python
python show_results.py
```

This will display:
- Mean execution time
- Standard deviation
- Min/max times
- Comparative analysis between implementations

## Troubleshooting

### Hyperfine not found
Install hyperfine using your package manager:
- macOS: `brew install hyperfine`
- Ubuntu: `apt install hyperfine`
- Cargo: `cargo install hyperfine`

### Contract compilation fails
Ensure Foundry is installed:
```bash
make setup-foundry
```

### EVM binary not found
Build the EVM implementations:
```bash
cd evms/go-ethereum && make all
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [Hyperfine](https://github.com/sharkdp/hyperfine) for statistical benchmarking
- [Foundry](https://github.com/foundry-rs/foundry) for Solidity tooling
- The Ethereum community for EVM implementations

## Contact

For questions, issues, or contributions, please open an issue on GitHub.