#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "ℹ $1"
}

print_header() {
    echo -e "${BLUE}======================================"
    echo "   $1"
    echo "======================================"
    echo -e "${NC}"
}

# Function to check prerequisites
check_prerequisites() {
    local all_found=true
    
    # Check OS
    OS=""
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    else
        print_error "Unsupported OS: $OSTYPE"
        exit 1
    fi
    
    # Check Zig
    if ! command -v zig &> /dev/null; then
        print_error "Zig not found. Please install from: https://ziglang.org/download/"
        if [[ "$OS" == "macos" ]]; then
            echo "    brew install zig"
        fi
        all_found=false
    fi
    
    # Check Rust
    if ! command -v rustc &> /dev/null; then
        print_error "Rust not found. Please install:"
        echo "    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
        all_found=false
    fi
    
    # Check Hyperfine
    if ! command -v hyperfine &> /dev/null; then
        print_error "Hyperfine not found. Please install:"
        if [[ "$OS" == "macos" ]]; then
            echo "    brew install hyperfine"
        else
            echo "    cargo install hyperfine"
        fi
        all_found=false
    fi
    
    if [ "$all_found" = false ]; then
        echo
        print_error "Missing prerequisites. Please install them and try again."
        exit 1
    fi
}

# Function to setup the project
setup_project() {
    print_header "Setting Up EVM Benchmark Suite"
    
    echo "Checking prerequisites..."
    check_prerequisites
    print_success "All prerequisites found"
    
    # Check for git submodules
    echo
    echo "Checking git submodules..."
    if [ ! -f "guillotine/.git" ] && [ ! -d "guillotine/src" ]; then
        print_info "Initializing submodules..."
        git submodule update --init --recursive
        print_success "Submodules initialized"
    else
        print_success "Git submodules found"
    fi
    
    # Build the project
    echo
    echo "Building the project..."
    print_info "This may take a few minutes on first build..."
    
    if zig build 2>&1 | tee build.log; then
        print_success "Build completed successfully!"
        rm -f build.log
    else
        print_error "Build failed. Check build.log for details"
        exit 1
    fi
    
    # Verify the build
    echo
    echo "Verifying installation..."
    local all_good=true
    
    if [ -f "./zig-out/bin/bench" ]; then
        print_success "Benchmark binary found"
    else
        print_error "Benchmark binary not found"
        all_good=false
    fi
    
    if [ -f "./target/release/evm-runner" ]; then
        print_success "Rust EVM runner found"
    else
        print_error "Rust EVM runner not found"
        all_good=false
    fi
    
    if [ -f "./zig-out/bin/guillotine-runner" ]; then
        print_success "Guillotine runner found"
    else
        print_error "Guillotine runner not found"
        all_good=false
    fi
    
    if [ "$all_good" = false ]; then
        print_error "Build verification failed"
        exit 1
    fi
    
    echo
    print_success "Setup complete!"
}

# Function to run a single benchmark
run_single_benchmark() {
    local bench_name=$1
    ./zig-out/bin/bench -f "$bench_name"
}

# Function to run all benchmarks and generate report
run_all_benchmarks() {
    print_header "Running All EVM Benchmarks"
    
    # Create temporary file for collecting results
    local TEMP_FILE=$(mktemp)
    local RESULTS_FILE="results.md"
    
    # List of benchmarks to run
    local BENCHMARKS=(
        "factorial"
        "factorial-recursive"
        "fibonacci"
        "fibonacci-recursive"
        "manyhashes"
        "push"
        "mstore"
        "sstore"
        "bubblesort"
        "snailtracer"
        "ten-thousand-hashes"
    )
    
    # Skip ERC20 benchmarks if they don't have the required lib/ERC20.sol
    if [ -f "fixtures/lib/ERC20.sol" ]; then
        BENCHMARKS+=("erc20transfer" "erc20mint" "erc20approval")
    fi
    
    # Start writing the results file
    cat > "$RESULTS_FILE" << 'EOF'
# Benchmark Results

> Auto-generated benchmark results comparing REVM, ethrex, and Guillotine EVM implementations.

## Summary Table

| Benchmark | REVM (ms) | ethrex (ms) | Guillotine (ms) | Fastest | Notes |
|-----------|-----------|-------------|-----------------|---------|-------|
EOF
    
    echo "Running benchmarks..."
    echo
    
    # Run each benchmark and collect results
    for bench_name in "${BENCHMARKS[@]}"; do
        local output_file=$(mktemp)
        
        echo -e "${YELLOW}Running $bench_name...${NC}"
        
        if ./zig-out/bin/bench -f "$bench_name" 2>&1 > "$output_file"; then
            # Extract execution times - the Time lines appear after all output
            # There are 3 Time lines, one for each benchmark
            local all_times=$(grep "Time (mean" "$output_file" | sed -E 's/.*Time \(mean[^:]*:[[:space:]]*([0-9.]+) ms.*/\1/')
            local revm_time=$(echo "$all_times" | sed -n '1p')
            local ethrex_time=$(echo "$all_times" | sed -n '2p')
            local guillotine_time=$(echo "$all_times" | sed -n '3p')
            
            # Extract gas usage
            local revm_gas=$(grep -B 1 "Time (mean" "$output_file" | grep "Gas used:" | head -1 | sed -E 's/.*Gas used: ([0-9]+).*/\1/')
            local ethrex_gas=$(grep -B 1 "Time (mean" "$output_file" | grep "Gas used:" | sed -n '2p' | sed -E 's/.*Gas used: ([0-9]+).*/\1/')
            local guillotine_gas=$(grep -B 1 "Time (mean" "$output_file" | grep "Gas used:" | tail -1 | sed -E 's/.*Gas used: ([0-9]+).*/\1/')
            
            # Check success
            local success_count=$(grep -c "Success: true" "$output_file" 2>/dev/null || echo "0")
            
            # Determine fastest
            local fastest="N/A"
            local notes=""
            
            if [ -n "$revm_time" ] && [ -n "$ethrex_time" ] && [ -n "$guillotine_time" ]; then
                # Determine fastest (using awk for float comparison)
                fastest=$(echo "$revm_time $ethrex_time $guillotine_time" | awk '{
                    min = $1; name = "REVM"
                    if ($2 < min) { min = $2; name = "ethrex" }
                    if ($3 < min) { min = $3; name = "Guillotine" }
                    print name
                }')
                
                if [ "$success_count" -lt 15 ]; then
                    notes="⚠️ Some failures"
                else
                    notes="✅ All passed"
                fi
            else
                notes="❌ Failed to run"
            fi
            
            # Default to "N/A" if extraction failed
            revm_time=${revm_time:-"N/A"}
            ethrex_time=${ethrex_time:-"N/A"}
            guillotine_time=${guillotine_time:-"N/A"}
            
            # Write to results file
            echo "| $bench_name | $revm_time | $ethrex_time | $guillotine_time | $fastest | $notes |" >> "$RESULTS_FILE"
            
            # Save gas info
            echo "$bench_name,$revm_gas,$ethrex_gas,$guillotine_gas" >> "$TEMP_FILE"
            
            echo -e "${GREEN}✓${NC} $bench_name complete"
        else
            echo "| $bench_name | Error | Error | Error | - | ❌ Failed |" >> "$RESULTS_FILE"
            echo -e "${RED}✗${NC} $bench_name failed"
        fi
        
        rm -f "$output_file"
        echo
    done
    
    # Add gas usage table
    cat >> "$RESULTS_FILE" << 'EOF'

## Gas Usage Comparison

| Benchmark | REVM Gas | ethrex Gas | Guillotine Gas | Most Efficient |
|-----------|----------|------------|----------------|----------------|
EOF
    
    # Process gas data
    while IFS=',' read -r name revm_gas ethrex_gas guillotine_gas; do
        if [ -n "$revm_gas" ] && [ -n "$ethrex_gas" ] && [ -n "$guillotine_gas" ]; then
            # Determine most efficient
            most_efficient=$(echo "$revm_gas $ethrex_gas $guillotine_gas" | awk '{
                min = $1; name = "REVM"
                if ($2 < min) { min = $2; name = "ethrex" }
                if ($3 < min) { min = $3; name = "Guillotine" }
                print name
            }')
            
            echo "| $name | $revm_gas | $ethrex_gas | $guillotine_gas | $most_efficient |" >> "$RESULTS_FILE"
        fi
    done < "$TEMP_FILE"
    
    # Add metadata
    cat >> "$RESULTS_FILE" << EOF

## Benchmark Details

- **Date**: $(date '+%Y-%m-%d %H:%M:%S')
- **Platform**: $(uname -s) $(uname -m)
- **CPU**: $(sysctl -n machdep.cpu.brand_string 2>/dev/null || lscpu | grep "Model name" | cut -d':' -f2 | xargs || echo "Unknown")

### Configuration
- Warmup runs: 2
- Benchmark runs: 5
- Gas limit: 30,000,000

### Notes
- Times are in milliseconds (ms)
- Lower values are better for both execution time and gas usage
- ✅ indicates all EVMs executed successfully
- ⚠️ indicates some EVMs failed
- ❌ indicates benchmark failed to run

## How to Run

\`\`\`bash
# Setup and run all benchmarks
./run.sh

# Run specific benchmark
./run.sh factorial

# Run all benchmarks (if already set up)
./run.sh all

# Just build without running benchmarks
./run.sh setup
\`\`\`
EOF
    
    rm -f "$TEMP_FILE"
    
    echo
    print_header "Benchmarks Complete!"
    echo "Results saved to: $RESULTS_FILE"
    echo
    echo "View results with: cat $RESULTS_FILE"
}

# Function to show help
show_help() {
    cat << EOF
EVM Benchmark Suite Runner

Usage: ./run.sh [command] [options]

Commands:
    (no command)      Setup project and run all benchmarks
    setup            Only setup/build the project
    all              Run all benchmarks (assumes already built)
    <benchmark>      Run specific benchmark (e.g., factorial)
    help             Show this help message

Available benchmarks:
    factorial, factorial-recursive
    fibonacci, fibonacci-recursive  
    manyhashes, push, mstore, sstore
    erc20transfer, erc20mint, erc20approval
    bubblesort, snailtracer, ten-thousand-hashes

Examples:
    ./run.sh                  # Setup and run everything
    ./run.sh setup           # Just setup/build
    ./run.sh all             # Run all benchmarks
    ./run.sh factorial       # Run factorial benchmark
    ./run.sh help            # Show help

EOF
}

# Main script logic
main() {
    # Parse command line arguments
    case "${1:-}" in
        help|--help|-h)
            show_help
            exit 0
            ;;
        setup)
            setup_project
            echo
            echo "Setup complete! You can now run benchmarks with:"
            echo "  ./run.sh all           # Run all benchmarks"
            echo "  ./run.sh factorial     # Run specific benchmark"
            ;;
        all)
            # Check if project is built
            if [ ! -f "./zig-out/bin/bench" ]; then
                print_warning "Project not built. Running setup first..."
                setup_project
                echo
            fi
            run_all_benchmarks
            ;;
        "")
            # No argument: setup and run all
            setup_project
            echo
            print_info "Running test benchmark to verify setup..."
            if ./zig-out/bin/bench -f factorial 2>&1 | grep -q "Success: true"; then
                print_success "Test benchmark successful!"
                echo
                read -p "Run all benchmarks now? (y/n) " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    run_all_benchmarks
                else
                    echo "You can run benchmarks later with:"
                    echo "  ./run.sh all           # Run all benchmarks"
                    echo "  ./run.sh factorial     # Run specific benchmark"
                fi
            else
                print_error "Test benchmark failed. Please check your setup."
                exit 1
            fi
            ;;
        *)
            # Assume it's a benchmark name
            if [ ! -f "./zig-out/bin/bench" ]; then
                print_warning "Project not built. Running setup first..."
                setup_project
                echo
            fi
            print_header "Running $1 Benchmark"
            run_single_benchmark "$1"
            ;;
    esac
}

# Run main function
main "$@"