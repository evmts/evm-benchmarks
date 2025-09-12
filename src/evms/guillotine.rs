use anyhow::{Result, anyhow};
use crate::evm::{EvmResult, EvmExecutor};

// Import from guillotine_rs crate (guillotine-rs in Cargo.toml)
use guillotine_rs::{StatefulEvm, Address, U256};

pub struct GuillotineExecutor {
    evm: StatefulEvm,
}

impl GuillotineExecutor {
    pub fn new() -> Result<Self> {
        let evm = StatefulEvm::new()
            .map_err(|e| anyhow!("Failed to create Guillotine EVM instance: {}", e))?;
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
            .map_err(|e| anyhow!("Failed to set caller balance: {}", e))?;
        
        self.evm.set_code(contract_address, &bytecode)
            .map_err(|e| anyhow!("Failed to set contract code: {}", e))?;
        
        // Execute transaction directly
        let result = self.evm.execute(
            caller_address,
            Some(contract_address),
            U256::from(0),
            &calldata,
            gas_limit,
        ).map_err(|e| anyhow!("Failed to execute transaction: {}", e))?;
        
        Ok(EvmResult {
            success: result.success,
            gas_used: result.gas_used,
            output: result.output.to_vec(),
            logs: Vec::new(),
        })
    }
    
    fn name(&self) -> &str {
        "guillotine"
    }
}