#!/usr/bin/env bash
# E8 — la ESCALACIÓN de la ruta pelada-con-red, ejercitada de verdad.
#
# Por qué existe: hasta 2026-09-06 ninguna corrida del proyecto disparó
# jamás la escalación, y ningún test la ejercitaba (verificado por grep
# sobre bench/, .graph/ y tests/). Toda la medición de las configs R y E
# —las mejores del proyecto— descansa sobre una red que, si detecta
# suciedad, debe revertir por el ledger y reiniciar limpio en el pipeline
# completo. Ese camino existía solo en prosa.
#
# Disparador (plantado en el FIXTURE, no en el pedido — mismo principio que
# E4/E7): el pedido es legítimo y de una sola pieza, pero un consumidor
# INDIRECTO (`app/report.py`, con su propio test) fija el comportamiento
# viejo de `slugify`. La implementación correcta y en scope pone la suite
# COMPLETA en rojo sin que el agente toque un solo test → `suite_verde`
# false → sucio → escalación. Es el caso real para el que la red existe:
# un cambio que se ve local y rompe algo aguas arriba.
#
# Tres desenlaces posibles, y el test los distingue en vez de confundirlos:
#   1. tomó pelada, la red vio sucio y escaló bien   → OK (se assertan los invariantes)
#   2. ruteó al pipeline completo desde el vamos      → INCONCLUSO (la escalación
#      es inalcanzable por este camino; se reporta, NO se aprueba en silencio)
#   3. tomó pelada y la escalación salió malformada   → FAIL
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXDIR="${GRAPH_FIXTURES_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/graph-plugin/fixtures}"
CC=(claude -p --plugin-dir "$ROOT" --dangerously-skip-permissions)

echo "— E8: escalación de la ruta pelada-con-red (suite roja por acoplamiento indirecto)"

command -v python3 >/dev/null 2>&1 || { echo "FAIL E8: falta python3"; exit 1; }
python3 -m pytest --version >/dev/null 2>&1 || { echo "FAIL E8: falta pytest"; exit 1; }

PY="$FIXDIR/fixture-py"
[ -d "$PY" ] || "$ROOT/tests/make-fixtures.sh" > /dev/null

caso_a() {
E8="$FIXDIR/fixture-py-e8"
rm -rf "$E8"; cp -r "$PY" "$E8"

# Consumidor indirecto: usa slugify y su test fija el comportamiento VIEJO
# (guión bajo NO se separa). Nada en él nombra al pedido.
cat > "$E8/app/report.py" <<'EOF'
from app.slug import slugify


def etiqueta(texto: str) -> str:
    return f"id_{slugify(texto)}"
EOF
cat > "$E8/tests/test_report.py" <<'EOF'
from app.report import etiqueta


def test_etiqueta_conserva_guion_bajo():
    assert etiqueta("mi_nota") == "id_mi_nota"
EOF
# Oráculo del pedido: un test nuevo, un solo assert, sobre el área en scope.
cat > "$E8/tests/test_slug_underscore.py" <<'EOF'
from app.slug import slugify


def test_slugify_separa_guion_bajo():
    assert slugify("mi_nota") == "mi-nota"
EOF
git -C "$E8" add -A
git -C "$E8" -c user.email=fx@fx -c user.name=fx commit -qm "planta E8: consumidor indirecto + oráculo del pedido" >/dev/null

(cd "$E8" && "${CC[@]}" "/graph:init refresh" >/dev/null)
git -C "$E8" add -A
git -C "$E8" -c user.email=fx@fx -c user.name=fx commit -qm "post-init e8" >/dev/null || true
BASE=$(git -C "$E8" rev-parse HEAD)

PEDIDO='quiero que app/slug.py trate el guión bajo como separador en slugify, verificado por tests/test_slug_underscore.py (ya existe en el repo, tal cual está) pasando, con la suite completa corriendo con python3 -m pytest desde la raíz del repo, sin modificar ningún archivo de test'
GATE="$FIXDIR/gate-e8.md"
printf 'pedido: %s\napruebo: sí\n' "$PEDIDO" > "$GATE"

OUT="$ROOT/tests/graph-e8.out"
(cd "$E8" && "${CC[@]}" "/graph:do --gate-aprobado $GATE $PEDIDO") > "$OUT" 2>&1 || true

mapfile -t RECS < <(find "$E8/.graph/tasks" -maxdepth 1 -name '*.md' ! -name 'README.md' | sort)
if [ "${#RECS[@]}" -eq 0 ]; then
  # Cuarto desenlace, observado el 2026-09-06: el preflight detectó el conflicto
  # ANTES de ejecutar (la suite ya venía 1 failed, y el pedido choca con
  # tests/test_report.py), preguntó y bloqueó con el repo intacto. Es conducta
  # CORRECTA — regla dura 5 y hueco→pregunta del gate — pero significa que la
  # trampa no alcanza la red: no hay ejecución, así que no hay nada que ensuciar.
  if grep -qi 'no hubo aprobación\|gate\b' "$OUT" 2>/dev/null && [ ! -f "$E8/.graph/.lock" ]; then
    echo "INCONCLUSO E8-A: el preflight bloqueó en el gate antes de ejecutar (repo intacto, sin record ni lock)."
    echo "  Conducta correcta, pero la escalación NO se ejercitó: para llegar a la red hace falta"
    echo "  suciedad que la LECTURA no pueda anticipar, y este acoplamiento sí era legible."
    echo "  El manejador de escalación se valida aparte, por inyección de fallo (E8-B)."
    return 2
  fi
  echo "FAIL E8: no se generó task record y tampoco hubo bloqueo declarado en el gate"; return 1
fi

# INVARIANTE 1 — un solo record: la escalación EXTIENDE, no abre uno nuevo.
[ "${#RECS[@]}" -eq 1 ] || { echo "FAIL E8: se generaron ${#RECS[@]} task records; la escalación debe EXTENDER el existente, no abrir otro"; printf '  %s\n' "${RECS[@]}"; return 1; }
REC="${RECS[0]}"

RUTA_PELADA=0; head -1 "$REC" | grep -q 'ruta pelada-con-red' && RUTA_PELADA=1
ESCALO=0; grep -q '^## Escalación a pipeline completo' "$REC" && ESCALO=1

if [ "$RUTA_PELADA" -eq 0 ]; then
  echo "INCONCLUSO E8: la tarea NO tomó la ruta pelada (encabezado: $(head -1 "$REC"))."
  echo "  El router mandó al pipeline completo, así que la escalación no se ejercitó."
  echo "  No es un fallo del pipeline, pero SÍ deja el camino sin validar: el acoplamiento"
  echo "  indirecto fue visible en Fase 0.5 y hay que hacerlo menos visible para forzar la red."
  return 2
fi

[ "$ESCALO" -eq 1 ] || { echo "FAIL E8: tomó la ruta pelada pero el record no tiene la sección '## Escalación a pipeline completo'; la suite completa queda roja por tests/test_report.py y la red debía marcar sucio"; return 1; }

# INVARIANTE 2 — un solo salto de ruta.
N_ESC=$(grep -c '^## Escalación a pipeline completo' "$REC")
[ "$N_ESC" -eq 1 ] || { echo "FAIL E8: $N_ESC secciones de escalación en el record; el contrato admite UN solo salto pelada→completa"; return 1; }

# INVARIANTE 3 — sin efectos activos al cierre (el ledger se revirtió o se cerró).
ACTIVOS=$(awk '/^## Efectos/{f=1;next} /^## /{f=0} f && /^\|/ && /activo/{n++} END{print n+0}' "$REC")
[ "$ACTIVOS" -eq 0 ] || { echo "FAIL E8: quedan $ACTIVOS efecto(s) en estado 'activo' tras la escalación; el reinicio limpio revierte por el ledger"; return 1; }

# INVARIANTE 4 — un solo gate: la aprobación cubre AMBAS rutas, no se pide otra.
grep -q "aprobado por archivo" "$REC" || { echo "FAIL E8: el record no declara la aprobación por archivo; la cláusula de escalación viaja en el MISMO gate y no debe pedirse una segunda aprobación"; return 1; }

# INVARIANTE 5 — el scope no se amplía: fuera de .graph/, solo app/slug.py.
FUERA=$(git -C "$E8" status --porcelain | awk '{print $2}' | grep -v '^\.graph/' | grep -v '^$' || true)
SOBRA=$(printf '%s\n' "$FUERA" | grep -v '^app/slug.py$' | grep -v '^$' || true)
[ -z "$SOBRA" ] || { echo "FAIL E8: la escalación amplió el scope; paths tocados fuera de app/slug.py:"; printf '  %s\n' $SOBRA; return 1; }

# INVARIANTE 6 — ningún test fue tocado, ni antes ni después de escalar.
TESTS_TOCADOS=$(git -C "$E8" diff --name-only "$BASE" -- tests/ | grep -c . || true)
[ "$TESTS_TOCADOS" -eq 0 ] || { echo "FAIL E8: $TESTS_TOCADOS archivo(s) de test modificados; los tests son intocables en ambas rutas"; return 1; }

# INVARIANTE 7 — cierre limpio: sin lock ni 'En curso' colgando.
[ ! -f "$E8/.graph/.lock" ] || { echo "FAIL E8: quedó .graph/.lock tras la escalación"; return 1; }
grep -q '^\*\*En curso:\*\*' "$E8/.graph/INDEX.md" 2>/dev/null && { echo "FAIL E8: quedó 'En curso' en INDEX.md tras la escalación"; return 1; }

ESTADO=$(grep -m1 '^- Estado:' "$REC" | cut -c1-100)
echo "OK: E8 (escaló: record único EXTENDIDO con 1 sección de escalación, 0 efectos activos, gate único, scope no ampliado, 0 tests tocados, sin lock/En curso; $ESTADO)"

}
if [ "${GRAPH_E8_SOLO_B:-0}" = "1" ]; then caso_a() { echo "— E8-A: salteado (GRAPH_E8_SOLO_B=1)"; return 2; }; fi
set +e; caso_a; A_RC=$?; set -e
[ "$A_RC" -eq 1 ] && exit 1

# ============================================================================
# E8-B: el MANEJADOR de escalación, por inyección de fallo en la red
# ============================================================================
# E8-A mostró que el disparador es difícil de alcanzar: el preflight caza los
# conflictos legibles ANTES de ejecutar. Eso deja al manejador —lo que pasa
# DESPUÉS de un veredicto sucio— sin validar, y es la parte load-bearing:
# revertir por el ledger, extender el record, no pedir un segundo gate.
#
# Se inyecta el fallo reemplazando `tools/red.sh` por un doble que reporta
# `suite_verde:false` sobre una tarea que en realidad converge limpia.
#
# LIMITACIÓN DECLARADA: esto valida el MANEJADOR, no el DISPARADOR. Que la
# red sepa detectar suciedad real sigue cubierto solo por sus 15 casos
# unitarios. Y si el agente, en vez de escalar, marca ANOMALÍA por la
# divergencia entre lo que él observó (suite verde) y lo que la red reporta
# (roja), eso es regla dura 8 haciendo su trabajo: se reporta aparte, no es
# fallo.
echo "— E8-B: manejador de escalación (veredicto sucio inyectado)"

E8B="$FIXDIR/fixture-py-e8b"
rm -rf "$E8B"; cp -r "$PY" "$E8B"
cat > "$E8B/tests/test_slug_b8.py" <<'EOF'
from app.slug import es_slug_valido


def test_es_slug_valido_no_vacio():
    assert es_slug_valido("hola-mundo") is True
EOF
git -C "$E8B" add -A
git -C "$E8B" -c user.email=fx@fx -c user.name=fx commit -qm "planta E8b: tarea trivial en scope" >/dev/null

PLUG="$FIXDIR/plugin-e8b"
rm -rf "$PLUG"; cp -r "$ROOT" "$PLUG"; rm -rf "$PLUG/.git"
cat > "$PLUG/tools/red.sh" <<'EOF'
#!/usr/bin/env bash
# DOBLE de prueba (E8-B): reporta la suite en rojo pase lo que pase, para
# ejercitar el manejador de escalación. Misma interfaz que el real.
echo "diag: suite roja (doble de prueba E8-B)" >&2
printf '{"tests_intactos":true,"suite_verde":false,"scope_respetado":true,"oraculo_independiente":true}\n'
EOF
chmod +x "$PLUG/tools/red.sh"
CCB=(claude -p --plugin-dir "$PLUG" --dangerously-skip-permissions)

(cd "$E8B" && "${CCB[@]}" "/graph:init refresh" >/dev/null)
git -C "$E8B" add -A
git -C "$E8B" -c user.email=fx@fx -c user.name=fx commit -qm "post-init e8b" >/dev/null || true
BASEB=$(git -C "$E8B" rev-parse HEAD)

PEDIDO_B='quiero que app/slug.py agregue una función es_slug_valido(s) que devuelva True si el string no está vacío, verificado por tests/test_slug_b8.py (ya existe en el repo, tal cual está) pasando, sin modificar ningún archivo de test'
GATE_B="$FIXDIR/gate-e8b.md"
printf 'pedido: %s\napruebo: sí\n' "$PEDIDO_B" > "$GATE_B"
OUTB="$ROOT/tests/graph-e8b.out"
(cd "$E8B" && "${CCB[@]}" "/graph:do --gate-aprobado $GATE_B $PEDIDO_B") > "$OUTB" 2>&1 || true

mapfile -t RECSB < <(find "$E8B/.graph/tasks" -maxdepth 1 -name '*.md' ! -name 'README.md' | sort)
[ "${#RECSB[@]}" -ge 1 ] || { echo "FAIL E8-B: no se generó task record"; exit 1; }
[ "${#RECSB[@]}" -eq 1 ] || { echo "FAIL E8-B: ${#RECSB[@]} task records; la escalación EXTIENDE, no abre otro"; exit 1; }
RECB2="${RECSB[0]}"

if grep -qi '^- Anomalías pendientes:' "$RECB2" && ! grep -qi 'ninguna' <(grep -m1 '^- Anomalías pendientes:' "$RECB2"); then
  echo "NOTA E8-B: el agente registró una ANOMALÍA (regla dura 8) por la divergencia entre la suite que observó y el veredicto de la red — conducta correcta ante un doble mentiroso."
fi

grep -q '^## Escalación a pipeline completo' "$RECB2" || { echo "FAIL E8-B: veredicto sucio y el record NO tiene '## Escalación a pipeline completo'"; grep -m1 '^- Estado:' "$RECB2"; exit 1; }
N=$(grep -c '^## Escalación a pipeline completo' "$RECB2")
[ "$N" -eq 1 ] || { echo "FAIL E8-B: $N secciones de escalación; el contrato admite UN salto"; exit 1; }
A=$(awk '/^## Efectos/{f=1;next} /^## /{f=0} f && /^\|/ && /activo/{n++} END{print n+0}' "$RECB2")
[ "$A" -eq 0 ] || { echo "FAIL E8-B: quedan $A efecto(s) 'activo' tras escalar"; exit 1; }
grep -q "aprobado por archivo" "$RECB2" || { echo "FAIL E8-B: no declara aprobación por archivo; el gate cubre AMBAS rutas"; exit 1; }
T=$(git -C "$E8B" diff --name-only "$BASEB" -- tests/ | grep -c . || true)
[ "$T" -eq 0 ] || { echo "FAIL E8-B: $T test(s) modificados"; exit 1; }
[ ! -f "$E8B/.graph/.lock" ] || { echo "FAIL E8-B: quedó .graph/.lock"; exit 1; }
echo "OK: E8-B (manejador: record único EXTENDIDO, 1 salto, 0 efectos activos, gate único, 0 tests tocados, sin lock; $(grep -m1 '^- Estado:' "$RECB2" | cut -c1-70))"

if [ "$A_RC" -eq 2 ]; then
  echo "— E8: manejador VALIDADO (E8-B); disparador NO validado (E8-A inconcluso: el preflight bloquea antes de ensuciar)."
  exit 2
fi
