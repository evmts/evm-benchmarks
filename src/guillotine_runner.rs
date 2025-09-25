use anyhow::Result;
use std::env;

// Import from guillotine-rs package
use guillotine_rs::executor::{GuillotineExecutor, EvmExecutor};

fn main() -> Result<()> {
    let args: Vec<String> = env::args().collect();

    // Check for --measure-startup flag
    let measure_startup = args.iter().any(|arg| arg == "--measure-startup");

    // Filter out --measure-startup from args for normal parsing
    let filtered_args: Vec<String> = args.iter()
        .filter(|arg| *arg != "--measure-startup")
        .cloned()
        .collect();

    if filtered_args.len() != 4 {
        eprintln!("Usage: {} <bytecode_hex> <calldata_hex> <gas_limit> [--measure-startup]", filtered_args[0]);
        std::process::exit(1);
    }

    let bytecode_hex = &filtered_args[1];
    let calldata_hex = &filtered_args[2];
    let gas_limit: u64 = filtered_args[3].parse()
        .map_err(|e| anyhow::anyhow!("Invalid gas limit: {}", e))?;

    // Parse hex strings
    let bytecode = hex::decode(bytecode_hex.trim_start_matches("0x"))
        .map_err(|e| anyhow::anyhow!("Invalid bytecode hex: {}", e))?;
    let calldata = hex::decode(calldata_hex.trim_start_matches("0x"))
        .map_err(|e| anyhow::anyhow!("Invalid calldata hex: {}", e))?;

    // Create executor
    let mut executor = GuillotineExecutor::new()?;

    // Exit here if measuring startup overhead
    if measure_startup {
        std::process::exit(0);
    }
    let result = executor.execute(bytecode, calldata, gas_limit)?;

    // Output results in the same format as REVM runner
    println!("Success: {}", result.success);
    println!("Gas used: {}", result.gas_used);
    println!("Output: 0x{}", hex::encode(&result.output));

    if !result.success {
        std::process::exit(1);
    }

    Ok(())
}

// Simple hex encoding/decoding utilities
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

    pub fn encode(bytes: &[u8]) -> String {
        let mut result = String::with_capacity(bytes.len() * 2);
        for byte in bytes {
            result.push_str(&format!("{:02x}", byte));
        }
        result
    }
}