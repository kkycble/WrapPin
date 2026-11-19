#!/usr/bin/env bash
# Keep a failing command's diagnostic tail in the check annotations as well as
# the job log. This is useful when inspecting CI through the GitHub checks API.
set -uo pipefail
LOG="$(mktemp "${TMPDIR:-/tmp}/wrappin-ci.XXXXXX")"
trap 'rm -f "$LOG"' EXIT
"$@" 2>&1 | tee "$LOG"
STATUS="${PIPESTATUS[0]}"
if [[ "$STATUS" != 0 && "${GITHUB_ACTIONS:-}" == true ]]; then
    python3 - "$LOG" <<'PY'
from pathlib import Path
import sys
text = "\n".join(Path(sys.argv[1]).read_text(errors="replace").splitlines()[-100:])[-14000:]
text = text.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
print(f"::error title=Command diagnostic tail::{text}")
PY
fi
exit "$STATUS"
