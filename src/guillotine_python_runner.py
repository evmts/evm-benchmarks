#!/usr/bin/env python3
import sys
import os
# Add guillotine Python SDK to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'guillotine', 'sdks', 'python'))

import argparse
from guillotine_evm import EVM, Address, U256, BlockInfo, CallType, CallParams

def hex_to_bytes(hex_str):
    """Convert hex string to bytes, handling 0x prefix."""
    if hex_str.startswith('0x') or hex_str.startswith('0X'):
        hex_str = hex_str[2:]
    return bytes.fromhex(hex_str)

def main():
    parser = argparse.ArgumentParser(description='Guillotine Python EVM benchmark runner')
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
    sender_address = Address.from_hex("0x0000000000000000000000000000000000000001")
    contract_address = Address.from_hex("0x0000000000000000000000000000000000000042")
    
    # Execute the call multiple times
    for _ in range(internal_runs):
        # Create block info to match the Zig runner
        block_info = BlockInfo(
            number=1,
            timestamp=1, 
            gas_limit=30000000,
            coinbase="0x0000000000000000000000000000000000000000",
            base_fee=1000000000,
            chain_id=1,
            difficulty=0,
            prev_randao=b'\x00' * 32
        )
        
        # Create EVM instance inside loop for fresh state each run
        evm = EVM(block_info)
        
        # Set sender balance (100 ETH)
        balance = U256.from_int(100_000_000_000_000_000_000)  # 100 ETH in wei
        evm.set_balance(sender_address, balance)
        
        # Deploy contract code
        evm.set_code(contract_address, bytecode)
        
        # Create call parameters
        call_params = CallParams(
            caller=sender_address,
            to=contract_address,
            value=U256.from_int(0),
            input=calldata,
            gas=gas_limit,
            call_type=CallType.CALL
        )
        
        # Call the contract
        result = evm.call(call_params)
        
        # Calculate gas used
        gas_used = gas_limit - result.gas_left
        
        # Output for each run (matching Zig runner format)
        print(str(result.success).lower())
        print(gas_used)
        
        # Clean up
        evm.destroy()

if __name__ == "__main__":
    main()