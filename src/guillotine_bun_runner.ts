#!/usr/bin/env bun
import { createEVM, CallType, hexToBytes } from "../guillotine/sdks/bun/src/index";
import { parseArgs } from "util";

const { values } = parseArgs({
  args: Bun.argv.slice(2),
  options: {
    bytecode: {
      type: "string",
    },
    calldata: {
      type: "string",
      default: "",
    },
    "gas-limit": {
      type: "string",
      default: "30000000",
    },
    "internal-runs": {
      type: "string",
      default: "1",
    },
    "measure-startup": {
      type: "boolean",
      default: false,
    },
  },
});

const bytecodeHex = values.bytecode;
if (!bytecodeHex) {
  process.exit(1);
}

const calldataHex = values.calldata || "";
const gasLimit = BigInt(values["gas-limit"] || "30000000");
const internalRuns = parseInt(values["internal-runs"] || "1", 10);

const bytecode = hexToBytes(bytecodeHex);
const calldata = calldataHex && calldataHex.length > 0 
  ? hexToBytes(calldataHex) 
  : new Uint8Array(0);

const senderAddress = "0x0000000000000000000000000000000000000001";
const contractAddress = "0x0000000000000000000000000000000000000042";

for (let i = 0; i < internalRuns; i++) {
  // Create EVM instance inside loop for fresh state each run
  const evm = createEVM({
    number: 1n,
    timestamp: 1n,
    gasLimit: 30_000_000n,
    coinbase: "0x0000000000000000000000000000000000000000",
    baseFee: 1_000_000_000n,
    chainId: 1n,
    difficulty: 0n,
  });

  evm.setBalance(senderAddress, 10n ** 20n); // 100 ETH

  evm.setCode(contractAddress, bytecode);

  const result = evm.call({
    caller: senderAddress,
    to: contractAddress,
    value: 0n,
    input: calldata,
    gas: gasLimit,
    callType: CallType.CALL,
  });

  const gasUsed = gasLimit - result.gasLeft;
  
  console.log(result.success);
  console.log(gasUsed.toString());
}