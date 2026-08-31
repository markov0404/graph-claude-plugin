#!/usr/bin/env bash
# Mapa de símbolos de nivel superior por archivo (JS/TS, Python, bash). Bash+awk puro, cero dependencias externas.
# Uso: tools/symbol-map.sh <raíz-de-repo>   (salida markdown por stdout)
# Limitación conocida: extract_sh no rastrea heredocs (marcador variable por heredoc) — un `nombre()` a columna 0 dentro de un heredoc bash podría inventarse; no cubierto en v1.
set -euo pipefail

ROOT="${1:-}"
[ -n "$ROOT" ] || { echo "FAIL symbol-map: falta la raíz del repo como argumento" >&2; exit 1; }
[ -d "$ROOT" ] || { echo "FAIL symbol-map: '$ROOT' no es un directorio" >&2; exit 1; }
ROOT="$(cd "$ROOT" && pwd)"

JS_EXT=(js mjs cjs jsx ts tsx)
PY_EXT=(py)
SH_EXT=(sh bash)
# Lenguajes de código reconocidos pero sin cobertura de símbolos en v1.
# Ante la duda se omite: nunca se inventan símbolos para estos archivos.
UNCOVERED_EXT=(rb go rs java h c cpp cc hpp hh php kt kts swift cs scala ex exs clj lua pl pm dart hs ml mli groovy m mm)

in_list() {
  local needle="$1" w
  shift
  for w in "$@"; do
    [ "$w" = "$needle" ] && return 0
  done
  return 1
}

# Une por líneas de stdin en "a, b, c" (una sola línea, sin dependencias externas).
join_comma() {
  local out="" line
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if [ -z "$out" ]; then out="$line"; else out="$out, $line"; fi
  done
  printf '%s' "$out"
}

# JS/TS: function y const-arrow EXPORTADAS de nivel superior, class con o sin export.
# Nivel superior = línea sin indentación (columna 0); dentro de bloques se omite a propósito.
# Endurecimiento adversarial: se rastrea paridad de backticks no escapados por archivo;
# si una línea ARRANCA dentro de un template literal multilínea, se omite su captura
# (solo se actualiza la paridad) para no inventar símbolos que en realidad son texto.
extract_js() {
  awk '
    BEGIN { intpl = 0 }
    {
      gsub(/\r$/, "")
      start_in_tpl = intpl
      tmp = $0
      gsub(/\\`/, "", tmp)
      n = gsub(/`/, "", tmp)
      if (n % 2 == 1) intpl = !intpl
      if (start_in_tpl) next
    }
    /^export[[:space:]]+(default[[:space:]]+)?function[[:space:]]+\*?[A-Za-z_$][A-Za-z0-9_$]*[[:space:]]*\(/ {
      t = $0
      sub(/^export[[:space:]]+/, "", t)
      sub(/^default[[:space:]]+/, "", t)
      sub(/^function[[:space:]]+/, "", t)
      sub(/^\*[[:space:]]*/, "", t)
      match(t, /^[A-Za-z_$][A-Za-z0-9_$]*/)
      if (RLENGTH > 0) print substr(t, RSTART, RLENGTH)
      next
    }
    /^export[[:space:]]+(default[[:space:]]+)?const[[:space:]]+[A-Za-z_$][A-Za-z0-9_$]*[[:space:]]*=[[:space:]]*(\([^()]*\)|[A-Za-z_$][A-Za-z0-9_$]*)[[:space:]]*=>/ {
      t = $0
      sub(/^export[[:space:]]+/, "", t)
      sub(/^default[[:space:]]+/, "", t)
      sub(/^const[[:space:]]+/, "", t)
      match(t, /^[A-Za-z_$][A-Za-z0-9_$]*/)
      if (RLENGTH > 0) print substr(t, RSTART, RLENGTH)
      next
    }
    /^(export[[:space:]]+(default[[:space:]]+)?)?class[[:space:]]+[A-Za-z_$][A-Za-z0-9_$]*/ {
      t = $0
      sub(/^export[[:space:]]+/, "", t)
      sub(/^default[[:space:]]+/, "", t)
      sub(/^class[[:space:]]+/, "", t)
      match(t, /^[A-Za-z_$][A-Za-z0-9_$]*/)
      if (RLENGTH > 0) print substr(t, RSTART, RLENGTH)
      next
    }
  ' "$1"
}

# Python: def y class de nivel superior (columna 0; indentado = método/anidado, se omite).
# Endurecimiento adversarial: se rastrea paridad de """ y de ''' por separado; si una
# línea ARRANCA dentro de un docstring/triple-quoted string, se omite su captura
# (solo se actualiza la paridad) para no inventar símbolos que en realidad son texto.
extract_py() {
  awk -v triq="'''" '
    BEGIN { dq = 0; sq = 0 }
    {
      gsub(/\r$/, "")
      start_in_str = (dq || sq)
      tmp = $0
      ndq = gsub(/"""/, "", tmp)
      if (ndq % 2 == 1) dq = !dq
      tmp2 = $0
      nsq = gsub(triq, "", tmp2)
      if (nsq % 2 == 1) sq = !sq
      if (start_in_str) next
    }
    /^def[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(/ {
      t = $0
      sub(/^def[[:space:]]+/, "", t)
      match(t, /^[A-Za-z_][A-Za-z0-9_]*/)
      if (RLENGTH > 0) print substr(t, RSTART, RLENGTH)
      next
    }
    /^class[[:space:]]+[A-Za-z_][A-Za-z0-9_]*/ {
      t = $0
      sub(/^class[[:space:]]+/, "", t)
      match(t, /^[A-Za-z_][A-Za-z0-9_]*/)
      if (RLENGTH > 0) print substr(t, RSTART, RLENGTH)
      next
    }
  ' "$1"
}

# Bash: funciones con `function nombre` o `nombre()`, de nivel superior (columna 0).
extract_sh() {
  awk '
    { gsub(/\r$/, "") }
    /^function[[:space:]]+[A-Za-z_][A-Za-z0-9_]*/ {
      t = $0
      sub(/^function[[:space:]]+/, "", t)
      match(t, /^[A-Za-z_][A-Za-z0-9_]*/)
      if (RLENGTH > 0) print substr(t, RSTART, RLENGTH)
      next
    }
    /^[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\([[:space:]]*\)/ {
      match($0, /^[A-Za-z_][A-Za-z0-9_]*/)
      if (RLENGTH > 0) print substr($0, RSTART, RLENGTH)
      next
    }
  ' "$1"
}

covered=""
uncovered=""

files="$(find "$ROOT" \( -name .git -o -name node_modules -o -name .graph -o -path "$ROOT/tests/build" \) -prune -o -type f -print | LC_ALL=C sort)"

while IFS= read -r f; do
  [ -z "$f" ] && continue
  [ -r "$f" ] || continue
  rel="${f#"$ROOT"/}"
  base="$(basename "$f")"
  ext="${base##*.}"
  [ "$ext" = "$base" ] && ext=""
  [ -n "$ext" ] || continue

  if in_list "$ext" "${JS_EXT[@]}"; then
    syms="$(extract_js "$f" | join_comma)"
    [ -n "$syms" ] && covered="${covered}- \`$rel\`: $syms"$'\n'
  elif in_list "$ext" "${PY_EXT[@]}"; then
    syms="$(extract_py "$f" | join_comma)"
    [ -n "$syms" ] && covered="${covered}- \`$rel\`: $syms"$'\n'
  elif in_list "$ext" "${SH_EXT[@]}"; then
    syms="$(extract_sh "$f" | join_comma)"
    [ -n "$syms" ] && covered="${covered}- \`$rel\`: $syms"$'\n'
  elif in_list "$ext" "${UNCOVERED_EXT[@]}"; then
    uncovered="${uncovered}- \`$rel\`"$'\n'
  fi
done <<< "$files"

echo "## Símbolos por archivo"
echo "_(generado automáticamente por tools/symbol-map.sh — no editar a mano esta sección)_"
echo
if [ -n "$covered" ]; then
  printf '%s' "$covered"
else
  echo "_(sin símbolos detectados en los lenguajes cubiertos)_"
fi

if [ -n "$uncovered" ]; then
  echo
  echo "_Sin cobertura de símbolos (prosa en la sección curada):_"
  echo
  printf '%s' "$uncovered"
fi
