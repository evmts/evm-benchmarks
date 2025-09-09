#!/bin/bash

# Benchmark with internal iterations to reduce startup overhead noise
# Runs each benchmark 100 times internally, 5 times externally

INTERNAL_RUNS=100
EXTERNAL_RUNS=5

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}EVM Benchmark with Internal Iterations${NC}"
echo -e "${BLUE}Internal runs: $INTERNAL_RUNS, External runs: $EXTERNAL_RUNS${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Function to run benchmark and extract timing
run_benchmark() {
    local evm_name=$1
    local evm_cmd=$2
    local bytecode_file=$3
    local gas_limit=$4
    local calldata=$5
    local benchmark_name=$6
    
    echo -e "${GREEN}Testing $benchmark_name on $evm_name...${NC}"
    
    # Create a wrapper script for internal iterations
    if [ "$evm_name" = "revm" ]; then
        # Revm with --bench flag (if it supports multiple runs)
        cmd="$evm_cmd evm --path $bytecode_file --gas-limit $gas_limit --input $calldata --bench"
    elif [ "$evm_name" = "geth" ]; then
        # Geth doesn't have internal iteration, so we'll loop in bash
        cmd="for i in {1..$INTERNAL_RUNS}; do $evm_cmd run --codefile $bytecode_file --gas $gas_limit --input $calldata 2>/dev/null; done"
    elif [ "$evm_name" = "guillotine" ]; then
        # Guillotine - check if it supports multiple runs
        cmd="for i in {1..$INTERNAL_RUNS}; do $evm_cmd run --codefile $bytecode_file --gas $gas_limit --input $calldata 2>/dev/null; done"
    fi
    
    # Run with hyperfine for external iterations
    hyperfine \
        --runs $EXTERNAL_RUNS \
        --warmup 1 \
        --export-json "results_${benchmark_name}_${evm_name}_internal.json" \
        --command-name "$evm_name-$benchmark_name" \
        "bash -c \"$cmd\""
    
    # Parse and normalize results
    if [ -f "results_${benchmark_name}_${evm_name}_internal.json" ]; then
        mean=$(jq '.results[0].mean' "results_${benchmark_name}_${evm_name}_internal.json")
        normalized=$(echo "scale=6; $mean / $INTERNAL_RUNS" | bc)
        echo -e "${YELLOW}  Raw mean (${INTERNAL_RUNS} iterations): ${mean}s${NC}"
        echo -e "${YELLOW}  Normalized per iteration: ${normalized}s (${normalized}000 ms)${NC}\n"
    fi
}

# Prepare test bytecode files
echo "Preparing bytecode files..."

# TenThousandHashes
cat out/TenThousandHashes.sol/TenThousandHashes.json | jq -r '.deployedBytecode.object' | sed 's/0x//' > /tmp/ten_k.hex

# ERC20Transfer
cat out/ERC20Transfer.sol/ERC20Transfer.json | jq -r '.deployedBytecode.object' | sed 's/0x//' > /tmp/erc20_transfer.hex

# Snailtracer
cp benchmarks/snailtracer/snailtracer_runtime.hex /tmp/snailtracer.hex

# Run benchmarks for each EVM
echo -e "\n${BLUE}=== Running Benchmarks ===${NC}\n"

# Geth
if [ -f "evms/go-ethereum/build/bin/evm" ]; then
    echo -e "${BLUE}--- GETH ---${NC}"
    run_benchmark "geth" "evms/go-ethereum/build/bin/evm" "/tmp/ten_k.hex" "30000000" "30627b7c" "ten_thousand_hashes"
    run_benchmark "geth" "evms/go-ethereum/build/bin/evm" "/tmp/erc20_transfer.hex" "30000000" "30627b7c" "erc20_transfer"
    run_benchmark "geth" "evms/go-ethereum/build/bin/evm" "/tmp/snailtracer.hex" "1000000000" "30627b7c" "snailtracer"
fi

# Revm
if [ -f "evms/revm/target/release/revme" ]; then
    echo -e "${BLUE}--- REVM ---${NC}"
    run_benchmark "revm" "evms/revm/target/release/revme" "/tmp/ten_k.hex" "30000000" "30627b7c" "ten_thousand_hashes"
    run_benchmark "revm" "evms/revm/target/release/revme" "/tmp/erc20_transfer.hex" "30000000" "30627b7c" "erc20_transfer"
    run_benchmark "revm" "evms/revm/target/release/revme" "/tmp/snailtracer.hex" "1000000000" "30627b7c" "snailtracer"
fi

# Guillotine
if [ -f "evms/guillotine-go-sdk/apps/cli/guillotine-bench" ]; then
    echo -e "${BLUE}--- GUILLOTINE ---${NC}"
    run_benchmark "guillotine" "evms/guillotine-go-sdk/apps/cli/guillotine-bench" "/tmp/ten_k.hex" "30000000" "30627b7c" "ten_thousand_hashes"
    run_benchmark "guillotine" "evms/guillotine-go-sdk/apps/cli/guillotine-bench" "/tmp/erc20_transfer.hex" "30000000" "30627b7c" "erc20_transfer"
    run_benchmark "guillotine" "evms/guillotine-go-sdk/apps/cli/guillotine-bench" "/tmp/snailtracer.hex" "1000000000" "30627b7c" "snailtracer"
fi

echo -e "${GREEN}Benchmark complete!${NC}"