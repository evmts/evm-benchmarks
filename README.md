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
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Build
cargo build --release
forge build

# Run
./target/release/bench run
```

## Usage

```bash
./target/release/bench run                    # Run all benchmarks
./target/release/bench run --all              # All EVMs
./target/release/bench run --evm geth         # Specific EVM
./target/release/bench list                   # List available benchmarks
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