#!/bin/bash
# Installs the custom Claude Code statusline on Linux or macOS.
# Usage: ./install.sh
#    or: curl -fsSL https://raw.githubusercontent.com/zarnuq/claude-statusline/master/install.sh | bash
set -euo pipefail

main() {
    SCRIPT_DIR=""
    [ -n "${BASH_SOURCE[0]:-}" ] && SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    RAW_URL="https://raw.githubusercontent.com/zarnuq/claude-statusline/master"
    CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
    STATUSLINE_DEST="$CLAUDE_DIR/statusline-command.sh"
    SETTINGS="$CLAUDE_DIR/settings.json"

    install_file() {
        if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/$1" ]; then
            cp "$SCRIPT_DIR/$1" "$CLAUDE_DIR/$1"
        elif command -v curl >/dev/null 2>&1; then
            curl -fsSL "$RAW_URL/$1" -o "$CLAUDE_DIR/$1"
        else
            wget -qO "$CLAUDE_DIR/$1" "$RAW_URL/$1"
        fi
    }

    echo "Installing Claude Code statusline into $CLAUDE_DIR ..."
    mkdir -p "$CLAUDE_DIR"
    install_file statusline-command.sh
    chmod +x "$STATUSLINE_DEST"

    if ! command -v jq >/dev/null 2>&1; then
        echo "jq not found — attempting to install it..."
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update </dev/null && sudo apt-get install -y jq </dev/null
        elif command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y jq </dev/null
        elif command -v yum >/dev/null 2>&1; then
            sudo yum install -y jq </dev/null
        elif command -v pacman >/dev/null 2>&1; then
            sudo pacman -S --noconfirm jq </dev/null
        elif command -v zypper >/dev/null 2>&1; then
            sudo zypper install -y jq </dev/null
        elif command -v brew >/dev/null 2>&1; then
            brew install jq </dev/null
        else
            echo "Could not detect a package manager to install jq automatically." >&2
            echo "Please install jq yourself, then re-run this script." >&2
            exit 1
        fi
    fi

    if [ ! -f "$SETTINGS" ]; then
        echo '{}' > "$SETTINGS"
    fi

    TMP="$(mktemp)"
    SCRIPT_PATH="~/.claude/statusline-command.sh"
    [ -n "${CLAUDE_CONFIG_DIR:-}" ] && SCRIPT_PATH="\"$STATUSLINE_DEST\""
    jq --arg cmd "bash $SCRIPT_PATH" '.statusLine = {"type": "command", "command": $cmd}' "$SETTINGS" > "$TMP"
    mv "$TMP" "$SETTINGS"

    echo "Done. Statusline installed at $STATUSLINE_DEST"
    echo "settings.json updated at $SETTINGS (other keys preserved)."
    echo "Restart Claude Code (or start a new session) to see it."
}

main "$@"
