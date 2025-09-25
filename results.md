# EVM Benchmark Results

_Times shown are per-execution averages from 1 internal runs per benchmark._

| Benchmark                        | Guillotine (ms) | REVM (ms)   | ethrex (ms) | Guillotine-Rust (ms) | Geth (ms)   | Guillotine-Go (ms) | Guillotine-Bun (ms) | Guillotine-Python (ms) | Fastest           |
|----------------------------------|-----------------|-------------|-------------|----------------------|-------------|--------------------|---------------------|------------------------|-------------------|
|                      snailtracer |       29.50 |       34.16 |       39.59 |       30.20 |       71.22 |       33.23 |       48.56 |       93.16 |        Guillotine |
|                    erc20transfer |        1.38 |        1.49 |        1.90 |        1.70 |        3.84 |        3.56 |       19.77 |       64.28 |        Guillotine |
|                        erc20mint |        1.34 |        1.54 |        1.61 |        1.85 |        3.56 |        3.63 |       19.69 |       65.23 |        Guillotine |
|                    erc20approval |        1.81 |        1.99 |        2.44 |        2.14 |        3.52 |        4.45 |       20.22 |       66.14 |        Guillotine |
|              ten-thousand-hashes |        7.20 |        9.14 |       10.25 |        7.71 |        3.57 |        9.36 |       24.86 |       70.85 |              Geth |
|                       bubblesort |        9.24 |       11.30 |       11.13 |        8.76 |        3.63 |       10.87 |       26.12 |       73.07 |              Geth |
|                       arithmetic |        1.15 |        1.41 |        1.41 |        1.32 |        3.60 |        3.35 |       18.85 |       64.36 |        Guillotine |
|                          bitwise |        1.28 |        1.84 |        1.78 |        1.45 |        3.58 |        3.14 |       19.10 |       63.59 |        Guillotine |
|                        blockinfo |        1.10 |        1.33 |        1.50 |        1.26 |        3.86 |        3.01 |       18.29 |       63.96 |        Guillotine |
|                         calldata |        1.07 |        1.30 |        1.37 |        0.00 |        0.00 |        0.00 |        0.00 |        0.00 |        Guillotine |
|                         codecopy |        1.06 |        1.28 |        1.32 |        1.19 |        3.96 |        3.54 |       15.54 |       65.21 |        Guillotine |
|                       comparison |        1.19 |        1.58 |        1.56 |        1.46 |        3.56 |        3.04 |       19.02 |       63.11 |        Guillotine |
|                          context |        1.05 |        1.39 |        1.32 |        1.22 |        3.49 |        3.01 |       17.95 |       65.47 |        Guillotine |
|                    contractcalls |        1.07 |        1.43 |        1.48 |        0.00 |        0.00 |        0.00 |        0.00 |        0.00 |        Guillotine |
|                 contractcreation |        1.03 |        1.26 |        1.29 |        0.00 |        0.00 |        0.00 |        0.00 |        0.00 |        Guillotine |
|                      controlflow |        1.08 |        1.32 |        1.30 |        1.19 |        3.48 |        3.30 |       18.36 |       63.80 |        Guillotine |
|                     externalcode |        1.02 |        1.23 |        1.30 |        0.00 |        0.00 |        0.00 |        0.00 |        0.00 |        Guillotine |
|                        factorial |        1.10 |        1.55 |        1.40 |        1.28 |        3.47 |        2.86 |       17.38 |       63.39 |        Guillotine |
|              factorial-recursive |        1.13 |        1.35 |        1.39 |        1.36 |        3.87 |        3.44 |       18.87 |       63.39 |        Guillotine |
|                        fibonacci |        1.15 |        1.60 |        1.41 |        1.37 |        3.71 |        3.19 |       18.28 |       63.41 |        Guillotine |
|              fibonacci-recursive |        1.76 |        1.61 |        2.23 |        1.83 |        3.98 |        3.82 |       19.31 |       65.31 |              REVM |
|                          hashing |        1.27 |        1.47 |        1.57 |        1.45 |        3.61 |        3.07 |       18.54 |       63.31 |        Guillotine |
|                             logs |        1.31 |        1.30 |        1.47 |        0.00 |        0.00 |        0.00 |        0.00 |        0.00 |              REVM |
|                       manyhashes |        1.36 |        1.75 |        1.82 |        1.71 |        3.37 |        3.24 |       16.59 |       64.18 |        Guillotine |
|                           memory |        1.10 |        1.43 |        1.43 |        1.26 |        3.40 |        2.96 |       16.16 |       62.33 |        Guillotine |
|                modulararithmetic |        1.08 |        1.34 |        1.28 |        1.22 |        3.32 |        2.91 |       16.05 |       62.15 |        Guillotine |
|                           mstore |        1.34 |        1.79 |        1.87 |        0.00 |        0.00 |        0.00 |        0.00 |        0.00 |        Guillotine |
|                             push |        1.48 |        1.95 |        2.08 |        0.00 |        0.00 |        0.00 |        0.00 |        0.00 |        Guillotine |
|                       returndata |        1.15 |        1.32 |        1.33 |        0.00 |        0.00 |        0.00 |        0.00 |        0.00 |        Guillotine |
|                           shifts |        1.13 |        1.39 |        1.50 |        1.30 |        4.02 |        3.11 |       18.59 |       64.34 |        Guillotine |
|                 signedarithmetic |        1.31 |        1.77 |        1.78 |        1.40 |        3.48 |        3.22 |       18.99 |       64.00 |        Guillotine |
|                           sstore |        1.26 |        2.09 |        1.95 |        0.00 |        0.00 |        0.00 |        0.00 |        0.00 |        Guillotine |
|                          storage |        1.46 |        1.72 |        1.95 |        1.60 |        3.68 |        3.37 |       19.82 |       65.52 |        Guillotine |

## Summary

Average execution time per benchmark:
- Guillotine: 2.51ms
- REVM: 3.04ms
- ethrex: 3.30ms
- Guillotine Rust: 2.34ms
- Geth: 4.69ms
- Guillotine Go: 3.72ms
- Guillotine Bun: 14.69ms
- Guillotine Python: 47.99ms

## Known Issues

**Note:** Guillotine FFI implementations (Rust, Bun, Python, Go) have known bugs causing some benchmarks to fail (shown as 0.00ms).
These failures typically occur on benchmarks involving state modifications, memory operations, or complex call operations.
The native Guillotine (Zig) implementation does not have these issues.

---
*Generated by EVM Benchmark Suite*
