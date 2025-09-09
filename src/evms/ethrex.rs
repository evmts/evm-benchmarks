use anyhow::{Result, anyhow, Context};
use crate::evm::{EvmResult, EvmExecutor};
use ethrex_common::{Address as EthrexAddress, H256, U256};
use ethrex_common::types::{Transaction, LegacyTransaction, TxKind, Account};
use ethrex_vm::DynVmDatabase;
use ethrex_blockchain::vm::StoreVmDatabase;
use ethrex_storage::Store;
use std::sync::Arc;
use std::collections::BTreeMap;

pub struct EthrexExecutor {
    contract_address: EthrexAddress,
    caller_address: EthrexAddress,
}

impl EthrexExecutor {
    pub fn new() -> Result<Self> {
        Ok(Self {
            contract_address: EthrexAddress::from([0x10; 20]),
            caller_address: EthrexAddress::from([0x01; 20]),
        })
    }
}

impl EvmExecutor for EthrexExecutor {
    fn execute(
        &mut self,
        bytecode: Vec<u8>,
        calldata: Vec<u8>,
        gas_limit: u64,
    ) -> Result<EvmResult> {
        use ethrex_vm::levm::{
            vm::{VM, VMType},
            Environment, 
            EVMConfig,
            tracing::LevmCallTracer,
            db::gen_db::GeneralizedDatabase,
        };

        // Create initial state with accounts
        let mut initial_state = BTreeMap::new();
        
        // Add caller account with balance
        initial_state.insert(
            self.caller_address,
            Account {
                balance: U256::from(1_000_000_000_000_000_000u128), // 1 ETH
                nonce: 0,
                code: vec![],
                storage: Default::default(),
            },
        );
        
        // Add contract account with bytecode
        initial_state.insert(
            self.contract_address,
            Account {
                balance: U256::ZERO,
                nonce: 1,
                code: bytecode.clone(),
                storage: Default::default(),
            },
        );

        // Create in-memory storage
        let in_memory_db = Store::new("", ethrex_storage::EngineType::InMemory)
            .map_err(|e| anyhow!("Failed to create in-memory store: {:?}", e))?;
        let store: DynVmDatabase = Box::new(StoreVmDatabase::new(in_memory_db, H256::zero()));
        let mut db = GeneralizedDatabase::new_with_account_state(Arc::new(store), initial_state);

        // Set up environment
        let env = Environment {
            origin: self.caller_address,
            gas_limit,
            gas_price: U256::from(1_000_000_000u128), // 1 gwei
            block_gas_limit: u64::MAX,
            config: EVMConfig::default(),
            coinbase: EthrexAddress::from([0x77; 20]),
            ..Default::default()
        };

        // Create transaction
        let tx = Transaction::LegacyTransaction(LegacyTransaction {
            nonce: 0,
            gas_price: 1_000_000_000, // 1 gwei
            gas: gas_limit,
            to: TxKind::Call(self.contract_address),
            value: U256::ZERO,
            data: calldata.into(),
            v: 27,
            r: U256::ZERO,
            s: U256::ZERO,
        });

        // Create and execute VM
        let mut vm = VM::new(
            env,
            &mut db,
            &tx,
            LevmCallTracer::disabled(),
            VMType::L1,
        ).map_err(|e| anyhow!("Failed to create VM: {:?}", e))?;

        let result = vm.execute()
            .map_err(|e| anyhow!("VM execution failed: {:?}", e))?;

        Ok(EvmResult {
            success: result.is_success(),
            gas_used: result.gas_used,
            output: result.output,
            logs: Vec::new(),
        })
    }
    
    fn name(&self) -> &str {
        "ethrex"
    }
}