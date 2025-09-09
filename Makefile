# Python targets
.PHONY: help install dev test-python lint-python format-python clean-python build-python run-python benchmark-python docker-build docker-run

help: ## Show this help message
	@echo "Usage: make [target]"
	@echo ""
	@echo "Available targets:"
	@echo ""
	@echo "Go CLI targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '^(build-go|run-go|test-go|bench-)' | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'
	@echo ""
	@echo "Python CLI targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '(python|install|dev|docker)' | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'
	@echo ""
	@echo "General targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -v -E '(python|go|bench-|docker)' | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

# Go CLI targets
build-go: ## Build Go CLI
	@echo "Building Go CLI..."
	go build -o bench cmd/bench/main.go
	@echo "✓ Build complete: ./bench"

run-go: build-go ## Run Go CLI
	./bench run --no-tui

test-go: ## Run Go tests
	go test -v ./...

bench-geth: build-go ## Run benchmarks on geth
	./bench run --evm geth --no-tui

bench-guillotine: build-go ## Run benchmarks on guillotine
	./bench run --evm guillotine --no-tui

bench-revm: build-go ## Run benchmarks on revm
	./bench run --evm revm --no-tui

bench-matrix: build-go ## Run matrix benchmark on all EVMs
	./bench run --all --no-tui --output matrix_results.json

# Python CLI targets
install-python: ## Install Python production dependencies
	pip install -e .

dev-python: ## Install Python development dependencies
	pip install -e .[dev]
	forge install

test-python: ## Run Python tests
	pytest tests/ -v --cov=src --cov-report=term-missing
	forge test

lint-python: ## Run Python linting checks
	flake8 src tests
	mypy src
	black --check src tests

format-python: ## Format Python code
	black src tests
	forge fmt

clean-python: ## Clean Python build artifacts
	rm -rf build dist *.egg-info
	rm -rf cache out
	rm -rf .pytest_cache .coverage
	find . -type d -name __pycache__ -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete

build-python: ## Build Python project
	python -m build
	forge build

run-python: ## Run Python CLI
	python src/cli.py --help

benchmark-python: ## Run Python benchmarks
	@echo "Running EVM benchmarks..."
	python src/cli.py run --verbose

# Docker targets
docker-build: ## Build Docker image
	docker build -t evm-bench:latest .

docker-run: ## Run Docker container
	docker run --rm -it evm-bench:latest

# Setup targets
setup-foundry: ## Install Foundry
	curl -L https://foundry.paradigm.xyz | bash
	foundryup

setup-go: ## Setup Go environment
	go mod download
	go mod tidy

# Clean all
clean: clean-python ## Clean all build artifacts
	rm -f bench bench-go
	rm -f results_*.json
	rm -f matrix_results.json

# Default target
all: build-go ## Build Go CLI by default