use anyhow::{Result, bail, Context};
use alloy_primitives::{Address, U256, Bytes};
use revm::{
    db::{CacheDB, EmptyDB},
    primitives::{AccountInfo, Bytecode, ExecutionResult, TransactTo, keccak256},
    EvmBuilder,
};
use std::str::FromStr;
use std::time::Duration;

pub struct EvmResult {
    pub success: bool,
    pub gas_used: u64,
    pub output: Vec<u8>,
    pub execution_time: Duration,
    pub logs: Vec<String>,
}

pub trait EvmExecutor {
    fn execute(
        &mut self,
        bytecode: Vec<u8>,
        calldata: Vec<u8>,
        gas_limit: u64,
    ) -> Result<EvmResult>;
    
    fn name(&self) -> &str;
}

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
    
    
    // Create database
    let mut db = CacheDB::new(EmptyDB::default());
    
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
    
    // Build EVM
    let mut evm = EvmBuilder::default()
        .with_db(db)
        .build();
    
    // Set up transaction environment
    evm.tx_mut().caller = caller_address;
    evm.tx_mut().transact_to = TransactTo::Call(contract_address);
    evm.tx_mut().data = Bytes::from(calldata);
    evm.tx_mut().gas_limit = gas_limit;
    evm.tx_mut().gas_price = U256::from(1_000_000_000u128); // 1 gwei
        
    let result = evm.transact_commit();
    
    // Check execution result
    match result {
        Ok(exec_result) => {
            match exec_result {
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
        Err(e) => bail!("EVM execution error: {:?}", e)
    }
}

fn execute_geth(_bytecode: &str, _calldata: &str, _gas_limit: u64) -> Result<()> {
    // TODO: Implement geth execution via FFI
    bail!("Geth execution not yet implemented. Use FFI to call go-ethereum.")
}

fn execute_guillotine(bytecode_hex: &str, calldata_hex: &str, gas_limit: u64) -> Result<()> {
    use crate::evms::guillotine::GuillotineExecutor;
    use crate::evm::EvmExecutor as _;
    
    // Strip 0x prefix if present
    let bytecode_hex = bytecode_hex.strip_prefix("0x").unwrap_or(bytecode_hex);
    let calldata_hex = calldata_hex.strip_prefix("0x").unwrap_or(calldata_hex);
    
    // Parse bytecode and calldata
    let bytecode = hex::decode(bytecode_hex)
        .context("Failed to decode bytecode hex")?;
    let calldata = hex::decode(calldata_hex)
        .context("Failed to decode calldata hex")?;
    
    // Create and execute with guillotine
    let mut executor = GuillotineExecutor::new()
        .context("Failed to create Guillotine executor")?;
    
    let result = executor.execute(bytecode, calldata, gas_limit)
        .context("Failed to execute with Guillotine")?;
    
    if result.success {
        Ok(())
    } else {
        bail!("Guillotine execution failed - Gas: {}", result.gas_used)
    }
}