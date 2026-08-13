#!/usr/bin/env bash
#
# dsh-apple-mode installer
#
#   1. Detects the Xcode installs on this Mac that provide `mcpbridge`
#      (Xcode 26+) and lets you choose which one to use — or pass --xcode.
#      The chosen command is baked into the installed preset, so the default
#      preset in presets/apple/ stays portable (xcrun / xcode-select).
#   2. Installs the `apple` agent preset into DSH's harness home
#      (~/.dsh/.agent-presets/apple).
#   3. Generates the Xcode AI skills LOCALLY on your machine via
#      `xcrun agent skills export` and merges them into the DSH skill root
#      (~/.agents/skills). Apple-authored skill content is produced from your
#      own Xcode installation — nothing is redistributed by this repository.
#
# Options:
#   --xcode <app-or-developer-dir>   Use this Xcode non-interactively.
#                                    Accepts "/Applications/Xcode-26.2.app" or
#                                    ".../Contents/Developer".
#   --runtime-selectable             Install bin/mcpbridge as the command and
#                                    switch Xcode later via
#                                    DSH_XCODE_DEVELOPER_DIR (no reinstall).
#   --list-xcodes                    Print detected mcpbridge-capable Xcode
#                                    developer dirs and exit.
#   --no-skills                      Skip the skills export step.
#   -h, --help                       Show this help.
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
TEMPLATE_PRESET="$repo_dir/presets/apple"

XCODE_DIR=""
RUNTIME_SELECTABLE=false
DO_SKILLS=true

usage() {
  sed -n '2,26p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 0
}

# ── arg parsing ──────────────────────────────────────────────────────────────
while [ $# -gt 0 ]; do
  case "$1" in
    --xcode) XCODE_DIR="${2:-}"; shift 2 ;;
    --xcode=*) XCODE_DIR="${1#*=}"; shift ;;
    --runtime-selectable) RUNTIME_SELECTABLE=true; shift ;;
    --list-xcodes) LIST_ONLY=true; shift ;;
    --no-skills) DO_SKILLS=false; shift ;;
    -h|--help) usage ;;
    *) echo "unknown option: $1" >&2; usage ;;
  esac
done

# ── detection ────────────────────────────────────────────────────────────────
dev_dir_of() { # Xcode.app path -> Contents/Developer
  local p="$1"
  case "$p" in
    *.app) echo "$p/Contents/Developer" ;;
    *) echo "$p" ;;
  esac
}

default_dir="$(xcode-select -p 2>/dev/null || true)"

detect() {
  local d
  if [ -n "$default_dir" ] && [ -x "$default_dir/usr/bin/mcpbridge" ]; then
    echo "$default_dir"
  fi
  for app in /Applications/Xcode*.app; do
    [ -d "$app" ] || continue
    d="$(dev_dir_of "$app")"
    [ "$d" = "$default_dir" ] && continue
    if [ -x "$d/usr/bin/mcpbridge" ]; then
      echo "$d"
    fi
  done
}

candidates=()
while IFS= read -r d; do
  [ -n "$d" ] && candidates+=("$d")
done < <(detect || true)

if [ "${LIST_ONLY:-false}" = true ]; then
  echo "mcpbridge-capable Xcode developer dirs:"
  if [ "${#candidates[@]}" -eq 0 ]; then
    echo "  (none found — need Xcode 26+)"
  else
    for d in "${candidates[@]}"; do
      marker=""; [ "$d" = "$default_dir" ] && marker="  (xcode-select default)"
      echo "  $d$marker"
    done
  fi
  exit 0
fi

# ── choose ───────────────────────────────────────────────────────────────────
if [ -n "$XCODE_DIR" ]; then
  chosen="$(dev_dir_of "$XCODE_DIR")"
elif [ "${#candidates[@]}" -eq 0 ]; then
  echo "WARNING: no Xcode with mcpbridge found (need Xcode 26+)." >&2
  echo "  The preset will use 'xcrun mcpbridge' and fail at runtime until you" >&2
  echo "  fix it (re-run with --xcode or install Xcode 26+)." >&2
  chosen=""
elif [ "${#candidates[@]}" -eq 1 ]; then
  chosen="${candidates[0]}"
elif [ -t 0 ]; then
  echo "Found Xcode installs providing mcpbridge:"
  i=1
  for d in "${candidates[@]}"; do
    marker=""; [ "$d" = "$default_dir" ] && marker="  (xcode-select default)"
    echo "  $i) $d$marker"
    i=$((i + 1))
  done
  printf "Choose (1-%d, default 1): " "${#candidates[@]}"
  read -r pick
  pick="${pick:-1}"
  if ! [[ "$pick" =~ ^[0-9]+$ ]] || [ "$pick" -lt 1 ] || [ "$pick" -gt "${#candidates[@]}" ]; then
    echo "invalid choice, using 1" >&2
    pick=1
  fi
  chosen="${candidates[$((pick - 1))]}"
else
  chosen="${candidates[0]}"
  echo "NOTE: no TTY — using ${chosen} (use --xcode to choose explicitly)" >&2
fi

if [ -n "$chosen" ] && [ ! -x "$chosen/usr/bin/mcpbridge" ]; then
  echo "ERROR: mcpbridge not found in $chosen" >&2
  exit 1
fi

# ── install preset ───────────────────────────────────────────────────────────
echo "==> [1/3] Installing 'apple' agent preset → $PRESET_DIR"
mkdir -p "$(dirname "$PRESET_DIR")"
if [ -e "$PRESET_DIR" ]; then
  backup="$PRESET_DIR.bak.$(date +%Y%m%d%H%M%S)"
  cp -R "$PRESET_DIR" "$backup"
  echo "    existing preset backed up to $backup"
fi
rm -rf "$PRESET_DIR"
cp -R "$TEMPLATE_PRESET" "$PRESET_DIR"
chmod 700 "$PRESET_DIR" 2>/dev/null || true

# ── render the mcp-xcode row with the chosen Xcode ──────────────────────────
render_mcp_row() {
  if [ "$RUNTIME_SELECTABLE" = true ]; then
    mkdir -p "$PRESET_DIR/bin"
    cp "$repo_dir/bin/mcpbridge" "$PRESET_DIR/bin/mcpbridge"
    chmod 700 "$PRESET_DIR/bin" 2>/dev/null || true
    chmod 700 "$PRESET_DIR/bin/mcpbridge" 2>/dev/null || true
    cat <<EOF
# mcpbridge: runtime-selectable (\$DSH_XCODE_DEVELOPER_DIR > xcrun > /Applications scan)
- id: mcp-xcode
  name: '@deepseek-ai/dsh-mcp-client'
  config:
    serverName: xcode
    transport: stdio
    command: $PRESET_DIR/bin/mcpbridge
    toolCallTimeoutMs: 120000
EOF
  elif [ -z "$chosen" ] || { [ -n "$default_dir" ] && [ "$chosen" = "$default_dir" ]; }; then
    cat <<EOF
# mcpbridge: xcrun (xcode-select default → ${default_dir:-<unset>})
- id: mcp-xcode
  name: '@deepseek-ai/dsh-mcp-client'
  config:
    serverName: xcode
    transport: stdio
    command: xcrun
    args: ['mcpbridge']
    toolCallTimeoutMs: 120000
EOF
  else
    cat <<EOF
# mcpbridge: $chosen/usr/bin/mcpbridge
- id: mcp-xcode
  name: '@deepseek-ai/dsh-mcp-client'
  config:
    serverName: xcode
    transport: stdio
    command: $chosen/usr/bin/mcpbridge
    toolCallTimeoutMs: 120000
EOF
  fi
}

new_block="$(render_mcp_row)"
python3 - "$PRESET_DIR/agent.cordis.yml" "$new_block" <<'PYEOF'
import sys
path, block = sys.argv[1], sys.argv[2]
src = open(path, encoding='utf-8').read()
old = '''# Xcode 官方 MCP 桥（mcpbridge）。工具以 mcp__xcode__* 注册进本 preset 的
# tools 层，只有选择本模式的会话可见。连接目标由 xcode-select 决定；
# 如需锁定某个 Xcode 实例，加 env: { MCP_XCODE_PID: '12345' }。
# 需要 Xcode 26+（含 mcpbridge）；如 xcrun 无法解析，可改用绝对路径。
- id: mcp-xcode
  name: '@deepseek-ai/dsh-mcp-client'
  config:
    serverName: xcode
    transport: stdio
    command: xcrun
    args: ['mcpbridge']
    toolCallTimeoutMs: 120000'''
if old not in src:
    sys.exit('ERROR: mcp-xcode template block not found in preset')
open(path, 'w', encoding='utf-8').write(src.replace(old, block, 1))
PYEOF
chmod 600 "$PRESET_DIR/agent.cordis.yml" "$PRESET_DIR/preset.yml" 2>/dev/null || true
echo "    installed."

if [ "$RUNTIME_SELECTABLE" = true ]; then
  echo "    mcpbridge source: runtime-selectable ($PRESET_DIR/bin/mcpbridge)"
elif [ -z "$chosen" ] || { [ -n "$default_dir" ] && [ "$chosen" = "$default_dir" ]; }; then
  echo "    mcpbridge source: xcrun (xcode-select default → ${default_dir:-<unset>})"
else
  echo "    mcpbridge source: $chosen/usr/bin/mcpbridge"
fi

# ── skills ───────────────────────────────────────────────────────────────────
if [ "$DO_SKILLS" = true ]; then
  echo "==> [2/3] Generating Xcode AI skills via 'xcrun agent skills export'"
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
else
  echo "==> [2/3] Skipped skills export (--no-skills)"
fi

cat <<EOF

==> [3/3] Done. Next steps:
  1. Restart dsh (or just open a NEW session).
  2. Pick the "Apple 开发模式" agent preset when creating the session.
  3. The mcp__xcode__* tools appear in that session (Xcode must be running).

Change the Xcode later:
  - Re-run this installer (it re-detects and asks again).
  - Or edit the mcp-xcode row in $PRESET_DIR/agent.cordis.yml.
  - Or, with --runtime-selectable, set DSH_XCODE_DEVELOPER_DIR when launching dsh.
  - To drive a specific *running* Xcode instance, add
    env: { MCP_XCODE_PID: '<pid>' } to the mcp-xcode row.
EOF
