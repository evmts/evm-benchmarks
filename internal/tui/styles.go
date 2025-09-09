package tui

import "github.com/charmbracelet/lipgloss"

var (
	// Colors
	primaryColor   = lipgloss.Color("39")  // Bright blue
	successColor   = lipgloss.Color("42")  // Green
	warningColor   = lipgloss.Color("214") // Orange
	errorColor     = lipgloss.Color("196") // Red
	mutedColor     = lipgloss.Color("240") // Gray
	accentColor    = lipgloss.Color("205") // Pink

	// Styles
	TitleStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(primaryColor).
			MarginBottom(1).
			Padding(1, 2)

	SubtitleStyle = lipgloss.NewStyle().
			Foreground(mutedColor).
			MarginBottom(1).
			PaddingLeft(2)

	BoxStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(primaryColor).
			Padding(1, 2).
			MarginBottom(1)

	SuccessStyle = lipgloss.NewStyle().
			Foreground(successColor)

	ErrorStyle = lipgloss.NewStyle().
			Foreground(errorColor)

	WarningStyle = lipgloss.NewStyle().
			Foreground(warningColor)

	MutedStyle = lipgloss.NewStyle().
			Foreground(mutedColor)

	SelectedStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(accentColor)

	HeaderStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(primaryColor).
			Border(lipgloss.NormalBorder(), false, false, true, false).
			BorderForeground(primaryColor).
			MarginBottom(1)

	FooterStyle = lipgloss.NewStyle().
			Foreground(mutedColor).
			MarginTop(1)

	TableHeaderStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(primaryColor).
			BorderStyle(lipgloss.NormalBorder()).
			BorderBottom(true).
			BorderForeground(mutedColor)

	TableCellStyle = lipgloss.NewStyle().
			PaddingRight(2)

	ResultStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("33"))

	SpinnerStyle = lipgloss.NewStyle().
			Foreground(accentColor)
)