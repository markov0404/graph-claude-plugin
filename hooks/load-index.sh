#!/usr/bin/env bash
# SessionStart: inyecta .graph/INDEX.md al contexto si existe. Silencioso si no.
set -euo pipefail
INDEX="${CLAUDE_PROJECT_DIR:-.}/.graph/INDEX.md"
if [ -r "$INDEX" ]; then
  echo "GRAPH: contexto del repo (.graph/INDEX.md — base completa en .graph/):"
  cat "$INDEX"
fi
exit 0
