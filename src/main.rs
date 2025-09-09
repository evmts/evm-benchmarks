mod cli;
mod benchmarks;
mod compiler;
mod display;
mod evm;
mod runner;

use anyhow::Result;
use clap::Parser;

fn main() -> Result<()> {
    let cli = cli::Cli::parse();
    cli.execute()
}