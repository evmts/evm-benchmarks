use anyhow::Result;
use clap::{Parser, Subcommand};
use std::path::PathBuf;

#[derive(Parser)]
#[command(name = "evm-bench")]
#[command(about = "EVM benchmarking tool for comparing different implementations")]
#[command(version)]
pub struct Cli {
    #[command(subcommand)]
    pub command: Commands,
}

#[derive(Subcommand)]
pub enum Commands {
    /// Execute bytecode directly (used internally for benchmarking)
    Execute {
        /// EVM implementation to use (geth, guillotine, revm)
        #[arg(long)]
        evm: String,
        
        /// Bytecode to execute (hex string)
        #[arg(long)]
        bytecode: String,
        
        /// Calldata (hex string)
        #[arg(long)]
        calldata: String,
        
        /// Gas limit
        #[arg(long)]
        gas: u64,
    },
    
    /// Run benchmarks
    Run {
        /// Name of specific benchmark to run
        benchmark: Option<String>,
        
        /// Number of iterations to run
        #[arg(short, long, default_value = "10")]
        iterations: usize,
        
        /// Number of warmup runs
        #[arg(short, long, default_value = "3")]
        warmup: usize,
        
        /// Specific EVM implementation to use (geth, guillotine, revm)
        #[arg(long)]
        evm: Option<String>,
        
        /// Multiple EVM implementations to benchmark (comma-separated)
        #[arg(long, conflicts_with = "evm")]
        evms: Option<String>,
        
        /// Run on all available EVMs
        #[arg(long, conflicts_with_all = &["evm", "evms"])]
        all: bool,
        
        /// Output file for results
        #[arg(short, long)]
        output: Option<PathBuf>,
        
        /// Export raw hyperfine JSON results
        #[arg(long)]
        export_json: Option<PathBuf>,
        
        /// Verbose output
        #[arg(short, long)]
        verbose: bool,
    },
    
    /// List available benchmarks
    List {
        /// Show detailed information
        #[arg(short, long)]
        verbose: bool,
    },
    
    /// Compare results from different EVMs
    Compare {
        /// EVM implementations to compare
        evms: Vec<String>,
        
        /// Specific benchmark to compare
        #[arg(short, long)]
        benchmark: Option<String>,
        
        /// Output file for comparison
        #[arg(short, long)]
        output: Option<PathBuf>,
    },
}

impl Cli {
    pub fn execute(self) -> Result<()> {
        match self.command {
            Commands::Execute { evm, bytecode, calldata, gas } => {
                crate::evm::execute_bytecode(&evm, &bytecode, &calldata, gas)?;
            }
            Commands::Run { 
                benchmark,
                iterations,
                warmup,
                evm,
                evms,
                all,
                output,
                export_json,
                verbose,
            } => {
                crate::runner::run_benchmarks(
                    benchmark,
                    iterations,
                    warmup,
                    evm,
                    evms,
                    all,
                    output,
                    export_json,
                    verbose,
                )?;
            }
            Commands::List { verbose } => {
                crate::benchmarks::list_benchmarks(verbose)?;
            }
            Commands::Compare { evms, benchmark, output } => {
                crate::runner::compare_evms(evms, benchmark, output)?;
            }
        }
        Ok(())
    }
}