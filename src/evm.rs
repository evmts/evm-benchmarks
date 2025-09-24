use anyhow::Result;

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