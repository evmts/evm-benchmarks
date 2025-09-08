# Contributing to EVM Benchmark Suite

Thank you for your interest in contributing to the EVM Benchmark Suite! This document provides guidelines and instructions for contributing to the project.

## Code of Conduct

Please note that this project is released with a [Contributor Code of Conduct](CODE_OF_CONDUCT.md). By participating in this project you agree to abide by its terms.

## How to Contribute

### Reporting Issues

- Check if the issue has already been reported
- Provide a clear and descriptive title
- Include steps to reproduce the issue
- Specify your environment (OS, Python version, etc.)
- Include relevant error messages and logs

### Suggesting Enhancements

- Use a clear and descriptive title
- Provide a detailed description of the enhancement
- Explain why this enhancement would be useful
- Include examples of how the feature would work

### Pull Requests

1. Fork the repository
2. Create a new branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run tests (`make test`)
5. Ensure code quality (`make lint`)
6. Commit with conventional commits (see below)
7. Push to your branch
8. Open a Pull Request

## Development Setup

```bash
# Clone the repository
git clone https://github.com/yourusername/evm-bench.git
cd evm-bench

# Install development dependencies
make dev

# Install Foundry
make setup-foundry

# Build the project
make build

# Run tests
make test
```

## Conventional Commits

We use conventional commits with emoji prefixes:

- 🎉 `feat:` New feature
- 🐛 `fix:` Bug fix
- 📚 `docs:` Documentation changes
- 🎨 `style:` Code style changes
- ♻️ `refactor:` Code refactoring
- 🧪 `test:` Test additions or changes
- 🔨 `build:` Build system changes
- 👷 `ci:` CI/CD changes
- 🔧 `chore:` Other changes

Example:
```
🎉 feat: add support for new EVM implementation
```

## Testing

### Running Tests

```bash
# Run all tests
make test

# Run Python tests only
pytest tests/

# Run Solidity tests only
forge test

# Run with coverage
pytest tests/ --cov=src --cov-report=html
```

### Writing Tests

- Write tests for all new functionality
- Ensure tests are deterministic
- Use descriptive test names
- Include both positive and negative test cases

## Code Style

### Python

- Follow PEP 8
- Use type hints
- Maximum line length: 100 characters
- Use Black for formatting

### Solidity

- Follow Solidity style guide
- Use Forge formatting
- Include NatSpec comments

## Adding Benchmarks

To add a new benchmark:

1. Create the benchmark contract in `benchmarks/`
2. Add configuration in `benchmark.evm-bench.json`
3. Update `src/evm_benchmarks.py` if needed
4. Add tests for the benchmark
5. Document the benchmark in README

## Documentation

- Update README.md for user-facing changes
- Add docstrings to all functions and classes
- Include examples in documentation
- Keep CHANGELOG.md updated

## Review Process

1. All submissions require review
2. Changes must pass CI checks
3. Maintain test coverage above 80%
4. Follow project coding standards

## Questions?

Feel free to open an issue for any questions about contributing!