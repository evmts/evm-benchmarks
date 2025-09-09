# EVM Benchmark Repository

## Project Overview
This repository contains benchmarking tools for comparing Ethereum Virtual Machine (EVM) implementations. The primary goal is to provide accurate, reproducible performance measurements across different EVM implementations including **geth** and **Guillotine**.

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
├── src/
│   ├── cli.py                 # Enhanced CLI with matrix benchmarking support
│   ├── evm_benchmarks.py      # Core EVM benchmark logic for geth & Guillotine
│   └── cli_display.py         # Rich terminal display utilities
├── benchmarks/
│   ├── solidity/              # Solidity benchmark contracts
│   │   ├── TenThousandHashes.sol
│   │   ├── ERC20Transfer.sol
│   │   ├── ERC20Mint.sol
│   │   └── ERC20ApprovalTransfer.sol
│   └── snailtracer/           # Ray tracing benchmark
│       ├── snailtracer.sol    # Solidity 0.4.26 implementation
│       └── snailtracer_runtime.hex  # Compiled bytecode
├── evms/
│   ├── go-ethereum/           # Geth EVM implementation (git submodule)
│   └── guillotine-go-sdk/     # Guillotine EVM implementation (git submodule)
├── out/                       # Foundry build artifacts
└── results_*.json             # Benchmark results for each test
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
# Run all benchmarks on default EVM (geth)
python src/cli.py run

# Run specific benchmark
python src/cli.py run ten_thousand_hashes

# Run on specific EVM
python src/cli.py run --evm guillotine

# Run matrix benchmark across multiple EVMs
python src/cli.py run --evms geth,guillotine
python src/cli.py run --all  # Run on all available EVMs
```

### Advanced Options
```bash
# Customize iterations and warmup
python src/cli.py run --iterations 20 --warmup 5

# Export results
python src/cli.py run --output results.json --export-json hyperfine.json

# Verbose output
python src/cli.py run -v
```

### Matrix Benchmarking
The CLI supports running benchmarks across multiple EVM implementations simultaneously:
```bash
# Compare geth and guillotine
python src/cli.py run --evms geth,guillotine

# Run all benchmarks on all EVMs
python src/cli.py run --all

# Save matrix results
python src/cli.py run --all --output full_matrix.json
```

Matrix results include:
- Side-by-side performance comparison
- Relative speed differences
- Gas consumption metrics
- Success/failure status per benchmark

## Key Features

### 1. Hyperfine Integration
All benchmarks use [hyperfine](https://github.com/sharkdp/hyperfine) for accurate measurements:
- Statistical analysis of multiple runs
- Warmup iterations to stabilize performance
- JSON export for detailed analysis
- Automatic outlier detection

### 2. Rich CLI Display
Beautiful terminal output with:
- Progress bars for benchmark execution
- Colored output for better readability
- Spinner animations during long operations
- Matrix summary tables for comparisons
- Real-time status updates

### 3. Dynamic Benchmark Discovery
- Automatically detects compiled Solidity contracts
- Loads bytecode from Foundry artifacts (`out/` directory)
- Validates EVM binary availability
- Skips unavailable benchmarks gracefully

### 4. Unified Benchmark Interface
Both geth and Guillotine use the same benchmark execution flow:
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
3. Add configuration in `evm_benchmarks.py`:
```python
benchmarks["new_benchmark"] = {
    "description": "Description of benchmark",
    "category": "compute|token|storage",
    "type": "evm",
    "bytecode": get_contract_bytecode("ContractName"),
    "calldata": get_function_selector("functionName()"),
    "gas": 30000000,
    "requires": []
}
```

### Adding New EVM Implementation
1. Add binary finder function:
```python
def find_new_evm_binary() -> Optional[str]:
    # Logic to locate the EVM binary
    pass
```

2. Add runner function:
```python
def run_new_evm_benchmark(name, config, iterations, use_hyperfine, verbose):
    # Implementation-specific execution logic
    pass
```

3. Update `run_evm_benchmark()` to route to new implementation

### Testing
```bash
# Run unit tests
pytest tests/

# Type checking
mypy src/

# Linting
ruff check src/

# Run a quick benchmark test
python src/cli.py run ten_thousand_hashes --iterations 3
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

## Recent Updates

### Matrix Benchmarking (v2.0)
- Compare multiple EVM implementations side-by-side
- Visual matrix summary with performance comparisons
- Support for `--evms` and `--all` flags

### Guillotine Integration (v1.5)
- Full support for Guillotine EVM benchmarking
- Custom runner for Zig-based implementation
- FFI bridge via Go SDK

### Enhanced CLI Display (v1.2)
- Rich terminal colors and formatting
- Progress bars and spinners
- Clear benchmark status indicators

### Snailtracer Benchmark (v1.0)
- Added compute-intensive ray tracing benchmark
- Tests extreme computation scenarios
- 1B gas limit for stress testing

Remember: The integrity of these benchmarks is paramount. When in doubt, choose accuracy over convenience.