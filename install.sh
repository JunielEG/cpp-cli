#!/usr/bin/env bash
set -euo pipefail

TOOL_NAME="cpp-cli"
REPO_URL="https://github.com/JunielEG/cpp-cli.git"
INSTALL_DIR="$HOME/ScaffoldingTools/$TOOL_NAME"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Detectar si los archivos están disponibles localmente
if [ -f "$SCRIPT_DIR/unix/cppx.sh" ]; then
    echo "Source found locally, installing from current folder..."
    SOURCE_DIR="$SCRIPT_DIR"
else
    echo "Cloning $TOOL_NAME..."
    TEMP_DIR="$(mktemp -d)"
    git clone "$REPO_URL" "$TEMP_DIR"
    SOURCE_DIR="$TEMP_DIR"
fi

# Crear carpeta destino y copiar archivos
echo "Installing in $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"
cp -r "$SOURCE_DIR/templates" "$INSTALL_DIR/templates"
cp    "$SOURCE_DIR/unix/cppx.sh"   "$INSTALL_DIR/cppx.sh"
chmod +x "$INSTALL_DIR/cppx.sh"

# Limpiar carpeta temporal si se clonó
if [ -n "${TEMP_DIR:-}" ] && [ -d "$TEMP_DIR" ]; then
    rm -rf "$TEMP_DIR"
fi

# Agregar al PATH en el perfil del shell
echo "Adding to PATH..."

# Detectar cuál archivo de perfil usar
if [ -f "$HOME/.zshrc" ]; then
    PROFILE="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
    PROFILE="$HOME/.bashrc"
elif [ -f "$HOME/.bash_profile" ]; then
    PROFILE="$HOME/.bash_profile"
else
    PROFILE="$HOME/.profile"
fi

# Solo agregar si no está ya en el PATH
if echo "$PATH" | grep -qF "$INSTALL_DIR"; then
    echo "PATH already contains $INSTALL_DIR, skipping."
else
    echo "" >> "$PROFILE"
    echo "# ScaffoldingTools - $TOOL_NAME" >> "$PROFILE"
    echo "export PATH=\"\$PATH:$INSTALL_DIR\"" >> "$PROFILE"
    echo "Added to $PROFILE"
fi

echo
echo "Done. Restart your terminal and use: cppx"