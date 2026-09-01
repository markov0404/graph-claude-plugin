#!/usr/bin/env bash
# E5 — bloqueo por pregunta sin firmar (R4-A1): gate --gate-aprobado cuyo
# `pedido:` coincide y trae `apruebo: sí`, pero el pedido fuerza una decisión
# de diseño abierta y deliberada que el archivo de gate NO responde.
#
# Diseño: el pedido no deja la ambigüedad implícita en lenguaje natural (eso
# dependería del criterio del modelo para detectarla) — la declara de forma
# EXPLÍCITA como una decisión que el propio usuario dice no poder resolver
# solo y pide que se le pregunte, con dos alternativas igual de válidas y
# mutuamente excluyentes, sin ningún criterio en el repo para preferir una.
# Así el preflight (Fase 3) tiene máxima probabilidad de listarla en
# "Necesito de ti"; y como el archivo de gate NO trae respuesta a esa
# pregunta, Fase 5 exige tratarlo como bloqueo (nunca asumir una respuesta):
# "Si falta la respuesta a alguna pregunta: es bloqueo ... se presenta la
# pantalla y termina" (skills/do/SKILL.md, Fase 5). Si el modelo igual
# procede sin preguntar, este escenario falla — señal honesta de una
# regresión real en la regla dura 7, no un falso positivo del script (mismo
# principio de diseño que E4).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXDIR="${GRAPH_FIXTURES_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/graph-plugin/fixtures}"
CC=(claude -p --plugin-dir "$ROOT" --dangerously-skip-permissions)

echo "— E5: bloqueo por pregunta sin respuesta firmada (gate-aprobado con decisión abierta sin responder)"

# --- fixture base ----------------------------------------------------------
PY="$FIXDIR/fixture-py"
# make-fixtures.sh empieza con `rm -rf "$FIXDIR"`: no volver a invocarlo si
# el fixture base ya existe (mismo cuidado que e4-convergencia.sh).
[ -d "$PY" ] || "$ROOT/tests/make-fixtures.sh" > /dev/null
[ -d "$PY" ] || { echo "FAIL E5: falta $PY (make-fixtures.sh no lo generó)"; exit 1; }

E5="$FIXDIR/fixture-py-e5"
rm -rf "$E5"
cp -r "$PY" "$E5"

# .graph/ tiene que existir antes de /graph:do en modo no interactivo (Fase 0).
(cd "$E5" && "${CC[@]}" "/graph:init refresh" > /dev/null)
git -C "$E5" add -A
git -C "$E5" -c user.email=fx@fx -c user.name=fx commit -qm "post-init e5" > /dev/null || true

# --- pedido con decisión abierta deliberada, sin criterio para elegir ------
PEDIDO='quiero que app/slug.py trunque el slug resultante a una longitud máxima cuando el texto de entrada es muy largo. Tengo una decisión de diseño abierta que no puedo resolver yo mismo y quiero que el sistema me pregunte antes de tocar nada: si trunca, ¿debe cortar en un límite duro de caracteres (pudiendo partir una palabra a la mitad) o debe recortar a la palabra completa más cercana al límite (pudiendo quedar más corto)? Ambas son válidas y mutuamente excluyentes, cambian el resultado en casos borde, y no hay ningún criterio en .graph/conventions.md ni .graph/map.md que decida por mí'

# El archivo de gate coincide TEXTUALMENTE con el pedido (Fase 0/5 recortan
# solo espacios/tabs de los extremos y el salto de línea final) y trae
# `apruebo: sí`, pero deliberadamente SIN ninguna respuesta a la pregunta de
# "Necesito de ti" que el preflight debe anticipar — el bloqueo que este
# escenario ejercita.
GATE="$FIXDIR/gate-e5.md"
printf 'pedido: %s\napruebo: sí\n' "$PEDIDO" > "$GATE"

E5OUT="$ROOT/tests/graph-e5.out"
(cd "$E5" && "${CC[@]}" "/graph:do --gate-aprobado $GATE $PEDIDO") > "$E5OUT" || true

# --- aserciones de ARTEFACTOS (no de prosa) --------------------------------

# NO existe task record nuevo (solo README.md, si acaso).
if ls "$E5/.graph/tasks" 2>/dev/null | grep -qv '^README\.md$'; then
  echo "FAIL E5: se creó un task record pese al bloqueo por pregunta sin firmar"; exit 1
fi

# git status limpio fuera de .graph/ preexistente (nada se ejecutó).
mut=$(cd "$E5" && git status --porcelain | grep -v '\.graph/' || true)
[ -z "$mut" ] || { echo "FAIL E5: mutó el repo pese al bloqueo: $mut"; exit 1; }

# Sin .graph/.lock (Fase 6, que crea el lock, nunca debió alcanzarse).
[ ! -f "$E5/.graph/.lock" ] || { echo "FAIL E5: quedó .graph/.lock pese al bloqueo (no debía llegar a Fase 6)"; exit 1; }

# La salida contiene la pantalla del gate (el sistema presentó y terminó).
grep -qiE "gate|apruéb|aprobar|necesito de ti" "$E5OUT" || { echo "FAIL E5: la salida no contiene la pantalla del gate"; exit 1; }

echo "OK: E5 (sin task record, sin mutación, sin lock, pantalla de gate presente)"
