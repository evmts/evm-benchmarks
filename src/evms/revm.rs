use anyhow::{Context, Result};
use alloy_primitives::{Address, U256, Bytes};
use revm::{
    bytecode::Bytecode,
    context::{Context as RevmContext, TxEnv},
    context_interface::result::ExecutionResult,
    database::CacheDB,
    database_interface::EmptyDB,
    primitives::{TxKind, keccak256},
    state::AccountInfo,
    ExecuteEvm,
};
use std::str::FromStr;
use std::time::{Duration, Instant};
use crate::evm::{EvmResult, EvmExecutor};

pub struct RevmExecutor {
    // We'll create a new instance for each execution for simplicity
}

impl RevmExecutor {
    pub fn new() -> Result<Self> {
        Ok(Self {})
    }
}

impl EvmExecutor for RevmExecutor {
    fn execute(
        &mut self,
        bytecode: Vec<u8>,
        calldata: Vec<u8>,
        gas_limit: u64,
    ) -> Result<EvmResult> {
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
        let ctx = RevmContext::mainnet().with_db(db);
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
        
        let start = Instant::now();    
        let result = evm.transact(tx_env)?;
        let execution_time = start.elapsed();
        
        // Check execution result
        match result.result {
            ExecutionResult::Success { 
                gas_used, 
                output, 
                .. 
            } => {
                let output_bytes = match output {
                    revm::context_interface::result::Output::Call(bytes) => bytes.to_vec(),
                    revm::context_interface::result::Output::Create(bytes, _) => bytes.to_vec(),
                };
                
                Ok(EvmResult {
                    success: true,
                    gas_used,
                    output: output_bytes,
                    execution_time,
                    logs: Vec::new(),
                })
            }
            ExecutionResult::Revert { gas_used, output } => {
                Ok(EvmResult {
                    success: false,
                    gas_used,
                    output: output.to_vec(),
                    execution_time,
                    logs: Vec::new(),
                })
            }
            ExecutionResult::Halt { reason, gas_used } => {
                Ok(EvmResult {
                    success: false,
                    gas_used,
                    output: format!("Halted: {:?}", reason).into_bytes(),
                    execution_time,
                    logs: Vec::new(),
                })
            }
        }
    }
    
    fn name(&self) -> &str {
        "revm"
    }
}