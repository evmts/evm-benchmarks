#!/bin/bash

# EVM Benchmark Suite - Quick Start Script
# This script sets up everything needed to run the benchmarks

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_status() {
    echo -e "${BLUE}[*]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_header() {
    echo -e "\n${BLUE}===================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================================${NC}\n"
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check and install dependencies
check_dependencies() {
    print_header "Checking Dependencies"
    
    local missing_deps=()
    
    # Check Go
    if command_exists go; then
        GO_VERSION=$(go version | awk '{print $3}')
        print_success "Go installed: $GO_VERSION"
    else
        print_error "Go is not installed"
        missing_deps+=("go")
    fi
    
    # Check Hyperfine
    if command_exists hyperfine; then
        HYPERFINE_VERSION=$(hyperfine --version | head -1)
        print_success "Hyperfine installed: $HYPERFINE_VERSION"
    else
        print_warning "Hyperfine is not installed"
        missing_deps+=("hyperfine")
    fi
    
    # Check Foundry (forge)
    if command_exists forge; then
        FORGE_VERSION=$(forge --version | head -1)
        print_success "Foundry installed: $FORGE_VERSION"
    else
        print_warning "Foundry is not installed"
        missing_deps+=("foundry")
    fi
    
    # Check Make
    if command_exists make; then
        print_success "Make installed"
    else
        print_error "Make is not installed"
        missing_deps+=("make")
    fi
    
    # Check Zig (optional, for building Guillotine)
    if command_exists zig; then
        ZIG_VERSION=$(zig version)
        print_success "Zig installed: $ZIG_VERSION"
    else
        print_warning "Zig is not installed (needed for Guillotine EVM)"
    fi
    
    # Check Cargo (optional, for building Revm)
    if command_exists cargo; then
        CARGO_VERSION=$(cargo --version)
        print_success "Cargo installed: $CARGO_VERSION"
    else
        print_warning "Cargo is not installed (needed for Revm EVM)"
    fi
    
    # Offer to install missing dependencies
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo
        print_warning "Missing dependencies: ${missing_deps[*]}"
        echo
        echo "Installation instructions:"
        
        for dep in "${missing_deps[@]}"; do
            case $dep in
                go)
                    echo "  Go: https://golang.org/doc/install"
                    ;;
                hyperfine)
                    echo "  Hyperfine:"
                    echo "    macOS: brew install hyperfine"
                    echo "    Linux: apt install hyperfine"
                    echo "    Cargo: cargo install hyperfine"
                    ;;
                foundry)
                    echo "  Foundry: curl -L https://foundry.paradigm.xyz | bash"
                    ;;
                make)
                    echo "  Make:"
                    echo "    macOS: xcode-select --install"
                    echo "    Linux: apt install build-essential"
                    ;;
            esac
        done
        
        echo
        read -p "Continue anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Initialize and update git submodules
init_submodules() {
    print_header "Initializing Git Submodules"
    
    if [ -d ".git" ]; then
        print_status "Initializing submodules..."
        git submodule init
        
        print_status "Updating submodules..."
        git submodule update --recursive
        
        print_success "Submodules initialized and updated"
    else
        print_error "Not a git repository. Please clone with --recursive flag:"
        echo "  git clone --recursive https://github.com/williamcory/bench.git"
        exit 1
    fi
}

# Install Go dependencies
install_go_deps() {
    print_header "Installing Go Dependencies"
    
    print_status "Downloading Go modules..."
    go mod download
    
    print_status "Tidying Go modules..."
    go mod tidy
    
    print_success "Go dependencies installed"
}

# Build the CLI
build_cli() {
    print_header "Building Benchmark CLI"
    
    print_status "Building bench CLI..."
    if [ -f "Makefile" ]; then
        make build-go
    else
        go build -o bench cmd/bench/main.go
    fi
    
    if [ -f "./bench" ]; then
        print_success "CLI built successfully: ./bench"
    else
        print_error "Failed to build CLI"
        exit 1
    fi
}

# Build Solidity contracts
build_contracts() {
    print_header "Building Solidity Contracts"
    
    if command_exists forge; then
        print_status "Building contracts with Foundry..."
        forge build
        
        if [ -d "out" ]; then
            print_success "Contracts built successfully"
        else
            print_error "Failed to build contracts"
            exit 1
        fi
    else
        print_warning "Foundry not installed, skipping contract build"
        print_warning "Some benchmarks may not be available"
    fi
}

# Build EVM implementations
build_evms() {
    print_header "Building EVM Implementations"
    
    # Build Geth
    if [ -d "evms/go-ethereum" ]; then
        print_status "Building Geth EVM..."
        (
            cd evms/go-ethereum
            if make geth && make evm; then
                print_success "Geth EVM built successfully"
            else
                print_warning "Failed to build Geth EVM"
            fi
        ) || print_warning "Geth build failed, will use system evm if available"
    else
        print_warning "Geth submodule not found"
    fi
    
    # Build Guillotine
    if [ -d "evms/guillotine-go-sdk" ] && command_exists zig; then
        print_status "Building Guillotine EVM..."
        (
            cd evms/guillotine-go-sdk
            if zig build; then
                cd apps/cli
                if go build -o guillotine-bench .; then
                    print_success "Guillotine EVM built successfully"
                else
                    print_warning "Failed to build Guillotine CLI"
                fi
            else
                print_warning "Failed to build Guillotine core"
            fi
        ) || print_warning "Guillotine build failed"
    else
        if [ ! -d "evms/guillotine-go-sdk" ]; then
            print_warning "Guillotine submodule not found"
        else
            print_warning "Zig not installed, skipping Guillotine build"
        fi
    fi
    
    # Build Revm
    if [ -d "evms/revm" ] && command_exists cargo; then
        print_status "Building Revm EVM..."
        (
            cd evms/revm
            if cargo build --release -p revme; then
                print_success "Revm EVM built successfully"
            else
                print_warning "Failed to build Revm EVM"
            fi
        ) || print_warning "Revm build failed"
    else
        if [ ! -d "evms/revm" ]; then
            print_warning "Revm submodule not found"
        else
            print_warning "Cargo not installed, skipping Revm build"
        fi
    fi
}

# Run benchmarks
run_benchmarks() {
    print_header "Running Benchmarks"
    
    if [ ! -f "./bench" ]; then
        print_error "Benchmark CLI not found. Please build first."
        exit 1
    fi
    
    # Check which EVMs are available
    local available_evms=()
    
    # Check for Geth
    if [ -f "evms/go-ethereum/build/bin/evm" ] || command_exists evm; then
        available_evms+=("geth")
        print_success "Geth EVM available"
    fi
    
    # Check for Guillotine
    if [ -f "evms/guillotine-go-sdk/apps/cli/guillotine-bench" ]; then
        available_evms+=("guillotine")
        print_success "Guillotine EVM available"
    fi
    
    # Check for Revm
    if [ -f "evms/revm/target/release/revme" ]; then
        available_evms+=("revm")
        print_success "Revm EVM available"
    fi
    
    if [ ${#available_evms[@]} -eq 0 ]; then
        print_error "No EVM implementations available"
        exit 1
    fi
    
    echo
    print_status "Available EVMs: ${available_evms[*]}"
    echo
    
    # Run benchmarks based on available options
    if command_exists hyperfine; then
        # Run with all available EVMs
        if [ ${#available_evms[@]} -gt 1 ]; then
            print_status "Running matrix benchmark with all available EVMs..."
            ./bench run --all --no-tui --iterations 5 --warmup 2
        else
            print_status "Running benchmark with ${available_evms[0]}..."
            ./bench run --evm "${available_evms[0]}" --no-tui --iterations 5 --warmup 2
        fi
    else
        print_warning "Hyperfine not installed, running without statistical analysis..."
        if [ ${#available_evms[@]} -gt 1 ]; then
            ./bench run --all --no-tui --no-hyperfine
        else
            ./bench run --evm "${available_evms[0]}" --no-tui --no-hyperfine
        fi
    fi
}

# Main execution
main() {
    print_header "EVM Benchmark Suite - Quick Start"
    
    echo "This script will:"
    echo "  1. Check and install dependencies"
    echo "  2. Initialize git submodules"
    echo "  3. Install Go dependencies"
    echo "  4. Build the benchmark CLI"
    echo "  5. Build Solidity contracts"
    echo "  6. Build EVM implementations"
    echo "  7. Run all benchmarks with all available EVMs"
    echo
    
    read -p "Continue? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
    
    # Run all setup steps
    check_dependencies
    init_submodules
    install_go_deps
    build_cli
    build_contracts
    build_evms
    
    print_header "Setup Complete!"
    
    echo "You can now run benchmarks with:"
    echo "  ./bench run                    # Interactive TUI"
    echo "  ./bench run --no-tui           # Command line mode"
    echo "  ./bench run --all --no-tui     # All EVMs, no TUI"
    echo "  ./bench run --evm geth         # Specific EVM"
    echo
    
    read -p "Run benchmarks now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        run_benchmarks
    fi
    
    print_header "Quick Start Complete!"
    print_success "All done! Happy benchmarking!"
}

# Run main function
main "$@"