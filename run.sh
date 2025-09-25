#!/bin/bash

set -e

# Check if Zig is installed
if ! command -v zig &> /dev/null; then
    echo "Error: Zig is not installed!"
    echo ""
    echo "Please install Zig from: https://ziglang.org/download/"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "  brew install zig"
    fi
    exit 1
fi

# Run the benchmark
zig build benchmark

# Serve the results with markserv
echo ""
echo "Starting markserv to display results..."
bunx markserv ./results.md