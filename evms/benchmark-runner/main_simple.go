package main

import (
	"encoding/hex"
	"flag"
	"fmt"
	"log"
	"os"
	"os/exec"
	"strings"
	"time"
)

func main() {
	var iterations int
	var bytecodeFile string
	var evmBinary string

	flag.IntVar(&iterations, "iterations", 1, "Number of iterations to run")
	flag.StringVar(&bytecodeFile, "bytecode-file", "", "Path to file containing bytecode")
	flag.StringVar(&evmBinary, "evm", "evm", "Path to evm binary")
	flag.Parse()

	if bytecodeFile == "" {
		// Simple mode - just execute a command for benchmarking
		if len(flag.Args()) == 0 {
			fmt.Println("Usage: benchmark-runner [OPTIONS] -- command [args...]")
			fmt.Println("   or: benchmark-runner -bytecode-file FILE")
			flag.PrintDefaults()
			os.Exit(1)
		}

		runCommandBenchmark(flag.Args(), iterations)
	} else {
		runEVMBenchmark(evmBinary, bytecodeFile, iterations)
	}
}

func runCommandBenchmark(command []string, iterations int) {
	var totalTime time.Duration

	for i := 0; i < iterations; i++ {
		start := time.Now()
		
		cmd := exec.Command(command[0], command[1:]...)
		err := cmd.Run()
		
		elapsed := time.Since(start)
		totalTime += elapsed
		
		if err != nil {
			log.Printf("Warning: Command failed: %v", err)
		}
	}

	avgTime := totalTime / time.Duration(iterations)
	fmt.Printf("Average execution time: %v\n", avgTime)
	fmt.Printf("Total time: %v\n", totalTime)
	fmt.Printf("Iterations: %d\n", iterations)
}

func runEVMBenchmark(evmBinary, bytecodeFile string, iterations int) {
	// Read bytecode from file
	bytecodeHex, err := os.ReadFile(bytecodeFile)
	if err != nil {
		log.Fatalf("Failed to read bytecode file: %v", err)
	}

	// Clean up the bytecode
	bytecodeStr := strings.TrimSpace(string(bytecodeHex))
	bytecodeStr = strings.TrimPrefix(bytecodeStr, "0x")
	
	// Validate it's hex
	_, err = hex.DecodeString(bytecodeStr)
	if err != nil {
		log.Fatalf("Invalid bytecode hex: %v", err)
	}

	var totalTime time.Duration

	for i := 0; i < iterations; i++ {
		start := time.Now()
		
		// Use geth's evm binary to run the bytecode
		cmd := exec.Command(evmBinary, "run", "--code", bytecodeStr, "--gas", "30000000")
		output, err := cmd.CombinedOutput()
		
		elapsed := time.Since(start)
		totalTime += elapsed
		
		if err != nil {
			log.Printf("Warning: EVM execution failed: %v\nOutput: %s", err, output)
		}
		
		if i == 0 && len(output) > 0 {
			fmt.Printf("First run output:\n%s\n", output)
		}
	}

	avgTime := totalTime / time.Duration(iterations)
	fmt.Printf("Average execution time: %v\n", avgTime)
	fmt.Printf("Total time: %v\n", totalTime)
	fmt.Printf("Iterations: %d\n", iterations)
}