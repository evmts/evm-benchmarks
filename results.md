# EVM Benchmark Results

_Times shown are per-execution averages from 1 internal runs per benchmark._

| Benchmark                        | Guillotine (ms) | REVM (ms)   | ethrex (ms) | Guillotine-Rust (ms) | Geth (ms)   | Guillotine-Go (ms) | Guillotine-Bun (ms) | Guillotine-Python (ms) | Fastest           |
|----------------------------------|-----------------|-------------|-------------|----------------------|-------------|--------------------|---------------------|------------------------|-------------------|
|                      snailtracer |       29.65 |       34.13 |       40.09 |       30.13 |       71.78 |       32.17 |       47.65 |       93.49 |        Guillotine |
|                    erc20transfer |        1.39 |        1.53 |        1.64 |        1.65 |        3.62 |        3.47 |       18.36 |       63.86 |        Guillotine |
|                        erc20mint |        1.40 |        1.50 |        1.65 |        1.83 |        3.79 |        3.36 |       19.53 |       64.13 |        Guillotine |
|                    erc20approval |        1.70 |        2.00 |        2.40 |        2.34 |        3.56 |        3.98 |       19.16 |       64.95 |        Guillotine |
|              ten-thousand-hashes |        7.35 |        9.41 |       10.46 |        7.56 |        3.71 |        9.61 |       24.87 |       70.60 |              Geth |
|                       bubblesort |        9.47 |       10.95 |       11.34 |        9.14 |        3.59 |       10.49 |       26.96 |       72.31 |              Geth |
|                       arithmetic |        1.18 |        1.50 |        1.45 |        1.35 |        3.51 |        3.41 |       18.21 |       66.97 |        Guillotine |
|                          bitwise |        1.39 |        1.83 |        1.85 |        1.66 |        3.58 |        3.64 |       19.30 |       64.51 |        Guillotine |
|                        blockinfo |        1.23 |        1.57 |        1.50 |        1.45 |        3.63 |        3.18 |       18.14 |       64.44 |        Guillotine |
|                         calldata |        1.07 |        1.31 |        1.32 |        0.00 |        0.00 |        0.00 |        0.00 |        0.00 |        Guillotine |
|                         codecopy |        1.07 |        1.36 |        1.31 |        1.37 |        3.50 |        2.80 |       19.53 |       63.54 |        Guillotine |
|                       comparison |        1.15 |        1.52 |        1.55 |        1.29 |        3.86 |        3.24 |       19.68 |       64.06 |        Guillotine |
|                          context |        1.08 |        1.33 |        1.43 |        1.24 |        4.50 |        3.09 |       18.65 |       63.89 |        Guillotine |
|                    contractcalls |        1.16 |        1.44 |        1.43 |        0.00 |        0.00 |        0.00 |        0.00 |        0.00 |        Guillotine |
|                 contractcreation |        1.10 |        1.57 |        1.64 |        0.00 |        0.00 |        0.00 |        0.00 |        0.00 |        Guillotine |
|                      controlflow |        1.06 |        1.37 |        1.39 |        1.43 |        3.63 |        2.98 |       18.41 |       63.33 |        Guillotine |
|                     externalcode |        1.08 |        1.29 |        1.35 |        0.00 |        0.00 |        0.00 |        0.00 |        0.00 |        Guillotine |
|                        factorial |        1.13 |        1.90 |        1.59 |        1.29 |        3.84 |        3.12 |       18.82 |       65.19 |        Guillotine |
|              factorial-recursive |        1.07 |        1.43 |        1.33 |        1.33 |        3.24 |        2.96 |       15.55 |       62.30 |        Guillotine |
|                        fibonacci |        1.12 |        1.41 |        1.36 |        1.25 |        3.90 |        3.24 |       18.01 |       65.11 |        Guillotine |
|              fibonacci-recursive |        1.68 |        1.66 |        2.20 |        1.95 |        3.76 |        4.09 |       18.80 |       67.90 |              REVM |
|                          hashing |        1.31 |        1.39 |        1.40 |        1.28 |        3.73 |        3.25 |       18.46 |       64.98 |   Guillotine-Rust |
|                             logs |        1.18 |        1.39 |        1.59 |        0.00 |        0.00 |        0.00 |        0.00 |        0.00 |        Guillotine |
|                       manyhashes |        1.60 |        2.01 |        2.06 |        1.89 |        3.57 |        3.22 |       19.48 |       62.72 |        Guillotine |
|                           memory |        1.24 |        1.52 |        1.48 |        1.47 |        3.61 |        2.91 |       18.03 |       62.82 |        Guillotine |
|                modulararithmetic |        1.17 |        1.49 |        1.71 |        1.43 |        3.57 |        2.97 |       18.44 |       65.19 |        Guillotine |
|                           mstore |        1.60 |        2.19 |        1.96 |        0.00 |        0.00 |        0.00 |        0.00 |        0.00 |        Guillotine |
|                             push |        1.57 |        2.24 |        2.32 |        0.00 |        0.00 |        0.00 |        0.00 |        0.00 |        Guillotine |
|                       returndata |        1.19 |        1.53 |        1.48 |        0.00 |        0.00 |        0.00 |        0.00 |        0.00 |        Guillotine |
|                           shifts |        1.22 |        1.51 |        1.42 |        1.27 |        4.13 |        3.62 |       19.30 |       64.49 |        Guillotine |
|                 signedarithmetic |        1.21 |        1.44 |        1.45 |        1.30 |        3.56 |        3.58 |       18.99 |       63.77 |        Guillotine |
|                           sstore |        1.26 |        2.15 |        1.71 |        0.00 |        0.00 |        0.00 |        0.00 |        0.00 |        Guillotine |
|                          storage |        1.41 |        1.86 |        1.84 |        1.55 |        3.76 |        3.32 |       19.49 |       64.47 |        Guillotine |

## Summary

Average execution time per benchmark:
- Guillotine: 2.56ms
- REVM: 3.11ms
- ethrex: 3.35ms
- Guillotine Rust: 2.38ms
- Geth: 4.76ms
- Guillotine Go: 3.69ms
- Guillotine Bun: 14.90ms
- Guillotine Python: 48.15ms

## Known Issues

**Note:** Guillotine FFI implementations (Rust, Bun, Python, Go) have known bugs causing some benchmarks to fail (shown as 0.00ms).
These failures typically occur on benchmarks involving state modifications, memory operations, or complex call operations.
The native Guillotine (Zig) implementation does not have these issues.

---
*Generated by EVM Benchmark Suite*
