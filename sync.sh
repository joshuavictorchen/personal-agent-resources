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

# Copy skills folders (clean target first to prevent stale file accumulation)
if [ -d "$SOURCE_DIR/skills" ] && [ -n "$(ls -A "$SOURCE_DIR/skills" 2>/dev/null)" ]; then
    for skill_dir in "$SOURCE_DIR/skills"/*/; do
        skill_name="$(basename "$skill_dir")"
        for target in "$CLAUDE_DIR/skills" "$CODEX_DIR/skills"; do
            echo "Syncing $skill_name to $target/$skill_name/"
            rm -rf "$target/$skill_name"
            cp -r "$skill_dir" "$target/$skill_name"
        done
    done
fi

echo ""
echo "Sync complete."
