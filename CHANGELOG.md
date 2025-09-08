# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial project structure and setup
- CLI application for running EVM benchmarks
- Support for multiple EVM implementations
- Integration with hyperfine for accurate measurements
- Benchmark suite including:
  - ERC20 token operations (transfer, mint, approval)
  - Ten thousand hashes computation test
  - SnailTracer ray tracing benchmark
- Docker containerization support
- GitHub Actions CI/CD pipeline
- Comprehensive test suite
- Makefile for common tasks
- Foundry integration for Solidity development

### Changed
- Updated SnailTracer contract for Solidity 0.8.0 compatibility
- Optimized CLI to focus on EVM-specific benchmarks

### Fixed
- Solidity 0.8.0 compatibility issues in benchmark contracts

## [0.1.0] - 2024-01-01

### Added
- Initial release
- Basic benchmark runner functionality
- Command-line interface
- Python package structure
- Development dependencies

[Unreleased]: https://github.com/yourusername/evm-bench/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/yourusername/evm-bench/releases/tag/v0.1.0