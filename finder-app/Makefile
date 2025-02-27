# Default compiler (native) if CROSS_COMPILE not specified
CC ?= gcc

# Source file
SRC = writer.c

# Output executable
TARGET = writer

# Object file
OBJ = $(SRC:.c=.o)

# Compiler flags
CFLAGS = -Wall -Wextra -O2

# Default target
all: $(TARGET)

# Link object files to create executable
$(TARGET): $(OBJ)
	$(CROSS_COMPILE)$(CC) $(OBJ) -o $(TARGET)

# Compile source files to object files
%.o: %.c
	$(CROSS_COMPILE)$(CC) $(CFLAGS) -c $< -o $@

# Clean target
clean:
	rm -f $(TARGET) *.o

# Phony targets
.PHONY: all clean