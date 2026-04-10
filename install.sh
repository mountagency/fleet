#!/usr/bin/env bash
set -euo pipefail

# fleet installer
# Usage: curl -fsSL https://raw.githubusercontent.com/mountagency/fleet/main/install.sh | bash

INSTALL_DIR="${FLEET_INSTALL_DIR:-$HOME/.local/bin}"
SKILL_DIR="${FLEET_SKILL_DIR:-$HOME/.claude/skills/fleet}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[fleet]${NC} $*"; }
warn() { echo -e "${YELLOW}[fleet]${NC} $*"; }
err()  { echo -e "${RED}[fleet]${NC} $*" >&2; exit 1; }

# Check dependencies
command -v git >/dev/null 2>&1 || err "git is required"
command -v tmux >/dev/null 2>&1 || err "tmux is required (brew install tmux)"
command -v jq >/dev/null 2>&1 || err "jq is required (brew install jq)"
command -v gh >/dev/null 2>&1 || warn "gh (GitHub CLI) is recommended for issue/PR features (brew install gh)"

# Create install directory
mkdir -p "$INSTALL_DIR"

# Download fleet script
if command -v curl >/dev/null 2>&1; then
  curl -fsSL "https://raw.githubusercontent.com/mountagency/fleet/main/fleet" -o "$INSTALL_DIR/fleet"
elif command -v wget >/dev/null 2>&1; then
  wget -qO "$INSTALL_DIR/fleet" "https://raw.githubusercontent.com/mountagency/fleet/main/fleet"
else
  err "curl or wget is required"
fi

chmod +x "$INSTALL_DIR/fleet"
log "Installed fleet to $INSTALL_DIR/fleet"

# Install Claude Code skill
mkdir -p "$SKILL_DIR"
if command -v curl >/dev/null 2>&1; then
  curl -fsSL "https://raw.githubusercontent.com/mountagency/fleet/main/skill/SKILL.md" -o "$SKILL_DIR/SKILL.md"
elif command -v wget >/dev/null 2>&1; then
  wget -qO "$SKILL_DIR/SKILL.md" "https://raw.githubusercontent.com/mountagency/fleet/main/skill/SKILL.md"
fi
log "Installed Claude Code skill to $SKILL_DIR/"

# Install worker protocol
if command -v curl >/dev/null 2>&1; then
  curl -fsSL "https://raw.githubusercontent.com/mountagency/fleet/main/skill/WORKER_PROTOCOL.md" -o "$SKILL_DIR/WORKER_PROTOCOL.md"
elif command -v wget >/dev/null 2>&1; then
  wget -qO "$SKILL_DIR/WORKER_PROTOCOL.md" "https://raw.githubusercontent.com/mountagency/fleet/main/skill/WORKER_PROTOCOL.md"
fi
log "Installed worker protocol to $SKILL_DIR/"

# Check PATH
if ! echo "$PATH" | tr ':' '\n' | grep -q "$INSTALL_DIR"; then
  warn "$INSTALL_DIR is not in your PATH"
  warn "Add this to your shell profile:"
  warn "  export PATH=\"$INSTALL_DIR:\$PATH\""
fi

echo ""
log "Fleet installed! Run 'fleet --help' to get started."
log "In Claude Code, the fleet skill will be available automatically."
