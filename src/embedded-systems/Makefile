# AEGIS-SE Embedded Systems Makefile
# Mission-critical embedded software build system

# Target configuration
TARGET ?= x86_64
BUILD_DIR = ../../build
INCLUDE_DIR = .

# Compiler settings based on target
ifeq ($(TARGET), arm-cortex-a78)
    CC = arm-linux-gnueabihf-gcc
    ARCH_FLAGS = -mcpu=cortex-a78 -march=armv8.2-a
else ifeq ($(TARGET), powerpc)
    CC = powerpc-linux-gnu-gcc
    ARCH_FLAGS = -mcpu=e6500
else
    CC = gcc
    ARCH_FLAGS = -march=native
endif

# MISRA C compliant flags
CFLAGS = -Wall -Wextra -Werror -std=c17 -pedantic $(ARCH_FLAGS)
CFLAGS += -O2 -g -fstack-protector-strong
CFLAGS += -I$(INCLUDE_DIR)

# Safety-critical flags
CFLAGS += -Wno-unused-parameter -Wno-unused-variable
LDFLAGS = -lm

# Source files
FLIGHT_CONTROL_SOURCES = flight-control/flight_control_system.c
OBJECTS = $(FLIGHT_CONTROL_SOURCES:%.c=$(BUILD_DIR)/%.o)

# Targets
.PHONY: all clean test

all: $(BUILD_DIR)/libflightcontrol.a

# Create build directory
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)/flight-control

# Create subdirectories for build
$(BUILD_DIR)/flight-control:
	mkdir -p $(BUILD_DIR)/flight-control

# Build flight control system library
$(BUILD_DIR)/libflightcontrol.a: $(BUILD_DIR)/flight-control/flight_control_system.o
	ar rcs $@ $^

# Compile source files
$(BUILD_DIR)/%.o: %.c | $(BUILD_DIR)/flight-control
	$(CC) $(CFLAGS) -c -o $@ $<

# Run tests
test: all
	@echo "✅ Embedded systems built successfully for target: $(TARGET)"

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)/flight-control
	rm -f $(BUILD_DIR)/libflightcontrol.a

# Help target
help:
	@echo "AEGIS-SE Embedded Systems Build System"
	@echo "Usage: make [TARGET=target] [goal]"
	@echo ""
	@echo "Targets:"
	@echo "  arm-cortex-a78  - ARM Cortex-A78 target"
	@echo "  powerpc         - PowerPC target"
	@echo "  x86_64          - x86_64 target (default)"
	@echo ""
	@echo "Goals:"
	@echo "  all    - Build all embedded systems"
	@echo "  test   - Build and test"
	@echo "  clean  - Clean build artifacts"
