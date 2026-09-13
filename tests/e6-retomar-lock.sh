#!/usr/bin/env bash
# E6 — retomar + lock (R4-A2). Dos casos en el mismo script:
#
# Caso principal: se PLANTA un estado interrumpido (task record parcial con
# Mini-spec + Efectos #0 + Diario de exactamente 1 fila reconocible, línea
# `**En curso:**` en INDEX y `.graph/.lock` huérfano del MISMO slug) y se
# corre la MISMA tarea con gate file. Se espera que Fase 0 la reconozca como
# la misma tarea (skills/do/SKILL.md, Fase 0: "cuyo slug ... es LA MISMA
# tarea ... retómala sin preguntar"), CONTINÚE el mismo task record (nunca lo
# pise) y cierre limpio (sin .lock ni En curso).
#
# Caso lock ajeno: `.graph/.lock` de un slug AJENO, sin línea En curso y SIN
# archivo de gate — una invocación headless de OTRA tarea debe reportar el
# lock y terminar sin crear record ni mutar (Fase 0, rama ".lock ajena", modo
# no interactivo).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXDIR="${GRAPH_FIXTURES_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/graph-plugin/fixtures}"
CC=(claude -p --plugin-dir "$ROOT" --dangerously-skip-permissions)

echo "— E6: retomar tarea interrumpida (lock propio) + lock ajeno sin gate"

# --- precheck de entorno: el caso principal SÍ converge de verdad con pytest
command -v python3 >/dev/null 2>&1 \
  || { echo "FAIL E6: falta python3 en el entorno (prerrequisito no declarado)"; exit 1; }
python3 -m pytest --version >/dev/null 2>&1 \
  || { echo "FAIL E6: falta pytest en el entorno (prerrequisito no declarado)"; exit 1; }

PY="$FIXDIR/fixture-py"
[ -d "$PY" ] || "$ROOT/tests/make-fixtures.sh" > /dev/null
[ -d "$PY" ] || { echo "FAIL E6: falta $PY (make-fixtures.sh no lo generó)"; exit 1; }

# ============================================================================
# Caso principal: retomar la MISMA tarea (lock + En curso propios)
# ============================================================================

E6="$FIXDIR/fixture-py-e6"
rm -rf "$E6"
cp -r "$PY" "$E6"

(cd "$E6" && "${CC[@]}" "/graph:init refresh" > /dev/null)
git -C "$E6" add -A
git -C "$E6" -c user.email=fx@fx -c user.name=fx commit -qm "post-init e6" > /dev/null || true

# --- simula el intento interrumpido: un primer borrador REAL, ya commiteado,
# que falla el caso de nombre vacío (consistente con la fila de Diario
# plantada más abajo) — así retomar de verdad exige converger, no es un
# no-op.
cat > "$E6/app/greet.py" <<'EOF'
def saluda(nombre: str) -> str:
    return f"Hola, {nombre}!"
EOF
cat > "$E6/tests/test_greet_e6.py" <<'EOF'
from app.greet import saluda

def test_saluda_con_nombre():
    assert saluda("Ana") == "Hola, Ana!"

def test_saluda_nombre_vacio():
    assert saluda("") == "Hola!"
EOF
git -C "$E6" add -A
git -C "$E6" -c user.email=fx@fx -c user.name=fx commit -qm "intento interrumpido: primer borrador de saluda (sin manejar vacío)" > /dev/null

# Base del efecto #0: el HEAD que YA incluye el borrador y el oráculo
# commiteados — el árbol tal como queda al ENTRAR a Fase 6
# (skills/do/SKILL.md, Fase 6: "efecto #0 = base git ... al entrar a Fase 6").
# Capturarlo ANTES de este commit dejaría tests/test_greet_e6.py fuera del
# efecto #0: tools/red.sh clasificaría el oráculo del PROPIO pedido como test
# nuevo del agente, lo borraría de la copia desechable y devolvería
# oraculo_independiente:false, y la retomada cerraría con una anomalía
# espuria (bifurcación: pendiente) en vez de limpio.
BASE_COMMIT=$(git -C "$E6" rev-parse HEAD)

SLUG="e6-retoma"
TODAY="$(date +%Y-%m-%d)"
REC="$E6/.graph/tasks/${TODAY}-${SLUG}.md"
MARKER="PLANTADA-E6-FILA-RECONOCIBLE-7f2a"

# El pedido de la invocación posterior debe ser identificable por Fase 0 como
# "la misma tarea": se cita LITERAL en la Mini-spec plantada para que la
# comparación no dependa de que el modelo parafrasee correctamente.
PEDIDO='quiero que app/greet.py tenga una función saluda(nombre) que devuelva "Hola, <nombre>!" y que si el nombre viene vacío devuelva exactamente "Hola!" (sin coma ni espacio colgante), verificado por tests/test_greet_e6.py (ya existe en el repo, tal cual está) pasando completo con pytest, sin modificar ese archivo de test'
GATE="$FIXDIR/gate-e6.md"
printf 'pedido: %s\napruebo: sí\ntier: M\n' "$PEDIDO" > "$GATE"

cat > "$REC" <<EOF
# ${SLUG} · ${TODAY} · tier M

## Mini-spec aprobada
- Intención: ${PEDIDO}
- Alcance: app/greet.py + tests/test_greet_e6.py (ya existe, no modificar). Fuera: cualquier otro módulo.
- Criterios (con método): 1) \`python3 -m pytest tests/test_greet_e6.py\` pasa completo.
- Anti-criterios (con método): no tocar app/slug.py ni tests/test_slug.py (verificado con \`git diff --stat\`).
- Tier: M — un solo frente con posibilidad de fallo y corrección.
- Aprobación: aprobado por archivo \`${GATE}\`

## Efectos
| # | efecto | inversa | estado |
|---|---|---|---|
| 0 | línea base del working tree al entrar a Fase 6 = HEAD \`${BASE_COMMIT}\` (árbol limpio) | restaurar paths tocados desde \`${BASE_COMMIT}\` y borrar no-rastreados del intento; jamás toca .graph/ | activo |

## Diario
| iteración | qué se hizo | diagnóstico | resultado |
|---|---|---|---|
| 1 | ${MARKER}: primer intento de saluda(nombre), sin manejar nombre vacío | pendiente: falta caso nombre vacío | RED: test_saluda_nombre_vacio falla (\`Hola, !\` ≠ \`Hola!\`) |

## Verificación final
| criterio/anti-criterio | método | comando/procedimiento ejecutado | evidencia | ✅/❌ |
|---|---|---|---|---|

## Resultado
- Estado: en ejecución (transitorio, solo mientras la Fase 6-7 corre)
- Evidencia final:
- Commits:
- Aprendizajes:
- Amenazas a la validez:
- Preguntas tardías (runtime):
EOF

# Línea `**En curso:**` bajo la línea de estado del INDEX (mismo formato que
# escribe Fase 6 de skills/do/SKILL.md).
awk -v line="**En curso:** ${SLUG} (tier M, desde ${TODAY})" '
  { print }
  /^> Actualizado:/ && !done { print line; done=1 }
' "$E6/.graph/INDEX.md" > "$E6/.graph/INDEX.md.tmp"
mv "$E6/.graph/INDEX.md.tmp" "$E6/.graph/INDEX.md"
grep -qF "**En curso:**" "$E6/.graph/INDEX.md" || { echo "FAIL E6: no se pudo plantar la línea En curso en INDEX.md"; exit 1; }

# .graph/.lock huérfano del MISMO slug (ningún proceso vivo detrás).
printf '%s · %s\n' "$SLUG" "$(date '+%Y-%m-%d %H:%M')" > "$E6/.graph/.lock"

# --- correr la MISMA tarea ---------------------------------------------------
E6OUT="$ROOT/tests/graph-e6.out"
(cd "$E6" && "${CC[@]}" "/graph:do --gate-aprobado $GATE $PEDIDO") > "$E6OUT" || true

# --- aserciones de ARTEFACTOS (caso principal) ------------------------------

# Sigue existiendo EXACTAMENTE un task record, y es el mismo archivo plantado
# (no se creó uno nuevo en paralelo — "no se pisó el record" se verifica por
# identidad de ruta, no solo por conteo).
mapfile -t RECS < <(find "$E6/.graph/tasks" -maxdepth 1 -name '*.md' ! -name 'README.md' 2>/dev/null | sort)
[ "${#RECS[@]}" -eq 1 ] || { echo "FAIL E6: se esperaba exactamente 1 task record tras retomar, hay ${#RECS[@]}"; exit 1; }
[ "${RECS[0]}" = "$REC" ] || { echo "FAIL E6: se creó un task record nuevo (${RECS[0]}) en vez de continuar $REC"; exit 1; }

# La fila plantada del Diario SOBREVIVE textualmente.
grep -qF "$MARKER" "$REC" || { echo "FAIL E6: la fila plantada del Diario no sobrevivió en $REC (el record fue pisado)"; exit 1; }

# Existe una fila que contiene "retomada tras interrupción" (texto exacto que
# exige skills/do/SKILL.md Fase 0).
grep -qF "retomada tras interrupción" "$REC" || { echo "FAIL E6: no hay fila 'retomada tras interrupción' en $REC"; exit 1; }

# El Diario creció (estructuralmente, por awk): la fila plantada + al menos
# la de retomar.
DIARIO_N=$(awk '/^## Diario/{f=1;next} /^## /{f=0} f' "$REC" | awk '
  !sep && /^\|[ :|-]+$/ && /-/ { sep=1; next }
  sep && /^\|/ { n++ }
  END { print n+0 }
')
[ "$DIARIO_N" -ge 2 ] || { echo "FAIL E6: Diario de $REC tiene $DIARIO_N filas (se esperaban ≥2 tras retomar)"; exit 1; }

# Al cierre no queda .lock ni línea En curso.
[ ! -f "$E6/.graph/.lock" ] || { echo "FAIL E6: quedó .graph/.lock tras la corrida (Fase 8 debía limpiarlo)"; exit 1; }
! grep -qF "**En curso:**" "$E6/.graph/INDEX.md" || { echo "FAIL E6: quedó línea En curso en INDEX.md tras el cierre"; exit 1; }

# Una retomada limpia no deja deuda de anomalías. Estas dos aserciones son
# las que DISCRIMINAN el baseline plantado: si el efecto #0 del record se
# capturara antes del commit del "intento interrumpido", tools/red.sh vería
# el oráculo del propio pedido (tests/test_greet_e6.py) como test nuevo del
# agente y devolvería oraculo_independiente:false — divergencia que la regla
# dura 8 obliga a registrar, y que en modo --gate-aprobado cierra con
# `bifurcación: pendiente` en el record y `**Anomalías pendientes:**` en
# INDEX. Sin estas dos líneas, E6 pasaría igual con el plantado incoherente.
! grep -qF '**Anomalías pendientes:**' "$E6/.graph/INDEX.md" || { echo "FAIL E6: quedó la línea **Anomalías pendientes:** en INDEX.md tras el cierre (una retomada limpia no deja deuda de anomalías)"; exit 1; }
! grep -qF 'bifurcación: pendiente' "$REC" || { echo "FAIL E6: el record $REC quedó con 'bifurcación: pendiente' (una retomada limpia no deja deuda de anomalías)"; exit 1; }

# La convergencia fue real: la suite completa del fixture queda en verde.
if ! (cd "$E6" && python3 -m pytest -q); then
  echo "FAIL E6: la suite completa del fixture no terminó en verde tras retomar"
  exit 1
fi

# ============================================================================
# Caso lock ajeno: sin gate file, otra tarea, debe reportar y no mutar
# ============================================================================

E6B="$FIXDIR/fixture-py-e6-ajeno"
rm -rf "$E6B"
cp -r "$PY" "$E6B"

(cd "$E6B" && "${CC[@]}" "/graph:init refresh" > /dev/null)
git -C "$E6B" add -A
git -C "$E6B" -c user.email=fx@fx -c user.name=fx commit -qm "post-init e6-ajeno" > /dev/null || true

AJENO_SLUG="otra-tarea-viva"
AJENO_LOCK_LINE="${AJENO_SLUG} · $(date '+%Y-%m-%d %H:%M')"
printf '%s\n' "$AJENO_LOCK_LINE" > "$E6B/.graph/.lock"
# Deliberadamente SIN línea En curso en INDEX: aísla el ejercicio a la rama
# de ".lock ajeno" de Fase 0, no a la rama de "En curso ajeno" (son dos
# preguntas distintas del mismo skill).

PEDIDO_AJENO='quiero que app/greet.py tenga un docstring de una línea explicando qué hace saluda'
E6BOUT="$ROOT/tests/graph-e6-ajeno.out"
(cd "$E6B" && "${CC[@]}" "/graph:do $PEDIDO_AJENO") > "$E6BOUT" || true

# La salida reporta el lock (contenido del lock, tal cual, per Fase 0).
# Limitación conocida: esta es la ÚNICA aserción que discrimina la rama de
# lock ajeno (las de no-mutación pasarían igual por la regla dura 7 sola).
grep -qF "$AJENO_SLUG" "$E6BOUT" || { echo "FAIL E6-ajeno: la salida no menciona el slug del lock ajeno ($AJENO_SLUG)"; exit 1; }

# No se creó task record.
if ls "$E6B/.graph/tasks" 2>/dev/null | grep -qv '^README\.md$'; then
  echo "FAIL E6-ajeno: se creó un task record pese al lock ajeno sin resolver"; exit 1
fi

# Sin mutación fuera de .graph/ preexistente.
mutb=$(cd "$E6B" && git status --porcelain | grep -v '\.graph/' || true)
[ -z "$mutb" ] || { echo "FAIL E6-ajeno: mutó el repo pese al lock ajeno: $mutb"; exit 1; }

# El lock ajeno sigue intacto (nadie debía tocarlo: no es el dueño).
[ -f "$E6B/.graph/.lock" ] || { echo "FAIL E6-ajeno: el .lock ajeno desapareció (nadie debía romperlo sin decisión del usuario)"; exit 1; }
grep -qF "$AJENO_LOCK_LINE" "$E6B/.graph/.lock" || { echo "FAIL E6-ajeno: el contenido del .lock ajeno cambió"; exit 1; }

echo "OK: E6 (retomar: record único con fila plantada + retomada tras interrupción, Diario $DIARIO_N filas, sin lock/En curso, suite verde; lock ajeno: reportado, sin record ni mutación)"
