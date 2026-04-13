CC := gcc
CFLAGS := -Wall -Wextra -Werror
TARGET := tmux-compose
BUILD_DIR := build
BIN := $(BUILD_DIR)/$(TARGET)

CFILES := $(shell find . -type f -name '*.c')
HFILES := $(shell find . -type f -name '*.h')
OBJECTS := $(addprefix $(BUILD_DIR)/,$(CFILES:.c=.o))

all: $(BIN)

$(BIN): $(OBJECTS)
	$(CC) $(CFLAGS) -o $@ $^

$(BUILD_DIR)/%.o: %.c $(HFILES)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -rf $(BUILD_DIR)

.PHONY: all clean
