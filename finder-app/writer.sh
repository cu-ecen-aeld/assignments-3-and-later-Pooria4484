#!/bin/bash

# Check if both arguments are provided
if [ $# -ne 2 ]; then
    echo "Error: Two arguments are required"
    echo "Usage: $0 <full_path_to_file> <text_string>"
    exit 1
fi

writefile="$1"
writestr="$2"

# Extract the directory path from the full file path
dir_path=$(dirname "$writefile")

# Create the directory path if it doesn't exist
if [ ! -d "$dir_path" ]; then
    mkdir -p "$dir_path"
    if [ $? -ne 0 ]; then
        echo "Error: Could not create directory path '$dir_path'"
        exit 1
    fi
fi

# Write the string to the file, creating or overwriting it
echo "$writestr" > "$writefile"
if [ $? -ne 0 ]; then
    echo "Error: Could not create or write to file '$writefile'"
    exit 1
fi

exit 0