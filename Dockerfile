# AEGIS-SE Defense Systems Development Environment
# Multi-stage build for security and optimization

# Base image with security hardening
FROM ubuntu:22.04 as base

# Security: Create non-root user early
RUN groupadd -r aegis && useradd -r -g aegis -d /home/aegis -s /bin/bash -c "AEGIS Developer" aegis

# Install security updates first
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    lsb-release && \
    rm -rf /var/lib/apt/lists/*

# Development tools stage
FROM base as development

# Install development dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Build essentials
    build-essential \
    cmake \
    ninja-build \
    pkg-config \
    autoconf \
    automake \
    libtool \
    # Cross-compilation toolchains
    gcc-multilib \
    gcc-arm-linux-gnueabihf \
    gcc-aarch64-linux-gnu \
    # FPGA and hardware tools
    ghdl \
    iverilog \
    verilator \
    # Python development
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    # Static analysis tools
    cppcheck \
    clang-tidy \
    valgrind \
    # Version control and utilities
    git \
    vim \
    nano \
    tree \
    htop \
    # Documentation tools  
    doxygen \
    graphviz \
    texlive-latex-base \
    # Network tools (for testing)
    netcat \
    tcpdump \
    wireshark-common && \
    rm -rf /var/lib/apt/lists/*

# Create development directories
RUN mkdir -p /workspace /home/aegis/{.local,workspace} && \
    chown -R aegis:aegis /home/aegis /workspace

# Switch to development user
USER aegis
WORKDIR /home/aegis

# Create Python virtual environment
RUN python3 -m venv venv && \
    . venv/bin/activate && \
    pip install --upgrade pip setuptools wheel

# Install Python development dependencies
COPY requirements.txt /tmp/requirements.txt
RUN . venv/bin/activate && \
    pip install -r /tmp/requirements.txt

# Production stage
FROM base as production

# Install only runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip && \
    rm -rf /var/lib/apt/lists/*

# Copy application code
COPY --chown=aegis:aegis src/ /app/src/
COPY --chown=aegis:aegis configs/ /app/configs/
COPY --chown=aegis:aegis scripts/ /app/scripts/

# Copy Python virtual environment from development stage
COPY --from=development --chown=aegis:aegis /home/aegis/venv /app/venv

# Switch to application user
USER aegis
WORKDIR /app

# Set environment variables
ENV PATH="/app/venv/bin:$PATH"
ENV PYTHONPATH="/app/src"
ENV AEGIS_ENV="production"

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python3 -c "import sys; sys.exit(0)" || exit 1

# Security: Run as non-root
EXPOSE 8080

# Default command
CMD ["python3", "src/main.py"]

# Development stage (for local development)
FROM development as dev

# Install additional development tools
RUN . venv/bin/activate && \
    pip install \
    jupyter \
    ipython \
    black \
    flake8 \
    mypy \
    pytest \
    pytest-cov \
    pytest-xdist

# Set development environment
ENV AEGIS_ENV="development"
ENV PYTHONPATH="/workspace/src"

# Mount point for source code
VOLUME ["/workspace"]
WORKDIR /workspace

# Development server
CMD ["bash"]
