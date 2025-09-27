# AEGIS-SE Unit Test Makefile
# Comprehensive unit testing for embedded systems

BUILD_DIR = ../../build
SRC_DIR = ../../src
TEST_SRC = ../test_flight_control.c

# Target configuration
TARGET ?= x86_64

# Compiler settings
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

CFLAGS = -Wall -Wextra -Werror -std=c17 -g $(ARCH_FLAGS)
CFLAGS += -I$(SRC_DIR)/embedded-systems
LDFLAGS = -lm

# Test targets
.PHONY: test clean

test: $(BUILD_DIR)/test_flight_control
	@echo "🧪 Running Unit Tests for $(TARGET)"
	@echo "=================================="
	$(BUILD_DIR)/test_flight_control
	@echo "✅ All unit tests passed!"

$(BUILD_DIR)/test_flight_control: $(TEST_SRC) $(SRC_DIR)/embedded-systems/flight-control/flight_control_system.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

clean:
	rm -f $(BUILD_DIR)/test_flight_control

help:
	@echo "Unit Test System"
	@echo "Usage: make [TARGET=target] test"
