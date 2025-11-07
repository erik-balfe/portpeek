#!/bin/bash

# portpeek installer script
# Installs portpeek to /usr/local/bin or ~/.local/bin

set -e

REPO_URL="https://raw.githubusercontent.com/erik-balfe/portpeek/master/portpeek.sh"
SCRIPT_NAME="portpeek"

echo "Installing portpeek..."

# Determine install location
if [[ -w "/usr/local/bin" ]]; then
    INSTALL_DIR="/usr/local/bin"
elif [[ -w "$HOME/.local/bin" ]]; then
    INSTALL_DIR="$HOME/.local/bin"
    mkdir -p "$INSTALL_DIR"
else
    echo "Error: Cannot write to /usr/local/bin or ~/.local/bin"
    echo "Try running with sudo: sudo $0"
    exit 1
fi

# Download and install
echo "Downloading portpeek to $INSTALL_DIR/$SCRIPT_NAME..."
curl -fsSL "$REPO_URL" -o "$INSTALL_DIR/$SCRIPT_NAME"
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

echo "✓ portpeek installed successfully!"
echo ""
echo "Location: $INSTALL_DIR/$SCRIPT_NAME"
echo "Usage: portpeek --help"
echo ""

# Check if install dir is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo "⚠️  Warning: $INSTALL_DIR is not in your PATH"
    echo "   Add this to your ~/.bashrc or ~/.zshrc:"
    echo "   export PATH=\"\$PATH:$INSTALL_DIR\""
fi

# Test installation
if command -v portpeek >/dev/null 2>&1; then
    echo "✓ portpeek is ready to use!"
    portpeek --help
else
    echo "Installation complete. You may need to restart your shell or add $INSTALL_DIR to PATH."
fi
