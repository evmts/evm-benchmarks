use anyhow::{Context, Result};
use guillotine_rs::{Evm, Address, U256, Bytes};
use std::time::{Duration, Instant};
use crate::evm::{EvmResult, EvmExecutor};

pub struct GuillotineExecutor {
    evm: Evm,
}

impl GuillotineExecutor {
    pub fn new() -> Result<Self> {
        let evm = Evm::new()
            .context("Failed to create Guillotine EVM instance")?;
        Ok(Self { evm })
    }
}

impl EvmExecutor for GuillotineExecutor {
    fn execute(
        &mut self,
        bytecode: Vec<u8>,
        calldata: Vec<u8>,
        gas_limit: u64,
    ) -> Result<EvmResult> {
        let contract_address = Address::from([0x42; 20]);
        let caller_address = Address::from([0x01; 20]);
        
        self.evm.set_balance(caller_address, U256::from(1_000_000_000_000_000_000u128))
            .context("Failed to set caller balance")?;
        
        self.evm.set_code(contract_address, &bytecode)
            .context("Failed to set contract code")?;
        
        let start = Instant::now();
        
        let result = self.evm.transact()
            .from(caller_address)
            .to(contract_address)
            .data(Bytes::from(calldata))
            .gas_limit(gas_limit)
            .execute()
            .context("Failed to execute transaction")?;
        
        let execution_time = start.elapsed();
        
        Ok(EvmResult {
            success: result.is_success(),
            gas_used: result.gas_used(),
            output: result.output().to_vec(),
            execution_time,
            logs: Vec::new(),
        })
    }
    
    fn name(&self) -> &str {
        "guillotine"
    }
}