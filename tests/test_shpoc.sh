#!/bin/bash

# ==============================================================================
#  test_shpoc - Functional Input Validation Script
#
#  DESCRIPTION
#
#  This script is designed to test and validate all input vectors of binaries
#  compiled with shpoc. It ensures that standard input pipes (stdin), 
#  interactive keyboard reads, and command-line arguments work seamlessly.
# ==============================================================================

echo "========================================="
echo "        SHPOC FUNCTIONAL TEST"
echo "========================================="

# 1. Test Command Line Arguments
echo "[*] Testing Command Line Arguments:"
echo "    Argument 1: ${1:-<EMPTY>}"
echo "    Argument 2: ${2:-<EMPTY>}"
echo ""

# 2. Test Input Pipe (Stdin)
echo "[*] Testing STDIN Pipe detection:"
if [ ! -t 0 ]; then
    # If stdin is not a terminal, data is being fed through a pipe
    read -r PIPE_DATA
    echo "    [✓] Success! Data received via Pipe: \"$PIPE_DATA\""
else
    echo "    [-] No pipe data detected (normal if you didn't use '|')"
fi
echo ""

# 3. Test Interactive Read (Keyboard input)
if [ -t 0 ]; then
    echo "[*] Testing Interactive STDIN (Keyboard):"
    echo -n "    Type something and press ENTER: "
    read -r USER_INPUT
    echo "    [✓] Success! You typed: \"$USER_INPUT\""
fi
echo "========================================="

