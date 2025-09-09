use anyhow::Result;
use foundry_compilers::{
    Project, ProjectPathsConfig,
};
use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;

pub struct ContractCompiler {
    project_root: PathBuf,
    contracts_dir: PathBuf,
    artifacts_dir: PathBuf,
}

impl ContractCompiler {
    pub fn new() -> Result<Self> {
        let project_root = std::env::current_dir()?;
        let contracts_dir = project_root.join("benchmarks");
        let artifacts_dir = project_root.join("target").join("contracts");
        
        // Create artifacts directory if it doesn't exist
        fs::create_dir_all(&artifacts_dir)?;
        
        Ok(Self {
            project_root,
            contracts_dir,
            artifacts_dir,
        })
    }
    
    pub fn compile_all(&self) -> Result<HashMap<String, CompiledContract>> {
        println!("Compiling Solidity contracts...");
        
        let mut compiled_contracts = HashMap::new();
        
        // Configure the project paths - include all subdirectories
        let paths = ProjectPathsConfig::builder()
            .root(&self.project_root)
            .sources(&self.contracts_dir)
            .artifacts(&self.artifacts_dir)
            .lib(self.project_root.join("lib"))
            .build()?;
        
        // Create and compile project with default settings
        let project = Project::builder()
            .paths(paths)
            .build(Default::default())?;
        
        // Compile the project
        println!("Running solc compiler...");
        let output = project.compile()?;
        
        // Check for errors and warnings
        if !output.output().errors.is_empty() {
            println!("Compilation messages:");
            for error in output.output().errors.iter() {
                println!("  {}", error);
            }
        }
        
        if output.has_compiler_errors() {
            anyhow::bail!("Compilation failed with errors");
        }
        
        // Extract compiled contracts using the artifacts
        println!("Processing compiled artifacts...");
        
        // Get all artifacts from the compilation output
        let artifacts = output.into_artifacts();
        
        for (artifact_id, artifact) in artifacts {
            let contract_name = artifact_id.name.clone();
            
            // Skip test contracts, interfaces, and libraries
            if contract_name.contains("Test") 
                || contract_name.contains("test")
                || contract_name.starts_with("I")
                || contract_name == "Context"
                || contract_name == "ERC20" {
                continue;
            }
            
            // Get deployed bytecode
            if let Some(deployed_bytecode) = artifact.deployed_bytecode {
                if let Some(bytecode_object) = deployed_bytecode.bytecode {
                    // BytecodeObject is an enum, we need to handle it properly
                    match bytecode_object.object {
                        foundry_compilers::artifacts::BytecodeObject::Bytecode(bytes) => {
                            let bytecode = hex::encode(bytes.as_ref());
                            
                            // Only store if bytecode is not empty
                            if !bytecode.is_empty() {
                                compiled_contracts.insert(
                                    contract_name.clone(),
                                    CompiledContract {
                                        name: contract_name.clone(),
                                        bytecode,
                                        path: artifact_id.source.to_string_lossy().to_string(),
                                    },
                                );
                                
                                println!("  ✓ Compiled {}", contract_name);
                            }
                        }
                        foundry_compilers::artifacts::BytecodeObject::Unlinked(s) => {
                            // Handle unlinked bytecode (libraries)
                            println!("  ⚠ {} has unlinked bytecode (library dependencies)", contract_name);
                        }
                    }
                }
            }
        }
        
        // Special handling for SnailTracer (legacy contract with pre-compiled bytecode)
        let snailtracer_hex_path = self.contracts_dir.join("snailtracer").join("snailtracer_runtime.hex");
        if snailtracer_hex_path.exists() {
            let bytecode = fs::read_to_string(&snailtracer_hex_path)?
                .trim()
                .trim_start_matches("0x")
                .to_string();
            
            if !bytecode.is_empty() {
                compiled_contracts.insert(
                    "SnailTracer".to_string(),
                    CompiledContract {
                        name: "SnailTracer".to_string(),
                        bytecode,
                        path: snailtracer_hex_path.to_string_lossy().to_string(),
                    },
                );
                
                println!("  ✓ Loaded SnailTracer (pre-compiled)");
            }
        }
        
        if compiled_contracts.is_empty() {
            anyhow::bail!("No contracts were compiled successfully. Make sure you have solc installed.");
        }
        
        println!("Compilation complete: {} contracts", compiled_contracts.len());
        Ok(compiled_contracts)
    }
    
    pub fn get_contract(&self, name: &str) -> Result<Option<CompiledContract>> {
        let contracts = self.compile_all()?;
        Ok(contracts.get(name).cloned())
    }
}

#[derive(Debug, Clone)]
pub struct CompiledContract {
    pub name: String,
    pub bytecode: String,
    pub path: String,
}