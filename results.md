# EVM Benchmark Results

_Times shown are per-execution averages from 1 internal runs per benchmark._

| Benchmark                        | REVM (ms)   | ethrex (ms) | Guillotine (ms) | Guillotine-Rust (ms) | Guillotine-Bun (ms) | Guillotine-Python (ms) | Guillotine-Go (ms) | Fastest           |
|----------------------------------|-------------|-------------|-----------------|----------------------|---------------------|------------------------|--------------------|-----------------|
|                      snailtracer |       34.53 |       39.97 |       29.98 |       30.55 |       48.48 |       93.26 |       32.55 |        Guillotine |
|                    erc20transfer |        1.79 |        1.67 |        1.41 |        1.64 |       19.88 |       62.93 |        3.33 |        Guillotine |
|                        erc20mint |        1.48 |        1.61 |        1.30 |        1.59 |       16.75 |       61.89 |        3.08 |        Guillotine |
|                    erc20approval |        2.06 |        2.60 |        1.74 |        1.87 |       19.68 |       65.71 |        4.08 |        Guillotine |
|              ten-thousand-hashes |        9.24 |       10.31 |        7.20 |        7.54 |       25.47 |       68.48 |        9.38 |        Guillotine |
|                       bubblesort |       10.49 |       10.50 |        9.86 |        9.66 |       23.06 |       68.94 |        9.92 |   Guillotine-Rust |
|                       arithmetic |        1.55 |        1.46 |        1.27 |        1.29 |       15.77 |       63.85 |        3.04 |        Guillotine |
|                          bitwise |        1.80 |        1.86 |        1.22 |        1.41 |       19.99 |       63.04 |        3.49 |        Guillotine |
|                        blockinfo |        1.33 |        1.36 |        1.13 |        1.34 |       18.58 |       63.63 |        3.31 |        Guillotine |
|                         calldata |        1.41 |        1.37 |        1.09 |        0.00 |        0.00 |        0.00 |        0.00 |   Guillotine-Rust |
|                         codecopy |        1.37 |        1.58 |        1.16 |        1.25 |       18.72 |       63.93 |        2.94 |        Guillotine |
|                       comparison |        1.69 |        1.74 |        1.23 |        1.34 |       18.71 |       64.01 |        2.98 |        Guillotine |
|                          context |        1.47 |        1.40 |        1.07 |        1.25 |       18.65 |       64.46 |        3.61 |        Guillotine |
|                    contractcalls |        1.32 |        1.33 |        1.16 |        0.00 |        0.00 |        0.00 |        0.00 |   Guillotine-Rust |
|                 contractcreation |        1.41 |        1.35 |        1.34 |        0.00 |        0.00 |        0.00 |        0.00 |   Guillotine-Rust |
|                      controlflow |        1.39 |        1.36 |        1.08 |        1.26 |       18.07 |       64.90 |        2.95 |        Guillotine |
|                     externalcode |        1.43 |        1.29 |        1.14 |        0.00 |        0.00 |        0.00 |        0.00 |   Guillotine-Rust |
|                        factorial |        1.36 |        1.40 |        1.14 |        1.48 |       19.52 |       65.09 |        3.54 |        Guillotine |
|              factorial-recursive |        1.33 |        1.48 |        1.10 |        1.66 |       18.55 |       63.99 |        3.29 |        Guillotine |
|                        fibonacci |        1.43 |        1.42 |        1.15 |        1.31 |       19.05 |       62.31 |        3.04 |        Guillotine |
|              fibonacci-recursive |        1.56 |        1.93 |        1.50 |        1.77 |       15.69 |       62.16 |        3.98 |        Guillotine |
|                          hashing |        1.67 |        1.44 |        1.24 |        1.33 |       18.33 |       64.25 |        3.04 |        Guillotine |
|                             logs |        1.56 |        1.52 |        1.19 |        0.00 |        0.00 |        0.00 |        0.00 |   Guillotine-Rust |
|                       manyhashes |        1.85 |        1.92 |        1.55 |        1.91 |       18.51 |       65.83 |        3.45 |        Guillotine |
|                           memory |        1.45 |        1.48 |        1.16 |        1.58 |       19.03 |       63.38 |        3.05 |        Guillotine |
|                modulararithmetic |        1.55 |        1.51 |        1.13 |        1.41 |       18.09 |       68.77 |        3.71 |        Guillotine |
|                           mstore |        1.78 |        1.89 |        1.36 |        0.00 |        0.00 |        0.00 |        0.00 |   Guillotine-Rust |
|                             push |        1.96 |        2.15 |        1.50 |        0.00 |        0.00 |        0.00 |        0.00 |   Guillotine-Rust |
|                       returndata |        1.36 |        1.33 |        1.09 |        0.00 |        0.00 |        0.00 |        0.00 |   Guillotine-Rust |
|                           shifts |        1.51 |        1.57 |        1.24 |        1.39 |       18.29 |       63.97 |        2.86 |        Guillotine |
|                 signedarithmetic |        1.50 |        1.62 |        1.19 |        1.33 |       18.45 |       64.05 |        2.96 |        Guillotine |
|                           sstore |        1.94 |        1.61 |        1.09 |        0.00 |        0.00 |        0.00 |        0.00 |   Guillotine-Rust |
|                          storage |        1.57 |        1.80 |        1.28 |        1.47 |       15.90 |       61.44 |        3.04 |        Guillotine |

## Summary

Average execution time per benchmark:
- REVM: 3.06ms
- ethrex: 3.30ms
- Guillotine: 2.55ms
- Guillotine Rust: 2.38ms
- Guillotine Bun: 14.58ms
- Guillotine Python: 47.70ms
- Guillotine Go: 3.66ms

---
*Generated by EVM Benchmark Suite*
