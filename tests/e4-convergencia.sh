#!/usr/bin/env bash
# E4 — convergencia/escalada determinista (R3-1): gate --gate-aprobado + bug
# plantado en el TEST (no en el pedido) cuyo fix "obvio" falla un caso borde,
# forzando >=2 iteraciones.
#
# Diseño "spec-by-test" (R-G): el pedido pide, sin ambigüedad de lenguaje
# natural, satisfacer tests/test_slug_e4.py TAL COMO ESTÁ — el propio test es
# la especificación, no una descripción parafraseable. Así el preflight (Fase
# 3) no tiene ningún criterio contradictorio ni decisión de diseño abierta que
# preguntar, y el gate --gate-aprobado debe quedar aprobado sin preguntas. La
# regla dura "pregunta sin respuesta firmada = bloqueo" queda INTACTA: si el
# modelo igual pregunta, este escenario falla (no se asume una respuesta) y
# eso es señal honesta de una regresión real, no un falso positivo del script.
#
# El flag --gate-aprobado lo implementa el frente R3-1 en skills/do/SKILL.md
# (docs/superpowers/specs/2026-08-31-graph-robustez-ronda-3-design.md); este
# script asume que ya existe cuando se ejecuta (integración: run-scenarios.sh).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXDIR="${GRAPH_FIXTURES_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/graph-plugin/fixtures}"
CC=(claude -p --plugin-dir "$ROOT" --dangerously-skip-permissions)

echo "— E4: convergencia con gate pre-aprobado (bug plantado en el test, Diario ≥2 filas)"

# --- precheck de entorno --------------------------------------------------
# Ningún otro escenario automatizado corre pytest en el host (make-fixtures.sh
# solo escribe pytest.ini). Si falta python3/pytest, el diagnóstico debe decir
# eso explícitamente en vez de culpar a la convergencia por un prerrequisito
# externo no declarado (roza C5: cero prerrequisitos externos).
command -v python3 >/dev/null 2>&1 \
  || { echo "FAIL E4: falta python3 en el entorno (prerrequisito no declarado)"; exit 1; }
python3 -m pytest --version >/dev/null 2>&1 \
  || { echo "FAIL E4: falta pytest en el entorno (prerrequisito no declarado)"; exit 1; }

PY="$FIXDIR/fixture-py"
# make-fixtures.sh empieza con `rm -rf "$FIXDIR"`: si ya corrió antes en esta
# suite (run-scenarios.sh lo invoca para E1-E3) volver a llamarlo aquí
# borraría fixture-js/fixture-py ya usados, destruyendo estado post-corrida
# sin necesidad. Solo se regenera si falta el fixture base.
[ -d "$PY" ] || "$ROOT/tests/make-fixtures.sh" > /dev/null
[ -d "$PY" ] || { echo "FAIL E4: falta $PY (make-fixtures.sh no lo generó)"; exit 1; }

E4="$FIXDIR/fixture-py-e4"
rm -rf "$E4"
cp -r "$PY" "$E4"

# --- bug plantado: por qué fuerza >=2 iteraciones -------------------------
# El fixture base (app/slug.py) solo minúsculas+join por espacios: no pasa
# ninguno de los dos tests nuevos tal cual, así que la primera iteración
# necesariamente escribe lógica real de slugify (RED→GREEN real, no un
# no-op). El primer intento "obvio" para "sacar tildes y puntuación" es
# borrar esos caracteres con una sustitución. Eso resuelve el caso simple
# (tildes/puntuación con espacios alrededor) pero falla el caso borde
# plantado: puntuación PEGADA a las letras, sin espacio alrededor, actuando
# de separador implícito entre palabras (p.ej. "precio/descuento: 10%").
# Borrar el "/" en vez de tratarlo como separador pega las palabras
# ("preciodescuento") en vez de separarlas con un guion. La implementación
# que sí converge trata la puntuación (y los espacios) como un único
# separador que colapsa a "-", no como ruido a eliminar. Verificado offline
# con 3 implementaciones (base sin cambios / "obvia" que borra / correcta
# que separa): la obvia pasa el primer assert y falla el segundo — fuerza
# diagnóstico + segunda iteración de forma determinista, sin depender de qué
# tan capaz sea el modelo. El test original del fixture (test_slug.py, "Hola
# Mundo") sigue en verde en las tres, así que no hay regresión que confunda
# la iteración.
cat > "$E4/tests/test_slug_e4.py" <<'EOF'
from app.slug import slugify

def test_slugify_tildes_y_puntuacion_con_espacios():
    # Caso simple: cualquier implementación que borre tildes/puntuación
    # (con espacios alrededor de por medio) ya lo resuelve.
    assert slugify("Canción, ¡Épico!") == "cancion-epico"

def test_slugify_puntuacion_como_separador_sin_espacio():
    # Caso borde plantado: puntuación pegada a las letras, sin espacio
    # alrededor, actuando de separador implícito entre palabras. Borrarla
    # (en vez de tratarla como separador) pega las palabras — la trampa
    # que fuerza una segunda iteración tras el primer intento "obvio".
    assert slugify("precio/descuento: 10%") == "precio-descuento-10"
EOF
git -C "$E4" add -A
git -C "$E4" -c user.email=fx@fx -c user.name=fx commit -qm "planta E4: test de convergencia (caso borde separador)" > /dev/null
# Hash del commit que planta el test — referencia FIJA contra la que se
# verifica más abajo que el archivo quedó intocado, sin importar cuántos
# commits produzca /graph:do después (no basta comparar contra HEAD: para
# entonces HEAD puede ya incluir los commits de la propia tarea).
PLANT_COMMIT=$(git -C "$E4" rev-parse HEAD)

# .graph/ tiene que existir antes de /graph:do en modo no interactivo (Fase 0).
(cd "$E4" && "${CC[@]}" "/graph:init refresh" > /dev/null)
git -C "$E4" add -A
git -C "$E4" -c user.email=fx@fx -c user.name=fx commit -qm "post-init e4" > /dev/null || true

# --- gate pre-aprobado (spec-by-test, sin ambigüedad de lenguaje natural) --
# El pedido remite al test tal cual está: no hay decisión de diseño abierta
# ni criterio contradictorio que el preflight deba levantar como pregunta.
# `tier: M` en el archivo cuenta como tier APROBADO EN EL GATE (R-C), no
# forzado — la escalada autónoma de la regla dura 3/4 aplica con normalidad
# si igual hay estancamiento.
# El archivo de gate se escribe FUERA del repo bajo prueba (en $FIXDIR, no
# en $E4): así no ensucia el árbol que la Fase 6 registra como efecto #0 ni
# queda expuesto a la inversa "borrar no-rastreados".
PEDIDO='quiero que app/slug.py implemente slugify de modo que tests/test_slug_e4.py (ya existe en el repo, tal cual está) pase completo con pytest, sin modificar ese archivo de test'
GATE="$FIXDIR/gate-aprobado-e4.md"
printf 'pedido: %s\napruebo: sí\ntier: M\n' "$PEDIDO" > "$GATE"

E4OUT="$ROOT/tests/graph-e4.out"
(cd "$E4" && "${CC[@]}" "/graph:do --gate-aprobado $GATE $PEDIDO") > "$E4OUT" || true

# --- aserciones de ARTEFACTOS (no de prosa) --------------------------------

mapfile -t RECS < <(find "$E4/.graph/tasks" -maxdepth 1 -name '*.md' ! -name 'README.md' 2>/dev/null | sort)
[ "${#RECS[@]}" -ge 1 ] || { echo "FAIL E4: no se generó task record en .graph/tasks/"; exit 1; }
REC="${RECS[${#RECS[@]}-1]}"

# Conteo del Diario por ESTRUCTURA: se extrae la sección '## Diario' y se
# cuentan las filas de tabla ('| ... |') que vienen DESPUÉS de la fila
# separadora ('|---|---|---|---|'), sin greps por palabras — así una celda
# que mencione "iteración" (la columna se llama justo así, skills/do/
# SKILL.md:224, y una celda de diagnóstico bien puede citar "misma causa
# raíz que la iteración anterior") no se descarta por accidente.
DIARIO_N=$(awk '/^## Diario/{f=1;next} /^## /{f=0} f' "$REC" | awk '
  !sep && /^\|[ :|-]+$/ && /-/ { sep=1; next }
  sep && /^\|/ { n++ }
  END { print n+0 }
')
[ "$DIARIO_N" -ge 2 ] || { echo "FAIL E4: Diario de $REC tiene $DIARIO_N filas (se esperaban ≥2)"; exit 1; }

# Efecto #0: la celda puede llevar '0' o '#0' (skills/do/SKILL.md llama al
# artefacto "efecto #0" en su prosa, líneas 30/122/133/166) — estricto en
# que exista la fila, tolerante en la forma exacta de la celda.
EFECTOS_0=$(awk '/^## Efectos/{f=1;next} /^## /{f=0} f' "$REC" | grep -c -E '^\| *#?0 *\|' || true)
[ "${EFECTOS_0:-0}" -ge 1 ] || { echo "FAIL E4: tabla Efectos de $REC sin fila de efecto #0"; exit 1; }

# El test plantado debe seguir INTOCADO desde que se plantó (commit
# PLANT_COMMIT): si el agente relaja el caso borde en vez de converger de
# verdad, esto lo detecta aunque el cambio ya esté commiteado.
git -C "$E4" diff --exit-code "$PLANT_COMMIT" -- tests/test_slug_e4.py > /dev/null \
  || { echo "FAIL E4: tests/test_slug_e4.py fue modificado desde que se plantó (debía quedar intocado)"; exit 1; }

# Suite COMPLETA del fixture (no solo el archivo plantado): una regresión en
# tests/test_slug.py (el test original del fixture) también debe hacer
# fallar E4.
if ! (cd "$E4" && python3 -m pytest -q); then
  echo "FAIL E4: la suite completa del fixture no terminó en verde tras la convergencia"
  exit 1
fi

[ ! -f "$E4/.graph/.lock" ] || { echo "FAIL E4: quedó .graph/.lock tras la corrida (Fase 8 debía limpiarlo)"; exit 1; }

echo "OK: E4 (task record $(basename "$REC"), Diario $DIARIO_N filas, suite del fixture verde, sin lock residual)"
