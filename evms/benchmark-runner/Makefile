.PHONY: build clean deps test

# Build the benchmark runner
build: deps
	go build -o benchmark-runner main.go

# Install dependencies
deps:
	cd ../go-ethereum && make geth
	go mod tidy

# Clean build artifacts
clean:
	rm -f benchmark-runner
	go clean

# Run tests
test:
	go test ./...

# Build go-ethereum from source
build-geth:
	cd ../go-ethereum && make geth

# Full setup
setup: build-geth build
	@echo "Setup complete!"