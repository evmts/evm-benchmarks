package main

import (
	"encoding/hex"
	"flag"
	"fmt"
	"math/big"
	"os"
	"strings"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/rawdb"
	"github.com/ethereum/go-ethereum/core/state"
	"github.com/ethereum/go-ethereum/core/tracing"
	"github.com/ethereum/go-ethereum/core/vm"
	"github.com/ethereum/go-ethereum/params"
	"github.com/ethereum/go-ethereum/triedb"
	"github.com/holiman/uint256"
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
	var measureStartup bool

	flag.StringVar(&bytecodeHex, "bytecode", "", "Hex-encoded bytecode to execute")
	flag.StringVar(&calldataHex, "calldata", "", "Hex-encoded calldata")
	flag.Uint64Var(&gasLimit, "gas-limit", 30000000, "Gas limit for execution")
	flag.IntVar(&internalRuns, "internal-runs", 1, "Number of internal runs")
	flag.BoolVar(&measureStartup, "measure-startup", false, "Measure startup overhead only")
	flag.Parse()

	if bytecodeHex == "" {
		fmt.Fprintf(os.Stderr, "Error: --bytecode is required\n")
		os.Exit(1)
	}

	// Parse inputs
	bytecode, err := hexToBytes(bytecodeHex)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error parsing bytecode: %v\n", err)
		os.Exit(1)
	}

	var calldata []byte
	if calldataHex != "" {
		calldata, err = hexToBytes(calldataHex)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error parsing calldata: %v\n", err)
			os.Exit(1)
		}
	}

	// Set up addresses
	senderAddress := common.HexToAddress("0x0000000000000000000000000000000000000001")
	contractAddress := common.HexToAddress("0x0000000000000000000000000000000000000042")

	// Exit here if measuring startup overhead
	if measureStartup {
		os.Exit(0)
	}

	// Execute the call multiple times
	for i := 0; i < internalRuns; i++ {
		// Create a new state database for each run
		memDb := rawdb.NewMemoryDatabase()
		tdb := triedb.NewDatabase(memDb, nil)
		statedb, err := state.New(common.Hash{}, state.NewDatabase(tdb, nil))
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error creating state: %v\n", err)
			os.Exit(1)
		}

		// Set sender balance (100 ETH in wei)
		balance, _ := new(big.Int).SetString("100000000000000000000", 10)
		balanceU256 := new(uint256.Int)
		balanceU256.SetBytes(balance.Bytes())
		statedb.SetBalance(senderAddress, balanceU256, tracing.BalanceChangeUnspecified)

		// Set contract code
		statedb.SetCode(contractAddress, bytecode, tracing.CodeChangeUnspecified)

		// Create block context
		blockContext := vm.BlockContext{
			CanTransfer: func(db vm.StateDB, addr common.Address, amount *uint256.Int) bool {
				return db.GetBalance(addr).Cmp(amount) >= 0
			},
			Transfer: func(db vm.StateDB, sender, recipient common.Address, amount *uint256.Int) {
				db.SubBalance(sender, amount, tracing.BalanceChangeTransfer)
				db.AddBalance(recipient, amount, tracing.BalanceChangeTransfer)
			},
			GetHash: func(uint64) common.Hash {
				return common.Hash{}
			},
			Coinbase:    common.Address{},
			BlockNumber: big.NewInt(1),
			Time:        1,
			Difficulty:  big.NewInt(0),
			GasLimit:    gasLimit,
			BaseFee:     big.NewInt(1000000000),
		}

		// Create transaction context
		txContext := vm.TxContext{
			Origin:     senderAddress,
			GasPrice:   big.NewInt(1000000000),
			BlobFeeCap: big.NewInt(0),
		}

		// Create EVM instance
		config := params.MainnetChainConfig
		vmConfig := vm.Config{}
		evm := vm.NewEVM(blockContext, statedb, config, vmConfig)
		evm.SetTxContext(txContext)

		// Execute the contract call
		ret, gasLeft, err := evm.Call(
			senderAddress,
			contractAddress,
			calldata,
			gasLimit,
			uint256.NewInt(0),
		)

		// Determine success based on error
		success := err == nil

		// Calculate gas used
		gasUsed := gasLimit - gasLeft

		// Output for each run (matching other runner formats)
		fmt.Println(success)
		fmt.Println(gasUsed)

		// Debug: if failed, show why (only on first failure)
		if !success && i == 0 {
			fmt.Fprintf(os.Stderr, "Execution failed: %v\n", err)
			if len(ret) > 0 {
				fmt.Fprintf(os.Stderr, "Output: 0x%s\n", hex.EncodeToString(ret))
			}
		}
	}
}