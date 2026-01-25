#!/bin/bash

# Sync agent configuration to Claude Code and Codex directories

set -e

SOURCE_DIR="$HOME/agent-config"

# Target directories
CLAUDE_DIR="$HOME/.claude"
CODEX_DIR="$HOME/.codex"

# Create target directories if they don't exist
mkdir -p "$CLAUDE_DIR/skills"
mkdir -p "$CODEX_DIR/skills"

# Copy default.md to each target with appropriate name
echo "Copying default.md:"
cp -v "$SOURCE_DIR/default.md" "$CLAUDE_DIR/CLAUDE.md"
cp -v "$SOURCE_DIR/default.md" "$CODEX_DIR/AGENTS.md"

# Copy skills folders and contents (overwrite existing, preserve extra files)
if [ -d "$SOURCE_DIR/skills" ] && [ -n "$(ls -A "$SOURCE_DIR/skills" 2>/dev/null)" ]; then
    echo ""
    echo "Copying skills to $CLAUDE_DIR/skills/:"
    cp -rv "$SOURCE_DIR/skills/"* "$CLAUDE_DIR/skills/"
    echo ""
    echo "Copying skills to $CODEX_DIR/skills/:"
    cp -rv "$SOURCE_DIR/skills/"* "$CODEX_DIR/skills/"
fi

echo ""
echo "Sync complete."
