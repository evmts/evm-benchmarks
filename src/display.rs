use anyhow::Result;
use colored::*;
use comfy_table::{Table, Cell, Attribute, Color as TableColor};
use std::collections::HashMap;
use crate::runner::BenchmarkResult;

pub fn show_results(results: &HashMap<String, HashMap<String, BenchmarkResult>>) -> Result<()> {
    println!("\n{}", "=".repeat(80).bright_blue());
    println!("{}", "BENCHMARK RESULTS".bright_white().bold());
    println!("{}", "=".repeat(80).bright_blue());
    
    for (bench_name, evm_results) in results {
        println!("\n📊 {}", bench_name.bright_yellow().bold());
        
        let mut table = Table::new();
        table.set_header(vec![
            Cell::new("EVM").add_attribute(Attribute::Bold),
            Cell::new("Mean (s)").add_attribute(Attribute::Bold),
            Cell::new("Std Dev").add_attribute(Attribute::Bold),
            Cell::new("Min (s)").add_attribute(Attribute::Bold),
            Cell::new("Max (s)").add_attribute(Attribute::Bold),
            Cell::new("Median (s)").add_attribute(Attribute::Bold),
        ]);
        
        // Find the fastest mean time for highlighting
        let fastest_mean = evm_results.values()
            .map(|r| r.mean)
            .min_by(|a, b| a.partial_cmp(b).unwrap())
            .unwrap_or(0.0);
        
        for (evm_name, result) in evm_results {
            let is_fastest = (result.mean - fastest_mean).abs() < 0.0001;
            
            let row = vec![
                if is_fastest {
                    Cell::new(format!("⚡ {}", evm_name))
                        .fg(TableColor::Green)
                        .add_attribute(Attribute::Bold)
                } else {
                    Cell::new(evm_name)
                },
                Cell::new(format!("{:.4}", result.mean)),
                Cell::new(format!("{:.4}", result.stddev)),
                Cell::new(format!("{:.4}", result.min)),
                Cell::new(format!("{:.4}", result.max)),
                Cell::new(format!("{:.4}", result.median)),
            ];
            
            table.add_row(row);
        }
        
        println!("{}", table);
        
        // Show relative performance if multiple EVMs
        if evm_results.len() > 1 {
            println!("\n   📈 Relative Performance:");
            let mut evms: Vec<_> = evm_results.iter().collect();
            evms.sort_by(|a, b| a.1.mean.partial_cmp(&b.1.mean).unwrap());
            
            let fastest = evms[0];
            let fastest_time = fastest.1.mean;
            
            for (evm, result) in &evms {
                let bar_length = ((fastest_time / result.mean) * 20.0) as usize;
                let bar = "█".repeat(bar_length.min(20));
                
                if evm == &fastest.0 {
                    println!("      {} {}{} {:.2}x (fastest)",
                        format!("{:12}", evm).bright_green(),
                        bar.bright_green(),
                        " ".repeat(20 - bar_length),
                        1.00);
                } else {
                    let times_slower = result.mean / fastest_time;
                    println!("      {} {}{} {:.2}x slower than {}",
                        format!("{:12}", evm),
                        bar.bright_yellow(),
                        " ".repeat(20 - bar_length.min(20)),
                        times_slower,
                        fastest.0);
                }
            }
        }
    }
    
    println!("\n{}", "=".repeat(80).bright_blue());
    
    Ok(())
}