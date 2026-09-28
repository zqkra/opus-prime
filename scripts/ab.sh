#!/usr/bin/env bash
# Runs one prompt with the default output style and with sr-opus, then compares tokens, cost, time, and text.
# Model, settings, CLAUDE.md, and tools stay identical, so the style is the only variable.
#
#   scripts/ab.sh "Is legacy-config.json still referenced?"
#   RUNS=3 MODEL=opus EFFORT=high scripts/ab.sh "Should we add Redis here?"
#
# Runs against the current directory. Anything that would ask for permission is denied, so the runs
# cannot edit files or run unapproved commands. Each run is billed to your normal Claude Code account.
set -euo pipefail

if [ $# -ne 1 ] || [ -z "$1" ]; then
  echo "Usage: [RUNS=n] [MODEL=m] [EFFORT=e] scripts/ab.sh \"<prompt>\"" >&2
  exit 2
fi
prompt="$1"
runs="${RUNS:-1}"
out="$(mktemp -d "${TMPDIR:-/tmp}/sr-opus-ab.XXXXXX")"

extra=()
[ -n "${MODEL:-}" ] && extra+=(--model "$MODEL")
[ -n "${EFFORT:-}" ] && extra+=(--effort "$EFFORT")

for i in $(seq "$runs"); do
  for style in default sr-opus; do
    echo "run $i/$runs: $style" >&2
    claude -p "$prompt" --output-format json --no-session-persistence \
      --permission-mode manual --permission-prompts none \
      --settings "{\"outputStyle\":\"$style\"}" ${extra[@]+"${extra[@]}"} \
      >"$out/$style.$i.json" 2>"$out/$style.$i.err" || true
  done
done

python3 - "$out" "$runs" <<'PY'
import json, os, sys

out, runs = sys.argv[1], int(sys.argv[2])
styles = ["default", "sr-opus"]
stats, texts = {}, {}

for style in styles:
    rows = []
    for i in range(1, runs + 1):
        try:
            with open(os.path.join(out, f"{style}.{i}.json")) as f:
                d = json.load(f)
        except (OSError, json.JSONDecodeError):
            with open(os.path.join(out, f"{style}.{i}.err")) as f:
                err = f.read().strip().splitlines()
            sys.exit(f"{style} run {i} failed: {err[-1] if err else 'no output'}")
        if d.get("is_error"):
            sys.exit(f"{style} run {i} returned an error: {d.get('result') or d.get('subtype')}")
        usage = d.get("usage", {})
        rows.append({
            "output": usage.get("output_tokens", 0),
            "thinking": usage.get("output_tokens_details", {}).get("thinking_tokens", 0),
            "cost": d.get("total_cost_usd", 0.0),
            "seconds": d.get("duration_ms", 0) / 1000,
            "turns": d.get("num_turns", 0),
        })
        texts.setdefault(style, d.get("result", ""))
    stats[style] = {k: sum(r[k] for r in rows) / len(rows) for k in rows[0]}

print(f"\nAverages over {runs} run(s). Output tokens include thinking tokens.\n")
print(f"{'style':<10}{'output tok':>12}{'thinking':>10}{'cost USD':>11}{'seconds':>9}{'turns':>7}")
for style in styles:
    s = stats[style]
    print(f"{style:<10}{s['output']:>12.0f}{s['thinking']:>10.0f}{s['cost']:>11.4f}{s['seconds']:>9.1f}{s['turns']:>7.1f}")

base, new = stats["default"]["output"], stats["sr-opus"]["output"]
if base:
    print(f"\nsr-opus output tokens vs default: {(new - base) / base:+.0%}")

for style in styles:
    print(f"\n--- {style} (run 1) ---\n{texts[style]}")
print(f"\nRaw JSON: {out}")
PY
