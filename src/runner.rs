use anyhow::{Context, Result, bail};
use std::collections::HashMap;
use std::path::PathBuf;
use std::process::Command;
use serde::{Deserialize, Serialize};
use crate::benchmarks::{Benchmark, get_evm_benchmarks};
use crate::compiler::ContractCompiler;
use crate::display;

#[derive(Debug, Serialize, Deserialize)]
pub struct BenchmarkResult {
    pub name: String,
    pub evm: String,
    pub mean: f64,
    pub stddev: f64,
    pub median: f64,
    pub min: f64,
    pub max: f64,
    pub times: Vec<f64>,
}

#[derive(Debug, Deserialize)]
struct HyperfineResult {
    results: Vec<HyperfineRun>,
}

#[derive(Debug, Deserialize)]
struct HyperfineRun {
    mean: f64,
    #[serde(default)]
    stddev: f64,
    median: f64,
    min: f64,
    max: f64,
    times: Vec<f64>,
}

pub fn run_benchmarks(
    benchmark_name: Option<String>,
    iterations: usize,
    warmup: usize,
    evm: Option<String>,
    evms: Option<String>,
    all: bool,
    output: Option<PathBuf>,
    _export_json: Option<PathBuf>,
    verbose: bool,
) -> Result<()> {
    // Check if hyperfine is installed
    which::which("hyperfine")
        .context("hyperfine not found. Please install it: cargo install hyperfine")?;
    
    // Load compiled contracts and get available benchmarks
    let compiler = ContractCompiler::new()?;
    let compiled_contracts = compiler.compile_all()?;
    let benchmarks = get_evm_benchmarks(&compiled_contracts);
    if benchmarks.is_empty() {
        bail!("No benchmarks available. Run 'forge build' to compile contracts.");
    }
    
    // Determine which EVMs to run
    let evms_to_run = determine_evms(evm, evms, all)?;
    
    // Determine which benchmarks to run
    let benchmarks_to_run = if let Some(name) = benchmark_name {
        if let Some(bench) = benchmarks.get(&name) {
            vec![(name, bench.clone())]
        } else {
            bail!("Benchmark '{}' not found", name);
        }
    } else {
        benchmarks.into_iter().collect::<Vec<_>>()
    };
    
    // Run benchmarks
    let mut all_results = HashMap::new();
    
    for (bench_name, benchmark) in &benchmarks_to_run {
        println!("\n📊 Running benchmark: {}", bench_name);
        println!("   {}", benchmark.description);
        
        for evm_name in &evms_to_run {
            println!("\n   🔧 EVM: {}", evm_name);
            
            let result = run_single_benchmark(
                evm_name,
                &benchmark,
                iterations,
                warmup,
                verbose,
            )?;
            
            all_results.entry(bench_name.clone())
                .or_insert_with(HashMap::new)
                .insert(evm_name.clone(), result);
        }
    }
    
    // Display results
    display::show_results(&all_results)?;
    
    // Save results if requested
    if let Some(output_path) = output {
        let json = serde_json::to_string_pretty(&all_results)?;
        std::fs::write(output_path, json)?;
        println!("\n💾 Results saved to file");
    }
    
    Ok(())
}

fn determine_evms(
    evm: Option<String>,
    evms: Option<String>,
    all: bool,
) -> Result<Vec<String>> {
    if all {
        // Check which EVMs are available
        let mut available = Vec::new();
        
        // Always have revm since it's compiled in
        available.push("revm".to_string());
        
        // Check for geth
        if which::which("evm").is_ok() || 
           std::path::Path::new("evms/go-ethereum/build/bin/evm").exists() {
            available.push("geth".to_string());
        }
        
        // Guillotine is always available via the crates.io library
        available.push("guillotine".to_string());
        
        Ok(available)
    } else if let Some(evms_list) = evms {
        Ok(evms_list.split(',').map(|s| s.trim().to_string()).collect())
    } else if let Some(single_evm) = evm {
        Ok(vec![single_evm])
    } else {
        // Default to revm
        Ok(vec!["revm".to_string()])
    }
}

fn run_single_benchmark(
    evm_name: &str,
    benchmark: &Benchmark,
    iterations: usize,
    warmup: usize,
    verbose: bool,
) -> Result<BenchmarkResult> {
    // Get path to our own executable
    let exe_path = std::env::current_exe()
        .context("Failed to get current executable path")?;
    
    // Build the command that hyperfine will run
    let bench_cmd = format!(
        "{} execute --evm {} --bytecode {} --calldata {} --gas {}",
        exe_path.display(),
        evm_name,
        benchmark.bytecode,
        benchmark.calldata,
        benchmark.gas,
    );
    
    // Create temp file for hyperfine JSON output
    let temp_file = tempfile::NamedTempFile::new()?;
    let json_path = temp_file.path();
    
    // Run hyperfine
    let mut cmd = Command::new("hyperfine");
    cmd.arg("--runs").arg(iterations.to_string())
       .arg("--warmup").arg(warmup.to_string())
       .arg("--export-json").arg(json_path)
       .arg("--shell").arg("none");
    
    // Add the command
    cmd.arg(&bench_cmd);
    
    if !verbose {
        cmd.arg("--style").arg("basic");
    }
    
    if verbose {
        eprintln!("Running hyperfine command: {:?}", cmd);
    }
    
    let status = cmd.status()
        .context("Failed to run hyperfine")?;
    
    if !status.success() {
        bail!("Hyperfine failed with exit code: {:?}", status.code());
    }
    
    // Parse hyperfine results
    let json_content = std::fs::read_to_string(json_path)
        .context("Failed to read hyperfine results")?;
    
    let hyperfine_result: HyperfineResult = serde_json::from_str(&json_content)
        .context("Failed to parse hyperfine results")?;
    
    let run = hyperfine_result.results.into_iter().next()
        .context("No results from hyperfine")?;
    
    Ok(BenchmarkResult {
        name: benchmark.name.clone(),
        evm: evm_name.to_string(),
        mean: run.mean,
        stddev: run.stddev,
        median: run.median,
        min: run.min,
        max: run.max,
        times: run.times,
    })
}

pub fn compare_evms(
    evms: Vec<String>,
    benchmark: Option<String>,
    output: Option<PathBuf>,
) -> Result<()> {
    // Run benchmarks for comparison
    run_benchmarks(
        benchmark,
        10,  // iterations
        3,   // warmup
        None,
        Some(evms.join(",")),
        false,
        output,
        None,
        false,
    )
}