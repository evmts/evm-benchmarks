#!/usr/bin/env python3
"""
Rich display utilities for the benchmark CLI.
"""
import sys
import time
import threading
from typing import Optional, Dict, Any
from pathlib import Path
import json


class Colors:
    """ANSI color codes for terminal output."""
    RESET = '\033[0m'
    BOLD = '\033[1m'
    DIM = '\033[2m'
    
    # Colors
    BLACK = '\033[30m'
    RED = '\033[31m'
    GREEN = '\033[32m'
    YELLOW = '\033[33m'
    BLUE = '\033[34m'
    MAGENTA = '\033[35m'
    CYAN = '\033[36m'
    WHITE = '\033[37m'
    
    # Bright colors
    BRIGHT_BLACK = '\033[90m'
    BRIGHT_RED = '\033[91m'
    BRIGHT_GREEN = '\033[92m'
    BRIGHT_YELLOW = '\033[93m'
    BRIGHT_BLUE = '\033[94m'
    BRIGHT_MAGENTA = '\033[95m'
    BRIGHT_CYAN = '\033[96m'
    BRIGHT_WHITE = '\033[97m'
    
    # Background colors
    BG_BLACK = '\033[40m'
    BG_RED = '\033[41m'
    BG_GREEN = '\033[42m'
    BG_YELLOW = '\033[43m'
    BG_BLUE = '\033[44m'
    BG_MAGENTA = '\033[45m'
    BG_CYAN = '\033[46m'
    BG_WHITE = '\033[47m'


class Spinner:
    """Animated spinner for long-running operations."""
    
    def __init__(self, message: str = "Processing"):
        self.message = message
        self.spinning = False
        self.thread = None
        self.frames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
        self.current = 0
        
    def _spin(self):
        """Internal spinning animation."""
        while self.spinning:
            frame = self.frames[self.current % len(self.frames)]
            sys.stdout.write(f'\r{Colors.CYAN}{frame}{Colors.RESET} {self.message}')
            sys.stdout.flush()
            self.current += 1
            time.sleep(0.1)
    
    def start(self):
        """Start the spinner."""
        if not self.spinning:
            self.spinning = True
            self.thread = threading.Thread(target=self._spin)
            self.thread.daemon = True
            self.thread.start()
    
    def stop(self, final_message: Optional[str] = None, success: bool = True):
        """Stop the spinner with an optional final message."""
        if self.spinning:
            self.spinning = False
            if self.thread:
                self.thread.join()
            
            # Clear the line
            sys.stdout.write('\r' + ' ' * (len(self.message) + 4) + '\r')
            
            if final_message:
                if success:
                    icon = f"{Colors.GREEN}✓{Colors.RESET}"
                else:
                    icon = f"{Colors.RED}✗{Colors.RESET}"
                print(f"{icon} {final_message}")
            sys.stdout.flush()


class ProgressBar:
    """Progress bar for tracking multiple operations."""
    
    def __init__(self, total: int, width: int = 40):
        self.total = total
        self.current = 0
        self.width = width
        
    def update(self, current: int, message: str = ""):
        """Update the progress bar."""
        self.current = min(current, self.total)
        percent = self.current / self.total if self.total > 0 else 0
        filled = int(self.width * percent)
        empty = self.width - filled
        
        bar = f"{Colors.BRIGHT_BLUE}{'█' * filled}{Colors.DIM}{'░' * empty}{Colors.RESET}"
        percent_str = f"{percent * 100:5.1f}%"
        
        sys.stdout.write(f'\r{bar} {percent_str} {message}')
        sys.stdout.flush()
        
        if self.current >= self.total:
            print()  # New line when complete


def print_header(title: str, subtitle: Optional[str] = None):
    """Print a styled header."""
    width = 80
    print()
    print(f"{Colors.BRIGHT_CYAN}{'═' * width}{Colors.RESET}")
    print(f"{Colors.BRIGHT_CYAN}║{Colors.RESET} {Colors.BOLD}{title.center(width - 4)}{Colors.RESET} {Colors.BRIGHT_CYAN}║{Colors.RESET}")
    if subtitle:
        print(f"{Colors.BRIGHT_CYAN}║{Colors.RESET} {Colors.DIM}{subtitle.center(width - 4)}{Colors.RESET} {Colors.BRIGHT_CYAN}║{Colors.RESET}")
    print(f"{Colors.BRIGHT_CYAN}{'═' * width}{Colors.RESET}")
    print()


def print_benchmark_header(name: str, description: str, index: int, total: int):
    """Print a benchmark section header."""
    print()
    print(f"{Colors.BRIGHT_BLUE}┌{'─' * 78}┐{Colors.RESET}")
    print(f"{Colors.BRIGHT_BLUE}│{Colors.RESET} {Colors.BOLD}Benchmark {index}/{total}: {name}{Colors.RESET}")
    print(f"{Colors.BRIGHT_BLUE}│{Colors.RESET} {Colors.DIM}{description}{Colors.RESET}")
    print(f"{Colors.BRIGHT_BLUE}└{'─' * 78}┘{Colors.RESET}")


def print_benchmark_info(info: Dict[str, Any]):
    """Print benchmark configuration info."""
    print(f"\n{Colors.DIM}Configuration:{Colors.RESET}")
    if info.get("bytecode"):
        bytecode_len = len(info["bytecode"])
        print(f"  • Bytecode: {Colors.YELLOW}{bytecode_len}{Colors.RESET} bytes")
    if info.get("gas"):
        gas_m = info["gas"] / 1_000_000
        print(f"  • Gas Limit: {Colors.YELLOW}{gas_m:.1f}M{Colors.RESET}")
    if info.get("calldata"):
        print(f"  • Function: {Colors.YELLOW}0x{info['calldata']}{Colors.RESET}")


def format_time(seconds: float) -> str:
    """Format time in appropriate units."""
    if seconds < 0.001:
        return f"{seconds * 1_000_000:.2f} μs"
    elif seconds < 1:
        return f"{seconds * 1000:.2f} ms"
    else:
        return f"{seconds:.2f} s"


def print_results_summary(results: Dict[str, Any]):
    """Print a formatted results summary."""
    if not results or "results" not in results or not results["results"]:
        return
    
    result = results["results"][0]
    mean = result.get("mean", 0)
    stddev = result.get("stddev", 0)
    min_time = result.get("min", 0)
    max_time = result.get("max", 0)
    times = result.get("times", [])
    
    print(f"\n{Colors.BOLD}Results:{Colors.RESET}")
    
    # Main metrics
    print(f"  {Colors.GREEN}✓{Colors.RESET} Mean:   {Colors.BOLD}{format_time(mean)}{Colors.RESET}")
    print(f"  {Colors.GREEN}✓{Colors.RESET} StdDev: {Colors.DIM}{format_time(stddev)}{Colors.RESET}")
    print(f"  {Colors.GREEN}✓{Colors.RESET} Min:    {Colors.CYAN}{format_time(min_time)}{Colors.RESET}")
    print(f"  {Colors.GREEN}✓{Colors.RESET} Max:    {Colors.YELLOW}{format_time(max_time)}{Colors.RESET}")
    
    # Performance bar visualization
    if times:
        print(f"\n  {Colors.DIM}Performance distribution ({len(times)} runs):{Colors.RESET}")
        print_performance_bar(times, min_time, max_time)


def print_performance_bar(times: list, min_time: float, max_time: float):
    """Print a visual performance distribution bar."""
    if not times or min_time >= max_time:
        return
    
    width = 50
    range_time = max_time - min_time
    
    # Create histogram buckets
    buckets = [0] * 10
    for t in times:
        bucket_idx = min(int((t - min_time) / range_time * 10), 9)
        buckets[bucket_idx] += 1
    
    max_count = max(buckets) if buckets else 1
    
    for i, count in enumerate(buckets):
        bar_len = int(count / max_count * width) if max_count > 0 else 0
        bar = "█" * bar_len
        bucket_start = min_time + (i * range_time / 10)
        bucket_end = min_time + ((i + 1) * range_time / 10)
        
        color = Colors.GREEN if i < 3 else Colors.YELLOW if i < 7 else Colors.RED
        print(f"  {color}{bar:<{width}}{Colors.RESET} {format_time(bucket_start)}")


def print_final_summary(all_results: Dict[str, Dict[str, Any]]):
    """Print final summary of all benchmarks."""
    print()
    print(f"{Colors.BRIGHT_GREEN}{'=' * 80}{Colors.RESET}")
    print(f"{Colors.BOLD}BENCHMARK SUMMARY{Colors.RESET}".center(88))
    print(f"{Colors.BRIGHT_GREEN}{'=' * 80}{Colors.RESET}")
    print()
    
    # Table header
    print(f"  {Colors.BOLD}{'Benchmark':<30} {'Mean':<12} {'Min':<12} {'Max':<12} {'Runs':<6}{Colors.RESET}")
    print(f"  {Colors.DIM}{'-' * 72}{Colors.RESET}")
    
    # Results rows
    for name, results in sorted(all_results.items()):
        if results and "results" in results and results["results"]:
            result = results["results"][0]
            mean = format_time(result.get("mean", 0))
            min_time = format_time(result.get("min", 0))
            max_time = format_time(result.get("max", 0))
            runs = len(result.get("times", []))
            
            # Truncate name if too long
            display_name = name[:28] + ".." if len(name) > 30 else name
            
            print(f"  {display_name:<30} {Colors.GREEN}{mean:<12}{Colors.RESET} "
                  f"{Colors.CYAN}{min_time:<12}{Colors.RESET} "
                  f"{Colors.YELLOW}{max_time:<12}{Colors.RESET} "
                  f"{Colors.DIM}{runs:<6}{Colors.RESET}")
    
    print()
    print(f"{Colors.BRIGHT_GREEN}{'=' * 80}{Colors.RESET}")
    print()


def print_error(message: str):
    """Print an error message."""
    print(f"{Colors.RED}✗ Error:{Colors.RESET} {message}", file=sys.stderr)


def print_warning(message: str):
    """Print a warning message."""
    print(f"{Colors.YELLOW}⚠ Warning:{Colors.RESET} {message}", file=sys.stderr)


def print_success(message: str):
    """Print a success message."""
    print(f"{Colors.GREEN}✓{Colors.RESET} {message}")


def clear_line():
    """Clear the current line."""
    sys.stdout.write('\r' + ' ' * 80 + '\r')
    sys.stdout.flush()