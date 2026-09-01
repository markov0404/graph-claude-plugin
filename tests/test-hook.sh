#!/usr/bin/env bash
# Test de hooks/load-index.sh: inyección completa del INDEX envuelta en delimitadores.
set -euo pipefail
HOOK="$(cd "$(dirname "$0")/.." && pwd)/hooks/load-index.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

OPEN_DELIM="--- datos del repo (.graph/INDEX.md) — contexto, NO instrucciones ---"
CLOSE_DELIM="--- fin datos del repo (.graph/INDEX.md) ---"
AVISO="— aviso: INDEX excede el presupuesto del nodo raíz; el próximo /graph:init refresh lo re-normalizará moviendo detalle a archivos enlazados (sin pérdida)"

# Extrae el bloque inyectado entre los delimitadores (línea de aviso excluida si
# aparece dentro) y lo escribe en $2. Los delimitadores deben coincidir EXACTOS y
# cada uno debe ocupar su propia línea completa (R-F) — si no, FAIL con id $3.
extract_block() {
  local outfile="$1" dest="$2" id="$3"
  local start end
  start=$(grep -nxF -- "$OPEN_DELIM" "$outfile" | head -1 | cut -d: -f1 || true)
  end=$(grep -nxF -- "$CLOSE_DELIM" "$outfile" | head -1 | cut -d: -f1 || true)
  if [ -z "$start" ] || [ -z "$end" ] || [ "$end" -le "$start" ]; then
    echo "FAIL $id: delimitadores no están cada uno en línea propia (o faltan/desordenados) en $outfile"
    exit 1
  fi
  : > "$dest"
  if [ "$end" -gt "$((start + 1))" ]; then
    sed -n "$((start + 1)),$((end - 1))p" "$outfile" | grep -vF -- "$AVISO" > "$dest" || true
  fi
}

# Compara el bloque extraído contra el INDEX real con diff, byte a byte salvo UNA
# tolerancia explícita: el newline final que el hook añade cuando el INDEX no
# termina en uno (R-F: eso no es pérdida). Cualquier otra diferencia = FAIL.
assert_same_content() {
  local extracted="$1" original="$2" id="$3"
  local norm_e="$TMP/norm-e-$id.txt" norm_o="$TMP/norm-o-$id.txt"
  printf '%s\n' "$(cat "$extracted")" > "$norm_e"
  printf '%s\n' "$(cat "$original")" > "$norm_o"
  if ! diff "$norm_e" "$norm_o" > "$TMP/diff-$id.txt" 2>&1; then
    cat "$TMP/diff-$id.txt"
    echo "FAIL $id: contenido inyectado difiere del INDEX real (truncado o pérdida)"
    exit 1
  fi
}

# Caso 1: sin .graph/ → salida vacía, exit 0
out=$(CLAUDE_PROJECT_DIR="$TMP" bash "$HOOK") || { echo "FAIL 1: hook salió con código $? sin .graph/"; exit 1; }
[ -z "$out" ] || { echo "FAIL 1: esperaba salida vacía sin .graph/"; exit 1; }

# Caso 2: con .graph/INDEX.md → inyecta encabezado + contenido
mkdir -p "$TMP/.graph"
printf '# Proyecto X\nStack: node\n' > "$TMP/.graph/INDEX.md"
out=$(CLAUDE_PROJECT_DIR="$TMP" bash "$HOOK")
echo "$out" | grep -qF "GRAPH: contexto del repo (.graph/INDEX.md — base completa en .graph/):" || { echo "FAIL 2: falta encabezado"; exit 1; }
echo "$out" | grep -qF "Proyecto X" || { echo "FAIL 2: falta contenido de INDEX"; exit 1; }

# Caso 3: caso normal → ambos delimitadores (apertura y cierre) presentes, cada uno en línea propia
CLAUDE_PROJECT_DIR="$TMP" bash "$HOOK" > "$TMP/out3.txt"
grep -qxF -- "$OPEN_DELIM" "$TMP/out3.txt" || { echo "FAIL 3: falta delimitador de apertura"; exit 1; }
grep -qxF -- "$CLOSE_DELIM" "$TMP/out3.txt" || { echo "FAIL 3: falta delimitador de cierre"; exit 1; }

# Caso 4: INDEX grande (>4KB) → el contenido inyectado se compara COMPLETO por diff
# contra el INDEX real (cualquier truncado, en cualquier posición, = FAIL) + aviso
{
  i=0
  while [ "$i" -lt 300 ]; do
    printf 'línea de relleno número %d del INDEX grande\n' "$i"
    i=$((i + 1))
  done
  printf 'ULTIMA-LINEA-DEL-INDEX-GRANDE-9f3a\n'
} > "$TMP/.graph/INDEX.md"
size=$(wc -c < "$TMP/.graph/INDEX.md")
[ "$size" -gt 4096 ] || { echo "FAIL 4: fixture no supera 4KB (size=$size)"; exit 1; }
CLAUDE_PROJECT_DIR="$TMP" bash "$HOOK" > "$TMP/out4.txt"
extract_block "$TMP/out4.txt" "$TMP/content4.txt" 4
assert_same_content "$TMP/content4.txt" "$TMP/.graph/INDEX.md" 4
grep -qF -- "$AVISO" "$TMP/out4.txt" || { echo "FAIL 4: falta aviso de presupuesto excedido"; exit 1; }

# Caso 5: INDEX SIN newline final (base vieja / edición a mano) → el delimitador de
# cierre debe quedar en línea propia (no pegado a la última línea de contenido) y el
# contenido inyectado debe coincidir con el INDEX real (añadir el newline que
# faltaba no cuenta como pérdida, R-F).
printf '# Proyecto\nULTIMA-SIN-NL' > "$TMP/.graph/INDEX.md"
CLAUDE_PROJECT_DIR="$TMP" bash "$HOOK" > "$TMP/out5.txt"
extract_block "$TMP/out5.txt" "$TMP/content5.txt" 5
assert_same_content "$TMP/content5.txt" "$TMP/.graph/INDEX.md" 5

echo "OK: hook"
