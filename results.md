# EVM Benchmark Results

_Times shown are per-execution averages from 1 internal runs per benchmark._

| Benchmark                        | Guillotine (ms) | REVM (ms)   | ethrex (ms) | Guillotine-Rust (ms) | Guillotine-Go (ms) | Guillotine-Bun (ms) | Guillotine-Python (ms) | Fastest           |
|----------------------------------|-----------------|-------------|-------------|----------------------|--------------------|---------------------|------------------------|-------------------|
|                      snailtracer |       29.61 |       34.28 |       39.78 |       30.31 |       32.19 |       47.07 |       92.32 |        Guillotine |
|                    erc20transfer |        1.44 |        1.61 |        1.78 |        1.66 |        3.54 |       19.29 |       64.13 |        Guillotine |
|                        erc20mint |        1.30 |        1.51 |        1.63 |        1.63 |        3.42 |       18.48 |       65.07 |        Guillotine |
|                    erc20approval |        1.72 |        2.19 |        2.46 |        2.10 |        4.23 |       20.28 |       70.00 |        Guillotine |
|              ten-thousand-hashes |        7.46 |        9.53 |       10.57 |        7.59 |        9.02 |       24.42 |       70.46 |        Guillotine |
|                       bubblesort |        9.30 |       10.87 |       10.94 |        8.80 |       11.49 |       26.76 |       72.52 |   Guillotine-Rust |
|                       arithmetic |        1.14 |        1.41 |        1.46 |        1.30 |        3.27 |       17.36 |       62.67 |        Guillotine |
|                          bitwise |        1.41 |        1.85 |        1.99 |        1.58 |        3.06 |       18.84 |       64.01 |        Guillotine |
|                        blockinfo |        1.12 |        1.38 |        1.32 |        1.26 |        3.33 |       18.90 |       64.70 |        Guillotine |
|                         calldata |        1.11 |        1.50 |        1.89 |        0.00 |        0.00 |        0.00 |        0.00 |        Guillotine |
|                         codecopy |        1.13 |        1.35 |        1.39 |        1.23 |        3.36 |       18.48 |       62.89 |        Guillotine |
|                       comparison |        1.22 |        1.60 |        1.74 |        1.53 |        3.75 |       18.73 |       65.37 |        Guillotine |
|                          context |        1.04 |        1.35 |        1.28 |        1.20 |        2.85 |       15.94 |       62.28 |        Guillotine |
|                    contractcalls |        1.06 |        1.25 |        1.27 |        0.00 |        0.00 |        0.00 |        0.00 |        Guillotine |
|                 contractcreation |        1.04 |        1.27 |        1.74 |        0.00 |        0.00 |        0.00 |        0.00 |        Guillotine |
|                      controlflow |        1.27 |        1.31 |        1.37 |        1.27 |        3.05 |       18.58 |       64.56 |   Guillotine-Rust |
|                     externalcode |        0.99 |        1.21 |        1.21 |        0.00 |        0.00 |        0.00 |        0.00 |        Guillotine |
|                        factorial |        1.21 |        1.53 |        1.45 |        1.44 |        3.24 |       18.48 |       65.41 |        Guillotine |
|              factorial-recursive |        1.09 |        1.34 |        1.35 |        1.24 |        3.09 |       17.72 |       65.57 |        Guillotine |
|                        fibonacci |        1.08 |        1.42 |        1.34 |        1.22 |        2.82 |       16.54 |       62.66 |        Guillotine |
|              fibonacci-recursive |        1.57 |        1.68 |        2.16 |        1.93 |        3.60 |       20.35 |       64.64 |        Guillotine |
|                          hashing |        1.14 |        1.52 |        1.43 |        1.32 |        3.16 |       18.83 |       63.41 |        Guillotine |
|                             logs |        1.06 |        1.33 |        1.50 |        0.00 |        0.00 |        0.00 |        0.00 |        Guillotine |
|                       manyhashes |        1.50 |        2.14 |        1.83 |        2.03 |        3.49 |       20.26 |       62.86 |        Guillotine |
|                           memory |        1.41 |        1.52 |        1.69 |        1.71 |        2.95 |       18.26 |       63.54 |        Guillotine |
|                modulararithmetic |        1.09 |        1.36 |        1.43 |        1.26 |        3.52 |       18.43 |       63.83 |        Guillotine |
|                           mstore |        1.45 |        2.15 |        1.92 |        0.00 |        0.00 |        0.00 |        0.00 |        Guillotine |
|                             push |        1.52 |        2.17 |        2.24 |        0.00 |        0.00 |        0.00 |        0.00 |        Guillotine |
|                       returndata |        1.07 |        1.23 |        1.28 |        0.00 |        0.00 |        0.00 |        0.00 |        Guillotine |
|                           shifts |        1.07 |        1.32 |        1.52 |        1.22 |        2.94 |       18.73 |       64.30 |        Guillotine |
|                 signedarithmetic |        1.21 |        1.53 |        1.52 |        1.44 |        3.07 |       18.29 |       63.78 |        Guillotine |
|                           sstore |        1.10 |        1.98 |        1.92 |        0.00 |        0.00 |        0.00 |        0.00 |        Guillotine |
|                          storage |        1.39 |        1.66 |        1.66 |        1.53 |        3.14 |       18.50 |       64.02 |        Guillotine |

## Summary

Average execution time per benchmark:
- Guillotine: 2.52ms
- REVM: 3.07ms
- ethrex: 3.34ms
- Guillotine Rust: 2.36ms
- Guillotine Go: 3.68ms
- Guillotine Bun: 14.77ms
- Guillotine Python: 48.03ms

## Known Issues

**Note:** Guillotine FFI implementations (Rust, Bun, Python, Go) have known bugs causing some benchmarks to fail (shown as 0.00ms).
These failures typically occur on benchmarks involving state modifications, memory operations, or complex call operations.
The native Guillotine (Zig) implementation does not have these issues.

---
*Generated by EVM Benchmark Suite*
