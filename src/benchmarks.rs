use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use sha3::{Keccak256, Digest};
use crate::compiler::{ContractCompiler, CompiledContract};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Benchmark {
    pub name: String,
    pub description: String,
    pub category: String,
    #[serde(rename = "type")]
    pub bench_type: String,
    pub bytecode: String,
    pub calldata: String,
    pub gas: u64,
}

pub fn get_function_selector(signature: &str) -> String {
    let mut hasher = Keccak256::new();
    hasher.update(signature.as_bytes());
    let result = hasher.finalize();
    format!("0x{}", hex::encode(&result[..4]))
}


pub fn get_evm_benchmarks(compiled_contracts: &HashMap<String, CompiledContract>) -> HashMap<String, Benchmark> {
    let mut benchmarks = HashMap::new();
    
    // Ten thousand hashes benchmark
    if let Some(contract) = compiled_contracts.get("TenThousandHashes") {
        benchmarks.insert("ten_thousand_hashes".to_string(), Benchmark {
            name: "ten_thousand_hashes".to_string(),
            description: "Execute 10,000 keccak256 hash operations".to_string(),
            category: "compute".to_string(),
            bench_type: "evm".to_string(),
            bytecode: contract.bytecode.clone(),
            calldata: get_function_selector("Benchmark()"),
            gas: 30000000,
        });
    }
    
    // Snailtracer benchmark (special case - pre-compiled hex file)
    if let Some(contract) = compiled_contracts.get("SnailTracer") {
        benchmarks.insert("snailtracer".to_string(), Benchmark {
            name: "snailtracer".to_string(),
            description: "Ray tracing benchmark (compute intensive)".to_string(),
            category: "compute".to_string(),
            bench_type: "evm".to_string(),
            bytecode: contract.bytecode.clone(),
            calldata: "0x30627b7c".to_string(), // Benchmark() function selector
            gas: 1000000000, // 1B gas
        });
    }
    
    // ERC20 Transfer benchmark
    if let Some(contract) = compiled_contracts.get("ERC20Transfer") {
        benchmarks.insert("erc20_transfer_bench".to_string(), Benchmark {
            name: "erc20_transfer_bench".to_string(),
            description: "Benchmark ERC20 transfer operations".to_string(),
            category: "token".to_string(),
            bench_type: "evm".to_string(),
            bytecode: contract.bytecode.clone(),
            calldata: get_function_selector("Benchmark()"),
            gas: 30000000,
        });
    }
    
    // ERC20 Mint benchmark
    if let Some(contract) = compiled_contracts.get("ERC20Mint") {
        benchmarks.insert("erc20_mint_bench".to_string(), Benchmark {
            name: "erc20_mint_bench".to_string(),
            description: "Benchmark ERC20 minting operations".to_string(),
            category: "token".to_string(),
            bench_type: "evm".to_string(),
            bytecode: contract.bytecode.clone(),
            calldata: get_function_selector("Benchmark()"),
            gas: 30000000,
        });
    }
    
    // ERC20 Approval benchmark
    if let Some(contract) = compiled_contracts.get("ERC20ApprovalTransfer") {
        benchmarks.insert("erc20_approval_bench".to_string(), Benchmark {
            name: "erc20_approval_bench".to_string(),
            description: "Benchmark ERC20 approval and transfer operations".to_string(),
            category: "token".to_string(),
            bench_type: "evm".to_string(),
            bytecode: contract.bytecode.clone(),
            calldata: get_function_selector("Benchmark()"),
            gas: 30000000,
        });
    }
    
    benchmarks
}

pub fn list_benchmarks(verbose: bool) -> Result<()> {
    // Compile contracts first
    let compiler = ContractCompiler::new()?;
    let compiled_contracts = compiler.compile_all()?;
    let benchmarks = get_evm_benchmarks(&compiled_contracts);
    
    if benchmarks.is_empty() {
        println!("No benchmarks available. Check that contracts compile successfully.");
        return Ok(());
    }
    
    println!("\nAvailable Benchmarks:");
    println!("====================\n");
    
    let mut categories: HashMap<String, Vec<&Benchmark>> = HashMap::new();
    for benchmark in benchmarks.values() {
        categories.entry(benchmark.category.clone())
            .or_insert_with(Vec::new)
            .push(benchmark);
    }
    
    for (category, benches) in categories {
        println!("{}:", category.to_uppercase());
        for bench in benches {
            println!("  • {} - {}", bench.name, bench.description);
            if verbose {
                println!("      Gas: {}", bench.gas);
                println!("      Calldata: {}", bench.calldata);
                println!("      Bytecode length: {} bytes", bench.bytecode.len() / 2);
            }
        }
        println!();
    }
    
    Ok(())
}