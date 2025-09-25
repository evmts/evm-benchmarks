#!/usr/bin/env python3

import argparse
import sys
from eth import constants
from eth.db.atomic import AtomicDB
from eth.chains.mainnet import MainnetChain
from eth_utils import decode_hex, to_canonical_address, to_checksum_address

def main():
    parser = argparse.ArgumentParser(description='py-evm runner for benchmarks')
    parser.add_argument('--bytecode', required=True, help='Hex-encoded bytecode to execute')
    parser.add_argument('--calldata', default='', help='Hex-encoded calldata')
    parser.add_argument('--gas-limit', type=int, default=30000000, help='Gas limit for execution')
    parser.add_argument('--internal-runs', type=int, default=1, help='Number of internal runs')
    parser.add_argument('--measure-startup', action='store_true', help='Measure startup overhead only')

    args = parser.parse_args()

    # Parse hex inputs (remove 0x prefix if present)
    bytecode_hex = args.bytecode
    if bytecode_hex.startswith('0x') or bytecode_hex.startswith('0X'):
        bytecode_hex = bytecode_hex[2:]
    bytecode = bytes.fromhex(bytecode_hex)

    calldata_hex = args.calldata
    if calldata_hex and (calldata_hex.startswith('0x') or calldata_hex.startswith('0X')):
        calldata_hex = calldata_hex[2:]
    calldata = bytes.fromhex(calldata_hex) if calldata_hex else b''

    # Set up addresses
    sender_address = to_canonical_address('0x0000000000000000000000000000000000000001')
    contract_address = to_canonical_address('0x0000000000000000000000000000000000000042')

    # Exit here if measuring startup overhead
    if args.measure_startup:
        sys.exit(0)

    # Execute multiple times
    for i in range(args.internal_runs):
        # Create a fresh state database for each run
        db = AtomicDB()

        # Create chain with latest fork rules
        chain = MainnetChain(db)
        vm = chain.get_vm()

        # Get the latest VM
        with vm.state.mutable_state_db() as state_db:
            # Set sender balance (100 ETH in wei)
            state_db.set_balance(sender_address, 100 * 10**18)

            # Set contract code
            state_db.set_code(contract_address, bytecode)

        # Execute the transaction directly using the VM's execute_bytecode
        try:
            # Create a simple transaction context
            from eth.vm.message import Message

            message = Message(
                gas=args.gas_limit,
                to=contract_address,
                sender=sender_address,
                value=0,
                data=calldata,
                code=bytecode,
                create_address=None,
            )

            # Apply the message
            computation = vm.state.get_computation(message).apply_message()

            # Determine success
            success = not computation.is_error

            # Calculate gas used
            gas_used = args.gas_limit - computation.get_gas_remaining()

            # Output for each run (matching other runner formats)
            print(str(success).lower())
            print(gas_used)

            # Debug: if failed, show why (only on first failure)
            if not success and i == 0:
                print(f"Execution failed: {computation.error}", file=sys.stderr)
                if computation.output:
                    print(f"Output: 0x{computation.output.hex()}", file=sys.stderr)

        except Exception as e:
            # On exception, treat as failure
            print("false")
            print(args.gas_limit)  # All gas consumed on failure

            if i == 0:
                print(f"Execution error: {e}", file=sys.stderr)

if __name__ == "__main__":
    main()