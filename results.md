# EVM Benchmark Results

_Times shown are per-execution averages from 1 internal runs per benchmark._

| Benchmark                        | REVM (ms)   | ethrex (ms) | Guillotine (ms) | Guillotine-Rust (ms) | Guillotine-Bun (ms) | Guillotine-Python (ms) | Guillotine-Go (ms) | Geth (ms)   | Fastest           |
|----------------------------------|-------------|-------------|-----------------|----------------------|---------------------|------------------------|--------------------|-------------|------------------|
|                      snailtracer |       35.69 |       41.48 |       30.22 |       31.81 |       49.32 |       99.58 |       33.52 |       72.74 |        Guillotine |
|                    erc20transfer |        1.81 |        2.24 |        1.70 |        2.32 |       20.41 |       66.94 |        3.69 |        3.69 |        Guillotine |
|                        erc20mint |        1.82 |        1.83 |        1.32 |        1.93 |       17.05 |       63.05 |        3.21 |        3.36 |        Guillotine |
|                    erc20approval |        2.34 |        2.97 |        1.81 |        2.30 |       20.96 |       67.29 |        3.84 |        3.45 |        Guillotine |
|              ten-thousand-hashes |        9.22 |       10.40 |        7.34 |        7.58 |       24.97 |       71.71 |        9.84 |        3.79 |              Geth |
|                       bubblesort |       11.08 |       11.34 |        9.38 |        8.87 |       26.58 |       72.70 |       10.92 |        3.65 |              Geth |
|                       arithmetic |        1.52 |        1.45 |        1.10 |        1.27 |       16.24 |       63.27 |        2.90 |        3.32 |        Guillotine |
|                          bitwise |        1.97 |        1.91 |        1.32 |        1.56 |       19.34 |       67.80 |        3.29 |        3.64 |        Guillotine |
|                        blockinfo |        1.36 |        1.25 |        1.05 |        1.20 |       16.55 |       67.55 |        2.94 |        3.42 |        Guillotine |
|                         calldata |        1.34 |        1.38 |        1.09 |        0.00 |        0.00 |        0.00 |        0.00 |        0.00 |   Guillotine-Rust |
|                         codecopy |        1.33 |        1.54 |        1.05 |        1.19 |       18.05 |       66.45 |        3.02 |        3.65 |        Guillotine |
|                       comparison |        1.81 |        1.60 |        1.24 |        1.47 |       18.70 |       65.29 |        3.66 |        4.27 |        Guillotine |
|                          context |        1.45 |        1.57 |        1.21 |        1.34 |       19.01 |       68.27 |        3.33 |        3.96 |        Guillotine |
|                    contractcalls |        1.24 |        1.29 |        1.07 |        0.00 |        0.00 |        0.00 |        0.00 |        0.00 |   Guillotine-Rust |
|                 contractcreation |        1.31 |        1.28 |        1.13 |        0.00 |        0.00 |        0.00 |        0.00 |        0.00 |   Guillotine-Rust |
|                      controlflow |        1.63 |        1.69 |        1.16 |        1.26 |       18.83 |       66.33 |        3.10 |        3.81 |        Guillotine |
|                     externalcode |        1.23 |        1.34 |        1.06 |        0.00 |        0.00 |        0.00 |        0.00 |        0.00 |   Guillotine-Rust |
|                        factorial |        1.73 |        1.74 |        1.24 |        1.46 |       18.62 |       66.07 |        3.35 |        4.08 |        Guillotine |
|              factorial-recursive |        1.43 |        1.44 |        1.16 |        1.54 |       18.91 |       68.67 |        3.55 |        3.70 |        Guillotine |
|                        fibonacci |        1.77 |        1.44 |        1.23 |        1.59 |       18.03 |       67.53 |        3.26 |        4.03 |        Guillotine |
|              fibonacci-recursive |        1.61 |        1.95 |        1.45 |        1.76 |       17.54 |       63.89 |        3.54 |        3.33 |        Guillotine |
|                          hashing |        1.61 |        1.60 |        1.28 |        1.55 |       20.27 |       66.67 |        3.72 |        4.84 |        Guillotine |
|                             logs |        1.33 |        1.47 |        1.08 |        0.00 |        0.00 |        0.00 |        0.00 |        0.00 |   Guillotine-Rust |
|                       manyhashes |        1.81 |        1.99 |        1.63 |        1.64 |       19.59 |       65.94 |        3.39 |        3.84 |        Guillotine |
|                           memory |        1.63 |        1.74 |        1.43 |        1.36 |       19.17 |       65.64 |        3.35 |        4.22 |   Guillotine-Rust |
|                modulararithmetic |        1.37 |        1.51 |        1.08 |        1.25 |       18.86 |       65.84 |        3.09 |        3.86 |        Guillotine |
|                           mstore |        1.93 |        2.31 |        1.56 |        0.00 |        0.00 |        0.00 |        0.00 |        0.00 |   Guillotine-Rust |
|                             push |        2.30 |        2.15 |        1.55 |        0.00 |        0.00 |        0.00 |        0.00 |        0.00 |   Guillotine-Rust |
|                       returndata |        1.45 |        1.39 |        1.15 |        0.00 |        0.00 |        0.00 |        0.00 |        0.00 |   Guillotine-Rust |
|                           shifts |        1.36 |        1.33 |        1.07 |        1.21 |       15.76 |       62.83 |        2.93 |        3.53 |        Guillotine |
|                 signedarithmetic |        1.70 |        1.71 |        1.22 |        1.37 |       19.11 |       65.80 |        3.51 |        3.95 |        Guillotine |
|                           sstore |        2.10 |        2.07 |        1.33 |        0.00 |        0.00 |        0.00 |        0.00 |        0.00 |   Guillotine-Rust |
|                          storage |        1.57 |        1.64 |        1.28 |        1.42 |       16.89 |       66.87 |        3.50 |        3.60 |        Guillotine |

## Summary

Average execution time per benchmark:
- REVM: 3.18ms
- ethrex: 3.45ms
- Guillotine: 2.58ms
- Guillotine Rust: 2.43ms
- Guillotine Bun: 14.81ms
- Guillotine Python: 49.45ms
- Guillotine Go: 3.77ms
- Geth: 4.84ms

## Known Issues

**Note:** Guillotine FFI implementations (Rust, Bun, Python, Go) have known bugs causing some benchmarks to fail (shown as 0.00ms).
These failures typically occur on benchmarks involving state modifications, memory operations, or complex call operations.
The native Guillotine (Zig) implementation does not have these issues.

---
*Generated by EVM Benchmark Suite*
