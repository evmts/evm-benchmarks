use anyhow::{Result, bail, Context};

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

pub fn execute_bytecode(evm_name: &str, bytecode: &str, calldata: &str, gas_limit: u64, internal_runs: usize) -> Result<()> {
    match evm_name {
        "revm" => execute_revm(bytecode, calldata, gas_limit, internal_runs),
        "geth" => execute_geth(bytecode, calldata, gas_limit, internal_runs),
        "guillotine" => execute_guillotine(bytecode, calldata, gas_limit, internal_runs),
        _ => bail!("Unknown EVM implementation: {}", evm_name),
    }
}

fn execute_revm(bytecode_hex: &str, calldata_hex: &str, gas_limit: u64, internal_runs: usize) -> Result<()> {
    use crate::evms::revm::RevmExecutor;
    use crate::evm::EvmExecutor as _;
    
    // Strip 0x prefix if present
    let bytecode_hex = bytecode_hex.strip_prefix("0x").unwrap_or(bytecode_hex);
    let calldata_hex = calldata_hex.strip_prefix("0x").unwrap_or(calldata_hex);
    
    // Parse bytecode and calldata
    let bytecode = hex::decode(bytecode_hex)
        .context("Failed to decode bytecode hex")?;
    let calldata = hex::decode(calldata_hex)
        .context("Failed to decode calldata hex")?;
    
    // Create and execute with revm
    let mut executor = RevmExecutor::new()
        .context("Failed to create Revm executor")?;
    
    // Run the benchmark multiple times
    for _ in 0..internal_runs {
        let result = executor.execute(bytecode.clone(), calldata.clone(), gas_limit)
            .context("Failed to execute with Revm")?;
        
        if !result.success {
            bail!("Revm execution failed - Gas: {}", result.gas_used)
        }
    }
    
    Ok(())
}

fn execute_geth(_bytecode: &str, _calldata: &str, _gas_limit: u64, _internal_runs: usize) -> Result<()> {
    // TODO: Implement geth execution via FFI
    bail!("Geth execution not yet implemented. Use FFI to call go-ethereum.")
}

fn execute_guillotine(bytecode_hex: &str, calldata_hex: &str, gas_limit: u64, internal_runs: usize) -> Result<()> {
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
    
    // Run the benchmark multiple times
    for _ in 0..internal_runs {
        let result = executor.execute(bytecode.clone(), calldata.clone(), gas_limit)
            .context("Failed to execute with Guillotine")?;
        
        if !result.success {
            bail!("Guillotine execution failed - Gas: {}", result.gas_used)
        }
    }
    
    Ok(())
}