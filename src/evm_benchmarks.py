#!/usr/bin/env python3
"""
EVM-specific benchmark configurations and utilities.
"""
import json
import os
import subprocess
import tempfile
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


def get_function_selector(function_signature: str) -> str:
    """Get the 4-byte function selector for a function signature."""
    # For now, return the known selector for run()
    # In a real implementation, this would compute keccak256(signature)[:8]
    if function_signature == "run()":
        return "30627b7c"  # Actual selector for run()
    elif function_signature == "Benchmark()":
        return "30627b7c"  # Actual selector for Benchmark() in snailtracer
    return ""


def get_evm_benchmarks() -> Dict[str, Dict[str, Any]]:
    """Get EVM-specific benchmark configurations."""
    benchmarks = {}
    
    # Check if geth is available
    geth_path = Path("evms/go-ethereum/build/bin/geth")
    if not geth_path.exists():
        # Try system geth as fallback silently
        if not subprocess.run(["which", "geth"], capture_output=True).returncode == 0:
            return benchmarks
    
    # TenThousandHashes benchmark
    ten_k_bytecode = get_contract_bytecode("TenThousandHashes")
    if ten_k_bytecode:
        benchmarks["ten_thousand_hashes"] = {
            "description": "Execute 10,000 keccak256 hashes",
            "category": "compute",
            "type": "evm",
            "bytecode": ten_k_bytecode,
            "calldata": get_function_selector("run()"),
            "gas": 30000000,
            "requires": []  # We'll handle geth checking separately
        }
    
    # ERC20 Transfer benchmark
    erc20_transfer_bytecode = get_contract_bytecode("ERC20Transfer")
    if erc20_transfer_bytecode:
        benchmarks["erc20_transfer_bench"] = {
            "description": "Benchmark ERC20 transfer operations",
            "category": "token",
            "type": "evm",
            "bytecode": erc20_transfer_bytecode,
            "calldata": get_function_selector("run()"),
            "gas": 30000000,
            "requires": []
        }
    
    # ERC20 Mint benchmark
    erc20_mint_bytecode = get_contract_bytecode("ERC20Mint")
    if erc20_mint_bytecode:
        benchmarks["erc20_mint_bench"] = {
            "description": "Benchmark ERC20 minting operations",
            "category": "token",
            "type": "evm",
            "bytecode": erc20_mint_bytecode,
            "calldata": get_function_selector("run()"),
            "gas": 30000000,
            "requires": []
        }
    
    # ERC20 Approval + Transfer benchmark
    erc20_approval_bytecode = get_contract_bytecode("ERC20ApprovalTransfer")
    if erc20_approval_bytecode:
        benchmarks["erc20_approval_bench"] = {
            "description": "Benchmark ERC20 approval and transfer operations",
            "category": "token",
            "type": "evm",
            "bytecode": erc20_approval_bytecode,
            "calldata": get_function_selector("run()"),
            "gas": 30000000,
            "requires": []
        }
    
    # Snailtracer benchmark - read the pre-compiled runtime bytecode
    snailtracer_path = Path("benchmarks/snailtracer/snailtracer_runtime.hex")
    if snailtracer_path.exists():
        try:
            with open(snailtracer_path, "r") as f:
                snailtracer_bytecode = f.read().strip()
                if snailtracer_bytecode:
                    benchmarks["snailtracer"] = {
                        "description": "Ray tracing benchmark (compute intensive)",
                        "category": "compute",
                        "type": "evm",
                        "bytecode": snailtracer_bytecode,
                        "calldata": "30627b7c",  # Benchmark() selector
                        "gas": 1000000000,  # Very high gas limit for compute intensive task (1 billion)
                        "requires": []
                    }
        except Exception:
            pass  # Snailtracer bytecode not available
    
    return benchmarks


def find_geth_binary() -> Optional[str]:
    """Find the geth binary, preferring our built version."""
    # First try our built geth
    local_geth = Path("evms/go-ethereum/build/bin/geth")
    if local_geth.exists():
        return str(local_geth.absolute())
    
    # Fall back to system geth
    result = subprocess.run(["which", "geth"], capture_output=True, text=True)
    if result.returncode == 0:
        return result.stdout.strip()
    
    return None


def find_guillotine_binary() -> Optional[str]:
    """Find the Guillotine benchmark binary."""
    # Check for the guillotine-bench binary in apps/cli
    guillotine_bench = Path("apps/cli/guillotine-bench")
    if guillotine_bench.exists():
        return str(guillotine_bench.absolute())
    
    # Check in evms/guillotine-go-sdk as well
    built_guillotine = Path("evms/guillotine-go-sdk/apps/cli/guillotine-bench")
    if built_guillotine.exists():
        return str(built_guillotine.absolute())
    
    return None


def find_revm_binary() -> Optional[str]:
    """Find the revm (revme) binary."""
    # Check for the revme binary in the release build - note the path structure
    revme_release = Path("revm/target/release/revme")
    if revme_release.exists():
        return str(revme_release.absolute())
    
    # Check in evms directory as well
    evms_revme_release = Path("evms/revm/target/release/revme")
    if evms_revme_release.exists():
        return str(evms_revme_release.absolute())
    
    # Check for debug build
    revme_debug = Path("revm/target/debug/revme")
    if revme_debug.exists():
        return str(revme_debug.absolute())
    
    evms_revme_debug = Path("evms/revm/target/debug/revme")
    if evms_revme_debug.exists():
        return str(evms_revme_debug.absolute())
    
    # Check for system revme
    result = subprocess.run(["which", "revme"], capture_output=True, text=True)
    if result.returncode == 0:
        return result.stdout.strip()
    
    return None


def run_revm_benchmark(
    name: str,
    config: Dict[str, Any],
    iterations: int = 10,
    use_hyperfine: bool = True,
    verbose: bool = False
) -> Dict[str, Any]:
    """Run an EVM benchmark using revm (revme)."""
    
    revm_binary = find_revm_binary()
    if not revm_binary:
        raise RuntimeError("revme not found. Please ensure revm is built (cargo build --release -p revme in evms/revm).")
    
    # Prepare the bytecode and calldata
    bytecode = config["bytecode"]
    calldata = config.get("calldata", "")
    
    if use_hyperfine:
        # Create a temporary file for the bytecode
        with tempfile.NamedTemporaryFile(mode='w', suffix='.hex', delete=False) as f:
            f.write(bytecode)
            temp_file = f.name
        
        try:
            # Build the command for revme evm
            cmd_args = [
                revm_binary,
                "evm",
                "--path", temp_file,
                "--gas-limit", str(config.get("gas", 30000000))
            ]
            
            if calldata:
                cmd_args.extend(["--input", calldata])
            
            # Use hyperfine for benchmarking
            cmd = [
                "hyperfine",
                "--runs", str(iterations),
                "--warmup", "3",
                "--export-json", f"results_{name}.json",
                "--",
                " ".join(cmd_args)
            ]
            
            if verbose:
                print(f"Running revm benchmark '{name}' with hyperfine...")
                print(f"Command: {' '.join(cmd)}")
            
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode == 0:
                # Parse hyperfine results
                results_file = f"results_{name}.json"
                if Path(results_file).exists():
                    with open(results_file, 'r') as f:
                        hyperfine_results = json.load(f)
                        return {
                            "name": name,
                            "tool": "hyperfine",
                            "evm": "revm",
                            "results": hyperfine_results
                        }
                else:
                    return {
                        "name": name,
                        "tool": "hyperfine",
                        "evm": "revm",
                        "output": result.stdout
                    }
            else:
                raise RuntimeError(f"Hyperfine failed: {result.stderr}")
        finally:
            # Clean up temp file
            if Path(temp_file).exists():
                os.unlink(temp_file)
    else:
        # Direct execution without hyperfine
        with tempfile.NamedTemporaryFile(mode='w', suffix='.hex', delete=False) as f:
            f.write(bytecode)
            temp_file = f.name
        
        try:
            cmd = [
                revm_binary,
                "evm",
                "--path", temp_file,
                "--gas-limit", str(config.get("gas", 30000000))
            ]
            
            if calldata:
                cmd.extend(["--input", calldata])
        
            print(f"Running revm benchmark '{name}' directly...")
            
            for i in range(iterations):
                result = subprocess.run(cmd, capture_output=True, text=True)
                if result.returncode != 0:
                    raise RuntimeError(f"revm execution failed: {result.stderr}")
            
            return {
                "name": name,
                "tool": "revm",
                "evm": "revm",
                "output": f"Completed {iterations} iterations"
            }
        finally:
            # Clean up temp file
            if Path(temp_file).exists():
                os.unlink(temp_file)


def run_guillotine_benchmark(
    name: str,
    config: Dict[str, Any],
    iterations: int = 10,
    use_hyperfine: bool = True,
    verbose: bool = False
) -> Dict[str, Any]:
    """Run an EVM benchmark using Guillotine."""
    
    guillotine_binary = find_guillotine_binary()
    if not guillotine_binary:
        raise RuntimeError("guillotine-bench not found. Please ensure Guillotine is built.")
    
    # Prepare the bytecode and calldata
    bytecode = config["bytecode"]
    calldata = config.get("calldata", "")
    
    if use_hyperfine:
        # Create a temporary file for the bytecode
        with tempfile.NamedTemporaryFile(mode='w', suffix='.hex', delete=False) as f:
            f.write(bytecode)
            temp_file = f.name
        
        try:
            # Build the command for guillotine-bench
            cmd_args = [
                guillotine_binary,
                "run",
                "--codefile", temp_file,
                "--gas", str(config.get("gas", 30000000))
            ]
            
            if calldata:
                cmd_args.extend(["--input", calldata])
            
            # Use hyperfine for benchmarking
            # Set environment to suppress Guillotine debug output
            env = os.environ.copy()
            env['GUILLOTINE_LOG_LEVEL'] = 'error'
            env['ZIG_LOG_LEVEL'] = 'error'
            
            cmd = [
                "hyperfine",
                "--runs", str(iterations),
                "--warmup", "3",
                "--export-json", f"results_{name}.json",
                "--",
                " ".join(cmd_args)
            ]
            
            if verbose:
                print(f"Running Guillotine benchmark '{name}' with hyperfine...")
                print(f"Command: {' '.join(cmd)}")
            
            result = subprocess.run(cmd, capture_output=True, text=True, env=env)
            
            if result.returncode == 0:
                # Parse hyperfine results
                results_file = f"results_{name}.json"
                if Path(results_file).exists():
                    with open(results_file, 'r') as f:
                        hyperfine_results = json.load(f)
                        return {
                            "name": name,
                            "tool": "hyperfine",
                            "evm": "guillotine",
                            "results": hyperfine_results
                        }
                else:
                    return {
                        "name": name,
                        "tool": "hyperfine",
                        "evm": "guillotine",
                        "output": result.stdout
                    }
            else:
                raise RuntimeError(f"Hyperfine failed: {result.stderr}")
        finally:
            # Clean up temp file
            if Path(temp_file).exists():
                os.unlink(temp_file)
    else:
        # Direct execution without hyperfine
        with tempfile.NamedTemporaryFile(mode='w', suffix='.hex', delete=False) as f:
            f.write(bytecode)
            temp_file = f.name
        
        try:
            cmd = [
                guillotine_binary,
                "run",
                "--codefile", temp_file,
                "--gas", str(config.get("gas", 30000000))
            ]
            
            if calldata:
                cmd.extend(["--input", calldata])
        
            print(f"Running Guillotine benchmark '{name}' directly...")
            
            # Set environment to suppress Guillotine debug output
            env = os.environ.copy()
            env['GUILLOTINE_LOG_LEVEL'] = 'error'
            env['ZIG_LOG_LEVEL'] = 'error'
            
            for i in range(iterations):
                result = subprocess.run(cmd, capture_output=True, text=True, env=env)
                if result.returncode != 0:
                    raise RuntimeError(f"Guillotine execution failed: {result.stderr}")
            
            return {
                "name": name,
                "tool": "guillotine",
                "evm": "guillotine",
                "output": f"Completed {iterations} iterations"
            }
        finally:
            # Clean up temp file
            if Path(temp_file).exists():
                os.unlink(temp_file)


def run_evm_benchmark(
    name: str,
    config: Dict[str, Any],
    iterations: int = 10,
    use_hyperfine: bool = True,
    verbose: bool = False,
    evm_type: str = "geth"
) -> Dict[str, Any]:
    """Run an EVM benchmark using the specified EVM implementation."""
    
    if evm_type == "guillotine":
        return run_guillotine_benchmark(name, config, iterations, use_hyperfine, verbose)
    elif evm_type == "revm":
        return run_revm_benchmark(name, config, iterations, use_hyperfine, verbose)
    
    # Default to geth implementation
    
    geth_binary = find_geth_binary()
    if not geth_binary:
        raise RuntimeError("geth not found. Please ensure go-ethereum is built or geth is installed.")
    
    # For geth, we need to use the evm tool
    # The evm tool is usually built alongside geth
    evm_binary = geth_binary.replace("/geth", "/evm")
    if not Path(evm_binary).exists():
        raise RuntimeError(f"evm binary not found at {evm_binary}. Please run 'make evm' in go-ethereum directory.")
    
    # Use the standalone evm binary
    evm_command = evm_binary
    
    # Prepare the bytecode with proper formatting
    bytecode = config["bytecode"]
    calldata = config.get("calldata", "")
    
    # Create the full code: deployed bytecode + calldata
    code = bytecode + calldata
    
    if use_hyperfine:
        # Create a temporary file for the bytecode
        with tempfile.NamedTemporaryFile(mode='w', suffix='.hex', delete=False) as f:
            f.write(bytecode)  # Write only bytecode, not bytecode+calldata
            temp_file = f.name
        
        try:
            # Use hyperfine for more accurate measurements
            # Build the command for geth's evm
            # The evm tool takes code via --codefile or stdin
            evm_cmd = [
                evm_command,
                "run",
                "--codefile", temp_file,
                "--gas", str(config.get("gas", 30000000)),
                "--input", calldata if calldata else ""
            ]
            
            # Hyperfine needs the command as a single string after '--'
            cmd = [
                "hyperfine",
                "--runs", str(iterations),
                "--warmup", "3",
                "--export-json", f"results_{name}.json",
                "--",
                " ".join(evm_cmd)  # Join the command into a single string
            ]
            
            if verbose:
                print(f"Running EVM benchmark '{name}' with hyperfine...")
                print(f"Command: {' '.join(cmd)}")
            
            # Run without shell for proper argument handling
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode == 0:
                # Parse hyperfine results
                results_file = f"results_{name}.json"
                if Path(results_file).exists():
                    with open(results_file, 'r') as f:
                        hyperfine_results = json.load(f)
                        return {
                            "name": name,
                            "tool": "hyperfine",
                            "evm": "geth",
                            "results": hyperfine_results
                        }
                else:
                    return {
                        "name": name,
                        "tool": "hyperfine",
                        "evm": "geth",
                        "output": result.stdout
                    }
            else:
                raise RuntimeError(f"Hyperfine failed: {result.stderr}")
        finally:
            # Clean up temp file
            if Path(temp_file).exists():
                os.unlink(temp_file)
    else:
        # Direct execution without hyperfine
        with tempfile.NamedTemporaryFile(mode='w', suffix='.hex', delete=False) as f:
            f.write(bytecode)
            temp_file = f.name
        
        try:
            cmd = [
                evm_command,
                "run",
                "--codefile", temp_file,
                "--gas", str(config.get("gas", 30000000)),
                "--input", calldata if calldata else ""
            ]
        
            print(f"Running EVM benchmark '{name}' directly...")
            
            total_time = 0
            for i in range(iterations):
                result = subprocess.run(cmd, capture_output=True, text=True)
                if result.returncode != 0:
                    raise RuntimeError(f"EVM execution failed: {result.stderr}")
            
            return {
                "name": name,
                "tool": "geth-evm",
                "evm": "geth",
                "output": f"Completed {iterations} iterations"
            }
        finally:
            # Clean up temp file
            if Path(temp_file).exists():
                os.unlink(temp_file)