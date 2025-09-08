.PHONY: help install dev test lint format clean build run benchmark docker-build docker-run

help: ## Show this help message
	@echo "Usage: make [target]"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

install: ## Install production dependencies
	pip install -e .

dev: ## Install development dependencies
	pip install -e .[dev]
	forge install

test: ## Run all tests
	pytest tests/ -v --cov=src --cov-report=term-missing
	forge test

lint: ## Run linting checks
	flake8 src tests
	mypy src
	black --check src tests

format: ## Format code
	black src tests
	forge fmt

clean: ## Clean build artifacts
	rm -rf build dist *.egg-info
	rm -rf cache out
	rm -rf .pytest_cache .coverage
	find . -type d -name __pycache__ -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete

build: ## Build project
	python -m build
	forge build

run: ## Run the CLI
	evm-bench --help

benchmark: ## Run benchmarks
	@echo "Running EVM benchmarks..."
	evm-bench run --category evm --verbose

docker-build: ## Build Docker image
	docker build -t evm-bench:latest .

docker-run: ## Run Docker container
	docker run --rm -it evm-bench:latest

setup-foundry: ## Install Foundry
	curl -L https://foundry.paradigm.xyz | bash
	foundryup

setup-go: ## Setup Go environment
	cd evms/benchmark-runner && go mod download

build-runner: ## Build benchmark runner
	cd evms/benchmark-runner && make build

test-runner: ## Test benchmark runner
	cd evms/benchmark-runner && ./benchmark-runner-simple

all: clean install test build ## Run full build pipeline