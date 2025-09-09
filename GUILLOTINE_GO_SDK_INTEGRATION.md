# Guillotine Go SDK Integration Status

## Current Status
- ✅ Guillotine Go SDK repository cloned with submodules
- ✅ Successfully built Guillotine Go SDK with dependencies (Rust, C-KZG-4844, etc.)
- ✅ Main Guillotine executable built at `evms/guillotine-go-sdk/zig-out/bin/Guillotine`
- ✅ Created bench_runner.zig template for benchmark execution

## Integration Approach

Guillotine Go SDK is a Zig-based EVM implementation with Go bindings that requires a different integration approach than geth:

1. **Go SDK Usage**: Unlike geth which has a standalone `evm` CLI tool, Guillotine Go SDK provides Go bindings to the Zig implementation
2. **Custom Runner Required**: We need to build a custom runner that:
   - Takes bytecode and calldata as command-line arguments
   - Initializes the Guillotine Go SDK EVM
   - Executes the bytecode
   - Returns execution time and gas usage

## Next Steps

To complete the integration:

1. **Build Custom Runner**:
   ```bash
   cd evms/guillotine-go-sdk
   # Add bench_runner.zig to build.zig
   zig build bench-runner
   ```

2. **Update Python CLI**:
   - Add `run_guillotine_benchmark()` function in `evm_benchmarks.py`
   - Add `--evm guillotine` option to CLI
   - Handle Guillotine Go SDK-specific execution flow

3. **Test Integration**:
   - Run existing benchmarks with Guillotine Go SDK
   - Compare results with geth

## Technical Notes

### Guillotine Go SDK EVM API Usage
```zig
// Initialize database
var db = evm.Database.init(allocator);

// Create transaction context
const tx_context = evm.TransactionContext{ ... };

// Initialize EVM
const evm_instance = try evm.Evm(.{}).init(allocator, db, tx_context);

// Execute
var result = try evm_instance.call(call_params);
```

### Build System
Guillotine Go SDK uses a sophisticated build system with:
- Rust dependencies (revm library)
- C dependencies (c-kzg-4844, blst)
- Multiple build configurations
- Module-based architecture

## Current Blockers

1. The bench_runner.zig needs to be properly integrated into Guillotine Go SDK's build system
2. The runner needs access to Guillotine Go SDK's modules (evm, primitives, crypto)
3. Alternative: Create a simpler FFI wrapper or use the existing executable differently

## Recommendation

For immediate benchmarking needs, continue using geth's evm tool. Guillotine Go SDK integration requires:
1. Deeper understanding of its module system
2. Proper build configuration
3. Potentially contributing a benchmark runner upstream to the Guillotine Go SDK project