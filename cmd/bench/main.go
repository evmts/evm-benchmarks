package main

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/urfave/cli/v2"
	"github.com/williamcory/bench/internal/benchmark"
	"github.com/williamcory/bench/internal/tui"
)

var (
	version = "0.1.0"
)

func main() {
	app := &cli.App{
		Name:    "bench",
		Usage:   "EVM Benchmark Runner - Run and analyze EVM performance benchmarks",
		Version: version,
		Commands: []*cli.Command{
			runCommand(),
			listCommand(),
			compareCommand(),
			configCommand(),
		},
		Action: func(c *cli.Context) error {
			// Default action - show help
			return cli.ShowAppHelp(c)
		},
	}

	if err := app.Run(os.Args); err != nil {
		log.Fatal(err)
	}
}

func runCommand() *cli.Command {
	return &cli.Command{
		Name:  "run",
		Usage: "Run benchmarks",
		Flags: []cli.Flag{
			&cli.BoolFlag{
				Name:    "verbose",
				Aliases: []string{"v"},
				Usage:   "Enable verbose output",
			},
			&cli.IntFlag{
				Name:    "iterations",
				Aliases: []string{"i"},
				Usage:   "Number of iterations",
				Value:   10,
			},
			&cli.IntFlag{
				Name:    "warmup",
				Aliases: []string{"w"},
				Usage:   "Number of warmup runs",
				Value:   3,
			},
			&cli.StringFlag{
				Name:    "output",
				Aliases: []string{"o"},
				Usage:   "Output file for results (JSON format)",
			},
			&cli.StringFlag{
				Name:  "export-json",
				Usage: "Export raw hyperfine results to JSON file",
			},
			&cli.StringFlag{
				Name:  "export-markdown",
				Usage: "Export results to Markdown file",
			},
			&cli.IntFlag{
				Name:  "timeout",
				Usage: "Timeout in seconds for each benchmark",
			},
			&cli.StringFlag{
				Name:  "evm",
				Usage: "Single EVM implementation to use (geth, guillotine, revm)",
			},
			&cli.StringFlag{
				Name:  "evms",
				Usage: "Comma-separated list of EVM implementations (e.g., geth,guillotine)",
			},
			&cli.BoolFlag{
				Name:  "all",
				Usage: "Run all available EVM implementations",
			},
			&cli.BoolFlag{
				Name:  "no-tui",
				Usage: "Disable interactive TUI mode",
			},
		},
		ArgsUsage: "[benchmark]",
		Action:    runAction,
	}
}

func runAction(c *cli.Context) error {
	// Check if hyperfine is installed
	if !benchmark.CheckHyperfine() {
		printHyperfineInstructions()
		return fmt.Errorf("hyperfine not installed")
	}

	// Get benchmarks
	benchmarks := benchmark.GetEVMBenchmarks()
	if len(benchmarks) == 0 {
		return fmt.Errorf("no benchmarks available")
	}

	// Filter by specific benchmark if provided
	benchmarkName := c.Args().First()
	if benchmarkName != "" {
		if b, ok := benchmarks[benchmarkName]; ok {
			benchmarks = map[string]*benchmark.Benchmark{
				benchmarkName: b,
			}
		} else {
			return fmt.Errorf("unknown benchmark: %s", benchmarkName)
		}
	}

	// Determine which EVMs to run
	var evmsToRun []benchmark.EVMType
	if c.Bool("all") {
		evmsToRun = benchmark.GetAvailableEVMs()
	} else if evmsList := c.String("evms"); evmsList != "" {
		for _, evm := range strings.Split(evmsList, ",") {
			switch strings.TrimSpace(evm) {
			case "geth":
				evmsToRun = append(evmsToRun, benchmark.EVMGeth)
			case "guillotine":
				evmsToRun = append(evmsToRun, benchmark.EVMGuillotine)
			case "revm":
				evmsToRun = append(evmsToRun, benchmark.EVMRevm)
			default:
				return fmt.Errorf("unknown EVM: %s", evm)
			}
		}
	} else if evm := c.String("evm"); evm != "" {
		switch evm {
		case "geth":
			evmsToRun = []benchmark.EVMType{benchmark.EVMGeth}
		case "guillotine":
			evmsToRun = []benchmark.EVMType{benchmark.EVMGuillotine}
		case "revm":
			evmsToRun = []benchmark.EVMType{benchmark.EVMRevm}
		default:
			return fmt.Errorf("unknown EVM: %s", evm)
		}
	} else {
		// Default to geth
		evmsToRun = []benchmark.EVMType{benchmark.EVMGeth}
	}

	if len(evmsToRun) == 0 {
		return fmt.Errorf("no EVM implementations available")
	}

	iterations := c.Int("iterations")
	useTUI := !c.Bool("no-tui")
	verbose := c.Bool("verbose")
	output := c.String("output")

	// Run matrix if multiple EVMs
	if len(evmsToRun) > 1 {
		return runMatrixBenchmark(benchmarks, evmsToRun, iterations, verbose, output)
	}

	// Single EVM - use TUI or direct mode
	evmType := evmsToRun[0]
	
	if useTUI && os.Getenv("TERM") != "" {
		// Run in TUI mode only if terminal is available
		model := tui.NewModel(benchmarks, evmType, iterations)
		p := tea.NewProgram(model, tea.WithAltScreen())
		
		if _, err := p.Run(); err != nil {
			// Fall back to direct mode if TUI fails
			return runDirectBenchmark(benchmarks, evmType, iterations, verbose, output)
		}
	} else {
		// Run in direct mode
		return runDirectBenchmark(benchmarks, evmType, iterations, verbose, output)
	}

	return nil
}

func runDirectBenchmark(benchmarks map[string]*benchmark.Benchmark, evmType benchmark.EVMType, iterations int, verbose bool, output string) error {
	fmt.Printf("Running %d benchmark(s) on %s\n\n", len(benchmarks), evmType)

	results := make(map[string]*benchmark.BenchmarkResult)

	for name, bench := range benchmarks {
		fmt.Printf("Running %s: %s\n", name, bench.Description)
		
		result, err := benchmark.RunEVMBenchmark(bench, evmType, iterations, true, verbose)
		if err != nil {
			fmt.Printf("  ✗ Failed: %v\n", err)
			continue
		}

		results[name] = result
		
		if result.Results != nil && len(result.Results.Results) > 0 {
			r := result.Results.Results[0]
			fmt.Printf("  ✓ Mean: %.3fs ± %.3fs\n", r.Mean, r.Stddev)
		}
	}

	// Save results if output specified
	if output != "" {
		data, err := json.MarshalIndent(results, "", "  ")
		if err != nil {
			return fmt.Errorf("failed to marshal results: %w", err)
		}
		if err := os.WriteFile(output, data, 0644); err != nil {
			return fmt.Errorf("failed to write output: %w", err)
		}
		fmt.Printf("\nResults saved to: %s\n", output)
	}

	return nil
}

func runMatrixBenchmark(benchmarks map[string]*benchmark.Benchmark, evms []benchmark.EVMType, iterations int, verbose bool, output string) error {
	headerStyle := lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("39"))
	fmt.Println(headerStyle.Render("EVM BENCHMARK MATRIX"))
	fmt.Printf("Running %d benchmark(s) on %d EVM(s)\n\n", len(benchmarks), len(evms))

	matrixResults := make(map[benchmark.EVMType]map[string]*benchmark.BenchmarkResult)

	for _, evmType := range evms {
		fmt.Printf("\n%s Testing EVM: %s %s\n", strings.Repeat("=", 30), evmType, strings.Repeat("=", 30))
		
		evmResults := make(map[string]*benchmark.BenchmarkResult)
		
		for name, bench := range benchmarks {
			fmt.Printf("  Running %s...", name)
			
			result, err := benchmark.RunEVMBenchmark(bench, evmType, iterations, true, verbose)
			if err != nil {
				fmt.Printf(" ✗ Failed: %v\n", err)
				result = &benchmark.BenchmarkResult{
					Name:  name,
					EVM:   string(evmType),
					Error: err.Error(),
				}
			} else {
				fmt.Printf(" ✓ Complete\n")
			}
			
			evmResults[name] = result
		}
		
		matrixResults[evmType] = evmResults
	}

	// Print matrix summary
	printMatrixSummary(matrixResults, benchmarks)

	// Save results if output specified
	if output != "" {
		data, err := json.MarshalIndent(matrixResults, "", "  ")
		if err != nil {
			return fmt.Errorf("failed to marshal results: %w", err)
		}
		if err := os.WriteFile(output, data, 0644); err != nil {
			return fmt.Errorf("failed to write output: %w", err)
		}
		fmt.Printf("\nMatrix results saved to: %s\n", output)
	}

	return nil
}

func printMatrixSummary(results map[benchmark.EVMType]map[string]*benchmark.BenchmarkResult, benchmarks map[string]*benchmark.Benchmark) {
	fmt.Printf("\n%s\n", strings.Repeat("=", 80))
	fmt.Println("                           BENCHMARK MATRIX SUMMARY")
	fmt.Printf("%s\n\n", strings.Repeat("=", 80))

	// Print header
	fmt.Printf("%-30s", "Benchmark")
	for evm := range results {
		fmt.Printf("%-20s", strings.ToUpper(string(evm)))
	}
	fmt.Println()
	fmt.Println(strings.Repeat("-", 78))

	// Print each benchmark row
	for name := range benchmarks {
		fmt.Printf("%-30s", name)
		
		for _, evmResults := range results {
			if result, ok := evmResults[name]; ok {
				if result.Error != "" {
					fmt.Printf("%-20s", "FAILED")
				} else if result.Results != nil && len(result.Results.Results) > 0 {
					mean := result.Results.Results[0].Mean
					timeStr := formatTime(mean)
					fmt.Printf("%-20s", timeStr)
				} else {
					fmt.Printf("%-20s", "NO DATA")
				}
			} else {
				fmt.Printf("%-20s", "SKIPPED")
			}
		}
		fmt.Println()
	}

	fmt.Printf("\n%s\n", strings.Repeat("=", 80))
}

func formatTime(seconds float64) string {
	if seconds < 0.001 {
		return fmt.Sprintf("%.2f μs", seconds*1000000)
	} else if seconds < 1 {
		return fmt.Sprintf("%.2f ms", seconds*1000)
	}
	return fmt.Sprintf("%.2f s", seconds)
}

func listCommand() *cli.Command {
	return &cli.Command{
		Name:  "list",
		Usage: "List available benchmarks",
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:  "category",
				Usage: "Filter by category",
			},
		},
		Action: listAction,
	}
}

func listAction(c *cli.Context) error {
	benchmarks := benchmark.GetEVMBenchmarks()
	
	if len(benchmarks) == 0 {
		fmt.Println("No benchmarks available")
		return nil
	}

	category := c.String("category")
	
	// Group by category
	categories := make(map[string][]*benchmark.Benchmark)
	for _, b := range benchmarks {
		if category != "" && b.Category != category {
			continue
		}
		categories[b.Category] = append(categories[b.Category], b)
	}

	if len(categories) == 0 {
		fmt.Printf("No benchmarks found for category: %s\n", category)
		return nil
	}

	fmt.Println("\n📊 Available Benchmarks:\n")
	
	for cat, benches := range categories {
		fmt.Printf("  [%s]\n", strings.ToUpper(cat))
		for _, b := range benches {
			fmt.Printf("    • %s: %s\n", b.Name, b.Description)
		}
		fmt.Println()
	}

	// Show available EVMs
	evms := benchmark.GetAvailableEVMs()
	if len(evms) > 0 {
		fmt.Println("  [AVAILABLE EVMS]")
		for _, evm := range evms {
			fmt.Printf("    • %s\n", evm)
		}
		fmt.Println()
	}

	return nil
}

func compareCommand() *cli.Command {
	return &cli.Command{
		Name:  "compare",
		Usage: "Compare different EVM implementations",
		Flags: []cli.Flag{
			&cli.BoolFlag{
				Name:    "verbose",
				Aliases: []string{"v"},
				Usage:   "Enable verbose output",
			},
			&cli.StringFlag{
				Name:    "benchmark",
				Aliases: []string{"b"},
				Usage:   "Specific benchmark to use for comparison",
			},
			&cli.IntFlag{
				Name:    "iterations",
				Aliases: []string{"i"},
				Usage:   "Number of iterations",
				Value:   10,
			},
			&cli.StringFlag{
				Name:    "output",
				Aliases: []string{"o"},
				Usage:   "Output file for comparison results",
			},
		},
		ArgsUsage: "<implementations...>",
		Action:    compareAction,
	}
}

func compareAction(c *cli.Context) error {
	if c.NArg() < 2 {
		return fmt.Errorf("please specify at least 2 EVM implementations to compare")
	}

	// Parse EVM implementations
	var evms []benchmark.EVMType
	for i := 0; i < c.NArg(); i++ {
		switch c.Args().Get(i) {
		case "geth":
			evms = append(evms, benchmark.EVMGeth)
		case "guillotine":
			evms = append(evms, benchmark.EVMGuillotine)
		case "revm":
			evms = append(evms, benchmark.EVMRevm)
		default:
			return fmt.Errorf("unknown EVM: %s", c.Args().Get(i))
		}
	}

	// Get benchmarks
	benchmarks := benchmark.GetEVMBenchmarks()
	
	// Filter by specific benchmark if provided
	if benchName := c.String("benchmark"); benchName != "" {
		if b, ok := benchmarks[benchName]; ok {
			benchmarks = map[string]*benchmark.Benchmark{
				benchName: b,
			}
		} else {
			return fmt.Errorf("unknown benchmark: %s", benchName)
		}
	}

	iterations := c.Int("iterations")
	output := c.String("output")
	verbose := c.Bool("verbose")

	return runMatrixBenchmark(benchmarks, evms, iterations, verbose, output)
}

func configCommand() *cli.Command {
	return &cli.Command{
		Name:  "config",
		Usage: "Manage benchmark configurations",
		Flags: []cli.Flag{
			&cli.BoolFlag{
				Name:  "show",
				Usage: "Show current configuration",
			},
			&cli.StringSliceFlag{
				Name:  "set",
				Usage: "Set configuration value (KEY=VALUE)",
			},
			&cli.BoolFlag{
				Name:  "reset",
				Usage: "Reset to default configuration",
			},
		},
		Action: configAction,
	}
}

func configAction(c *cli.Context) error {
	fmt.Println("Config management not yet implemented")
	return nil
}

func printHyperfineInstructions() {
	fmt.Fprintln(os.Stderr, "\n❌ hyperfine is not installed!")
	fmt.Fprintln(os.Stderr, "\nTo install hyperfine, visit:")
	fmt.Fprintln(os.Stderr, "https://github.com/sharkdp/hyperfine#installation")
	fmt.Fprintln(os.Stderr, "\nQuick installation options:")
	fmt.Fprintln(os.Stderr, "  • macOS:  brew install hyperfine")
	fmt.Fprintln(os.Stderr, "  • Ubuntu: apt install hyperfine")
	fmt.Fprintln(os.Stderr, "  • Cargo:  cargo install hyperfine")
	fmt.Fprintln(os.Stderr, "  • Windows: scoop install hyperfine\n")
}