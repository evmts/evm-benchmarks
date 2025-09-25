package main

import (
	"encoding/hex"
	"flag"
	"fmt"
	"math/big"
	"os"
	"strings"

	"github.com/evmts/guillotine/sdks/go/evm"
	"github.com/evmts/guillotine/sdks/go/primitives"
)

func hexToBytes(hexStr string) ([]byte, error) {
	// Remove 0x prefix if present
	hexStr = strings.TrimPrefix(hexStr, "0x")
	hexStr = strings.TrimPrefix(hexStr, "0X")
	return hex.DecodeString(hexStr)
}

func main() {
	// Parse command line arguments
	var bytecodeHex string
	var calldataHex string
	var gasLimit uint64
	var internalRuns int

	flag.StringVar(&bytecodeHex, "bytecode", "", "Hex-encoded bytecode to execute")
	flag.StringVar(&calldataHex, "calldata", "", "Hex-encoded calldata")
	flag.Uint64Var(&gasLimit, "gas-limit", 30000000, "Gas limit for execution")
	flag.IntVar(&internalRuns, "internal-runs", 1, "Number of internal runs")
	flag.Parse()

	if bytecodeHex == "" {
		os.Exit(1)
	}

	// Parse inputs
	bytecode, err := hexToBytes(bytecodeHex)
	if err != nil {
		os.Exit(1)
	}

	var calldata []byte
	if calldataHex != "" {
		calldata, err = hexToBytes(calldataHex)
		if err != nil {
			os.Exit(1)
		}
	}

	// Set up addresses
	senderAddress, _ := primitives.AddressFromHex("0x0000000000000000000000000000000000000001")
	contractAddress, _ := primitives.AddressFromHex("0x0000000000000000000000000000000000000042")

	// Execute the call multiple times
	for i := 0; i < internalRuns; i++ {
		// Create EVM instance inside loop for fresh state each run
		vm, err := evm.New()
		if err != nil {
			os.Exit(1)
		}

		// Set sender balance (100 ETH)
		balance := new(big.Int)
		balance.SetString("100000000000000000000", 10) // 100 ETH in wei
		err = vm.SetBalance(senderAddress, balance)
		if err != nil {
			os.Exit(1)
		}

		// Deploy contract code
		err = vm.SetCode(contractAddress, bytecode)
		if err != nil {
			os.Exit(1)
		}

		// Call the contract
		result, err := vm.Call(evm.Call{
			Caller: senderAddress,
			To:     contractAddress,
			Value:  big.NewInt(0),
			Input:  calldata,
			Gas:    gasLimit,
		})

		if err != nil {
			os.Exit(1)
		}

		// Calculate gas used
		gasUsed := gasLimit - result.GasLeft

		// Output for each run (matching Zig runner format)
		fmt.Println(result.Success)
		fmt.Println(gasUsed)
		
		// Clean up
		vm.Destroy()
	}
}