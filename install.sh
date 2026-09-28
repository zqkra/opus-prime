#!/usr/bin/env bash
# Installs the sr-opus output style for every Claude Code session of this user
# (terminal, IDE, desktop, Agent SDK, and hosts that spawn the claude CLI such as Zeron).
#
#   ./install.sh              install or update, then verify
#   ./install.sh --check      report the effective output style in the current directory
#   ./install.sh --uninstall  remove the style and the outputStyle setting
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
STYLE_NAME="sr-opus"
STYLE_DST="$CLAUDE_DIR/output-styles/$STYLE_NAME.md"
SETTINGS="$CLAUDE_DIR/settings.json"

# Claude Code skips a settings file that fails to parse, so refuse to write anything but valid JSON.
edit_settings() {
  python3 - "$SETTINGS" "$STYLE_NAME" "$1" <<'PY'
import json, os, shutil, sys, time

path, style, mode = sys.argv[1:4]
data = {}
if os.path.exists(path) and os.path.getsize(path) > 0:
    try:
        with open(path) as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        sys.exit(f"{path} is not valid JSON ({e}). Fix it and rerun. Nothing was changed.")

previous = data.get("outputStyle")
if mode == "install":
    if previous not in (None, style):
        print(f"Replacing previous outputStyle={previous}")
    data["outputStyle"] = style
    attribution = data.get("attribution")
    if not isinstance(attribution, dict):
        attribution = {}
    attribution.update({"commit": "", "pr": "", "sessionUrl": False})
    data["attribution"] = attribution
    message = f"Set outputStyle={style} and empty attribution in {path}"
else:
    if previous != style:
        print(f"outputStyle in {path} is {previous!r}, left unchanged.")
        sys.exit(0)
    del data["outputStyle"]
    message = f"Removed outputStyle from {path}. The attribution block was kept; delete it by hand if you want the trailers back."

if os.path.exists(path):
    shutil.copy2(path, f"{path}.bak.{time.strftime('%Y%m%d%H%M%S')}")
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
print(message)
PY
}

check() {
  # Project-level settings win over user settings, and /output-style writes to .claude/settings.local.json.
  local overrides
  overrides=$(grep -ls '"outputStyle"' .claude/settings.json .claude/settings.local.json 2>/dev/null || true)
  if [ -n "$overrides" ]; then
    echo "Warning: these project files set outputStyle and override the user setting in $(pwd):"
    echo "$overrides"
  fi

  if ! command -v claude >/dev/null 2>&1; then
    echo "claude is not on PATH, skipped verification."
    return 0
  fi
  local current
  # The "Output style:" header echoes the configured value even when no style matches it,
  # so only the "(current)" marker in the list proves the style resolved.
  current=$(claude -p "/output-style" 2>/dev/null | sed -n 's/^- \([^:]*\) (current).*/\1/p')
  if [ "$current" = "$STYLE_NAME" ]; then
    echo "Verified: claude reports $STYLE_NAME as the current output style in $(pwd)."
  else
    echo "claude reports '${current:-unknown}' as the current output style in $(pwd), not $STYLE_NAME."
    return 1
  fi
}

command -v python3 >/dev/null 2>&1 || { echo "python3 is required to edit $SETTINGS safely." >&2; exit 1; }

case "${1:-}" in
  "")
    mkdir -p "$CLAUDE_DIR/output-styles"
    cp "$SRC_DIR/output-styles/$STYLE_NAME.md" "$STYLE_DST"
    echo "Copied style to $STYLE_DST"
    edit_settings install
    check
    ;;
  --check)
    check
    ;;
  --uninstall)
    rm -f "$STYLE_DST"
    echo "Removed $STYLE_DST"
    edit_settings uninstall
    ;;
  *)
    echo "Usage: ./install.sh [--check | --uninstall]" >&2
    exit 2
    ;;
esac
