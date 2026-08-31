#!/usr/bin/env bash
set -euo pipefail
HOOK="$(cd "$(dirname "$0")/.." && pwd)/hooks/load-index.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Caso 1: sin .graph/ → salida vacía, exit 0
out=$(CLAUDE_PROJECT_DIR="$TMP" bash "$HOOK")
[ -z "$out" ] || { echo "FAIL: esperaba salida vacía sin .graph/"; exit 1; }

# Caso 2: con .graph/INDEX.md → inyecta encabezado + contenido
mkdir -p "$TMP/.graph"
printf '# Proyecto X\nStack: node\n' > "$TMP/.graph/INDEX.md"
out=$(CLAUDE_PROJECT_DIR="$TMP" bash "$HOOK")
echo "$out" | grep -q "GRAPH: contexto del repo" || { echo "FAIL: falta encabezado"; exit 1; }
echo "$out" | grep -q "Proyecto X" || { echo "FAIL: falta contenido de INDEX"; exit 1; }

echo "OK: hook"
