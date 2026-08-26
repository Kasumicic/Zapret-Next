#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
"$ROOT/tests/test_parser.sh"
"$ROOT/tests/test_runtime.sh"
"$ROOT/tests/test_action.sh"
python3 "$ROOT/tests/test_webui.py"
node --check /tmp/zapret-webui.js
echo "All tests passed"
