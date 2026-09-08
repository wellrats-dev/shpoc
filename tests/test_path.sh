#!/bin/bash

echo "========================================="
echo "       SHPOC PATH & SUDO RESOLUTION TEST"
echo "========================================="
echo "[*] Native Bash \$0 (RAM Descriptor): $0"
echo "[*] Shpoc Custom \$_0 (Real Absolute Path): $_0"
echo ""

# sudo test
if [ "$EUID" -ne 0 ]; then
    echo "[*] Testing path validity: Attempting re-execution via sudo..."
    echo "    Command: sudo \"$_0\" --inside-sudo"
    echo ""
    # Executa a si mesmo como root usando a nossa âncora $_0
    exec sudo "$_0" --inside-sudo
fi

if [ "$1" == "--inside-sudo" ]; then
    echo "[✓] SUCCESS: The script re-executed under sudo context perfectly!"
    echo "    Current User UID: $(id -u) (Should be 0 / root)"
fi
echo "========================================="

