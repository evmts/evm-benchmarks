use anyhow::Result;
use alloy_primitives::{Address, U256, Bytes};
use revm::{
    db::{CacheDB, EmptyDB},
    primitives::{AccountInfo, Bytecode, ExecutionResult, Output, TransactTo, keccak256},
    Evm, EvmBuilder,
};
use std::str::FromStr;
use crate::evm::{EvmResult, EvmExecutor};

pub struct RevmExecutor {
    evm: Evm<'static, (), CacheDB<EmptyDB>>,
    contract_address: Address,
    caller_address: Address,
}

impl RevmExecutor {
    pub fn new() -> Result<Self> {
        let db = CacheDB::new(EmptyDB::default());
        let evm = EvmBuilder::default()
            .with_db(db)
            .build();
        
        let contract_address = Address::from_str("0x1000000000000000000000000000000000000000")?;
        let caller_address = Address::from_str("0x0000000000000000000000000000000000000001")?;
        
        Ok(Self {
            evm,
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
        // Insert the contract code into the database as deployed code
        let bytecode_hash = keccak256(&bytecode);
        self.evm.db_mut().insert_account_info(
            self.contract_address,
            AccountInfo {
                balance: U256::ZERO,
                nonce: 1,
                code_hash: bytecode_hash,
                code: Some(Bytecode::new_raw(Bytes::from(bytecode))),
            },
        );
        
        // Also fund the caller account
        self.evm.db_mut().insert_account_info(
            self.caller_address,
            AccountInfo {
                balance: U256::from(1_000_000_000_000_000_000u128), // 1 ETH
                nonce: 0,
                code_hash: keccak256(&[]),
                code: None,
            },
        );
        
        // Set up transaction environment
        self.evm.tx_mut().caller = self.caller_address;
        self.evm.tx_mut().transact_to = TransactTo::Call(self.contract_address);
        self.evm.tx_mut().data = Bytes::from(calldata);
        self.evm.tx_mut().gas_limit = gas_limit;
        self.evm.tx_mut().gas_price = U256::from(1_000_000_000u128); // 1 gwei
        
        let result = self.evm.transact_commit();
        
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
                            logs: Vec::new(),
                        })
                    }
                    ExecutionResult::Revert { gas_used, output } => {
                        Ok(EvmResult {
                            success: false,
                            gas_used,
                            output: output.to_vec(),
                            logs: Vec::new(),
                        })
                    }
                    ExecutionResult::Halt { reason, gas_used } => {
                        Ok(EvmResult {
                            success: false,
                            gas_used,
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