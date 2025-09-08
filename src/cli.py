#!/usr/bin/env python3
"""
EVM Benchmark Runner - A CLI tool for running EVM benchmarks using hyperfine.
"""
import argparse
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional, Any
import shutil


def check_hyperfine() -> bool:
    """Check if hyperfine is installed."""
    return shutil.which("hyperfine") is not None


def print_hyperfine_install_instructions():
    """Print instructions for installing hyperfine."""
    print("\n❌ hyperfine is not installed!", file=sys.stderr)
    print("\nTo install hyperfine, visit:", file=sys.stderr)
    print("https://github.com/sharkdp/hyperfine?tab=readme-ov-file#installation", file=sys.stderr)
    print("\nQuick installation options:", file=sys.stderr)
    print("  • macOS:  brew install hyperfine", file=sys.stderr)
    print("  • Ubuntu: apt install hyperfine", file=sys.stderr)
    print("  • Cargo:  cargo install hyperfine", file=sys.stderr)
    print("  • Windows: scoop install hyperfine\n", file=sys.stderr)


def parse_arguments() -> argparse.Namespace:
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description="EVM Benchmark Runner - Run and analyze EVM performance benchmarks",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="Example usage:\n"
               "  %(prog)s run --iterations 10 --warmup 3\n"
               "  %(prog)s compare reth geth\n"
               "  %(prog)s list"
    )
    
    parser.add_argument(
        "--version",
        action="version",
        version="%(prog)s 0.1.0"
    )
    
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Enable verbose output"
    )
    
    subparsers = parser.add_subparsers(dest="command", help="Available commands")
    
    # Run command
    run_parser = subparsers.add_parser("run", help="Run benchmarks")
    run_parser.add_argument(
        "benchmark",
        nargs="?",
        help="Specific benchmark to run (default: all)"
    )
    run_parser.add_argument(
        "-i", "--iterations",
        type=int,
        default=10,
        help="Number of iterations (default: 10)"
    )
    run_parser.add_argument(
        "-w", "--warmup",
        type=int,
        default=3,
        help="Number of warmup runs (default: 3)"
    )
    run_parser.add_argument(
        "-o", "--output",
        type=str,
        help="Output file for results (JSON format)"
    )
    run_parser.add_argument(
        "--export-json",
        type=str,
        help="Export raw hyperfine results to JSON file"
    )
    run_parser.add_argument(
        "--export-markdown",
        type=str,
        help="Export results to Markdown file"
    )
    run_parser.add_argument(
        "--timeout",
        type=int,
        help="Timeout in seconds for each benchmark"
    )
    
    # Compare command
    compare_parser = subparsers.add_parser("compare", help="Compare different EVM implementations")
    compare_parser.add_argument(
        "implementations",
        nargs="+",
        help="EVM implementations to compare (e.g., reth, geth, erigon)"
    )
    compare_parser.add_argument(
        "-b", "--benchmark",
        type=str,
        help="Specific benchmark to use for comparison"
    )
    compare_parser.add_argument(
        "-i", "--iterations",
        type=int,
        default=10,
        help="Number of iterations (default: 10)"
    )
    compare_parser.add_argument(
        "-o", "--output",
        type=str,
        help="Output file for comparison results"
    )
    
    # List command
    list_parser = subparsers.add_parser("list", help="List available benchmarks")
    list_parser.add_argument(
        "--category",
        type=str,
        help="Filter by category"
    )
    
    # Config command
    config_parser = subparsers.add_parser("config", help="Manage benchmark configurations")
    config_parser.add_argument(
        "--show",
        action="store_true",
        help="Show current configuration"
    )
    config_parser.add_argument(
        "--set",
        nargs=2,
        metavar=("KEY", "VALUE"),
        help="Set configuration value"
    )
    config_parser.add_argument(
        "--reset",
        action="store_true",
        help="Reset to default configuration"
    )
    
    return parser.parse_args()


def get_default_benchmarks() -> Dict[str, Dict[str, Any]]:
    """Get default benchmark configurations."""
    return {
        "simple_transfer": {
            "description": "Simple ETH transfer transaction",
            "command": "cast send --private-key $PRIVATE_KEY $TO_ADDRESS --value 0.001ether",
            "category": "transaction",
            "requires": ["cast", "anvil"]
        },
        "erc20_transfer": {
            "description": "ERC20 token transfer",
            "command": "cast send $TOKEN_ADDRESS 'transfer(address,uint256)' $TO_ADDRESS 1000000000000000000",
            "category": "transaction",
            "requires": ["cast"]
        },
        "contract_deploy": {
            "description": "Deploy a simple contract",
            "command": "forge create ./contracts/SimpleStorage.sol:SimpleStorage",
            "category": "deployment",
            "requires": ["forge"]
        },
        "storage_read": {
            "description": "Read from contract storage",
            "command": "cast call $CONTRACT_ADDRESS 'getValue()'",
            "category": "call",
            "requires": ["cast"]
        },
        "storage_write": {
            "description": "Write to contract storage",
            "command": "cast send $CONTRACT_ADDRESS 'setValue(uint256)' 42",
            "category": "transaction",
            "requires": ["cast"]
        },
        "block_sync": {
            "description": "Sync latest blocks",
            "command": "reth node --debug.tip 0x1000",
            "category": "sync",
            "requires": ["reth"]
        }
    }


def list_benchmarks(category: Optional[str] = None, verbose: bool = False) -> None:
    """List available benchmarks."""
    benchmarks = get_default_benchmarks()
    
    if category:
        benchmarks = {k: v for k, v in benchmarks.items() if v.get("category") == category}
    
    if not benchmarks:
        print(f"No benchmarks found for category: {category}")
        return
    
    print("\n📊 Available Benchmarks:\n")
    
    categories = {}
    for name, config in benchmarks.items():
        cat = config.get("category", "uncategorized")
        if cat not in categories:
            categories[cat] = []
        categories[cat].append((name, config))
    
    for cat, items in sorted(categories.items()):
        print(f"  [{cat.upper()}]")
        for name, config in items:
            print(f"    • {name}: {config['description']}")
            if verbose:
                print(f"      Command: {config['command']}")
                if config.get('requires'):
                    print(f"      Requires: {', '.join(config['requires'])}")
        print()


def run_benchmark(
    benchmark_name: Optional[str],
    iterations: int,
    warmup: int,
    output: Optional[str],
    export_json: Optional[str],
    export_markdown: Optional[str],
    timeout: Optional[int],
    verbose: bool
) -> int:
    """Run benchmarks using hyperfine."""
    benchmarks = get_default_benchmarks()
    
    if benchmark_name and benchmark_name not in benchmarks:
        print(f"Error: Unknown benchmark '{benchmark_name}'", file=sys.stderr)
        print("Use 'list' command to see available benchmarks", file=sys.stderr)
        return 1
    
    to_run = {benchmark_name: benchmarks[benchmark_name]} if benchmark_name else benchmarks
    
    print(f"\n🚀 Running {len(to_run)} benchmark(s)...\n")
    
    for name, config in to_run.items():
        print(f"📈 Benchmark: {name}")
        print(f"   {config['description']}")
        
        # Check required tools
        missing_tools = []
        for tool in config.get('requires', []):
            if not shutil.which(tool):
                missing_tools.append(tool)
        
        if missing_tools:
            print(f"   ⚠️  Skipping: Missing required tools: {', '.join(missing_tools)}")
            continue
        
        # Build hyperfine command
        cmd = ["hyperfine"]
        cmd.extend(["--runs", str(iterations)])
        cmd.extend(["--warmup", str(warmup)])
        
        if export_json:
            json_file = export_json.replace(".json", f"_{name}.json")
            cmd.extend(["--export-json", json_file])
        
        if export_markdown:
            md_file = export_markdown.replace(".md", f"_{name}.md")
            cmd.extend(["--export-markdown", md_file])
        
        if timeout:
            cmd.extend(["--command-timeout", str(timeout)])
        
        if verbose:
            cmd.append("--show-output")
        
        # Add the actual command to benchmark
        cmd.append(config['command'])
        
        print(f"   Running: {' '.join(cmd)}\n")
        
        try:
            result = subprocess.run(cmd, capture_output=False, text=True)
            if result.returncode != 0:
                print(f"   ❌ Benchmark failed with code {result.returncode}")
        except KeyboardInterrupt:
            print("\n   ⚠️  Benchmark interrupted by user")
            return 130
        except Exception as e:
            print(f"   ❌ Error running benchmark: {e}")
            continue
        
        print()
    
    if output:
        print(f"✅ Results saved to: {output}")
    
    return 0


def compare_implementations(
    implementations: List[str],
    benchmark: Optional[str],
    iterations: int,
    output: Optional[str],
    verbose: bool
) -> int:
    """Compare different EVM implementations."""
    benchmarks = get_default_benchmarks()
    
    if benchmark and benchmark not in benchmarks:
        print(f"Error: Unknown benchmark '{benchmark}'", file=sys.stderr)
        return 1
    
    print(f"\n⚔️  Comparing implementations: {', '.join(implementations)}\n")
    
    # Build commands for each implementation
    commands = []
    for impl in implementations:
        if impl == "reth":
            cmd = "reth --version"
        elif impl == "geth":
            cmd = "geth version"
        elif impl == "erigon":
            cmd = "erigon --version"
        else:
            print(f"Warning: Unknown implementation '{impl}'", file=sys.stderr)
            continue
        
        commands.append(f"'{cmd}'")
    
    if not commands:
        print("Error: No valid implementations to compare", file=sys.stderr)
        return 1
    
    # Build hyperfine comparison command
    hyperfine_cmd = ["hyperfine"]
    hyperfine_cmd.extend(["--runs", str(iterations)])
    hyperfine_cmd.extend(["--warmup", "3"])
    
    if output:
        hyperfine_cmd.extend(["--export-json", output])
    
    if verbose:
        hyperfine_cmd.append("--show-output")
    
    hyperfine_cmd.extend(commands)
    
    print(f"Running comparison: {' '.join(hyperfine_cmd)}\n")
    
    try:
        result = subprocess.run(hyperfine_cmd, capture_output=False, text=True)
        return result.returncode
    except KeyboardInterrupt:
        print("\n⚠️  Comparison interrupted by user")
        return 130
    except Exception as e:
        print(f"Error running comparison: {e}", file=sys.stderr)
        return 1


def main() -> int:
    """Main entry point."""
    # Check for hyperfine first
    if not check_hyperfine():
        print_hyperfine_install_instructions()
        return 1
    
    args = parse_arguments()
    
    if not args.command:
        print("Error: No command specified. Use --help for usage information.", file=sys.stderr)
        return 1
    
    try:
        if args.command == "run":
            return run_benchmark(
                args.benchmark,
                args.iterations,
                args.warmup,
                args.output,
                args.export_json,
                args.export_markdown,
                args.timeout,
                args.verbose
            )
        elif args.command == "compare":
            return compare_implementations(
                args.implementations,
                args.benchmark if hasattr(args, 'benchmark') else None,
                args.iterations,
                args.output if hasattr(args, 'output') else None,
                args.verbose
            )
        elif args.command == "list":
            list_benchmarks(args.category if hasattr(args, 'category') else None, args.verbose)
            return 0
        elif args.command == "config":
            print("Config management not yet implemented")
            return 0
        else:
            print(f"Error: Unknown command '{args.command}'", file=sys.stderr)
            return 1
    except KeyboardInterrupt:
        print("\n⚠️  Operation cancelled by user", file=sys.stderr)
        return 130
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        if args.verbose:
            import traceback
            traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())