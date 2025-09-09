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
from evm_benchmarks import get_evm_benchmarks, run_evm_benchmark
from cli_display import (
    Colors, Spinner, ProgressBar, print_header, print_benchmark_header,
    print_benchmark_info, print_results_summary, print_final_summary,
    print_error, print_warning, print_success, clear_line, print_matrix_summary
)


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
    run_parser.add_argument(
        "--evm",
        type=str,
        choices=["geth", "guillotine", "revm"],
        help="Single EVM implementation to use"
    )
    run_parser.add_argument(
        "--evms",
        type=str,
        help="Comma-separated list of EVM implementations (e.g., geth,guillotine)"
    )
    run_parser.add_argument(
        "--all",
        action="store_true",
        help="Run all available EVM implementations"
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
    # Only return EVM benchmarks that we can actually run
    return get_evm_benchmarks()


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


def run_benchmark_matrix(
    benchmark_name: Optional[str],
    iterations: int,
    warmup: int,
    output: Optional[str],
    export_json: Optional[str],
    export_markdown: Optional[str],
    timeout: Optional[int],
    verbose: bool,
    evms: List[str]
) -> int:
    """Run benchmarks across multiple EVM implementations."""
    benchmarks = get_default_benchmarks()
    
    if benchmark_name and benchmark_name not in benchmarks:
        print(f"Error: Unknown benchmark '{benchmark_name}'", file=sys.stderr)
        print("Use 'list' command to see available benchmarks", file=sys.stderr)
        return 1
    
    to_run = {benchmark_name: benchmarks[benchmark_name]} if benchmark_name else benchmarks
    
    # Print header
    evms_str = ", ".join(evms)
    print_header("EVM BENCHMARK MATRIX", f"Running {len(to_run)} benchmark(s) on {evms_str}")
    
    # Store results for matrix display
    matrix_results = {}
    
    for evm in evms:
        print(f"\n[94m{'='*80}[0m")
        print(f"[1mTesting EVM: {evm.upper()}[0m")
        print(f"[94m{'='*80}[0m\n")
        
        evm_results = {}
        progress = ProgressBar(len(to_run))
        
        for idx, (name, config) in enumerate(to_run.items(), 1):
            progress.update(idx - 1, f"Running {name} on {evm}...")
            
            # Print benchmark header
            print_benchmark_header(name, config['description'], idx, len(to_run))
            
            if verbose:
                print_benchmark_info(config)
            
            # Handle EVM benchmarks
            if config.get('type') == 'evm':
                spinner = Spinner(f"Running {name} ({iterations} iterations) on {evm}...")
                spinner.start()
                
                try:
                    result = run_evm_benchmark(name, config, iterations, use_hyperfine=True, verbose=verbose, evm_type=evm)
                    spinner.stop(f"Benchmark {name} on {evm} completed", success=True)
                    
                    # Load and store results
                    results_file = f"results_{name}.json"
                    if Path(results_file).exists():
                        with open(results_file, 'r') as f:
                            results_data = json.load(f)
                            evm_results[name] = results_data
                            print_results_summary(results_data)
                    
                except Exception as e:
                    spinner.stop(f"Benchmark {name} on {evm} failed: {e}", success=False)
                    evm_results[name] = {"error": str(e)}
        
        progress.update(len(to_run), f"All benchmarks completed for {evm}")
        matrix_results[evm] = evm_results
    
    # Print matrix summary
    print_matrix_summary(matrix_results, to_run.keys())
    
    # Save matrix results if output specified
    if output:
        with open(output, 'w') as f:
            json.dump(matrix_results, f, indent=2)
        print_success(f"Matrix results saved to: {output}")
    
    return 0


def run_benchmark(
    benchmark_name: Optional[str],
    iterations: int,
    warmup: int,
    output: Optional[str],
    export_json: Optional[str],
    export_markdown: Optional[str],
    timeout: Optional[int],
    verbose: bool,
    evm_type: str = "geth"
) -> int:
    """Run benchmarks using hyperfine."""
    benchmarks = get_default_benchmarks()
    
    if benchmark_name and benchmark_name not in benchmarks:
        print(f"Error: Unknown benchmark '{benchmark_name}'", file=sys.stderr)
        print("Use 'list' command to see available benchmarks", file=sys.stderr)
        return 1
    
    to_run = {benchmark_name: benchmarks[benchmark_name]} if benchmark_name else benchmarks
    
    # Print header
    print_header("EVM BENCHMARK SUITE", f"Running {len(to_run)} benchmark(s)")
    
    # Progress tracking
    all_results = {}
    progress = ProgressBar(len(to_run))
    
    for idx, (name, config) in enumerate(to_run.items(), 1):
        # Update progress
        progress.update(idx - 1, f"Preparing {name}...")
        
        # Print benchmark header
        print_benchmark_header(name, config['description'], idx, len(to_run))
        
        # Print benchmark info if verbose
        if verbose:
            print_benchmark_info(config)
        
        # Check required tools
        missing_tools = []
        for tool in config.get('requires', []):
            if not shutil.which(tool):
                missing_tools.append(tool)
        
        if missing_tools:
            print_warning(f"Skipping: Missing required tools: {', '.join(missing_tools)}")
            continue
        
        # Handle EVM benchmarks differently
        if config.get('type') == 'evm':
            # Create spinner for running benchmark
            spinner = Spinner(f"Running {name} ({iterations} iterations)...")
            spinner.start()
            
            try:
                result = run_evm_benchmark(name, config, iterations, use_hyperfine=True, verbose=verbose, evm_type=evm_type)
                spinner.stop(f"Benchmark {name} completed", success=True)
                
                # Load and display results
                results_file = f"results_{name}.json"
                if Path(results_file).exists():
                    with open(results_file, 'r') as f:
                        results_data = json.load(f)
                        all_results[name] = results_data
                        print_results_summary(results_data)
                
            except Exception as e:
                spinner.stop(f"Benchmark {name} failed: {e}", success=False)
            continue
        
        # Build hyperfine command for non-EVM benchmarks
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
    
    # Update final progress
    progress.update(len(to_run), "All benchmarks completed")
    
    # Print final summary
    if all_results:
        print_final_summary(all_results)
    
    if output:
        print_success(f"Results saved to: {output}")
    
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
            # Determine which EVMs to run
            evms_to_run = []
            
            if args.all:
                # Run all available EVMs
                evms_to_run = ["geth", "guillotine", "revm"]
            elif args.evms:
                # Parse comma-separated list
                evms_to_run = [evm.strip() for evm in args.evms.split(",")]
                # Validate EVMs
                valid_evms = ["geth", "guillotine", "revm"]
                for evm in evms_to_run:
                    if evm not in valid_evms:
                        print(f"Error: Unknown EVM '{evm}'. Valid options: {', '.join(valid_evms)}", file=sys.stderr)
                        return 1
            elif args.evm:
                # Single EVM specified
                evms_to_run = [args.evm]
            else:
                # Default to geth
                evms_to_run = ["geth"]
            
            # Run matrix if multiple EVMs, otherwise single run
            if len(evms_to_run) > 1:
                return run_benchmark_matrix(
                    args.benchmark,
                    args.iterations,
                    args.warmup,
                    args.output,
                    args.export_json,
                    args.export_markdown,
                    args.timeout,
                    args.verbose,
                    evms_to_run
                )
            else:
                return run_benchmark(
                    args.benchmark,
                    args.iterations,
                    args.warmup,
                    args.output,
                    args.export_json,
                    args.export_markdown,
                    args.timeout,
                    args.verbose,
                    evms_to_run[0]
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