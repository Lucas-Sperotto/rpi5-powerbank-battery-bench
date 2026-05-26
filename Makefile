CC ?= gcc
CFLAGS ?= -O2 -Wall -Wextra -pedantic -std=c11
LDFLAGS ?= -pthread -lm
BUILD_DIR := build
TARGET := $(BUILD_DIR)/battery_logger
SRC := src/battery_logger.c

.PHONY: all clean run

all: $(TARGET)

$(TARGET): $(SRC)
	mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) $(SRC) -o $(TARGET) $(LDFLAGS)

run: $(TARGET)
	mkdir -p logs
	./$(TARGET) logs/manual_test.csv 30 4 1024

clean:
	rm -rf $(BUILD_DIR)
