mod evm;
mod revm_executor;

use anyhow::Result;
use clap::Parser;
use hex;
use revm_executor::RevmExecutor;
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

    // Create and use REVM executor
    let mut executor = RevmExecutor::new()?;
    
    println!("Executing with {}...", executor.name());
    println!("Bytecode: {} bytes", bytecode.len());
    println!("Calldata: {} bytes", calldata.len());
    println!("Gas limit: {}", args.gas_limit);
    println!();

    // Execute
    let result = executor.execute(bytecode, calldata, args.gas_limit)?;

    // Print results
    println!("Execution Result:");
    println!("  Success: {}", result.success);
    println!("  Gas used: {}", result.gas_used);
    println!("  Output: 0x{}", hex::encode(&result.output));
    
    if !result.logs.is_empty() {
        println!("  Logs:");
        for log in &result.logs {
            println!("    {}", log);
        }
    }

    Ok(())
}