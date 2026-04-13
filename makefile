CC := gcc
CFLAGS := -Wall -Wextra -Werror
TARGET := tmux-compose

CFILES := $(shell find . -type f -name '*.c')
HFILES := $(shell find . -type f -name '*.h')
OBJECTS := $(CFILES:.c=.o)

all: $(TARGET)

$(TARGET): $(OBJECTS)
	$(CC) $(CFLAGS) -o $@ $^

%.o: %.c $(HFILES)
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(OBJECTS) $(TARGET)

.PHONY: all clean
