#!/usr/bin/env python3
"""
EVM-specific benchmark configurations and utilities.
"""
import json
import os
import subprocess
from pathlib import Path
from typing import Dict, List, Optional, Any


def get_contract_bytecode(contract_name: str) -> Optional[str]:
    """Get compiled bytecode for a contract from Foundry artifacts."""
    out_dir = Path("out")
    
    # Search for the contract JSON file
    for json_file in out_dir.rglob(f"{contract_name}.json"):
        try:
            with open(json_file, 'r') as f:
                data = json.load(f)
                # Get deployed bytecode
                bytecode = data.get("deployedBytecode", {}).get("object", "")
                if bytecode and bytecode.startswith("0x"):
                    return bytecode[2:]  # Remove 0x prefix
                return bytecode
        except (json.JSONDecodeError, KeyError):
            continue
    
    return None


def get_evm_benchmarks() -> Dict[str, Dict[str, Any]]:
    """Get EVM-specific benchmark configurations."""
    benchmarks = {}
    
    # TenThousandHashes benchmark
    ten_k_bytecode = get_contract_bytecode("TenThousandHashes")
    if ten_k_bytecode:
        benchmarks["ten_thousand_hashes"] = {
            "description": "Execute 10,000 keccak256 hashes",
            "category": "compute",
            "type": "evm",
            "bytecode": ten_k_bytecode,
            "calldata": "e27e2e5c",  # Function selector for run()
            "gas": 30000000,
            "requires": ["benchmark-runner"]
        }
    
    # ERC20 Transfer benchmark
    erc20_transfer_bytecode = get_contract_bytecode("ERC20Transfer")
    if erc20_transfer_bytecode:
        benchmarks["erc20_transfer_bench"] = {
            "description": "Benchmark ERC20 transfer operations",
            "category": "token",
            "type": "evm",
            "bytecode": erc20_transfer_bytecode,
            "calldata": "e27e2e5c",  # Function selector for run()
            "gas": 30000000,
            "requires": ["benchmark-runner"]
        }
    
    # ERC20 Mint benchmark
    erc20_mint_bytecode = get_contract_bytecode("ERC20Mint")
    if erc20_mint_bytecode:
        benchmarks["erc20_mint_bench"] = {
            "description": "Benchmark ERC20 minting operations",
            "category": "token",
            "type": "evm",
            "bytecode": erc20_mint_bytecode,
            "calldata": "e27e2e5c",  # Function selector for run()
            "gas": 30000000,
            "requires": ["benchmark-runner"]
        }
    
    # ERC20 Approval + Transfer benchmark
    erc20_approval_bytecode = get_contract_bytecode("ERC20ApprovalTransfer")
    if erc20_approval_bytecode:
        benchmarks["erc20_approval_bench"] = {
            "description": "Benchmark ERC20 approval and transfer operations",
            "category": "token",
            "type": "evm",
            "bytecode": erc20_approval_bytecode,
            "calldata": "e27e2e5c",  # Function selector for run()
            "gas": 30000000,
            "requires": ["benchmark-runner"]
        }
    
    return benchmarks


def run_evm_benchmark(
    name: str,
    config: Dict[str, Any],
    iterations: int = 10,
    use_hyperfine: bool = True
) -> Dict[str, Any]:
    """Run an EVM benchmark using the Go benchmark runner."""
    
    # Path to benchmark runner
    runner_path = Path("evms/benchmark-runner/benchmark-runner")
    
    if not runner_path.exists():
        print(f"Building benchmark runner...")
        build_result = subprocess.run(
            ["make", "build"],
            cwd="evms/benchmark-runner",
            capture_output=True,
            text=True
        )
        if build_result.returncode != 0:
            raise RuntimeError(f"Failed to build benchmark runner: {build_result.stderr}")
    
    if use_hyperfine:
        # Use hyperfine for more accurate measurements
        cmd = [
            "hyperfine",
            "--runs", str(iterations),
            "--warmup", "3",
            "--export-json", f"results_{name}.json",
            "--",
            str(runner_path),
            "--bytecode", config["bytecode"],
            "--calldata", config.get("calldata", ""),
            "--gas", str(config.get("gas", 30000000)),
            "--iterations", "1"  # Single iteration per hyperfine run
        ]
        
        print(f"Running EVM benchmark '{name}' with hyperfine...")
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode == 0:
            # Parse hyperfine results
            with open(f"results_{name}.json", 'r') as f:
                hyperfine_results = json.load(f)
                return {
                    "name": name,
                    "tool": "hyperfine",
                    "results": hyperfine_results
                }
    else:
        # Use built-in benchmark runner iterations
        cmd = [
            str(runner_path),
            "--bytecode", config["bytecode"],
            "--calldata", config.get("calldata", ""),
            "--gas", str(config.get("gas", 30000000)),
            "--iterations", str(iterations)
        ]
        
        print(f"Running EVM benchmark '{name}' directly...")
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode == 0:
            return {
                "name": name,
                "tool": "benchmark-runner",
                "output": result.stdout
            }
    
    raise RuntimeError(f"Benchmark failed: {result.stderr}")


def create_benchmark_config(benchmarks: Dict[str, Dict[str, Any]], output_file: str):
    """Create a JSON config file for batch benchmark execution."""
    configs = []
    
    for name, config in benchmarks.items():
        if config.get("type") == "evm":
            configs.append({
                "name": name,
                "bytecode": config["bytecode"],
                "calldata": config.get("calldata", ""),
                "gas": config.get("gas", 30000000),
                "iterations": 10
            })
    
    with open(output_file, 'w') as f:
        json.dump(configs, f, indent=2)
    
    print(f"Created benchmark config: {output_file}")