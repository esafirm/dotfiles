#!/bin/bash

# Get the directory of the script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CFR_JAR="$SCRIPT_DIR/../assets/cfr-0.152.jar"

if ! command -v java &> /dev/null; then
    echo "Error: 'java' command not found. Please install a Java Runtime Environment (JRE) to use the decompiler."
    echo "On Ubuntu/Debian: sudo apt update && sudo apt install default-jre"
    exit 1
fi

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <jar_path> <class_name> [output_dir]"
    echo "Example: $0 myapp.jar com.example.Main ./src"
    exit 1
fi

JAR_PATH="$1"
CLASS_NAME="$2"
OUTPUT_DIR="${3:-.}"

# Run CFR decompiler
# Note: CFR expects class names with dots, but some versions need the full path in the jar.
# If class name ends with .class, remove it.
CLASS_NAME="${CLASS_NAME%.class}"

echo "Decompiling $CLASS_NAME from $JAR_PATH..."
java -jar "$CFR_JAR" "$JAR_PATH" --class "$CLASS_NAME" --outputpath "$OUTPUT_DIR" --silent true

if [ $? -eq 0 ]; then
    echo "Decompilation successful. Output saved to $OUTPUT_DIR"
else
    echo "Decompilation failed."
fi
