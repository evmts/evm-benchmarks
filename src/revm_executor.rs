use anyhow::Result;
use revm::{
    context::{Context, TxEnv},
    context_interface::result::{ExecutionResult, Output},
    database::CacheDB,
    database_interface::EmptyDB,
    primitives::{Address, U256, Bytes, TxKind, keccak256, KECCAK_EMPTY},
    bytecode::Bytecode,
    state::AccountInfo,
    ExecuteCommitEvm, MainBuilder, MainContext,
};
use std::str::FromStr;
use crate::evm::{EvmResult, EvmExecutor};

pub struct RevmExecutor {
    contract_address: Address,
    caller_address: Address,
}

impl RevmExecutor {
    pub fn new() -> Result<Self> {
        let contract_address = Address::from_str("0x1000000000000000000000000000000000000000")?;
        let caller_address = Address::from_str("0x0000000000000000000000000000000000000001")?;
        
        Ok(Self {
            contract_address,
            caller_address,
        })
    }
}

impl EvmExecutor for RevmExecutor {
    fn execute(
        &mut self,
        bytecode: Vec<u8>,
        calldata: Vec<u8>,
        gas_limit: u64,
    ) -> Result<EvmResult> {
        // Create a fresh database for each execution
        let mut cache_db = CacheDB::<EmptyDB>::default();
        
        // Insert the contract code into the database as deployed code
        let bytecode_hash = keccak256(&bytecode);
        cache_db.insert_account_info(
            self.contract_address,
            AccountInfo {
                balance: U256::ZERO,
                nonce: 1,
                code_hash: bytecode_hash,
                code: Some(Bytecode::new_raw(Bytes::from(bytecode))),
            },
        );
        
        // Also fund the caller account
        cache_db.insert_account_info(
            self.caller_address,
            AccountInfo {
                balance: U256::from(1_000_000_000_000_000_000u128), // 1 ETH
                nonce: 0,
                code_hash: KECCAK_EMPTY,
                code: None,
            },
        );
        
        // Build transaction
        let tx = TxEnv::builder()
            .caller(self.caller_address)
            .kind(TxKind::Call(self.contract_address))
            .data(Bytes::from(calldata))
            .gas_limit(gas_limit)
            .gas_price(1_000_000_000u128) // 1 gwei
            .build()
            .unwrap();
        
        // Build context and EVM
        let ctx = Context::mainnet()
            .with_db(cache_db);
        
        let mut evm = ctx.build_mainnet();
        
        // Execute the transaction
        let result = evm.transact_commit(tx);
        
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
                            gas_used: gas_used as u64,
                            output: output_bytes,
                            logs: Vec::new(),
                        })
                    }
                    ExecutionResult::Revert { gas_used, output } => {
                        Ok(EvmResult {
                            success: false,
                            gas_used: gas_used as u64,
                            output: output.to_vec(),
                            logs: Vec::new(),
                        })
                    }
                    ExecutionResult::Halt { reason, gas_used } => {
                        Ok(EvmResult {
                            success: false,
                            gas_used: gas_used as u64,
                            output: format!("Halted: {:?}", reason).into_bytes(),
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