// Standalone test file to verify revm execution works correctly
use alloy_primitives::{Address, U256, Bytes};
use revm::{
    db::{CacheDB, EmptyDB},
    primitives::{AccountInfo, Bytecode, ExecutionResult, Output, TransactTo, keccak256},
    EvmBuilder,
};
use std::str::FromStr;
use hex;

fn main() {
    println!("Testing revm execution...\n");
    
    // Test bytecode - simple contract that returns 42
    // This is: PUSH1 0x2A PUSH1 0x00 MSTORE PUSH1 0x20 PUSH1 0x00 RETURN
    // Which stores 42 in memory and returns it
    let simple_bytecode = "602a60005260206000f3";
    
    // First test with simple bytecode
    println!("Test 1: Simple bytecode that returns 42");
    match execute_simple_test(simple_bytecode) {
        Ok(_) => println!("✓ Simple test passed!\n"),
        Err(e) => println!("✗ Simple test failed: {}\n", e),
    }
    
    // Now test with the actual TenThousandHashes bytecode
    println!("Test 2: TenThousandHashes contract");
    let ten_k_hashes_bytecode = "6080604052348015600e575f80fd5b50600436106026575f3560e01c806330627b7c14602a575b5f80fd5b60306032565b005b5f5b614e2081101560665760408051602081018390520160408051601f198184030190525280605f816069565b9150506034565b50565b5f60018201608557634e487b7160e01b5f52601160045260245ffd5b506001019056";
    
    // The correct function selector for Benchmark()
    let benchmark_selector = "0x30627b7c"; // Benchmark()
    
    match execute_contract_test(ten_k_hashes_bytecode, benchmark_selector) {
        Ok(_) => println!("✓ TenThousandHashes test passed!"),
        Err(e) => println!("✗ TenThousandHashes test failed: {}", e),
    }
}

fn execute_simple_test(bytecode_hex: &str) -> Result<(), String> {
    let bytecode = hex::decode(bytecode_hex).map_err(|e| format!("Hex decode error: {}", e))?;
    
    let mut db = CacheDB::new(EmptyDB::default());
    let contract_address = Address::from_str("0x1000000000000000000000000000000000000000")
        .map_err(|e| format!("Address parse error: {}", e))?;
    
    // Insert contract
    db.insert_account_info(
        contract_address,
        AccountInfo {
            balance: U256::ZERO,
            nonce: 1,
            code_hash: keccak256(&bytecode),
            code: Some(Bytecode::new_raw(Bytes::from(bytecode))),
        },
    );
    
    // Build EVM
    let mut evm = EvmBuilder::default()
        .with_db(db)
        .build();
    
    // Set up transaction
    evm.tx_mut().caller = Address::from_str("0x0000000000000000000000000000000000000001").unwrap();
    evm.tx_mut().transact_to = TransactTo::Call(contract_address);
    evm.tx_mut().data = Bytes::new();
    evm.tx_mut().gas_limit = 100_000;
    
    let result = evm.transact_commit();
    
    match result {
        Ok(exec_result) => {
            match exec_result {
                ExecutionResult::Success { gas_used, output, .. } => {
                    println!("  Gas used: {}", gas_used);
                    if let Output::Call(bytes) = output {
                        println!("  Output: 0x{}", hex::encode(&bytes));
                        // Check if it returned 42
                        if bytes.len() >= 32 {
                            let value = U256::from_be_slice(&bytes[..32]);
                            println!("  Returned value: {}", value);
                        }
                    }
                    Ok(())
                }
                ExecutionResult::Revert { gas_used, output } => {
                    Err(format!("Reverted - Gas: {}, Data: 0x{}", gas_used, hex::encode(&output)))
                }
                ExecutionResult::Halt { reason, gas_used } => {
                    Err(format!("Halted - Reason: {:?}, Gas: {}", reason, gas_used))
                }
            }
        }
        Err(e) => Err(format!("Transaction error: {:?}", e))
    }
}

fn execute_contract_test(bytecode_hex: &str, calldata_hex: &str) -> Result<(), String> {
    let bytecode = hex::decode(bytecode_hex).map_err(|e| format!("Hex decode error: {}", e))?;
    let calldata_hex = calldata_hex.strip_prefix("0x").unwrap_or(calldata_hex);
    let calldata = hex::decode(calldata_hex).map_err(|e| format!("Calldata decode error: {}", e))?;
    
    println!("  Bytecode length: {} bytes", bytecode.len());
    println!("  Calldata: 0x{}", calldata_hex);
    
    let mut db = CacheDB::new(EmptyDB::default());
    let contract_address = Address::from_str("0x1000000000000000000000000000000000000000")
        .map_err(|e| format!("Address parse error: {}", e))?;
    
    // Insert contract
    db.insert_account_info(
        contract_address,
        AccountInfo {
            balance: U256::ZERO,
            nonce: 1,
            code_hash: keccak256(&bytecode),
            code: Some(Bytecode::new_raw(Bytes::from(bytecode))),
        },
    );
    
    // Fund caller
    let caller = Address::from_str("0x0000000000000000000000000000000000000001").unwrap();
    db.insert_account_info(
        caller,
        AccountInfo {
            balance: U256::from(1_000_000_000_000_000_000u128),
            nonce: 0,
            code_hash: keccak256(&[]),
            code: None,
        },
    );
    
    // Build EVM
    let mut evm = EvmBuilder::default()
        .with_db(db)
        .build();
    
    // Set up transaction with high gas limit
    evm.tx_mut().caller = caller;
    evm.tx_mut().transact_to = TransactTo::Call(contract_address);
    evm.tx_mut().data = Bytes::from(calldata);
    evm.tx_mut().gas_limit = 30_000_000;
    evm.tx_mut().gas_price = U256::from(1_000_000_000u128);
    
    let result = evm.transact_commit();
    
    match result {
        Ok(exec_result) => {
            match exec_result {
                ExecutionResult::Success { gas_used, output, .. } => {
                    println!("  Gas used: {}", gas_used);
                    if let Output::Call(bytes) = output {
                        if !bytes.is_empty() {
                            println!("  Output: 0x{}", hex::encode(&bytes));
                        }
                    }
                    Ok(())
                }
                ExecutionResult::Revert { gas_used, output } => {
                    Err(format!("Reverted - Gas: {}, Data: 0x{}", gas_used, hex::encode(&output)))
                }
                ExecutionResult::Halt { reason, gas_used } => {
                    Err(format!("Halted - Reason: {:?}, Gas: {}", reason, gas_used))
                }
            }
        }
        Err(e) => Err(format!("Transaction error: {:?}", e))
    }
}