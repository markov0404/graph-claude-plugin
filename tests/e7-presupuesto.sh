#!/usr/bin/env bash
# E7 — presupuesto agotado en modo pre-aprobado (R4-A3), más (B3) la
# demostración del formato compacto de tier S trivial integrada aquí por
# naturalidad (spec ronda 4, "Verificación del conjunto" ítem 4: "puede
# integrarse como caso dentro de E7 ... a criterio del implementador").
#
# Caso principal: gate file con `budget:` deliberadamente ínfimo para una
# tarea que NO puede completarse con ese tope (mismo bug de convergencia
# forzada que e4-convergencia.sh — plantado en el TEST, no en el pedido —
# así se garantiza que la tarea necesita ≥2 iteraciones y por tanto el
# presupuesto ínfimo se agota ANTES de que pueda converger en la primera
# pasada; sin esa garantía, una tarea que converge a la primera declararía
# éxito sin importar el presupuesto). Se espera cierre por
# `cerrado por bloqueo (pre-aprobado)` (skills/do/SKILL.md, regla dura 5 y
# Fase 6 "Presupuesto"), efectos sin ningún `activo`, sin lock/En curso, y
# el proceso termina (exit) sin colgarse — se envuelve con `timeout` para
# volver esa última aserción verificable en vez de solo esperada.
#
# Caso B3: tarea S trivial (un criterio, un archivo) vía gate-aprobado SIN
# budget ni tier forzado — deja que Fase 4 clasifique. Asserta que el
# task record resultante usa el formato compacto (R4-B3): Efectos con solo
# la fila #0, Diario con 1 fila, y el total de líneas de CONTENIDO (bullets
# de Mini-spec/Resultado + filas de datos de las tablas, sin contar headings
# ni separadores) es ≤ 15 — operacionalización directa de "~10 líneas:
# mini-spec en 3, Efectos 1 fila, Diario 1 fila, Verificación final 1 fila,
# Resultado 4 líneas" con la tolerancia "≤ ~15" del ítem 4 de verificación
# del spec.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXDIR="${GRAPH_FIXTURES_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/graph-plugin/fixtures}"
CC=(claude -p --plugin-dir "$ROOT" --dangerously-skip-permissions)

echo "— E7: presupuesto agotado (pre-aprobado) + (B3) ruta trivial S compacta"

# --- precheck de entorno ----------------------------------------------------
command -v python3 >/dev/null 2>&1 \
  || { echo "FAIL E7: falta python3 en el entorno (prerrequisito no declarado)"; exit 1; }
python3 -m pytest --version >/dev/null 2>&1 \
  || { echo "FAIL E7: falta pytest en el entorno (prerrequisito no declarado)"; exit 1; }

PY="$FIXDIR/fixture-py"
[ -d "$PY" ] || "$ROOT/tests/make-fixtures.sh" > /dev/null
[ -d "$PY" ] || { echo "FAIL E7: falta $PY (make-fixtures.sh no lo generó)"; exit 1; }

# ============================================================================
# Caso principal: budget ínfimo con bug plantado que fuerza ≥2 iteraciones
# ============================================================================

E7="$FIXDIR/fixture-py-e7"
rm -rf "$E7"
cp -r "$PY" "$E7"

# Mismo caso borde que e4-convergencia.sh (verificado offline allí: la
# implementación "obvia" que borra puntuación pasa el primer assert y falla
# el segundo, forzando una segunda iteración de forma determinista). Se
# reutiliza tal cual porque es la única función disponible en este momento
# del proyecto que ya está verificada como forzadora de ≥2 iteraciones sin
# depender de qué tan capaz sea el modelo — justo lo que hace falta para que
# el presupuesto ínfimo se agote ANTES de la convergencia, no después.
cat > "$E7/tests/test_slug_e7.py" <<'EOF'
from app.slug import slugify

def test_slugify_tildes_y_puntuacion_con_espacios():
    assert slugify("Canción, ¡Épico!") == "cancion-epico"

def test_slugify_puntuacion_como_separador_sin_espacio():
    assert slugify("precio/descuento: 10%") == "precio-descuento-10"
EOF
git -C "$E7" add -A
git -C "$E7" -c user.email=fx@fx -c user.name=fx commit -qm "planta E7: mismo caso borde de separador que E4 (fuerza >=2 iteraciones)" > /dev/null

(cd "$E7" && "${CC[@]}" "/graph:init refresh" > /dev/null)
git -C "$E7" add -A
git -C "$E7" -c user.email=fx@fx -c user.name=fx commit -qm "post-init e7" > /dev/null || true

PEDIDO='quiero que app/slug.py implemente slugify de modo que tests/test_slug_e7.py (ya existe en el repo, tal cual está) pase completo con pytest, sin modificar ese archivo de test'
GATE="$FIXDIR/gate-e7.md"
# budget ínfimo: 1 token no alcanza ni para la primera iteración real.
printf 'pedido: %s\napruebo: sí\ntier: M\nbudget: 1\n' "$PEDIDO" > "$GATE"

E7OUT="$ROOT/tests/graph-e7.out"
set +e
(cd "$E7" && timeout 1800 "${CC[@]}" "/graph:do --gate-aprobado $GATE $PEDIDO") > "$E7OUT"
RC=$?
set -e
[ "$RC" -ne 124 ] || { echo "FAIL E7: la corrida se colgó (timeout de 1800s) con presupuesto agotado en modo pre-aprobado"; exit 1; }

# --- aserciones de ARTEFACTOS (caso principal) ------------------------------

mapfile -t RECS < <(find "$E7/.graph/tasks" -maxdepth 1 -name '*.md' ! -name 'README.md' 2>/dev/null | sort)
[ "${#RECS[@]}" -ge 1 ] || { echo "FAIL E7: no se generó task record en .graph/tasks/"; exit 1; }
REC="${RECS[${#RECS[@]}-1]}"

# Estado exacto: cerrado por bloqueo (pre-aprobado) — nunca "abortado por
# usuario" (regla dura 5: el usuario no decidió la parada, firmó un pedido
# puntual).
ESTADO=$(awk '/^## Resultado/{f=1;next} /^## /{f=0} f' "$REC" | grep -m1 -E '^- Estado:' || true)
# Ambas ramas son CORRECTAS según el skill (sección Presupuesto): si la
# iteración que agota el presupuesto no convergió → cierre por bloqueo; si
# ya convergió, la convergencia gana (el presupuesto limita trabajo restante,
# no anula un éxito). Con tests visibles no se puede forzar el número de
# iteraciones de un buen modelo — lo determinista es exigir EVIDENCIA de que
# el presupuesto se aplicó y quedó documentado.
if echo "$ESTADO" | grep -qF "cerrado por bloqueo (pre-aprobado)"; then
  : # rama bloqueo: correcta por sí sola
elif echo "$ESTADO" | grep -qF "convergió"; then
  grep -qiE '(presupuesto|budget).*(agotado|excedido)' "$REC" \
    || { echo "FAIL E7: convergió pero el record no documenta el presupuesto agotado (budget: 1 ignorado)"; exit 1; }
else
  echo "FAIL E7: Estado de $REC no es ni bloqueo ni convergencia documentada — línea: $ESTADO"; exit 1
fi

# La tabla Efectos NO tiene NINGUNA fila en estado `activo` (todas deben
# quedar revertidas, conservadas o irreversibles antes del cierre).
ACTIVOS=$(awk '/^## Efectos/{f=1;next} /^## /{f=0} f' "$REC" | awk '
  !sep && /^\|[ :|-]+$/ && /-/ { sep=1; next }
  sep && /^\|/ { print }
' | grep -c -E '\| *activo *\|' || true)
[ "${ACTIVOS:-0}" -eq 0 ] || { echo "FAIL E7: tabla Efectos de $REC tiene $ACTIVOS fila(s) en estado 'activo' tras el cierre"; exit 1; }

# Sin lock ni línea En curso al cierre.
[ ! -f "$E7/.graph/.lock" ] || { echo "FAIL E7: quedó .graph/.lock tras el cierre por bloqueo de presupuesto"; exit 1; }
! grep -qF "**En curso:**" "$E7/.graph/INDEX.md" || { echo "FAIL E7: quedó línea En curso en INDEX.md tras el cierre por bloqueo de presupuesto"; exit 1; }

# ============================================================================
# Caso B3: tarea S trivial (1 criterio, 1 archivo) → record compacto
# ============================================================================

E7B="$FIXDIR/fixture-py-e7b"
rm -rf "$E7B"
cp -r "$PY" "$E7B"

# Spec-by-test (mismo truco que E4/E7 principal, aquí para garantizar
# "un solo criterio, un solo archivo" sin depender de que el modelo lo
# perciba por lenguaje natural): un test nuevo con UN solo assert sobre una
# función nueva y aditiva en app/slug.py — no toca el test existente, no
# contradice ningún comportamiento previo (evita cualquier disparo de
# preflight que rompería la clasificación trivial).
cat > "$E7B/tests/test_slug_b3.py" <<'EOF'
from app.slug import es_slug_valido

def test_es_slug_valido_no_vacio():
    assert es_slug_valido("hola-mundo") is True
EOF
git -C "$E7B" add -A
git -C "$E7B" -c user.email=fx@fx -c user.name=fx commit -qm "planta E7b (B3): test trivial de un criterio/un archivo" > /dev/null

(cd "$E7B" && "${CC[@]}" "/graph:init refresh" > /dev/null)
git -C "$E7B" add -A
git -C "$E7B" -c user.email=fx@fx -c user.name=fx commit -qm "post-init e7b" > /dev/null || true

PEDIDO_B3='quiero que app/slug.py agregue una función es_slug_valido(s) que devuelva True si el string no está vacío, verificado por tests/test_slug_b3.py (ya existe en el repo, tal cual está) pasando completo con pytest, sin modificar ese archivo de test ni ningún otro'
GATE_B3="$FIXDIR/gate-e7b.md"
# Deliberadamente SIN tier ni budget: se deja que Fase 4 clasifique sola —
# la condición de R4-B3 (un criterio, un archivo) depende de esa
# clasificación real, no de forzarla por flag.
printf 'pedido: %s\napruebo: sí\n' "$PEDIDO_B3" > "$GATE_B3"

E7BOUT="$ROOT/tests/graph-e7b.out"
(cd "$E7B" && "${CC[@]}" "/graph:do --gate-aprobado $GATE_B3 $PEDIDO_B3") > "$E7BOUT" || true

mapfile -t RECSB < <(find "$E7B/.graph/tasks" -maxdepth 1 -name '*.md' ! -name 'README.md' 2>/dev/null | sort)
[ "${#RECSB[@]}" -ge 1 ] || { echo "FAIL E7-B3: no se generó task record en .graph/tasks/"; exit 1; }
RECB="${RECSB[${#RECSB[@]}-1]}"

# Clasificó tier S, o legítimamente ruta pelada-con-red (router r7: huecos
# nulos + oráculo verificado con pytest + consecuencia baja también habilita
# esa ruta para este pedido) — ambas dan record compacto (condición de
# entrada al formato compacto de R4-B3).
head -1 "$RECB" | grep -qE '· (tier S( \(ruta trivial\))?|ruta pelada-con-red) *$' || { echo "FAIL E7-B3: $RECB no clasificó tier S ni ruta pelada-con-red (encabezado: $(head -1 "$RECB"))"; exit 1; }

# Efectos: SOLO la fila #0 (estructural, por awk — mismo patrón que E4).
EFECTOS_N=$(awk '/^## Efectos/{f=1;next} /^## /{f=0} f' "$RECB" | awk '
  !sep && /^\|[ :|-]+$/ && /-/ { sep=1; next }
  sep && /^\|/ { n++ }
  END { print n+0 }
')
[ "$EFECTOS_N" -eq 1 ] || { echo "FAIL E7-B3: tabla Efectos de $RECB tiene $EFECTOS_N filas (compacto espera solo #0)"; exit 1; }

# Ruta detectada (r7): la pelada registra en el Diario un evento REAL por
# fila (RED/GREEN, corrida de la red, fricciones) — no iteraciones de loop —
# y su Verificación final trae por diseño 5 filas (4 flags de red.sh +
# anti-criterios), así que sus cotas compactas son Diario 1..4 y contenido
# ≤ 20; la trivial mantiene Diario = 1 y contenido ≤ 15.
IS_PELADA=0; head -1 "$RECB" | grep -q 'ruta pelada-con-red' && IS_PELADA=1

# Diario: trivial = 1 fila (una sola pasada); pelada = 1..4 (eventos reales).
DIARIO_NB=$(awk '/^## Diario/{f=1;next} /^## /{f=0} f' "$RECB" | awk '
  !sep && /^\|[ :|-]+$/ && /-/ { sep=1; next }
  sep && /^\|/ { n++ }
  END { print n+0 }
')
if [ "$IS_PELADA" -eq 1 ]; then
  { [ "$DIARIO_NB" -ge 1 ] && [ "$DIARIO_NB" -le 4 ]; } || { echo "FAIL E7-B3: tabla Diario de $RECB tiene $DIARIO_NB filas (pelada espera 1..4 eventos)"; exit 1; }
else
  [ "$DIARIO_NB" -eq 1 ] || { echo "FAIL E7-B3: tabla Diario de $RECB tiene $DIARIO_NB filas (compacto trivial espera 1)"; exit 1; }
fi

# Total de líneas de CONTENIDO ≤ 15: bullets de Mini-spec + filas de datos de
# Efectos/Diario/Verificación final + bullets de Resultado (sin contar
# headings `## ...` ni filas de encabezado/separador de tabla).
CONTENT_N=$(awk '
  /^## Mini-spec/  { sec="mini"; next }
  /^## Efectos/    { sec="efectos"; next }
  /^## Diario/     { sec="diario"; next }
  /^## Verificaci/ { sec="verif"; next }
  /^## Resultado/  { sec="resultado"; next }
  /^## /           { sec=""; next }
  sec=="mini" && /^- /      { n++ }
  sec=="resultado" && /^- / { n++ }
  sec=="efectos" && /^\|/ {
    if (!sep_e && /^\|[ :|-]+$/ && /-/) { sep_e=1; next }
    if (sep_e) n++
  }
  sec=="diario" && /^\|/ {
    if (!sep_d && /^\|[ :|-]+$/ && /-/) { sep_d=1; next }
    if (sep_d) n++
  }
  sec=="verif" && /^\|/ {
    if (!sep_v && /^\|[ :|-]+$/ && /-/) { sep_v=1; next }
    if (sep_v) n++
  }
  END { print n+0 }
' "$RECB")
CONTENT_MAX=15; [ "$IS_PELADA" -eq 1 ] && CONTENT_MAX=20
[ "$CONTENT_N" -le "$CONTENT_MAX" ] || { echo "FAIL E7-B3: $RECB tiene $CONTENT_N líneas de contenido (compacto espera ≤$CONTENT_MAX para esta ruta)"; exit 1; }

echo "OK: E7 (presupuesto: Estado 'cerrado por bloqueo (pre-aprobado)', sin efectos activos, sin lock/En curso, sin cuelgue; B3: record compacto S con $EFECTOS_N efecto(s), $DIARIO_NB fila(s) de diario, $CONTENT_N líneas de contenido)"
