# EVM benchmark runner Docker image
FROM rust:1.75-slim AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Set up working directory
WORKDIR /app

# Copy Cargo files
COPY Cargo.toml Cargo.lock ./

# Copy source code
COPY src ./src

# Build release binary
RUN cargo build --release

# Runtime stage
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    make \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Foundry
RUN curl -L https://foundry.paradigm.xyz | bash && \
    /root/.foundry/bin/foundryup

# Install hyperfine for benchmarking
RUN curl -L https://github.com/sharkdp/hyperfine/releases/download/v1.18.0/hyperfine_1.18.0_amd64.deb -o hyperfine.deb && \
    dpkg -i hyperfine.deb && \
    rm hyperfine.deb

# Copy binary from builder
COPY --from=builder /app/target/release/bench /usr/local/bin/bench

# Copy application code
WORKDIR /app
COPY . .

# Set PATH to include foundry binaries
ENV PATH="/root/.foundry/bin:${PATH}"

# Default command
CMD ["bench", "--help"]