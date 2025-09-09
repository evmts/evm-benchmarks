use anyhow::{Context, Result};
use alloy_primitives::{Address, U256, Bytes, FixedBytes};
use revm::{
    db::{CacheDB, EmptyDB},
    interpreter::{InstructionResult, InterpreterResult},
    primitives::{AccountInfo, Bytecode, ExecutionResult, Output, TransactTo, TxEnv, keccak256},
    Evm, EvmBuilder,
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
        
        let start = Instant::now();    
        let result = evm.transact_commit();
        let execution_time = start.elapsed();
        
        // Check execution result
        match result {
            Ok(exec_result) => {
                match exec_result {
                    ExecutionResult::Success { 
                        gas_used, 
                        output, 
                        .. 
                    } => {
                        let output_bytes = match output {
                            Output::Call(bytes) => bytes.to_vec(),
                            Output::Create(bytes, _) => bytes.to_vec(),
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
            Err(e) => Err(anyhow::anyhow!("EVM execution error: {:?}", e))
        }
    }
    
    fn name(&self) -> &str {
        "revm"
    }
}