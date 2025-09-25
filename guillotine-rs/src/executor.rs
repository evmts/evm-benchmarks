use anyhow::Result;
use crate::{Evm, CallParams, u256_to_bytes_be};

// Re-export the EvmResult and EvmExecutor trait that we'll implement
#[derive(Debug)]
pub struct EvmResult {
    pub success: bool,
    pub gas_used: u64,
    pub output: Vec<u8>,
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

pub struct GuillotineExecutor {
    evm: Option<Evm>,
    contract_address: [u8; 20],
    caller_address: [u8; 20],
}

impl GuillotineExecutor {
    pub fn new() -> Result<Self> {
        // Use the same addresses as REVM for consistency
        let contract_address = hex_to_address("0x1000000000000000000000000000000000000000")?;
        let caller_address = hex_to_address("0x0000000000000000000000000000000000000001")?;

        Ok(Self {
            evm: None,
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
        // Create a new EVM instance for each execution (matches REVM behavior)
        // The Zig implementation has instance pooling so this is still efficient
        let mut evm = Evm::new().map_err(|e| anyhow::anyhow!(e))?;

        // Set up the contract with the bytecode
        evm.set_code(self.contract_address, &bytecode)
            .map_err(|e| anyhow::anyhow!("Failed to set code: {}", e))?;

        // Fund the caller account with 100 ETH (same as REVM)
        let balance = u256_to_bytes_be(100_000_000_000_000_000_000u128);
        evm.set_balance(self.caller_address, balance)
            .map_err(|e| anyhow::anyhow!("Failed to set balance: {}", e))?;

        // Prepare call parameters
        let params = CallParams {
            caller: self.caller_address,
            to: self.contract_address,
            value: [0; 32], // Zero value transfer
            input: calldata.as_ptr(),
            input_len: calldata.len(),
            gas: gas_limit,
            call_type: 0, // CALL
            salt: [0; 32],
        };

        // Execute the call
        let result = evm.execute(&params)
            .map_err(|e| anyhow::anyhow!("Execution failed: {}", e))?;

        // Calculate gas used from gas_left
        let gas_used = gas_limit.saturating_sub(result.gas_left);

        Ok(EvmResult {
            success: result.success,
            gas_used,
            output: result.output,
            logs: Vec::new(), // Guillotine provides logs but we don't need them for benchmarks
        })
    }

    fn name(&self) -> &str {
        "guillotine"
    }
}

// Helper function to convert hex string to address
fn hex_to_address(hex: &str) -> Result<[u8; 20]> {
    let hex = hex.trim_start_matches("0x");
    let bytes = hex::decode(hex)
        .map_err(|e| anyhow::anyhow!("Invalid hex address: {}", e))?;

    if bytes.len() != 20 {
        return Err(anyhow::anyhow!("Address must be 20 bytes"));
    }

    let mut addr = [0u8; 20];
    addr.copy_from_slice(&bytes);
    Ok(addr)
}

// Hex decoding helper
mod hex {
    pub fn decode(s: &str) -> Result<Vec<u8>, &'static str> {
        if s.len() % 2 != 0 {
            return Err("Hex string must have even length");
        }

        let mut result = Vec::with_capacity(s.len() / 2);
        for i in (0..s.len()).step_by(2) {
            let byte_str = &s[i..i+2];
            let byte = u8::from_str_radix(byte_str, 16)
                .map_err(|_| "Invalid hex character")?;
            result.push(byte);
        }
        Ok(result)
    }
}