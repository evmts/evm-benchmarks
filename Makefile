# Rust/Cargo targets
.PHONY: help build test run clean dev release benchmark docker-build docker-run

help: ## Show this help message
	@echo "Usage: make [target]"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

# Main targets
build: ## Build debug version
	cargo build

release: ## Build release version
	cargo build --release

test: ## Run tests
	cargo test

run: ## Run benchmarks (release mode)
	cargo run --release -- run

dev: ## Run in development mode
	cargo run -- run

benchmark: ## Run benchmarks with verbose output
	@echo "Running EVM benchmarks..."
	cargo run --release -- run --verbose

clean: ## Clean build artifacts
	cargo clean
	rm -rf build dist *.egg-info
	rm -rf cache out
	rm -f results_*.json matrix_results.json

lint: ## Run clippy linter
	cargo clippy -- -D warnings

format: ## Format code
	cargo fmt
	forge fmt

# Docker targets
docker-build: ## Build Docker image
	docker build -t evm-bench:latest .

docker-run: ## Run Docker container
	docker run --rm -it evm-bench:latest

# Setup targets
setup-foundry: ## Install Foundry
	curl -L https://foundry.paradigm.xyz | bash
	foundryup

# Default target
all: release ## Build release version by default