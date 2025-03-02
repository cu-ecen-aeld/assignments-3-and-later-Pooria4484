#!/bin/sh
# Tester script for assignment 1 and assignment 2
# Author: Siddhant Jajoo
# Modified for Assignment 2 to use native-compiled writer application

set -e
set -u

NUMFILES=10
WRITESTR=AELD_IS_FUN
WRITEDIR=/tmp/aeld-data
username=$(cat conf/username.txt)

if [ $# -lt 3 ]
then
    echo "Using default value ${WRITESTR} for string to write"
    if [ $# -lt 1 ]
    then
        echo "Using default value ${NUMFILES} for number of files to write"
    else
        NUMFILES=$1
    fi    
else
    NUMFILES=$1
    WRITESTR=$2
    WRITEDIR=/tmp/aeld-data/$3
fi

MATCHSTR="The number of files are ${NUMFILES} and the number of matching lines are ${NUMFILES}"

echo "Writing ${NUMFILES} files containing string ${WRITESTR} to ${WRITEDIR}"

rm -rf "${WRITEDIR}"

# create $WRITEDIR if not assignment1
assignment=$(cat ../conf/assignment.txt)

if [ "$assignment" != 'assignment1' ]
then
    mkdir -p "$WRITEDIR"

    # Check if directory was created successfully
    if [ -d "$WRITEDIR" ]
    then
        echo "$WRITEDIR created"
    else
        echo "Failed to create $WRITEDIR"
        exit 1
    fi
fi

# Clean previous build artifacts and compile writer as native application
echo "Cleaning previous build artifacts and compiling writer application"
# make clean
# make

for i in $(seq 1 "$NUMFILES")
do
    ./writer "$WRITEDIR/${username}$i.txt" "$WRITESTR"
done

echo $(pwd)

OUTPUTSTRING=$(/home/finder.sh "$WRITEDIR" "$WRITESTR")

# remove temporary directories
rm -rf /tmp/aeld-data

set +e
echo "${OUTPUTSTRING}" | grep "${MATCHSTR}"
if [ $? -eq 0 ]; then
    echo "success"
    exit 0
else
    echo "failed: expected  ${MATCHSTR} in ${OUTPUTSTRING} but instead found"
    echo "${OUTPUTSTRING}"
    exit 1
fi