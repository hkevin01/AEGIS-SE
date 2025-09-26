# AEGIS-SE Flight Control System Makefile
# MISRA C:2012 Compliant Build System
# DO-178C Level A Ready

# Compiler Configuration
CC = gcc
CFLAGS = -std=c11 -Wall -Wextra -Werror -pedantic
CFLAGS += -O2 -g -fstack-protector-strong
CFLAGS += -D_FORTIFY_SOURCE=2 -fPIE -pie
CFLAGS += -Wformat=2 -Wformat-security -Wcast-align -Wcast-qual
CFLAGS += -Wwrite-strings -Wconversion -Wshadow -Wstrict-prototypes
CFLAGS += -Wmissing-prototypes -Wold-style-definition -Wredundant-decls
CFLAGS += -Wnested-externs -Wmissing-include-dirs -Wlogical-op
CFLAGS += -Wdouble-promotion -Wfloat-equal -Wundef -Winit-self

# MISRA C:2012 Additional Flags
MISRA_FLAGS = -DMISRA_C_2012_COMPLIANCE

# Security Hardening Flags
SECURITY_FLAGS = -fstack-clash-protection -fcf-protection=full
SECURITY_FLAGS += -Wl,-z,relro,-z,now -Wl,-z,noexecstack

# Libraries
LIBS = -lm -lpthread -lrt

# Directories
SRC_DIR = src/embedded-systems/flight-control
TEST_DIR = tests
BUILD_DIR = build
INCLUDE_DIR = src/embedded-systems/flight-control

# Source Files
SOURCES = $(SRC_DIR)/flight_control_system.c
TEST_SOURCES = $(TEST_DIR)/test_flight_control.c
HEADERS = $(SRC_DIR)/flight_control_system.h

# Object Files
OBJECTS = $(BUILD_DIR)/flight_control_system.o
TEST_OBJECTS = $(BUILD_DIR)/test_flight_control.o

# Executables
TEST_EXECUTABLE = $(BUILD_DIR)/test_flight_control

# Default target
.PHONY: all
all: clean directories test

# Create build directories
.PHONY: directories
directories:
	mkdir -p $(BUILD_DIR)

# Build object files
$(BUILD_DIR)/flight_control_system.o: $(SRC_DIR)/flight_control_system.c $(HEADERS)
	echo "Compiling flight control system..."
	$(CC) $(CFLAGS) $(MISRA_FLAGS) -I$(INCLUDE_DIR) -c $< -o $@

$(BUILD_DIR)/test_flight_control.o: $(TEST_DIR)/test_flight_control.c $(HEADERS)
	echo "Compiling flight control tests..."
	$(CC) $(CFLAGS) $(MISRA_FLAGS) -I$(INCLUDE_DIR) -c $< -o $@

# Build test executable
$(TEST_EXECUTABLE): $(OBJECTS) $(TEST_OBJECTS)
	echo "Linking test executable..."
	$(CC) $(CFLAGS) $(SECURITY_FLAGS) $^ -o $@ $(LIBS)

# Run tests
.PHONY: test
test: $(TEST_EXECUTABLE)
	echo "Running AEGIS-SE Flight Control System Tests..."
	echo "=============================================="
	./$(TEST_EXECUTABLE)

# Clean build artifacts
.PHONY: clean
clean:
	echo "Cleaning build artifacts..."
	rm -rf $(BUILD_DIR)
	rm -f gmon.out profile_report.txt

# Help target
.PHONY: help
help:
	echo "AEGIS-SE Flight Control System Build System"
	echo "=========================================="
	echo "Targets:"
	echo "  all     - Build and test everything (default)"
	echo "  test    - Build and run unit tests"
	echo "  clean   - Clean build artifacts"
	echo "  help    - Show this help message"
