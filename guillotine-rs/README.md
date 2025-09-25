# guillotine-rs

Rust bindings for the Guillotine EVM - a high-performance Ethereum Virtual Machine implementation written in Zig.

## Note

Guillotine doesn't currently have an official Rust SDK, but it can still be used via its C FFI interface. This package provides safe Rust bindings to the Guillotine C API exported from `evm_c_api.zig`.

## Architecture

This package uses the C FFI exported by Guillotine's `evm_c_api.zig` to provide:
- Safe Rust wrappers around the unsafe FFI calls
- An `EvmExecutor` implementation compatible with the benchmark suite
- Zero-copy operations where possible for optimal performance

## Building

The package requires the Guillotine library to be built first:

```bash
# Build Guillotine (from project root)
cd evms/guillotine
zig build

# Build this package
cd ../../guillotine-rs
cargo build --release
```

## Usage

```rust
use guillotine_rs::GuillotineExecutor;
use anyhow::Result;

fn main() -> Result<()> {
    let mut executor = GuillotineExecutor::new()?;

    // Execute some bytecode
    let result = executor.execute(
        bytecode,
        calldata,
        gas_limit
    )?;

    println!("Gas used: {}", result.gas_used);
    Ok(())
}
```

## Implementation Details

The bindings use:
- `bindgen` to generate FFI bindings from the C header
- Instance pooling in the Zig layer for performance
- Zero-copy interfaces where possible
- Safe wrappers to prevent memory leaks

## Performance

Guillotine is designed for high performance and includes:
- Instance pooling to avoid allocation overhead
- Efficient state management
- Optimized opcode dispatch
- Zero-copy FFI interface