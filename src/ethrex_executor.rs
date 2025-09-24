use anyhow::Result;
use ethrex_common::{Address, U256, H256, Bytes};
use ethrex_levm::{
    Environment,
    db::gen_db::GeneralizedDatabase,
    errors::TxResult,
    tracing::LevmCallTracer,
    vm::{VM, VMType},
};
use ethrex_blockchain::vm::StoreVmDatabase;
use ethrex_storage::Store;
use ethrex_vm::DynVmDatabase;
use std::sync::Arc;
use std::collections::BTreeMap;
use crate::evm::{EvmResult, EvmExecutor};
use ethrex_common::types::{Account, EIP1559Transaction, Transaction, TxKind};

// Use constant addresses like in the reference
const SENDER_ADDRESS: u64 = 0x100;
const CONTRACT_ADDRESS: u64 = 0x42;

pub struct EthrexExecutor;

impl EthrexExecutor {
    pub fn new() -> Result<Self> {
        Ok(Self)
    }
}

impl EvmExecutor for EthrexExecutor {
    fn execute(
        &mut self,
        bytecode: Vec<u8>,
        calldata: Vec<u8>,
        gas_limit: u64,
    ) -> Result<EvmResult> {
        // Initialize database with bytecode like in the reference
        let bytecode_bytes = Bytes::from(bytecode);
        let calldata_bytes = Bytes::from(calldata);
        
        // Create in-memory store
        let in_memory_db = Store::new("", ethrex_storage::EngineType::InMemory)?;
        let store: DynVmDatabase = Box::new(StoreVmDatabase::new(in_memory_db, H256::zero()));
        
        // Set up initial accounts state with the contract and sender
        let cache = BTreeMap::from([
            (
                Address::from_low_u64_be(CONTRACT_ADDRESS),
                Account::new(U256::zero(), bytecode_bytes.clone(), 1, BTreeMap::new()),
            ),
            (
                Address::from_low_u64_be(SENDER_ADDRESS),
                Account::new(U256::from(1_000_000_000_000_000_000u128), Bytes::new(), 0, BTreeMap::new()),
            ),
        ]);
        
        let mut db = GeneralizedDatabase::new_with_account_state(Arc::new(store), cache);
        
        // Set up environment
        let env = Environment {
            origin: Address::from_low_u64_be(SENDER_ADDRESS),
            tx_nonce: 0,
            gas_limit,
            block_gas_limit: 30_000_000,
            ..Default::default()
        };
        
        // Create transaction
        let tx = Transaction::EIP1559Transaction(EIP1559Transaction {
            to: TxKind::Call(Address::from_low_u64_be(CONTRACT_ADDRESS)),
            data: calldata_bytes,
            ..Default::default()
        });
        
        // Create VM and execute
        let mut vm = VM::new(env, &mut db, &tx, LevmCallTracer::disabled(), VMType::L1)?;
        
        // Use stateless_execute like in the reference
        let tx_report = vm.stateless_execute()?;
        
        // Convert result to EvmResult
        match tx_report.result {
            TxResult::Success => {
                Ok(EvmResult {
                    success: true,
                    gas_used: tx_report.gas_used,
                    output: tx_report.output.to_vec(),
                    logs: tx_report.logs.iter().map(|log| format!("{:?}", log)).collect(),
                })
            }
            TxResult::Revert(_) => {
                Ok(EvmResult {
                    success: false,
                    gas_used: tx_report.gas_used,
                    output: tx_report.output.to_vec(),
                    logs: tx_report.logs.iter().map(|log| format!("{:?}", log)).collect(),
                })
            }
        }
    }
    
    fn name(&self) -> &str {
        "ethrex"
    }
}