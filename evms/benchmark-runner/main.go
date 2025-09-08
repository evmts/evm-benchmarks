package main

import (
	"encoding/hex"
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/rawdb"
	"github.com/ethereum/go-ethereum/core/state"
	"github.com/ethereum/go-ethereum/core/tracing"
	"github.com/ethereum/go-ethereum/core/vm"
	"github.com/ethereum/go-ethereum/params"
	"github.com/ethereum/go-ethereum/triedb"
	"github.com/holiman/uint256"
)

type BenchmarkConfig struct {
	Name        string `json:"name"`
	Bytecode    string `json:"bytecode"`
	CallData    string `json:"calldata"`
	Gas         uint64 `json:"gas"`
	Iterations  int    `json:"iterations"`
}

type BenchmarkResult struct {
	Name       string        `json:"name"`
	Iterations int           `json:"iterations"`
	TotalTime  time.Duration `json:"total_time_ns"`
	AvgTime    time.Duration `json:"avg_time_ns"`
	GasUsed    uint64        `json:"gas_used"`
}

func main() {
	var configFile string
	var outputFile string
	var iterations int
	var bytecodeHex string
	var callDataHex string
	var gasLimit uint64

	flag.StringVar(&configFile, "config", "", "Path to benchmark config JSON file")
	flag.StringVar(&outputFile, "output", "", "Path to output results JSON file")
	flag.IntVar(&iterations, "iterations", 1, "Number of iterations to run")
	flag.StringVar(&bytecodeHex, "bytecode", "", "Contract bytecode in hex")
	flag.StringVar(&callDataHex, "calldata", "", "Call data in hex")
	flag.Uint64Var(&gasLimit, "gas", 30000000, "Gas limit for execution")
	flag.Parse()

	if configFile != "" {
		runFromConfig(configFile, outputFile)
	} else if bytecodeHex != "" {
		runSingleBenchmark(bytecodeHex, callDataHex, gasLimit, iterations)
	} else {
		fmt.Println("Usage: benchmark-runner [OPTIONS]")
		fmt.Println("Options:")
		flag.PrintDefaults()
		os.Exit(1)
	}
}

func runFromConfig(configFile, outputFile string) {
	data, err := ioutil.ReadFile(configFile)
	if err != nil {
		log.Fatalf("Failed to read config file: %v", err)
	}

	var configs []BenchmarkConfig
	if err := json.Unmarshal(data, &configs); err != nil {
		log.Fatalf("Failed to parse config: %v", err)
	}

	var results []BenchmarkResult
	for _, config := range configs {
		result := executeBenchmark(config.Bytecode, config.CallData, config.Gas, config.Iterations, config.Name)
		results = append(results, result)
		fmt.Printf("Benchmark %s: avg time = %v, gas used = %d\n", 
			config.Name, result.AvgTime, result.GasUsed)
	}

	if outputFile != "" {
		output, _ := json.MarshalIndent(results, "", "  ")
		if err := ioutil.WriteFile(outputFile, output, 0644); err != nil {
			log.Fatalf("Failed to write output: %v", err)
		}
	}
}

func runSingleBenchmark(bytecodeHex, callDataHex string, gasLimit uint64, iterations int) {
	result := executeBenchmark(bytecodeHex, callDataHex, gasLimit, iterations, "benchmark")
	fmt.Printf("Average execution time: %v\n", result.AvgTime)
	fmt.Printf("Gas used: %d\n", result.GasUsed)
}

func executeBenchmark(bytecodeHex, callDataHex string, gasLimit uint64, iterations int, name string) BenchmarkResult {
	bytecode, err := hex.DecodeString(bytecodeHex)
	if err != nil {
		log.Fatalf("Invalid bytecode hex: %v", err)
	}

	var callData []byte
	if callDataHex != "" {
		callData, err = hex.DecodeString(callDataHex)
		if err != nil {
			log.Fatalf("Invalid calldata hex: %v", err)
		}
	}

	// Setup EVM environment
	db := rawdb.NewMemoryDatabase()
	trieDB := triedb.NewDatabase(db, &triedb.Config{})
	statedb, _ := state.New(common.Hash{}, state.NewDatabase(trieDB, nil))
	
	// Create a dummy block context
	blockContext := vm.BlockContext{
		BlockNumber: uint256.NewInt(1),
		Time:        uint64(time.Now().Unix()),
		Difficulty:  uint256.NewInt(1),
		GasLimit:    gasLimit,
	}

	// Create transaction context
	origin := common.HexToAddress("0x1000000000000000000000000000000000000000")
	txContext := vm.TxContext{
		Origin:   origin,
		GasPrice: uint256.NewInt(1),
	}

	// Deploy contract
	contractAddr := common.HexToAddress("0x2000000000000000000000000000000000000000")
	statedb.SetCode(contractAddr, bytecode, tracing.CodeChangeReasonEVMCreate)

	// Create EVM instance
	config := params.AllEthashProtocolChanges
	vmConfig := vm.Config{}
	evm := vm.NewEVM(blockContext, statedb, config, vmConfig)
	evm.TxContext = txContext

	// Run benchmark
	var totalTime time.Duration
	var gasUsed uint64
	
	for i := 0; i < iterations; i++ {
		start := time.Now()
		
		ret, leftOverGas, err := evm.Call(
			vm.AccountRef(origin),
			contractAddr,
			callData,
			gasLimit,
			uint256.NewInt(0),
		)
		
		elapsed := time.Since(start)
		totalTime += elapsed
		
		if i == 0 {
			gasUsed = gasLimit - leftOverGas
			if err != nil {
				log.Printf("Warning: EVM execution error: %v", err)
			}
			_ = ret // Ignore return value
		}
		
		// Reset state for next iteration
		statedb.RevertToSnapshot(statedb.Snapshot())
	}

	avgTime := totalTime / time.Duration(iterations)
	
	return BenchmarkResult{
		Name:       name,
		Iterations: iterations,
		TotalTime:  totalTime,
		AvgTime:    avgTime,
		GasUsed:    gasUsed,
	}
}