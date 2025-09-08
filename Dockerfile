# Multi-stage build for EVM benchmark runner
FROM golang:1.21-alpine AS go-builder

# Install build dependencies
RUN apk add --no-cache git make gcc musl-dev linux-headers

# Build go-ethereum
WORKDIR /build
COPY evms/go-ethereum ./go-ethereum
RUN cd go-ethereum && make geth

# Build benchmark runner
COPY evms/benchmark-runner ./benchmark-runner
RUN cd benchmark-runner && go mod download && make build

# Python stage
FROM python:3.11-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    make \
    && rm -rf /var/lib/apt/lists/*

# Install Foundry
RUN curl -L https://foundry.paradigm.xyz | bash && \
    /root/.foundry/bin/foundryup

# Copy go-ethereum binaries
COPY --from=go-builder /build/go-ethereum/build/bin/geth /usr/local/bin/
COPY --from=go-builder /build/go-ethereum/build/bin/evm /usr/local/bin/
COPY --from=go-builder /build/benchmark-runner/benchmark-runner-simple /usr/local/bin/

# Set up Python environment
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Install hyperfine for benchmarking
RUN curl -L https://github.com/sharkdp/hyperfine/releases/download/v1.18.0/hyperfine_1.18.0_amd64.deb -o hyperfine.deb && \
    dpkg -i hyperfine.deb && \
    rm hyperfine.deb

# Install the package
RUN pip install -e .

# Build Foundry contracts
RUN /root/.foundry/bin/forge build

# Set environment variables
ENV PATH="/root/.foundry/bin:${PATH}"
ENV PYTHONUNBUFFERED=1

# Default command
CMD ["evm-bench", "--help"]