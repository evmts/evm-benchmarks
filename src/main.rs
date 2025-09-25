mod evm;
mod revm_executor;
mod ethrex_executor;

use anyhow::Result;
use clap::Parser;
use hex;
use revm_executor::RevmExecutor;
use ethrex_executor::EthrexExecutor;
use evm::EvmExecutor;

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Bytecode to execute (hex encoded)
    #[arg(short, long)]
    bytecode: String,

    /// Calldata for the transaction (hex encoded)
    #[arg(short, long, default_value = "")]
    calldata: String,

    /// Gas limit for execution
    #[arg(short, long, default_value_t = 30_000_000)]
    gas_limit: u64,

    /// EVM implementation to use (revm or ethrex)
    #[arg(short = 'e', long, default_value = "revm")]
    evm: String,
    
    /// Number of internal runs for benchmarking
    #[arg(short = 'i', long, default_value_t = 1)]
    internal_runs: u32,
}

fn decode_hex(s: &str) -> Result<Vec<u8>> {
    let s = if s.starts_with("0x") || s.starts_with("0X") {
        &s[2..]
    } else {
        s
    };
    hex::decode(s).map_err(|e| anyhow::anyhow!("Failed to decode hex: {}", e))
}

fn main() -> Result<()> {
    let args = Args::parse();

    // Decode hex inputs
    let bytecode = decode_hex(&args.bytecode)?;
    let calldata = decode_hex(&args.calldata)?;
    
    // Execute multiple internal runs
    for _ in 0..args.internal_runs {
        // Create executor inside loop for fresh state each run
        let mut executor: Box<dyn EvmExecutor> = match args.evm.as_str() {
            "revm" => Box::new(RevmExecutor::new()?),
            "ethrex" => Box::new(EthrexExecutor::new()?),
            _ => {
                return Err(anyhow::anyhow!("Unknown EVM implementation: {}. Use 'revm' or 'ethrex'.", args.evm));
            }
        };
        
        let result = executor.execute(bytecode.clone(), calldata.clone(), args.gas_limit)?;
        
        // Output only essential benchmark data for each run
        println!("{}", result.success);
        println!("{}", result.gas_used);
    }

    Ok(())
}