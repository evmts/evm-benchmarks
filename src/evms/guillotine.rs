use anyhow::{Result, anyhow};
use guillotine_ffi::{Evm, Address, U256};
use crate::evm::{EvmResult, EvmExecutor};

pub struct GuillotineExecutor {
    evm: Evm,
    contract_address: Address,
    caller_address: Address,
}

impl GuillotineExecutor {
    pub fn new() -> Result<Self> {
        let evm = Evm::new()
            .map_err(|e| anyhow!("Failed to create Guillotine EVM instance: {}", e))?;
        
        let contract_address = Address::from([0x42; 20]);
        let caller_address = Address::from([0x01; 20]);
        
        Ok(Self { 
            evm,
            contract_address,
            caller_address,
        })
    }
}

impl EvmExecutor for GuillotineExecutor {
    fn execute(
        &mut self,
        bytecode: Vec<u8>,
        calldata: Vec<u8>,
        gas_limit: u64,
    ) -> Result<EvmResult> {
        self.evm.set_balance(self.caller_address, U256::from(1_000_000_000_000_000_000u128))
            .map_err(|e| anyhow!("Failed to set caller balance: {}", e))?;
        
        self.evm.set_code(self.contract_address, &bytecode)
            .map_err(|e| anyhow!("Failed to set contract code: {}", e))?;
        
        // Try with input instead of data
        let result = self.evm.transact()
            .from(self.caller_address)
            .to(self.contract_address)
            .input(calldata)
            .gas_limit(gas_limit)
            .execute()
            .map_err(|e| anyhow!("Failed to execute transaction: {}", e))?;
        
        Ok(EvmResult {
            success: result.is_success(),
            gas_used: result.gas_used,
            output: result.output().to_vec(),
            logs: Vec::new(),
        })
    }
    
    fn name(&self) -> &str {
        "guillotine"
    }
}