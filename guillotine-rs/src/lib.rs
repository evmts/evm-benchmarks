//! # guillotine-rs
//!
//! Safe Rust bindings for the Guillotine EVM - a high-performance Ethereum Virtual Machine
//! implementation written in Zig.

#![allow(non_upper_case_globals)]
#![allow(non_camel_case_types)]
#![allow(non_snake_case)]
#![allow(dead_code)]

pub mod executor;

use std::ffi::CStr;
use std::ptr;
use std::slice;
use std::sync::Once;

// Include the auto-generated bindings from bindgen
include!(concat!(env!("OUT_DIR"), "/bindings.rs"));

// Global FFI initialization
static INIT: Once = Once::new();

/// Initialize the FFI layer. This is called automatically when needed.
pub fn ensure_initialized() {
    INIT.call_once(|| {
        unsafe {
            guillotine_init();
        }
    });
}

/// Safe Rust wrapper for Guillotine EVM
pub struct Evm {
    handle: *mut EvmHandle,
}

impl Evm {
    /// Create a new Guillotine EVM instance with default block info
    pub fn new() -> Result<Self, String> {
        let block_info = BlockInfoFFI {
            number: 1,
            timestamp: 1000,
            gas_limit: 30_000_000,
            coinbase: [0; 20],
            base_fee: 1_000_000_000,
            chain_id: 1,
            difficulty: 0,
            prev_randao: [0; 32],
        };
        Self::with_block_info(block_info)
    }

    /// Create a new Guillotine EVM instance with custom block info
    pub fn with_block_info(block_info: BlockInfoFFI) -> Result<Self, String> {
        ensure_initialized();

        unsafe {
            let handle = guillotine_evm_create(&block_info);
            if handle.is_null() {
                let error = get_last_error();
                Err(format!("Failed to create Guillotine VM: {}", error))
            } else {
                Ok(Self { handle })
            }
        }
    }

    /// Set balance for an address
    pub fn set_balance(&mut self, address: [u8; 20], balance: [u8; 32]) -> Result<(), String> {
        unsafe {
            if guillotine_set_balance(self.handle, address.as_ptr(), balance.as_ptr()) {
                Ok(())
            } else {
                Err(get_last_error())
            }
        }
    }

    /// Set code for an address
    pub fn set_code(&mut self, address: [u8; 20], code: &[u8]) -> Result<(), String> {
        unsafe {
            if guillotine_set_code(self.handle, address.as_ptr(), code.as_ptr(), code.len()) {
                Ok(())
            } else {
                Err(get_last_error())
            }
        }
    }

    /// Execute a call
    pub fn execute(&mut self, params: &CallParams) -> Result<ExecutionResult, String> {
        unsafe {
            let result = guillotine_call(self.handle, params);

            if result.is_null() {
                return Err(get_last_error());
            }

            let exec_result = convert_result(&*result);
            guillotine_free_result(result);
            exec_result
        }
    }
}

impl Drop for Evm {
    fn drop(&mut self) {
        unsafe {
            guillotine_evm_destroy(self.handle);
        }
    }
}

unsafe impl Send for Evm {}
unsafe impl Sync for Evm {}

/// Result of executing a transaction on the EVM
#[derive(Debug, Clone)]
pub struct ExecutionResult {
    pub success: bool,
    pub gas_used: u64,
    pub gas_left: u64,
    pub output: Vec<u8>,
}

// Helper functions

fn get_last_error() -> String {
    unsafe {
        let error_ptr = guillotine_get_last_error();
        if error_ptr.is_null() {
            "Unknown error".to_string()
        } else {
            CStr::from_ptr(error_ptr).to_string_lossy().into_owned()
        }
    }
}

unsafe fn convert_result(result: &EvmResult) -> Result<ExecutionResult, String> {
    if !result.success && !result.error_message.is_null() {
        let error = CStr::from_ptr(result.error_message).to_string_lossy().into_owned();
        return Err(error);
    }

    let output = if result.output_len > 0 && !result.output.is_null() {
        slice::from_raw_parts(result.output, result.output_len).to_vec()
    } else {
        Vec::new()
    };

    Ok(ExecutionResult {
        success: result.success,
        gas_used: 0, // Will be calculated from gas_left
        gas_left: result.gas_left,
        output,
    })
}

/// Convert u256 to bytes (big-endian)
pub fn u256_to_bytes_be(value: u128) -> [u8; 32] {
    let mut bytes = [0u8; 32];
    // Put the value in the last 16 bytes (big-endian)
    bytes[16..].copy_from_slice(&value.to_be_bytes());
    bytes
}

/// Convert bytes to u256 (big-endian)
pub fn bytes_to_u256_be(bytes: &[u8; 32]) -> u128 {
    // Read from the last 16 bytes
    u128::from_be_bytes(bytes[16..].try_into().unwrap())
}