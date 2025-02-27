#!/bin/bash

# Check if both arguments are provided
if [ $# -ne 2 ]; then
    echo "Error: Two arguments are required"
    echo "Usage: $0 <directory_path> <search_string>"
    exit 1
fi

filesdir="$1"
searchstr="$2"

# Check if filesdir exists and is a directory
if [ ! -d "$filesdir" ]; then
    echo "Error: '$filesdir' is not a directory or does not exist"
    exit 1
fi

# Count total number of files in directory and subdirectories
num_files=$(find "$filesdir" -type f | wc -l)

# Count number of lines containing searchstr across all files
num_matches=$(grep -r "$searchstr" "$filesdir" 2>/dev/null | wc -l)

# Print the result
echo "The number of files are $num_files and the number of matching lines are $num_matches"

exit 0