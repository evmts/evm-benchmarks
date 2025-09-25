#!/usr/bin/env node

const { VM } = require('@ethereumjs/vm');
const { Chain, Common, Hardfork } = require('@ethereumjs/common');
const { Account, Address } = require('@ethereumjs/util');
const { DefaultStateManager } = require('@ethereumjs/statemanager');
const { hexToBytes, bytesToBigInt, bigIntToBytes } = require('@ethereumjs/util');

async function main() {
  // Parse command line arguments
  const args = process.argv.slice(2);
  let bytecodeHex = '';
  let calldataHex = '';
  let gasLimit = 30000000;
  let internalRuns = 1;
  let measureStartup = false;

  for (let i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--bytecode':
        bytecodeHex = args[++i];
        break;
      case '--calldata':
        calldataHex = args[++i];
        break;
      case '--gas-limit':
        gasLimit = parseInt(args[++i]);
        break;
      case '--internal-runs':
        internalRuns = parseInt(args[++i]);
        break;
      case '--measure-startup':
        measureStartup = true;
        break;
    }
  }

  if (!bytecodeHex) {
    console.error('Error: --bytecode is required');
    process.exit(1);
  }

  // Remove 0x prefix if present
  if (bytecodeHex.startsWith('0x') || bytecodeHex.startsWith('0X')) {
    bytecodeHex = bytecodeHex.slice(2);
  }
  if (calldataHex && (calldataHex.startsWith('0x') || calldataHex.startsWith('0X'))) {
    calldataHex = calldataHex.slice(2);
  }

  // Parse hex inputs
  const bytecode = hexToBytes('0x' + bytecodeHex);
  const calldata = calldataHex ? hexToBytes('0x' + calldataHex) : new Uint8Array();

  // Set up addresses
  const senderAddress = Address.fromString('0x0000000000000000000000000000000000000001');
  const contractAddress = Address.fromString('0x0000000000000000000000000000000000000042');

  // Exit here if measuring startup overhead
  if (measureStartup) {
    process.exit(0);
  }

  // Run multiple times
  for (let run = 0; run < internalRuns; run++) {
    // Create a new VM instance for each run with latest hardfork
    const common = new Common({ chain: Chain.Mainnet, hardfork: Hardfork.Cancun });
    const stateManager = new DefaultStateManager();
    const vm = await VM.create({ common, stateManager });

    // Set up sender account with balance (100 ETH in wei)
    const senderAccount = Account.fromAccountData({
      balance: BigInt('100000000000000000000'), // 100 ETH
      nonce: BigInt(0)
    });
    await vm.stateManager.putAccount(senderAddress, senderAccount);

    // Set up contract account with code
    await vm.stateManager.putContractCode(contractAddress, bytecode);
    const contractAccount = Account.fromAccountData({
      balance: BigInt(0),
      nonce: BigInt(0)
    });
    await vm.stateManager.putAccount(contractAddress, contractAccount);

    try {
      // Execute the contract call
      const result = await vm.evm.runCall({
        caller: senderAddress,
        to: contractAddress,
        value: BigInt(0),
        data: calldata,
        gasLimit: BigInt(gasLimit),
        origin: senderAddress,
        block: {
          header: {
            baseFeePerGas: BigInt(1000000000),
            gasLimit: BigInt(gasLimit),
            number: BigInt(1),
            timestamp: BigInt(1)
          }
        }
      });

      // Calculate gas used
      const gasUsed = gasLimit - Number(result.execResult.gasRefund || 0) -
                     Number(result.execResult.gas);

      // Determine success - no exception means success
      const success = result.execResult.exceptionError === undefined;

      // Output for each run (matching other runner formats)
      console.log(success.toString().toLowerCase());
      console.log(gasUsed);

      // Debug: if failed, show why (only on first failure)
      if (!success && run === 0) {
        console.error('Execution failed:', result.execResult.exceptionError?.toString());
        if (result.execResult.returnValue && result.execResult.returnValue.length > 0) {
          console.error('Output: 0x' + Buffer.from(result.execResult.returnValue).toString('hex'));
        }
      }
    } catch (error) {
      // On exception, treat as failure
      console.log('false');
      console.log(gasLimit); // All gas consumed on failure

      if (run === 0) {
        console.error('Execution error:', error.message);
      }
    }
  }
}

main().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});