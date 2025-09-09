# EVM Benchmark Suite

Compare Ethereum Virtual Machine implementations with real performance metrics.

## Quick Start

```bash
git clone --recursive https://github.com/williamcory/bench.git
cd bench
./quick-start.sh
```

## Manual Setup

```bash
# Dependencies
brew install hyperfine
curl -L https://foundry.paradigm.xyz | bash

# Build
go build -o bench cmd/bench/main.go
forge build

# Run
./bench run
```

## Usage

```bash
./bench run                    # Interactive TUI
./bench run --all --no-tui     # All EVMs
./bench run --evm geth         # Specific EVM
```

## Benchmarks

- `ten_thousand_hashes` - 10,000 keccak256 operations
- `snailtracer` - Ray tracing (1B gas)
- `erc20_transfer_bench` - Token transfers
- `erc20_mint_bench` - Token minting
- `erc20_approval_bench` - Approvals

## EVMs Supported

- **geth** - go-ethereum
- **guillotine** - Zig-based EVM
- **revm** - Rust-based EVM

## License

MIT