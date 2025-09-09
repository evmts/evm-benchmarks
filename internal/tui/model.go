package tui

import (
	"fmt"
	"strings"
	"time"

	"github.com/charmbracelet/bubbles/progress"
	"github.com/charmbracelet/bubbles/spinner"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/williamcory/bench/internal/benchmark"
)

// BenchmarkStatus represents the status of a benchmark
type BenchmarkStatus string

const (
	StatusPending  BenchmarkStatus = "pending"
	StatusRunning  BenchmarkStatus = "running"
	StatusComplete BenchmarkStatus = "complete"
	StatusFailed   BenchmarkStatus = "failed"
)

// BenchmarkItem represents a single benchmark in the list
type BenchmarkItem struct {
	Benchmark *benchmark.Benchmark
	Status    BenchmarkStatus
	Result    *benchmark.BenchmarkResult
	StartTime time.Time
	EndTime   time.Time
}

// Model represents the TUI application state
type Model struct {
	benchmarks   []BenchmarkItem
	currentIndex int
	evmType      benchmark.EVMType
	iterations   int
	spinner      spinner.Model
	progress     progress.Model
	width        int
	height       int
	err          error
	quitting     bool
	running      bool
	results      map[string]*benchmark.BenchmarkResult
}

// NewModel creates a new TUI model
func NewModel(benchmarks map[string]*benchmark.Benchmark, evmType benchmark.EVMType, iterations int) Model {
	s := spinner.New()
	s.Spinner = spinner.Dot
	s.Style = lipgloss.NewStyle().Foreground(lipgloss.Color("205"))

	p := progress.New(progress.WithDefaultGradient())

	// Convert benchmarks map to slice
	items := make([]BenchmarkItem, 0, len(benchmarks))
	for _, b := range benchmarks {
		items = append(items, BenchmarkItem{
			Benchmark: b,
			Status:    StatusPending,
		})
	}

	return Model{
		benchmarks: items,
		evmType:    evmType,
		iterations: iterations,
		spinner:    s,
		progress:   p,
		results:    make(map[string]*benchmark.BenchmarkResult),
	}
}

// Init initializes the model
func (m Model) Init() tea.Cmd {
	return tea.Batch(
		m.spinner.Tick,
		tea.EnterAltScreen,
	)
}

// Update handles messages
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "q", "ctrl+c":
			m.quitting = true
			return m, tea.Quit
		case "enter", " ":
			if !m.running && m.currentIndex < len(m.benchmarks) {
				m.running = true
				return m, m.runCurrentBenchmark()
			}
		case "up", "k":
			if m.currentIndex > 0 {
				m.currentIndex--
			}
		case "down", "j":
			if m.currentIndex < len(m.benchmarks)-1 {
				m.currentIndex++
			}
		case "a":
			// Run all benchmarks
			if !m.running {
				m.running = true
				m.currentIndex = 0
				return m, m.runAllBenchmarks()
			}
		}

	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		m.progress.Width = msg.Width - 4

	case spinner.TickMsg:
		var cmd tea.Cmd
		m.spinner, cmd = m.spinner.Update(msg)
		return m, cmd

	case progress.FrameMsg:
		progressModel, cmd := m.progress.Update(msg)
		m.progress = progressModel.(progress.Model)
		return m, cmd

	case benchmarkCompleteMsg:
		if msg.index < len(m.benchmarks) {
			m.benchmarks[msg.index].Status = StatusComplete
			m.benchmarks[msg.index].Result = msg.result
			m.benchmarks[msg.index].EndTime = time.Now()
			m.results[m.benchmarks[msg.index].Benchmark.Name] = msg.result
		}

		// Run next benchmark if running all
		if m.running && msg.runNext && msg.index+1 < len(m.benchmarks) {
			m.currentIndex = msg.index + 1
			m.benchmarks[m.currentIndex].Status = StatusRunning
			m.benchmarks[m.currentIndex].StartTime = time.Now()
			return m, m.runBenchmark(m.currentIndex, true)
		}

		m.running = false
		return m, nil

	case benchmarkErrorMsg:
		if msg.index < len(m.benchmarks) {
			m.benchmarks[msg.index].Status = StatusFailed
			m.benchmarks[msg.index].EndTime = time.Now()
		}
		m.err = msg.err
		m.running = false
		return m, nil

	case benchmarkStartMsg:
		if msg.index < len(m.benchmarks) {
			m.benchmarks[msg.index].Status = StatusRunning
			m.benchmarks[msg.index].StartTime = time.Now()
		}
		return m, nil
	}

	return m, nil
}

// View renders the TUI
func (m Model) View() string {
	if m.quitting {
		return ""
	}

	var s strings.Builder

	// Header
	headerStyle := lipgloss.NewStyle().
		Bold(true).
		Foreground(lipgloss.Color("39")).
		MarginBottom(1)

	s.WriteString(headerStyle.Render(fmt.Sprintf("EVM Benchmark Suite - %s", m.evmType)))
	s.WriteString("\n\n")

	// Benchmark list
	for i, item := range m.benchmarks {
		cursor := "  "
		if i == m.currentIndex {
			cursor = "> "
		}

		status := ""
		statusStyle := lipgloss.NewStyle()
		
		switch item.Status {
		case StatusPending:
			status = "⏸ "
			statusStyle = statusStyle.Foreground(lipgloss.Color("240"))
		case StatusRunning:
			status = m.spinner.View() + " "
			statusStyle = statusStyle.Foreground(lipgloss.Color("205"))
		case StatusComplete:
			status = "✓ "
			statusStyle = statusStyle.Foreground(lipgloss.Color("42"))
		case StatusFailed:
			status = "✗ "
			statusStyle = statusStyle.Foreground(lipgloss.Color("196"))
		}

		nameStyle := lipgloss.NewStyle()
		if i == m.currentIndex {
			nameStyle = nameStyle.Bold(true)
		}

		line := fmt.Sprintf("%s%s%s - %s",
			cursor,
			statusStyle.Render(status),
			nameStyle.Render(item.Benchmark.Name),
			item.Benchmark.Description,
		)

		// Add result if available
		if item.Result != nil && item.Result.Results != nil && len(item.Result.Results.Results) > 0 {
			result := item.Result.Results.Results[0]
			timeStr := formatDuration(result.Mean)
			resultStyle := lipgloss.NewStyle().Foreground(lipgloss.Color("33"))
			line += resultStyle.Render(fmt.Sprintf(" [%s]", timeStr))
		}

		s.WriteString(line)
		s.WriteString("\n")
	}

	// Progress bar if running
	if m.running {
		completed := 0
		for _, item := range m.benchmarks {
			if item.Status == StatusComplete || item.Status == StatusFailed {
				completed++
			}
		}
		percent := float64(completed) / float64(len(m.benchmarks))
		s.WriteString("\n")
		s.WriteString(m.progress.ViewAs(percent))
		s.WriteString("\n")
	}

	// Error message if any
	if m.err != nil {
		errorStyle := lipgloss.NewStyle().
			Foreground(lipgloss.Color("196")).
			MarginTop(1)
		s.WriteString(errorStyle.Render(fmt.Sprintf("Error: %v", m.err)))
		s.WriteString("\n")
	}

	// Footer
	footerStyle := lipgloss.NewStyle().
		Foreground(lipgloss.Color("240")).
		MarginTop(1)
	
	footer := "Press 'a' to run all • Enter to run selected • q to quit"
	if m.running {
		footer = "Running benchmarks... • Press q to quit"
	}
	s.WriteString(footerStyle.Render(footer))

	return s.String()
}

// Helper function to format duration
func formatDuration(seconds float64) string {
	if seconds < 0.001 {
		return fmt.Sprintf("%.2f μs", seconds*1000000)
	} else if seconds < 1 {
		return fmt.Sprintf("%.2f ms", seconds*1000)
	}
	return fmt.Sprintf("%.2f s", seconds)
}

// Messages
type benchmarkStartMsg struct {
	index int
}

type benchmarkCompleteMsg struct {
	index   int
	result  *benchmark.BenchmarkResult
	runNext bool
}

type benchmarkErrorMsg struct {
	index int
	err   error
}

// Commands
func (m Model) runCurrentBenchmark() tea.Cmd {
	if m.currentIndex >= len(m.benchmarks) {
		return nil
	}
	m.benchmarks[m.currentIndex].Status = StatusRunning
	m.benchmarks[m.currentIndex].StartTime = time.Now()
	return m.runBenchmark(m.currentIndex, false)
}

func (m Model) runAllBenchmarks() tea.Cmd {
	if len(m.benchmarks) == 0 {
		return nil
	}
	m.benchmarks[0].Status = StatusRunning
	m.benchmarks[0].StartTime = time.Now()
	return m.runBenchmark(0, true)
}

func (m Model) runBenchmark(index int, runNext bool) tea.Cmd {
	return func() tea.Msg {
		if index >= len(m.benchmarks) {
			return benchmarkErrorMsg{index: index, err: fmt.Errorf("index out of range")}
		}

		bench := m.benchmarks[index].Benchmark
		result, err := benchmark.RunEVMBenchmark(
			bench,
			m.evmType,
			m.iterations,
			true,  // use hyperfine
			false, // verbose
		)

		if err != nil {
			return benchmarkErrorMsg{index: index, err: err}
		}

		return benchmarkCompleteMsg{
			index:   index,
			result:  result,
			runNext: runNext,
		}
	}
}