#!/bin/bash
# Ralph Wiggum Plugin Installer
# Installs the self-referential development loop for Claude Code
#
# Usage:
#   ./install-ralph-plugin.sh --local    # Install from template source
#   ./install-ralph-plugin.sh --uninstall # Remove Ralph plugin

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Help text
show_help() {
    cat << 'EOF'
Ralph Wiggum Plugin Installer

USAGE:
    ./install-ralph-plugin.sh [OPTIONS]

OPTIONS:
    --help        Show this help message
    --local       Copy files from local template source repository
    --uninstall   Remove Ralph plugin files

DESCRIPTION:
    Installs the Ralph Wiggum iterative development loop plugin:
    - scripts/setup-ralph-loop.sh       Setup script for starting loops
    - .claude/hooks/ralph-stop-hook.sh  Stop hook that prevents exit during loops
    - .claude/commands/ralph-loop.md    Slash command to start a loop
    - .claude/commands/cancel-ralph.md  Slash command to cancel active loop

    Also updates .claude/settings.json to register the stop hook.

SOURCE DISCOVERY (--local):
    1. Uses PROJECT_HOME environment variable if set
    2. Otherwise searches parent directories for template source

EXAMPLES:
    # Install from local template source
    ./install-ralph-plugin.sh --local

    # Remove the plugin
    ./install-ralph-plugin.sh --uninstall
EOF
    exit 0
}

# Find source directory by walking up from script location
find_source_dir() {
    local dir
    dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Walk up looking for Ralph source files
    while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/scripts/setup-ralph-loop.sh" ]] && \
           [[ -f "$dir/hooks/ralph-stop-hook.sh" ]] && \
           [[ -f "$dir/.claude/commands/ralph-loop.md" ]]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done

    return 1
}

# Update settings.json to add Ralph stop hook
update_settings_json() {
    local settings_file=".claude/settings.json"

    if [[ ! -f "$settings_file" ]]; then
        echo -e "${YELLOW}Warning: $settings_file not found, creating minimal config${NC}"
        mkdir -p .claude
        cat > "$settings_file" << 'SETTINGS'
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/ralph-stop-hook.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
SETTINGS
        return 0
    fi

    # Check if Ralph hook already exists (check for partial match on filename)
    if jq -e '.hooks.Stop[0].hooks[]? | select(.command | contains("ralph-stop-hook"))' "$settings_file" > /dev/null 2>&1; then
        echo "Ralph stop hook already registered in settings.json"
        return 0
    fi

    # Check if Stop hooks array exists
    if ! jq -e '.hooks.Stop[0].hooks?' "$settings_file" > /dev/null 2>&1; then
        # Create Stop hooks structure if missing
        jq '.hooks.Stop = [{"hooks": []}]' "$settings_file" > "${settings_file}.tmp"
        mv "${settings_file}.tmp" "$settings_file"
    fi

    # Prepend Ralph hook to Stop hooks array (first position)
    local ralph_hook='{"type": "command", "command": ".claude/hooks/ralph-stop-hook.sh", "timeout": 5}'
    jq --argjson hook "$ralph_hook" '.hooks.Stop[0].hooks = [$hook] + .hooks.Stop[0].hooks' "$settings_file" > "${settings_file}.tmp"
    mv "${settings_file}.tmp" "$settings_file"

    echo "Added Ralph stop hook to settings.json"
}

# Remove Ralph hook from settings.json
remove_from_settings_json() {
    local settings_file=".claude/settings.json"

    if [[ ! -f "$settings_file" ]]; then
        return 0
    fi

    # Check if Stop hooks array exists
    if ! jq -e '.hooks.Stop[0].hooks?' "$settings_file" > /dev/null 2>&1; then
        return 0
    fi

    # Remove Ralph hook entries
    jq '.hooks.Stop[0].hooks = [.hooks.Stop[0].hooks[] | select(.command | contains("ralph-stop-hook") | not)]' "$settings_file" > "${settings_file}.tmp"
    mv "${settings_file}.tmp" "$settings_file"

    echo "Removed Ralph stop hook from settings.json"
}

# Install Ralph plugin
do_install() {
    local source_dir="$1"

    echo "Installing Ralph Wiggum plugin from: $source_dir"
    echo ""

    # Create target directories
    mkdir -p scripts
    mkdir -p .claude/hooks
    mkdir -p .claude/commands

    # Copy files
    echo "Copying files..."
    cp -f "$source_dir/scripts/setup-ralph-loop.sh" scripts/
    echo "  - scripts/setup-ralph-loop.sh"

    cp -f "$source_dir/hooks/ralph-stop-hook.sh" .claude/hooks/
    echo "  - .claude/hooks/ralph-stop-hook.sh"

    cp -f "$source_dir/.claude/commands/ralph-loop.md" .claude/commands/
    echo "  - .claude/commands/ralph-loop.md"

    cp -f "$source_dir/.claude/commands/cancel-ralph.md" .claude/commands/
    echo "  - .claude/commands/cancel-ralph.md"

    # Make scripts executable
    chmod +x scripts/setup-ralph-loop.sh
    chmod +x .claude/hooks/ralph-stop-hook.sh

    # Update settings.json
    echo ""
    update_settings_json

    echo ""
    echo -e "${GREEN}Ralph Wiggum plugin installed successfully!${NC}"
    echo ""
    echo "Usage:"
    echo "  /ralph-loop <prompt> [--max-iterations N] [--completion-promise 'TEXT']"
    echo ""
    echo "Example:"
    echo "  /ralph-loop Fix the auth bug --max-iterations 10"
}

# Uninstall Ralph plugin
do_uninstall() {
    echo "Uninstalling Ralph Wiggum plugin..."
    echo ""

    local removed=0

    # Remove files
    if [[ -f "scripts/setup-ralph-loop.sh" ]]; then
        rm -f scripts/setup-ralph-loop.sh
        echo "  Removed: scripts/setup-ralph-loop.sh"
        ((removed++)) || true
    fi

    if [[ -f ".claude/hooks/ralph-stop-hook.sh" ]]; then
        rm -f .claude/hooks/ralph-stop-hook.sh
        echo "  Removed: .claude/hooks/ralph-stop-hook.sh"
        ((removed++)) || true
    fi

    if [[ -f ".claude/commands/ralph-loop.md" ]]; then
        rm -f .claude/commands/ralph-loop.md
        echo "  Removed: .claude/commands/ralph-loop.md"
        ((removed++)) || true
    fi

    if [[ -f ".claude/commands/cancel-ralph.md" ]]; then
        rm -f .claude/commands/cancel-ralph.md
        echo "  Removed: .claude/commands/cancel-ralph.md"
        ((removed++)) || true
    fi

    # Update settings.json
    remove_from_settings_json

    echo ""
    if [[ $removed -gt 0 ]]; then
        echo -e "${GREEN}Ralph Wiggum plugin uninstalled ($removed files removed)${NC}"
    else
        echo -e "${YELLOW}No Ralph plugin files found${NC}"
    fi
}

# Main
main() {
    local mode=""
    local use_local=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                show_help
                ;;
            --local)
                use_local=true
                mode="install"
                shift
                ;;
            --uninstall)
                mode="uninstall"
                shift
                ;;
            *)
                echo -e "${RED}Error: Unknown option: $1${NC}" >&2
                echo "Use --help for usage information" >&2
                exit 1
                ;;
        esac
    done

    # Default to showing help if no arguments
    if [[ -z "$mode" ]]; then
        show_help
    fi

    # Check for jq dependency
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: jq is required but not installed${NC}" >&2
        echo "Install with: sudo apt install jq" >&2
        exit 1
    fi

    # Execute requested mode
    case "$mode" in
        install)
            local source_dir=""

            # Find source directory
            if [[ -n "${PROJECT_HOME:-}" ]] && [[ -d "$PROJECT_HOME" ]]; then
                source_dir="$PROJECT_HOME"
            elif $use_local; then
                source_dir=$(find_source_dir) || true
            fi

            if [[ -z "$source_dir" ]]; then
                echo -e "${RED}Error: Could not find source directory${NC}" >&2
                echo "Set PROJECT_HOME environment variable or ensure Ralph source files are in a parent directory" >&2
                exit 1
            fi

            # Verify source files exist
            if [[ ! -f "$source_dir/scripts/setup-ralph-loop.sh" ]]; then
                echo -e "${RED}Error: Source file not found: $source_dir/scripts/setup-ralph-loop.sh${NC}" >&2
                exit 1
            fi

            do_install "$source_dir"
            ;;
        uninstall)
            do_uninstall
            ;;
    esac
}

main "$@"
