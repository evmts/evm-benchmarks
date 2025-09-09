package benchmark

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

// RunEVMBenchmark runs a benchmark using the specified EVM implementation
func RunEVMBenchmark(
	bench *Benchmark,
	evmType EVMType,
	iterations int,
	useHyperfine bool,
	verbose bool,
) (*BenchmarkResult, error) {
	switch evmType {
	case EVMGuillotine:
		return runGuillotineBenchmark(bench, iterations, useHyperfine, verbose)
	case EVMRevm:
		return runRevmBenchmark(bench, iterations, useHyperfine, verbose)
	default:
		return runGethBenchmark(bench, iterations, useHyperfine, verbose)
	}
}

func runGethBenchmark(bench *Benchmark, iterations int, useHyperfine bool, verbose bool) (*BenchmarkResult, error) {
	gethBinary, err := FindGethBinary()
	if err != nil {
		return nil, fmt.Errorf("geth not found: %w", err)
	}
	
	// Find evm binary (usually alongside geth)
	evmBinary := strings.Replace(gethBinary, "/geth", "/evm", 1)
	if _, err := os.Stat(evmBinary); err != nil {
		return nil, fmt.Errorf("evm binary not found at %s", evmBinary)
	}
	
	// Create temp file for bytecode
	tempFile, err := os.CreateTemp("", "bytecode-*.hex")
	if err != nil {
		return nil, err
	}
	defer os.Remove(tempFile.Name())
	
	if _, err := tempFile.WriteString(bench.Bytecode); err != nil {
		return nil, err
	}
	tempFile.Close()
	
	if useHyperfine {
		// Build command for geth's evm
		evmCmd := []string{
			evmBinary,
			"run",
			"--codefile", tempFile.Name(),
			"--gas", fmt.Sprintf("%d", bench.Gas),
		}
		
		if bench.Calldata != "" {
			evmCmd = append(evmCmd, "--input", bench.Calldata)
		}
		
		// Use hyperfine for benchmarking
		resultsFile := fmt.Sprintf("results_%s.json", bench.Name)
		hyperfineCmd := []string{
			"hyperfine",
			"--runs", fmt.Sprintf("%d", iterations),
			"--warmup", "3",
			"--export-json", resultsFile,
			"--",
			strings.Join(evmCmd, " "),
		}
		
		if verbose {
			fmt.Printf("Running geth benchmark '%s' with hyperfine...\n", bench.Name)
			fmt.Printf("Command: %s\n", strings.Join(hyperfineCmd, " "))
		}
		
		cmd := exec.Command("hyperfine", hyperfineCmd[1:]...)
		output, err := cmd.CombinedOutput()
		
		if err != nil {
			return &BenchmarkResult{
				Name:  bench.Name,
				Tool:  "hyperfine",
				EVM:   "geth",
				Error: fmt.Sprintf("hyperfine failed: %s", string(output)),
			}, err
		}
		
		// Parse results
		if data, err := os.ReadFile(resultsFile); err == nil {
			var results HyperfineResult
			if err := json.Unmarshal(data, &results); err == nil {
				return &BenchmarkResult{
					Name:    bench.Name,
					Tool:    "hyperfine",
					EVM:     "geth",
					Results: &results,
				}, nil
			}
		}
		
		return &BenchmarkResult{
			Name:   bench.Name,
			Tool:   "hyperfine",
			EVM:    "geth",
			Output: string(output),
		}, nil
	}
	
	// Direct execution without hyperfine
	cmd := exec.Command(evmBinary, "run",
		"--codefile", tempFile.Name(),
		"--gas", fmt.Sprintf("%d", bench.Gas),
		"--input", bench.Calldata,
	)
	
	for i := 0; i < iterations; i++ {
		if err := cmd.Run(); err != nil {
			return nil, fmt.Errorf("evm execution failed: %w", err)
		}
	}
	
	return &BenchmarkResult{
		Name:   bench.Name,
		Tool:   "geth-evm",
		EVM:    "geth",
		Output: fmt.Sprintf("Completed %d iterations", iterations),
	}, nil
}

func runGuillotineBenchmark(bench *Benchmark, iterations int, useHyperfine bool, verbose bool) (*BenchmarkResult, error) {
	guillotineBinary, err := FindGuillotineBinary()
	if err != nil {
		return nil, fmt.Errorf("guillotine-bench not found: %w", err)
	}
	
	// Create temp file for bytecode
	tempFile, err := os.CreateTemp("", "bytecode-*.hex")
	if err != nil {
		return nil, err
	}
	defer os.Remove(tempFile.Name())
	
	if _, err := tempFile.WriteString(bench.Bytecode); err != nil {
		return nil, err
	}
	tempFile.Close()
	
	if useHyperfine {
		// Build command for guillotine-bench
		guillotineCmd := []string{
			guillotineBinary,
			"run",
			"--codefile", tempFile.Name(),
			"--gas", fmt.Sprintf("%d", bench.Gas),
		}
		
		if bench.Calldata != "" {
			guillotineCmd = append(guillotineCmd, "--input", bench.Calldata)
		}
		
		// Set environment to suppress debug output
		env := os.Environ()
		env = append(env, "GUILLOTINE_LOG_LEVEL=error", "ZIG_LOG_LEVEL=error")
		
		resultsFile := fmt.Sprintf("results_%s.json", bench.Name)
		hyperfineCmd := []string{
			"hyperfine",
			"--runs", fmt.Sprintf("%d", iterations),
			"--warmup", "3",
			"--export-json", resultsFile,
			"--",
			strings.Join(guillotineCmd, " "),
		}
		
		if verbose {
			fmt.Printf("Running Guillotine benchmark '%s' with hyperfine...\n", bench.Name)
			fmt.Printf("Command: %s\n", strings.Join(hyperfineCmd, " "))
		}
		
		cmd := exec.Command("hyperfine", hyperfineCmd[1:]...)
		cmd.Env = env
		output, err := cmd.CombinedOutput()
		
		if err != nil {
			return &BenchmarkResult{
				Name:  bench.Name,
				Tool:  "hyperfine",
				EVM:   "guillotine",
				Error: fmt.Sprintf("hyperfine failed: %s", string(output)),
			}, err
		}
		
		// Parse results
		if data, err := os.ReadFile(resultsFile); err == nil {
			var results HyperfineResult
			if err := json.Unmarshal(data, &results); err == nil {
				return &BenchmarkResult{
					Name:    bench.Name,
					Tool:    "hyperfine",
					EVM:     "guillotine",
					Results: &results,
				}, nil
			}
		}
		
		return &BenchmarkResult{
			Name:   bench.Name,
			Tool:   "hyperfine",
			EVM:    "guillotine",
			Output: string(output),
		}, nil
	}
	
	// Direct execution without hyperfine
	env := os.Environ()
	env = append(env, "GUILLOTINE_LOG_LEVEL=error", "ZIG_LOG_LEVEL=error")
	
	cmd := exec.Command(guillotineBinary, "run",
		"--codefile", tempFile.Name(),
		"--gas", fmt.Sprintf("%d", bench.Gas),
		"--input", bench.Calldata,
	)
	cmd.Env = env
	
	for i := 0; i < iterations; i++ {
		if err := cmd.Run(); err != nil {
			return nil, fmt.Errorf("guillotine execution failed: %w", err)
		}
	}
	
	return &BenchmarkResult{
		Name:   bench.Name,
		Tool:   "guillotine",
		EVM:    "guillotine",
		Output: fmt.Sprintf("Completed %d iterations", iterations),
	}, nil
}

func runRevmBenchmark(bench *Benchmark, iterations int, useHyperfine bool, verbose bool) (*BenchmarkResult, error) {
	revmBinary, err := FindRevmBinary()
	if err != nil {
		return nil, fmt.Errorf("revme not found: %w", err)
	}
	
	// Create temp file for bytecode
	tempFile, err := os.CreateTemp("", "bytecode-*.hex")
	if err != nil {
		return nil, err
	}
	defer os.Remove(tempFile.Name())
	
	if _, err := tempFile.WriteString(bench.Bytecode); err != nil {
		return nil, err
	}
	tempFile.Close()
	
	if useHyperfine {
		// Build command for revme
		revmeCmd := []string{
			revmBinary,
			"evm",
			"--path", tempFile.Name(),
			"--gas-limit", fmt.Sprintf("%d", bench.Gas),
		}
		
		if bench.Calldata != "" {
			revmeCmd = append(revmeCmd, "--input", bench.Calldata)
		}
		
		resultsFile := fmt.Sprintf("results_%s.json", bench.Name)
		hyperfineCmd := []string{
			"hyperfine",
			"--runs", fmt.Sprintf("%d", iterations),
			"--warmup", "3",
			"--export-json", resultsFile,
			"--",
			strings.Join(revmeCmd, " "),
		}
		
		if verbose {
			fmt.Printf("Running revm benchmark '%s' with hyperfine...\n", bench.Name)
			fmt.Printf("Command: %s\n", strings.Join(hyperfineCmd, " "))
		}
		
		cmd := exec.Command("hyperfine", hyperfineCmd[1:]...)
		output, err := cmd.CombinedOutput()
		
		if err != nil {
			return &BenchmarkResult{
				Name:  bench.Name,
				Tool:  "hyperfine",
				EVM:   "revm",
				Error: fmt.Sprintf("hyperfine failed: %s", string(output)),
			}, err
		}
		
		// Parse results
		if data, err := os.ReadFile(resultsFile); err == nil {
			var results HyperfineResult
			if err := json.Unmarshal(data, &results); err == nil {
				return &BenchmarkResult{
					Name:    bench.Name,
					Tool:    "hyperfine",
					EVM:     "revm",
					Results: &results,
				}, nil
			}
		}
		
		return &BenchmarkResult{
			Name:   bench.Name,
			Tool:   "hyperfine",
			EVM:    "revm",
			Output: string(output),
		}, nil
	}
	
	// Direct execution without hyperfine
	cmd := exec.Command(revmBinary, "evm",
		"--path", tempFile.Name(),
		"--gas-limit", fmt.Sprintf("%d", bench.Gas),
		"--input", bench.Calldata,
	)
	
	for i := 0; i < iterations; i++ {
		if err := cmd.Run(); err != nil {
			return nil, fmt.Errorf("revm execution failed: %w", err)
		}
	}
	
	return &BenchmarkResult{
		Name:   bench.Name,
		Tool:   "revm",
		EVM:    "revm",
		Output: fmt.Sprintf("Completed %d iterations", iterations),
	}, nil
}

// CheckHyperfine checks if hyperfine is installed
func CheckHyperfine() bool {
	_, err := exec.LookPath("hyperfine")
	return err == nil
}

// GetAvailableEVMs returns list of available EVM implementations
func GetAvailableEVMs() []EVMType {
	var evms []EVMType
	
	if _, err := FindGethBinary(); err == nil {
		// Also check for evm binary
		gethPath, _ := FindGethBinary()
		evmPath := strings.Replace(gethPath, "/geth", "/evm", 1)
		if _, err := os.Stat(evmPath); err == nil {
			evms = append(evms, EVMGeth)
		}
	}
	
	if _, err := FindGuillotineBinary(); err == nil {
		evms = append(evms, EVMGuillotine)
	}
	
	if _, err := FindRevmBinary(); err == nil {
		evms = append(evms, EVMRevm)
	}
	
	return evms
}