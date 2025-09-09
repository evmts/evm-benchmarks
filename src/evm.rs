use anyhow::{Result, bail};
use alloy_primitives::{Address, U256, Bytes};
use revm::{
    bytecode::Bytecode,
    context::{Context, TxEnv},
    context_interface::result::{ExecutionResult, Output},
    database::CacheDB,
    database_interface::EmptyDB,
    primitives::{TxKind, keccak256},
    state::AccountInfo,
    ExecuteEvm, MainBuilder, MainContext,
};
use std::str::FromStr;

pub fn execute_bytecode(evm_name: &str, bytecode: &str, calldata: &str, gas_limit: u64) -> Result<()> {
    match evm_name {
        "revm" => execute_revm(bytecode, calldata, gas_limit),
        "geth" => execute_geth(bytecode, calldata, gas_limit),
        "guillotine" => execute_guillotine(bytecode, calldata, gas_limit),
        _ => bail!("Unknown EVM implementation: {}", evm_name),
    }
}

fn execute_revm(bytecode_hex: &str, calldata_hex: &str, gas_limit: u64) -> Result<()> {
    // Strip 0x prefix if present
    let bytecode_hex = bytecode_hex.strip_prefix("0x").unwrap_or(bytecode_hex);
    let calldata_hex = calldata_hex.strip_prefix("0x").unwrap_or(calldata_hex);
    
    // Parse bytecode and calldata
    let bytecode = hex::decode(bytecode_hex)?;
    let calldata = hex::decode(calldata_hex)?;
    
    
    // Create database and context
    let mut db = CacheDB::<EmptyDB>::default();
    
    // Deploy contract to a fixed address
    let contract_address = Address::from_str("0x1000000000000000000000000000000000000000")?;
    
    // Insert the contract code into the database as deployed code
    let bytecode_hash = keccak256(&bytecode);
    db.insert_account_info(
        contract_address,
        AccountInfo {
            balance: U256::ZERO,
            nonce: 1,
            code_hash: bytecode_hash,
            code: Some(Bytecode::new_raw(Bytes::from(bytecode))),
        },
    );
    
    // Also fund the caller account
    let caller_address = Address::from_str("0x0000000000000000000000000000000000000001")?;
    db.insert_account_info(
        caller_address,
        AccountInfo {
            balance: U256::from(1_000_000_000_000_000_000u128), // 1 ETH
            nonce: 0,
            code_hash: keccak256(&[]),
            code: None,
        },
    );
    
    // Create context and build EVM
    let ctx = Context::mainnet().with_db(db);
    let mut evm = ctx.build_mainnet();
    
    // Execute the transaction
    let tx_env = TxEnv::builder()
        .kind(TxKind::Call(contract_address))
        .caller(caller_address)
        .data(Bytes::from(calldata))
        .gas_limit(gas_limit)
        .gas_price(1_000_000_000u128) // 1 gwei
        .build()
        .map_err(|e| anyhow::anyhow!("Failed to build transaction: {:?}", e))?;
        
    let result = evm.transact(tx_env)?;
    
    // Check execution result
    match result.result {
        ExecutionResult::Success { 
            gas_used: _, 
            output: _, 
            .. 
        } => {
            // Success! Execution completed without errors
            Ok(())
        }
        ExecutionResult::Revert { gas_used, output } => {
            bail!("EVM execution reverted - Gas: {}, Data: 0x{}", gas_used, hex::encode(&output));
        }
        ExecutionResult::Halt { reason, gas_used } => {
            bail!("EVM execution halted - Reason: {:?}, Gas: {}", reason, gas_used);
        }
    }
}

fn execute_geth(_bytecode: &str, _calldata: &str, _gas_limit: u64) -> Result<()> {
    // TODO: Implement geth execution via FFI
    bail!("Geth execution not yet implemented. Use FFI to call go-ethereum.")
}

fn execute_guillotine(_bytecode: &str, _calldata: &str, _gas_limit: u64) -> Result<()> {
    // TODO: Implement guillotine execution via FFI  
    bail!("Guillotine execution not yet implemented. Use FFI to call guillotine.")
}