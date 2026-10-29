#!/usr/bin/env bash
# Usage: prototype/picking_spike/run.sh <godot-binary>
# 1. Extracts EsSol and the example sheet straight from docs/design/picking.md,
#    so the tests always check what the design doc says.
# 2. Imports the project (registers class_name scripts) and runs the tests.
# 3. Fails on a failed test or on any engine/script error in the log.
set -u
GODOT="$1"
DIR="$(cd "$(dirname "$0")" && pwd)"
DOC="$DIR/../../docs/design/picking.md"
python3 -I "$DIR/tools/extract_blocks.py" "$DOC" 0 "$DIR/es_sol.gd" || exit 1
python3 -I "$DIR/tools/extract_blocks.py" "$DOC" 5 "$DIR/example_level.gd" || exit 1
"$GODOT" --headless --path "$DIR" --import >/dev/null 2>&1
LOG="$DIR/test.log"
"$GODOT" --headless --path "$DIR" --script res://tests/run_tests.gd >"$LOG" 2>&1
CODE=$?
cat "$LOG"
if grep -qE "SCRIPT ERROR|Parse Error|ERROR:" "$LOG"; then
	echo "run.sh: errors in log"
	exit 1
fi
exit $CODE
