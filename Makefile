# AEGIS-SE Defense Platform Build System
# Comprehensive Makefile for all components

# Build Configuration
BUILD_DIR = build
SRC_DIR = src
TEST_DIR = tests
DOCS_DIR = docs

# Compiler Settings
CC = gcc
CFLAGS = -Wall -Wextra -O2 -std=c11
LDFLAGS = -lm

# Python Settings
PYTHON = python3
PIP = pip3

# VHDL Simulation Settings
VHDL_SIM = ghdl
VHDL_FLAGS = --std=08 --workdir=$(BUILD_DIR)

# Default target
.PHONY: all
all: build test

# Create build directory
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Build C components
.PHONY: build-c
build-c: $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $(SRC_DIR)/embedded-systems/flight-control/flight_control_system.c -o $(BUILD_DIR)/flight_control_system.o
	$(CC) $(CFLAGS) -c $(TEST_DIR)/test_flight_control.c -o $(BUILD_DIR)/test_flight_control.o
	$(CC) $(CFLAGS) $(BUILD_DIR)/flight_control_system.o $(BUILD_DIR)/test_flight_control.o -o $(BUILD_DIR)/test_flight_control $(LDFLAGS)

# Build Python components
.PHONY: build-python
build-python:
	$(PIP) install -r requirements.txt
	$(PYTHON) -m py_compile $(SRC_DIR)/ai-ml-systems/integrated_pipeline.py
	$(PYTHON) -m py_compile $(SRC_DIR)/ai-ml-systems/threat-detection/threat_analyzer.py
	$(PYTHON) -m py_compile $(SRC_DIR)/ai-ml-systems/sensor-fusion/sensor_fusion.py
	$(PYTHON) -m py_compile $(SRC_DIR)/ai-ml-systems/feature-extraction/feature_extractor.py
	$(PYTHON) -m py_compile $(SRC_DIR)/ai-ml-systems/inference-engines/onnx_engine.py
	$(PYTHON) -m py_compile $(SRC_DIR)/ai-ml-systems/inference-engines/tflite_engine.py

# Build VHDL components
.PHONY: build-vhdl
build-vhdl: $(BUILD_DIR)
	# Analyze VHDL files
	$(VHDL_SIM) -a $(VHDL_FLAGS) $(SRC_DIR)/fpga-designs/cryptography/*.vhd
	$(VHDL_SIM) -a $(VHDL_FLAGS) $(SRC_DIR)/fpga-designs/signal-processing/*.vhd
	$(VHDL_SIM) -a $(VHDL_FLAGS) $(SRC_DIR)/fpga-designs/system-controllers/*.vhd
	$(VHDL_SIM) -a $(VHDL_FLAGS) $(SRC_DIR)/fpga-designs/interfaces/*.vhd
	$(VHDL_SIM) -a $(VHDL_FLAGS) $(SRC_DIR)/fpga-designs/sensor-interfaces/*.vhd
	$(VHDL_SIM) -a $(VHDL_FLAGS) $(SRC_DIR)/fpga-designs/memory-controllers/*.vhd
	$(VHDL_SIM) -a $(VHDL_FLAGS) $(SRC_DIR)/fpga-designs/testbenches/*.vhd
	$(VHDL_SIM) -a $(VHDL_FLAGS) $(SRC_DIR)/fpga-acceleration/crypto-engine/*.vhd

# Build all components
.PHONY: build
build: build-c build-python build-vhdl

# Run C tests
.PHONY: test-c
test-c: build-c
	./$(BUILD_DIR)/test_flight_control

# Run Python tests
.PHONY: test-python
test-python: build-python
	$(PYTHON) -m pytest $(TEST_DIR)/ai-ml/ -v

# Run VHDL simulation tests
.PHONY: test-vhdl
test-vhdl: build-vhdl
	# Run comprehensive testbench
	$(VHDL_SIM) -e $(VHDL_FLAGS) crypto_comprehensive_tb
	$(VHDL_SIM) -r $(VHDL_FLAGS) crypto_comprehensive_tb --stop-time=1ms --vcd=$(BUILD_DIR)/crypto_test.vcd

	# Run AEGIS system testbench
	$(VHDL_SIM) -e $(VHDL_FLAGS) aegis_comprehensive_tb
	$(VHDL_SIM) -r $(VHDL_FLAGS) aegis_comprehensive_tb --stop-time=1ms --vcd=$(BUILD_DIR)/aegis_test.vcd

# Run all tests
.PHONY: test
test: test-c test-python test-vhdl

# Run AEGIS demonstration
.PHONY: demo
demo: build-python
	$(PYTHON) scripts/demo_aegis_systems.py

# Performance benchmarks
.PHONY: benchmark
benchmark: build
	@echo "Running performance benchmarks..."
	./$(BUILD_DIR)/test_flight_control --benchmark
	$(PYTHON) -m pytest $(TEST_DIR)/performance/ -v --benchmark-only

# Security analysis
.PHONY: security
security: build
	@echo "Running security analysis..."
	# Static analysis
	cppcheck --enable=all $(SRC_DIR)/embedded-systems/
	bandit -r $(SRC_DIR)/ai-ml-systems/

	# Dynamic testing would go here
	@echo "Security analysis complete"

# Generate documentation
.PHONY: docs
docs:
	@echo "Generating documentation..."
	# Convert markdown to HTML
	if command -v pandoc >/dev/null 2>&1; then \
		pandoc $(DOCS_DIR)/*.md -o $(BUILD_DIR)/documentation.html; \
	else \
		echo "Pandoc not found, skipping HTML generation"; \
	fi

	# Generate VHDL documentation
	if command -v doxygen >/dev/null 2>&1; then \
		doxygen Doxyfile; \
	else \
		echo "Doxygen not found, skipping VHDL documentation"; \
	fi

# Clean build artifacts
.PHONY: clean
clean:
	rm -rf $(BUILD_DIR)
	find . -name "*.pyc" -delete
	find . -name "__pycache__" -delete
	find . -name "*.o" -delete

# Docker build
.PHONY: docker
docker:
	docker build -t aegis-se:latest .

# Deployment package
.PHONY: package
package: build test docs
	@echo "Creating deployment package..."
	mkdir -p $(BUILD_DIR)/package

	# Copy executables
	cp $(BUILD_DIR)/test_flight_control $(BUILD_DIR)/package/

	# Copy Python modules
	cp -r $(SRC_DIR)/ai-ml-systems $(BUILD_DIR)/package/

	# Copy VHDL files
	cp -r $(SRC_DIR)/fpga-designs $(BUILD_DIR)/package/
	cp -r $(SRC_DIR)/fpga-acceleration $(BUILD_DIR)/package/

	# Copy documentation
	cp -r $(DOCS_DIR) $(BUILD_DIR)/package/

	# Copy configuration
	cp -r configs $(BUILD_DIR)/package/

	# Create archive
	cd $(BUILD_DIR) && tar -czf aegis-se-package.tar.gz package/
	@echo "Package created: $(BUILD_DIR)/aegis-se-package.tar.gz"

# Install dependencies
.PHONY: install-deps
install-deps:
	# Python dependencies
	$(PIP) install -r requirements.txt

	# System dependencies (Ubuntu/Debian)
	sudo apt-get update
	sudo apt-get install -y build-essential ghdl cppcheck python3-dev

	# Optional dependencies
	sudo apt-get install -y pandoc doxygen graphviz

# Code formatting
.PHONY: format
format:
	# Format Python code
	if command -v black >/dev/null 2>&1; then \
		black $(SRC_DIR)/ai-ml-systems/; \
		black $(TEST_DIR)/ai-ml/; \
		black scripts/; \
	fi

	# Format C code
	if command -v clang-format >/dev/null 2>&1; then \
		find $(SRC_DIR)/embedded-systems -name "*.c" -o -name "*.h" | xargs clang-format -i; \
		find $(TEST_DIR) -name "*.c" -o -name "*.h" | xargs clang-format -i; \
	fi

# Lint checking
.PHONY: lint
lint:
	# Python linting
	if command -v flake8 >/dev/null 2>&1; then \
		flake8 $(SRC_DIR)/ai-ml-systems/; \
		flake8 $(TEST_DIR)/ai-ml/; \
	fi

	# C linting
	if command -v cppcheck >/dev/null 2>&1; then \
		cppcheck --enable=all --error-exitcode=1 $(SRC_DIR)/embedded-systems/; \
	fi

# Continuous Integration
.PHONY: ci
ci: install-deps format lint build test security

# Help target
.PHONY: help
help:
	@echo "AEGIS-SE Defense Platform Build System"
	@echo ""
	@echo "Available targets:"
	@echo "  all          - Build all components and run tests"
	@echo "  build        - Build all components"
	@echo "  build-c      - Build C components only"
	@echo "  build-python - Build Python components only"
	@echo "  build-vhdl   - Build VHDL components only"
	@echo "  test         - Run all tests"
	@echo "  test-c       - Run C tests only"
	@echo "  test-python  - Run Python tests only"
	@echo "  test-vhdl    - Run VHDL simulation tests only"
	@echo "  demo         - Run AEGIS demonstration"
	@echo "  benchmark    - Run performance benchmarks"
	@echo "  security     - Run security analysis"
	@echo "  docs         - Generate documentation"
	@echo "  clean        - Clean build artifacts"
	@echo "  docker       - Build Docker image"
	@echo "  package      - Create deployment package"
	@echo "  install-deps - Install system dependencies"
	@echo "  format       - Format source code"
	@echo "  lint         - Run code linting"
	@echo "  ci           - Run continuous integration pipeline"
	@echo "  help         - Show this help message"
	@echo ""
	@echo "Configuration:"
	@echo "  CC           - C compiler (default: gcc)"
	@echo "  PYTHON       - Python interpreter (default: python3)"
	@echo "  VHDL_SIM     - VHDL simulator (default: ghdl)"
	@echo ""
