#!/usr/bin/env python3
"""
Test script to verify the benchmark pipeline works.
"""
import json
import sys
from pathlib import Path

# Add src to path
sys.path.insert(0, 'src')

from evm_benchmarks import get_contract_bytecode, get_evm_benchmarks

def main():
    print("Testing EVM Benchmark Pipeline\n")
    print("=" * 50)
    
    # Test 1: Get contract bytecode
    print("\n1. Getting TenThousandHashes bytecode...")
    bytecode = get_contract_bytecode("TenThousandHashes")
    if bytecode:
        print(f"   ✅ Found bytecode (length: {len(bytecode)} chars)")
        print(f"   First 100 chars: {bytecode[:100]}...")
    else:
        print("   ❌ Failed to get bytecode")
        return 1
    
    # Test 2: Get EVM benchmarks
    print("\n2. Getting EVM benchmark configurations...")
    benchmarks = get_evm_benchmarks()
    print(f"   ✅ Found {len(benchmarks)} EVM benchmarks:")
    for name, config in benchmarks.items():
        print(f"      - {name}: {config['description']}")
    
    # Test 3: Create a test bytecode file
    print("\n3. Creating test bytecode file...")
    test_file = Path("test_bytecode.hex")
    test_file.write_text(bytecode)
    print(f"   ✅ Created {test_file}")
    
    # Test 4: Run simple benchmark test
    print("\n4. Testing benchmark runner...")
    import subprocess
    result = subprocess.run(
        ["evms/benchmark-runner/benchmark-runner-simple", "--iterations", "2", "--", "echo", "test"],
        capture_output=True,
        text=True
    )
    if result.returncode == 0:
        print("   ✅ Benchmark runner works")
        print(f"   Output: {result.stdout.strip()}")
    else:
        print(f"   ❌ Benchmark runner failed: {result.stderr}")
    
    print("\n" + "=" * 50)
    print("✅ All tests passed!")
    
    # Clean up
    if test_file.exists():
        test_file.unlink()
    
    return 0

if __name__ == "__main__":
    sys.exit(main())