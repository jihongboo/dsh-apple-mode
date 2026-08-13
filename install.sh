#!/usr/bin/env bash
#
# dsh-apple-mode installer
#
#   1. Installs the `apple` agent preset into DSH's harness home
#      (~/.dsh/.agent-presets/apple).
#   2. Generates the Xcode AI skills LOCALLY on your machine via
#      `xcrun agent skills export` and merges them into the DSH skill root
#      (~/.agents/skills). Apple-authored skill content is produced from your
#      own Xcode installation — nothing is redistributed by this repository.
#
# Requires: bash, macOS, Xcode 26+ (for the skills export and mcpbridge),
#           DeepSeek Harness (dsh).
#
set -euo pipefail

DSH_HOME="${DSH_HOME:-$HOME/.dsh}"
AGENTS_HOME="${DSH_AGENTS_HOME:-$HOME/.agents}"
PRESET_DIR="$DSH_HOME/.agent-presets/apple"
SKILLS_DIR="$AGENTS_HOME/skills"

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> [1/2] Installing 'apple' agent preset → $PRESET_DIR"
mkdir -p "$(dirname "$PRESET_DIR")"
if [ -e "$PRESET_DIR" ]; then
  backup="$PRESET_DIR.bak.$(date +%Y%m%d%H%M%S)"
  cp -R "$PRESET_DIR" "$backup"
  echo "    existing preset backed up to $backup"
fi
cp -R "$repo_dir/presets/apple" "$PRESET_DIR"
chmod 700 "$PRESET_DIR" 2>/dev/null || true
chmod 600 "$PRESET_DIR/agent.cordis.yml" "$PRESET_DIR/preset.yml" 2>/dev/null || true
echo "    installed."

echo "==> [2/2] Generating Xcode AI skills via 'xcrun agent skills export'"
if command -v xcrun >/dev/null 2>&1 && xcrun --find mcpbridge >/dev/null 2>&1; then
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  (cd "$tmp" && xcrun agent skills export >/dev/null 2>&1) || true
  mkdir -p "$SKILLS_DIR"
  if [ -d "$tmp/xcode-skills" ]; then
    count=0
    for d in "$tmp"/xcode-skills/*/; do
      [ -d "$d" ] || continue
      name="$(basename "$d")"
      echo "    skill: $name"
      rm -rf "$SKILLS_DIR/$name"
      cp -R "$d" "$SKILLS_DIR/$name"
      count=$((count + 1))
    done
    echo "    $count skills merged into $SKILLS_DIR"
  else
    echo "    WARNING: export produced no skills — Xcode may be too old or not installed."
  fi
else
  echo "    WARNING: xcrun / mcpbridge not found — skills not generated (preset installed anyway)."
  echo "    Install skills later: xcrun agent skills export, then merge the directories into $SKILLS_DIR"
fi

cat <<'EOF'

Done. Next steps:
  1. Restart dsh (or just open a NEW session).
  2. Pick the "Apple 开发模式" agent preset when creating the session.
  3. The mcp__xcode__* tools appear in that session (Xcode must be running).
EOF
