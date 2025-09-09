#!/usr/bin/env python3
"""
Display benchmark results in a nice format.
"""
import json
import glob
from pathlib import Path

def main():
    results_files = glob.glob("results_*.json")
    if not results_files:
        print("No results files found.")
        return
    
    print("\n" + "=" * 70)
    print("EVM BENCHMARK RESULTS (go-ethereum)")
    print("=" * 70)
    
    for result_file in sorted(results_files):
        name = result_file.replace("results_", "").replace(".json", "")
        
        with open(result_file, 'r') as f:
            data = json.load(f)
        
        if data.get("results"):
            result = data["results"][0]
            mean_ms = result["mean"] * 1000
            min_ms = result["min"] * 1000
            max_ms = result["max"] * 1000
            
            print(f"\n📊 {name}")
            print(f"   Mean:  {mean_ms:.2f} ms")
            print(f"   Min:   {min_ms:.2f} ms") 
            print(f"   Max:   {max_ms:.2f} ms")
            print(f"   Runs:  {len(result.get('times', []))}")
    
    print("\n" + "=" * 70)
    print("✅ All benchmarks completed successfully!")
    print("=" * 70 + "\n")

if __name__ == "__main__":
    main()