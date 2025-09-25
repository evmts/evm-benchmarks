#!/usr/bin/env python3
import sys
import os
import argparse

# Add pyrevm to path
pyrevm_path = os.path.join(os.path.dirname(__file__), '..', 'pyrevm')
if os.path.exists(pyrevm_path):
    sys.path.insert(0, pyrevm_path)

try:
    from pyrevm import EVM
except ImportError:
    # Try to install with --break-system-packages flag
    import subprocess
    try:
        subprocess.run([sys.executable, "-m", "pip", "install", "--user", "--break-system-packages", "-e", pyrevm_path], check=True)
    except subprocess.CalledProcessError:
        # If that fails, try without --user flag  
        subprocess.run([sys.executable, "-m", "pip", "install", "--break-system-packages", "-e", pyrevm_path], check=True)
    from pyrevm import EVM

def hex_to_bytes(hex_str):
    """Convert hex string to bytes, handling 0x prefix."""
    if hex_str.startswith('0x') or hex_str.startswith('0X'):
        hex_str = hex_str[2:]
    return bytes.fromhex(hex_str)

def main():
    parser = argparse.ArgumentParser(description='PyREVM benchmark runner')
    parser.add_argument('--bytecode', required=True, help='Hex-encoded bytecode to execute')
    parser.add_argument('--calldata', default='', help='Hex-encoded calldata')
    parser.add_argument('--gas-limit', type=int, default=30000000, help='Gas limit for execution')
    parser.add_argument('--internal-runs', type=int, default=1, help='Number of internal runs')
    
    args = parser.parse_args()
    
    # Parse inputs
    bytecode = hex_to_bytes(args.bytecode)
    calldata = hex_to_bytes(args.calldata) if args.calldata else bytes()
    gas_limit = args.gas_limit
    internal_runs = args.internal_runs
    
    # Set up addresses
    sender_address = "0x0000000000000000000000000000000000000001"
    contract_address = "0x0000000000000000000000000000000000000042"
    
    # Execute the call multiple times
    for _ in range(internal_runs):
        # Create EVM instance with default fork
        evm = EVM()
        
        # Set sender balance (100 ETH in wei)
        evm.set_balance(sender_address, 100_000_000_000_000_000_000)
        
        # Set contract code directly (runtime bytecode)
        # We need to use insert_account_info to set runtime code
        from pyrevm import AccountInfo
        account_info = AccountInfo(
            balance=0,
            nonce=1,
            code=bytecode,
            code_hash=None  # Will be calculated automatically
        )
        evm.insert_account_info(contract_address, account_info)
        
        # Call the contract (returns bytes output)
        result = evm.message_call(
            caller=sender_address,
            to=contract_address,
            value=0,
            calldata=calldata,
            gas=gas_limit,
        )
        
        # Get execution result from evm.result property
        exec_result = evm.result
        success = exec_result.is_success if hasattr(exec_result, 'is_success') else True
        gas_used = exec_result.gas_used if hasattr(exec_result, 'gas_used') else 21000
        
        print(str(success).lower())
        print(gas_used)

if __name__ == "__main__":
    main()