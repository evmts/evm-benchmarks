# EVM Benchmark Repository

## Project Overview
This repository contains benchmarking tools for comparing Ethereum Virtual Machine (EVM) implementations. The primary goal is to provide accurate, reproducible performance measurements across different EVM implementations including geth, reth, and evms.

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
- `src/cli.py`: Command-line interface for running benchmarks
- `src/evm_benchmarks.py`: Core benchmarking logic and test suite
- `tests/`: Unit tests for the benchmarking framework
- `evms/`: Git submodule containing the evms implementation

## Running Benchmarks
The benchmarks measure real execution performance by:
1. Loading actual blockchain test vectors
2. Running full EVM execution without shortcuts
3. Measuring wall-clock time and resource usage
4. Comparing results across different implementations

## Development Guidelines
When modifying or extending benchmarks:
1. Always test against real EVM implementations
2. Verify results match expected blockchain behavior
3. Never optimize benchmarks at the expense of accuracy
4. Document any assumptions clearly
5. Ensure reproducibility across different environments

## Testing Commands
- Run tests: `pytest tests/`
- Run benchmarks: `python src/cli.py benchmark`
- Type checking: `mypy src/`
- Linting: `ruff check src/`

Remember: The integrity of these benchmarks is paramount. When in doubt, choose accuracy over convenience.