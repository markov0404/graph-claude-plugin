#!/usr/bin/env bash
# Suite automatizada GRAPH. Los escenarios interactivos están en scenarios.md.
# Usa --dangerously-skip-permissions SOLO dentro de fixtures desechables.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC=(claude -p --plugin-dir "$ROOT" --dangerously-skip-permissions)

"$ROOT/tests/test-hook.sh"
"$ROOT/tests/make-fixtures.sh"
JS="$ROOT/tests/build/fixture-js"

echo "— E1: init genera .graph/ con comandos verificados"
(cd "$JS" && "${CC[@]}" "/graph:init refresh" > /dev/null)
for f in INDEX.md map.md conventions.md commands.md decisions.md tasks/README.md; do
  [ -f "$JS/.graph/$f" ] || { echo "FAIL E1: falta .graph/$f"; exit 1; }
done
grep -F '`npm test`' "$JS/.graph/commands.md" | grep -q '| sí' || { echo "FAIL E1: fila npm test sin verificado 'sí'"; exit 1; }

echo "— E2: el gate bloquea en headless (sin mutación fuera de .graph/)"
(cd "$JS" && git add -A && git -c user.email=fx@fx -c user.name=fx commit -qm "post-init" || true)
E2OUT="$ROOT/tests/build/graph-e2.out"
(cd "$JS" && "${CC[@]}" "/graph:do quiero que total aplique un descuento porcentual opcional") > "$E2OUT" || true
grep -qiE "gate|apruéb|aprobar" "$E2OUT" || { echo "FAIL E2: no presentó el gate"; exit 1; }
mut=$(cd "$JS" && git status --porcelain | grep -v '\.graph/' || true)
[ -z "$mut" ] || { echo "FAIL E2: mutó el repo antes del OK: $mut"; exit 1; }
if ls "$JS/.graph/tasks" 2>/dev/null | grep -qv '^README\.md$'; then
  echo "FAIL E2: task record creado antes del OK"; exit 1
fi

echo "— E3: --quick sin .graph/ crea base parcial y no muta código"
QT=$(mktemp -d); cp -r "$JS/src" "$JS/test" "$JS/package.json" "$QT/"
trap 'rm -rf "$QT"' EXIT
(cd "$QT" && git init -qb main && git add -A && git -c user.email=fx@fx -c user.name=fx commit -qm x)
E3OUT="$ROOT/tests/build/graph-e3.out"
(cd "$QT" && "${CC[@]}" "/graph:do --quick quiero que total redondee a 2 decimales") > "$E3OUT" || true
[ -f "$QT/.graph/INDEX.md" ] && grep -qi "parcial" "$QT/.graph/INDEX.md" || { echo "FAIL E3: sin INDEX parcial"; exit 1; }
mutq=$(cd "$QT" && git status --porcelain | grep -v '\.graph/' || true)
[ -z "$mutq" ] || { echo "FAIL E3: mutó código con --quick: $mutq"; exit 1; }
grep -qiE "gate|apruéb|aprobar" "$E3OUT" || { echo "FAIL E3: no presentó el gate con --quick"; exit 1; }

echo "OK: escenarios automatizados (E1-E3)"
