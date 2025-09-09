package benchmark

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// EVMType represents the type of EVM implementation
type EVMType string

const (
	EVMGeth       EVMType = "geth"
	EVMGuillotine EVMType = "guillotine"
	EVMRevm       EVMType = "revm"
)

// Benchmark represents a benchmark configuration
type Benchmark struct {
	Name        string  `json:"name"`
	Description string  `json:"description"`
	Category    string  `json:"category"`
	Type        string  `json:"type"`
	Bytecode    string  `json:"bytecode"`
	Calldata    string  `json:"calldata"`
	Gas         uint64  `json:"gas"`
	Requires    []string `json:"requires"`
}

// HyperfineResult represents the result from hyperfine
type HyperfineResult struct {
	Results []struct {
		Command string    `json:"command"`
		Mean    float64   `json:"mean"`
		Stddev  float64   `json:"stddev"`
		Median  float64   `json:"median"`
		User    float64   `json:"user"`
		System  float64   `json:"system"`
		Min     float64   `json:"min"`
		Max     float64   `json:"max"`
		Times   []float64 `json:"times"`
	} `json:"results"`
}

// BenchmarkResult represents the result of a benchmark run
type BenchmarkResult struct {
	Name    string           `json:"name"`
	Tool    string           `json:"tool"`
	EVM     string           `json:"evm"`
	Results *HyperfineResult `json:"results,omitempty"`
	Error   string           `json:"error,omitempty"`
	Output  string           `json:"output,omitempty"`
}

// GetContractBytecode reads compiled bytecode from Foundry artifacts
func GetContractBytecode(contractName string) (string, error) {
	outDir := "out"
	
	pattern := filepath.Join(outDir, "**", contractName+".json")
	matches, err := filepath.Glob(pattern)
	if err != nil {
		return "", err
	}
	
	// Also check subdirectories
	err = filepath.Walk(outDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if strings.HasSuffix(path, contractName+".json") {
			matches = append(matches, path)
		}
		return nil
	})
	
	for _, match := range matches {
		data, err := os.ReadFile(match)
		if err != nil {
			continue
		}
		
		var artifact map[string]interface{}
		if err := json.Unmarshal(data, &artifact); err != nil {
			continue
		}
		
		if deployedBytecode, ok := artifact["deployedBytecode"].(map[string]interface{}); ok {
			if object, ok := deployedBytecode["object"].(string); ok {
				if strings.HasPrefix(object, "0x") {
					return object[2:], nil
				}
				return object, nil
			}
		}
	}
	
	return "", fmt.Errorf("bytecode not found for contract %s", contractName)
}

// GetFunctionSelector returns the 4-byte function selector
func GetFunctionSelector(functionSignature string) string {
	// For now, return known selectors
	// In production, compute keccak256(signature)[:8]
	switch functionSignature {
	case "run()":
		return "30627b7c"
	case "Benchmark()":
		return "30627b7c"
	default:
		return ""
	}
}

// GetEVMBenchmarks returns all available EVM benchmarks
func GetEVMBenchmarks() map[string]*Benchmark {
	benchmarks := make(map[string]*Benchmark)
	
	// Check if geth is available
	if !isGethAvailable() {
		return benchmarks
	}
	
	// TenThousandHashes benchmark
	if bytecode, err := GetContractBytecode("TenThousandHashes"); err == nil {
		benchmarks["ten_thousand_hashes"] = &Benchmark{
			Name:        "ten_thousand_hashes",
			Description: "Execute 10,000 keccak256 hashes",
			Category:    "compute",
			Type:        "evm",
			Bytecode:    bytecode,
			Calldata:    GetFunctionSelector("run()"),
			Gas:         30000000,
		}
	}
	
	// ERC20 Transfer benchmark
	if bytecode, err := GetContractBytecode("ERC20Transfer"); err == nil {
		benchmarks["erc20_transfer_bench"] = &Benchmark{
			Name:        "erc20_transfer_bench",
			Description: "Benchmark ERC20 transfer operations",
			Category:    "token",
			Type:        "evm",
			Bytecode:    bytecode,
			Calldata:    GetFunctionSelector("run()"),
			Gas:         30000000,
		}
	}
	
	// ERC20 Mint benchmark
	if bytecode, err := GetContractBytecode("ERC20Mint"); err == nil {
		benchmarks["erc20_mint_bench"] = &Benchmark{
			Name:        "erc20_mint_bench",
			Description: "Benchmark ERC20 minting operations",
			Category:    "token",
			Type:        "evm",
			Bytecode:    bytecode,
			Calldata:    GetFunctionSelector("run()"),
			Gas:         30000000,
		}
	}
	
	// ERC20 Approval + Transfer benchmark
	if bytecode, err := GetContractBytecode("ERC20ApprovalTransfer"); err == nil {
		benchmarks["erc20_approval_bench"] = &Benchmark{
			Name:        "erc20_approval_bench",
			Description: "Benchmark ERC20 approval and transfer operations",
			Category:    "token",
			Type:        "evm",
			Bytecode:    bytecode,
			Calldata:    GetFunctionSelector("run()"),
			Gas:         30000000,
		}
	}
	
	// Snailtracer benchmark
	snailPath := filepath.Join("benchmarks", "snailtracer", "snailtracer_runtime.hex")
	if data, err := os.ReadFile(snailPath); err == nil {
		bytecode := strings.TrimSpace(string(data))
		if bytecode != "" {
			benchmarks["snailtracer"] = &Benchmark{
				Name:        "snailtracer",
				Description: "Ray tracing benchmark (compute intensive)",
				Category:    "compute",
				Type:        "evm",
				Bytecode:    bytecode,
				Calldata:    "30627b7c",
				Gas:         1000000000,
			}
		}
	}
	
	return benchmarks
}

func isGethAvailable() bool {
	// Check local geth
	localGeth := filepath.Join("evms", "go-ethereum", "build", "bin", "geth")
	if _, err := os.Stat(localGeth); err == nil {
		return true
	}
	
	// Check system geth
	if _, err := exec.LookPath("geth"); err == nil {
		return true
	}
	
	return false
}

// FindGethBinary finds the geth binary path
func FindGethBinary() (string, error) {
	// First try local geth
	localGeth := filepath.Join("evms", "go-ethereum", "build", "bin", "geth")
	if _, err := os.Stat(localGeth); err == nil {
		abs, _ := filepath.Abs(localGeth)
		return abs, nil
	}
	
	// Fall back to system geth
	if path, err := exec.LookPath("geth"); err == nil {
		return path, nil
	}
	
	return "", fmt.Errorf("geth not found")
}

// FindGuillotineBinary finds the Guillotine binary path
func FindGuillotineBinary() (string, error) {
	// Check for guillotine-bench in apps/cli
	guillotineBench := filepath.Join("apps", "cli", "guillotine-bench")
	if _, err := os.Stat(guillotineBench); err == nil {
		abs, _ := filepath.Abs(guillotineBench)
		return abs, nil
	}
	
	// Check in evms/guillotine-go-sdk
	builtGuillotine := filepath.Join("evms", "guillotine-go-sdk", "apps", "cli", "guillotine-bench")
	if _, err := os.Stat(builtGuillotine); err == nil {
		abs, _ := filepath.Abs(builtGuillotine)
		return abs, nil
	}
	
	return "", fmt.Errorf("guillotine-bench not found")
}

// FindRevmBinary finds the revm (revme) binary path
func FindRevmBinary() (string, error) {
	// Check for revme in release build
	revmeRelease := filepath.Join("revm", "target", "release", "revme")
	if _, err := os.Stat(revmeRelease); err == nil {
		abs, _ := filepath.Abs(revmeRelease)
		return abs, nil
	}
	
	// Check in evms directory
	evmsRevmeRelease := filepath.Join("evms", "revm", "target", "release", "revme")
	if _, err := os.Stat(evmsRevmeRelease); err == nil {
		abs, _ := filepath.Abs(evmsRevmeRelease)
		return abs, nil
	}
	
	// Check debug builds
	revmeDebug := filepath.Join("revm", "target", "debug", "revme")
	if _, err := os.Stat(revmeDebug); err == nil {
		abs, _ := filepath.Abs(revmeDebug)
		return abs, nil
	}
	
	evmsRevmeDebug := filepath.Join("evms", "revm", "target", "debug", "revme")
	if _, err := os.Stat(evmsRevmeDebug); err == nil {
		abs, _ := filepath.Abs(evmsRevmeDebug)
		return abs, nil
	}
	
	// Check system revme
	if path, err := exec.LookPath("revme"); err == nil {
		return path, nil
	}
	
	return "", fmt.Errorf("revme not found")
}