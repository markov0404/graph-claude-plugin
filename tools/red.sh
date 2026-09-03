#!/usr/bin/env bash
# La red de la ruta pelada-con-red (ronda 7). Verificador determinístico
# bash+git, cero dependencias externas.
#
# Uso: tools/red.sh <dir> <baseline-ref> <cmd-suite> <scope-file>
#   <dir>          raíz del repo/fixture donde trabajó el agente (repo git
#                  normal O worktree; se valida con
#                  `git rev-parse --show-toplevel`, no con `[ -d .git ]`,
#                  para aceptar worktrees donde .git es un archivo-puntero
#                  en vez de un directorio).
#   <baseline-ref> ref de git (hash o tag) del efecto #0 del ledger. Este
#                  ES el baseline de red (§2 del contrato r7): red.sh no
#                  sabe nada de caracterización — si el gate detectó "ruta
#                  pelada con refuerzo de caracterización", el llamador ya
#                  escribió y congeló esos tests como efecto #1 ANTES de
#                  invocar este script, y ese estado post-efecto-#1 es lo
#                  que se pasa acá como <baseline-ref>. Para este script,
#                  "baseline" es simplemente "el commit contra el que se
#                  diffea", sin distinción de origen.
#   <cmd-suite>    comando de la suite COMPLETA verificado en commands.md,
#                  como una única cadena (se ejecuta vía `bash -c`).
#   <scope-file>   lista de paths/prefijos permitidos, uno por línea.
#                  La línea literal `.` es un caso especial: significa
#                  "todo el repo está en scope" (ningún archivo puede
#                  violar scope). La línea literal `tests-nuevos-registrar`
#                  (si aparece) es un no-op documental: no cambia el
#                  contrato ni cuenta como prefijo real.
#
# stdout: UNA línea JSON —
#   {"tests_intactos":bool,"suite_verde":bool,"scope_respetado":bool,"oraculo_independiente":bool}
#
# stderr: contrato r6 —
#   `tests_fallidos: <nodeids>`  (de la corrida de la suite; vacía si verde
#                                  o si nunca se llegó a correr)
#   `diag: <detalle>`            (uno por hallazgo: paths violados, tests
#                                  tocados, tests nuevos, motivo de error)
#
# Semántica de los 4 flags:
#   tests_intactos       — ningún test EXISTENTE en el baseline de red fue
#                           modificado, borrado O RENOMBRADO (con
#                           `--no-renames` un rename se ve siempre como
#                           borrado+alta: el borrado del path viejo pone
#                           esto en false). Agregar tests NUEVOS (paths que
#                           no existían en el baseline) NO lo pone en false
#                           — eso se reporta aparte en
#                           `diag: tests nuevos del agente: ...` y gobierna
#                           `oraculo_independiente` (RULING §3 del
#                           contrato: agregar tests no es indisciplina).
#   suite_verde           — <cmd-suite> sale 0, corrido en una copia
#                           desechable con los tests EXISTENTES tocados
#                           restaurados al baseline y los tests NUEVOS del
#                           agente borrados (estilo check.sh de bench): un
#                           test nuevo del agente no se ejecuta como
#                           oráculo; un test existente modificado se corre
#                           en su versión de baseline.
#   scope_respetado        — todo archivo tocado (diff+status vs baseline)
#                           está contenido en scope-file, EXCEPTO los paths
#                           de test que son enteramente nuevos (no violan
#                           scope, pero se registran en diag). La línea
#                           `.` en scope-file exime a todo archivo.
#   oraculo_independiente  — false únicamente cuando el diff agrega tests
#                           nuevos Y el área tocada (por coincidencia de
#                           nombre de archivo con los tests que ya existían
#                           en baseline) no tenía ningún test de baseline
#                           cubriéndola. Caso normal: true.
#
# Heurística de "área tocada" (sin ejecutar la suite dos veces): se compara
# el "stem" del nombre de archivo (basename sin extensión, sin afijos
# test_/_test/.test/.spec/test-/-test) de los archivos no-test tocados
# contra el stem de los archivos de test que YA existían en baseline. Si
# ningún test de baseline comparte stem con ningún archivo no-test tocado,
# el área se considera sin cobertura previa. Es una aproximación declarada
# (convención de nombres), no un análisis de imports — ante la duda, sin
# tests nuevos de por medio esto nunca se evalúa.
#
# TEST_PATTERN (paths que cuentan como "test"): directorios `test/` o
# `tests/` y `spec/` (a cualquier profundidad: todo archivo bajo esos
# directorios cuenta, sea cual sea su nombre); nombres `test_*`,
# `*_test.*`, `*.test.*`, `*.spec.*`, `conftest*`; directorio `fixtures/`.
# Cubre tanto convención Python (`test_calc.py`, `conftest.py`) como JS/TS
# (`calc.test.js`, `calc.spec.ts` bajo `test/` o `tests/`).
#
# Heurística de `tests_fallidos`: reconoce salida estilo pytest
# (`FAILED <nodeid> - ...` / `ERROR <nodeid> - ...`), `unittest` en modo
# discover (`FAIL: <method> (<nodeid>)` / `ERROR: <method> (<nodeid>)`) y
# TAP de `node --test` (`not ok N - <desc>`). Un runner con otro formato de
# salida no rompe el contrato: `tests_fallidos` puede quedar vacía aun con
# `suite_verde:false` — la línea `diag:` lo señala.
#
# Robustez de git (contrato §7): TODOS los consumos de git van con
# `-c core.quotepath=false` (paths con acentos no se escapan/entrecomillan)
# y, donde se lista más de un path, `--no-renames -z` + lectura con
# `read -r -d ''` (paths con espacios/acentos no rompen el parseo; un
# rename se ve SIEMPRE como borrado+alta, nunca como `R viejo -> nuevo`
# que `cut -c4-` destrozaría). El status usa `-uall` para que un
# directorio untracked NUEVO se expanda a sus archivos individuales en vez
# de colapsar a una sola línea `?? dir/` — si colapsara, tratar esa línea
# como un path de archivo (p.ej. para restaurarlo/borrarlo en la copia
# desechable) operaría sobre un directorio, no un archivo.
#
# Fail-closed REAL: además de los chequeos explícitos de argumentos (dir,
# baseline, cmd-suite, scope-file), un trap de EXIT captura CUALQUIER
# terminación del script que no haya emitido ya el JSON (p.ej. un fallo
# interno inesperado bajo `set -e` en cualquier punto posterior que no
# pasó por `fail_closed`) y emite los 4 flags en false + un `diag:`
# genérico antes de salir con código 1. Un cmd-suite que SÍ corre pero
# falla con tests rojos NO es error interno: es `suite_verde:false`
# normal (no dispara este trap).
#
# Límites conocidos (declarados, no resueltos por este script):
#   - Un helper NO-test fuera de cualquier directorio test/tests/spec
#     (p.ej. un módulo de fixtures en app/ importado por los tests, cuyo
#     nombre no matchea TEST_PATTERN) modificado por el agente NO se
#     restaura al baseline en la copia desechable de suite_verde: si el
#     agente debilita un assert indirectamente vía ese helper, suite_verde
#     no lo detecta. Mitigación fuera de alcance de este script: scope
#     estricto sobre esos helpers.
#   - Un cmd-suite que siempre sale 0 (no ejecuta tests reales, o un
#     wrapper roto) hace que `suite_verde:true` sea trivialmente un falso
#     positivo. red.sh confía en que commands.md ya verificó ese comando
#     (§1 del contrato: la verificación previa del init no se re-corre acá).
set -euo pipefail

gitq() { git -c core.quotepath=false "$@"; }

TMP_DIRS=()
JSON_DONE=false

emit_json() {
  printf '{"tests_intactos":%s,"suite_verde":%s,"scope_respetado":%s,"oraculo_independiente":%s}\n' \
    "$1" "$2" "$3" "$4"
  JSON_DONE=true
}

# Fail-closed REAL (hallazgo CRÍTICO): dispare lo que dispare la
# terminación del script (fail_closed explícito, o cualquier abort
# inesperado bajo `set -e`), si el JSON todavía no salió, este trap lo
# emite en 4 false + diag genérico y fuerza exit 1.
on_exit() {
  local rc=$?
  local d
  for d in "${TMP_DIRS[@]:-}"; do
    [ -n "$d" ] && rm -rf "$d"
  done
  if [ "$JSON_DONE" != true ]; then
    echo "diag: error interno inesperado (rc=$rc) — fail-closed" >&2
    echo "tests_fallidos: " >&2
    emit_json false false false false
    exit 1
  fi
}
trap on_exit EXIT

fail_closed() {
  local reason="$1"
  echo "diag: $reason" >&2
  echo "tests_fallidos: " >&2
  emit_json false false false false
  exit 1
}

[ $# -eq 4 ] || fail_closed "uso: red.sh <dir> <baseline-ref> <cmd-suite> <scope-file> (recibí $# argumentos)"

DIR="$1"
BASELINE="$2"
CMD_SUITE="$3"
SCOPE_FILE="$4"

[ -n "$DIR" ] || fail_closed "el argumento <dir> está vacío"
[ -d "$DIR" ] || fail_closed "'$DIR' no es un directorio"
GIT_TOPLEVEL="$(gitq -C "$DIR" rev-parse --show-toplevel 2>/dev/null)" \
  || fail_closed "'$DIR' no es un repo git ni un worktree: rev-parse --show-toplevel falló"
DIR="$(cd "$DIR" && pwd -P)"
GIT_TOPLEVEL="$(cd "$GIT_TOPLEVEL" && pwd -P)"
[ "$DIR" = "$GIT_TOPLEVEL" ] \
  || fail_closed "'$DIR' no es la raíz de un repo/worktree git (toplevel es '$GIT_TOPLEVEL')"

[ -n "$BASELINE" ] || fail_closed "el argumento <baseline-ref> está vacío"
gitq -C "$DIR" rev-parse --verify "${BASELINE}^{commit}" >/dev/null 2>&1 \
  || fail_closed "baseline-ref '$BASELINE' no resuelve a un commit en '$DIR'"
BASELINE_SHA="$(gitq -C "$DIR" rev-parse "${BASELINE}^{commit}")"

[ -n "$CMD_SUITE" ] || fail_closed "el argumento <cmd-suite> está vacío"

[ -n "$SCOPE_FILE" ] || fail_closed "el argumento <scope-file> está vacío"
[ -f "$SCOPE_FILE" ] || fail_closed "scope-file '$SCOPE_FILE' no existe o no es un archivo regular"
[ -r "$SCOPE_FILE" ] || fail_closed "scope-file '$SCOPE_FILE' no se puede leer"

# --- scope-file: paths/prefijos permitidos --------------------------------
SCOPE_ALL=false
SCOPE_ENTRIES=()
while IFS= read -r sline || [ -n "$sline" ]; do
  sline="${sline%$'\r'}"
  # trim espacios de borde
  sline="${sline#"${sline%%[![:space:]]*}"}"
  sline="${sline%"${sline##*[![:space:]]}"}"
  [ -z "$sline" ] && continue
  [ "$sline" = "tests-nuevos-registrar" ] && continue
  if [ "$sline" = "." ]; then
    SCOPE_ALL=true
    continue
  fi
  SCOPE_ENTRIES+=("${sline%/}")
done < "$SCOPE_FILE"

path_in_scope() {
  [ "$SCOPE_ALL" = true ] && return 0
  local f="$1" e
  for e in "${SCOPE_ENTRIES[@]:-}"; do
    [ -z "$e" ] && continue
    if [ "$f" = "$e" ] || [[ "$f" == "$e"/* ]]; then
      return 0
    fi
  done
  return 1
}

# --- clasificación de paths de test ----------------------------------------
TEST_PATTERN='(^|/)tests?/|(^|/)spec/|(^|/)test_[^/]*($|/)|(^|/)[^/]*_test\.[^/]+$|(^|/)[^/]*\.test\.[^/]+$|(^|/)[^/]*\.spec\.[^/]+$|(^|/)conftest[^/]*$|(^|/)fixtures($|/)'

# --- archivos tocados vs baseline (diff commiteado + working tree) --------
# Sigue el estilo de bench/*/check.sh: diff nombrado + status porcelain,
# excluyendo .graph (bitácora propia del sistema, no cuenta como mutación
# del pedido — conventions.md). `-uall` expande directorios untracked
# nuevos a sus archivos individuales (hallazgo CRÍTICO); `--no-renames`
# fuerza que un rename se vea como borrado+alta; `-z` + `read -r -d ''`
# hace el parseo inmune a espacios/acentos/etc en los nombres.
changed_paths() {
  local -a paths=()
  local line
  while IFS= read -r -d '' line; do
    [ -z "$line" ] && continue
    paths+=("$line")
  done < <(gitq -C "$DIR" diff --name-only --no-renames -z "$BASELINE_SHA" -- . ':!.graph' 2>/dev/null || true)
  while IFS= read -r -d '' line; do
    [ -z "$line" ] && continue
    paths+=("${line:3}")
  done < <(gitq -C "$DIR" status --porcelain -uall --no-renames -z -- . ':!.graph' 2>/dev/null || true)
  printf '%s\n' "${paths[@]}" | sed '/^$/d' | sort -u
}

ALL_CHANGED="$(changed_paths)" || fail_closed "no se pudo calcular el diff contra baseline en '$DIR'"

TESTS_CHANGED=""
TOUCHED_NONTEST=""
if [ -n "$ALL_CHANGED" ]; then
  TESTS_CHANGED="$(printf '%s\n' "$ALL_CHANGED" | grep -E "$TEST_PATTERN" || true)"
  TOUCHED_NONTEST="$(printf '%s\n' "$ALL_CHANGED" | grep -vE "$TEST_PATTERN" || true)"
fi

# --- separar tests EXISTENTES en baseline de tests NUEVOS del agente ------
existed_at_baseline() {
  gitq -C "$DIR" cat-file -e "${BASELINE_SHA}:$1" 2>/dev/null
}

EXISTING_TESTS_CHANGED=""
NEW_TEST_FILES=""
if [ -n "$TESTS_CHANGED" ]; then
  while IFS= read -r tp; do
    [ -z "$tp" ] && continue
    if existed_at_baseline "$tp"; then
      EXISTING_TESTS_CHANGED="${EXISTING_TESTS_CHANGED}${tp}"$'\n'
    else
      NEW_TEST_FILES="${NEW_TEST_FILES}${tp}"$'\n'
    fi
  done <<< "$TESTS_CHANGED"
  EXISTING_TESTS_CHANGED="$(printf '%s' "$EXISTING_TESTS_CHANGED" | sed '/^$/d')"
  NEW_TEST_FILES="$(printf '%s' "$NEW_TEST_FILES" | sed '/^$/d')"
fi

# --- tests_intactos (RULING §3: solo tests EXISTENTES tocados/borrados) ---
# agregar tests nuevos NO pone esto en false.
TESTS_INTACTOS=true
if [ -n "$EXISTING_TESTS_CHANGED" ]; then
  TESTS_INTACTOS=false
  echo "diag: tests tocados: $(printf '%s' "$EXISTING_TESTS_CHANGED" | tr '\n' ' ')" >&2
fi

if [ -n "$NEW_TEST_FILES" ]; then
  echo "diag: tests nuevos del agente: registrados, no sustituyen al oráculo ($(printf '%s' "$NEW_TEST_FILES" | tr '\n' ' '))" >&2
fi

# --- scope_respetado --------------------------------------------------------
# Los paths de test nuevos están exentos (ya se registran arriba); todo lo
# demás tocado debe estar contenido en scope-file (o SCOPE_ALL vía ".").
TOUCHED_FOR_SCOPE="$ALL_CHANGED"
if [ -n "$NEW_TEST_FILES" ] && [ -n "$ALL_CHANGED" ]; then
  TOUCHED_FOR_SCOPE="$(comm -23 <(printf '%s\n' "$ALL_CHANGED" | sort -u) <(printf '%s\n' "$NEW_TEST_FILES" | sort -u))"
fi

SCOPE_RESPETADO=true
VIOLATIONS=""
if [ -n "$TOUCHED_FOR_SCOPE" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    if ! path_in_scope "$f"; then
      VIOLATIONS="${VIOLATIONS}${f}"$'\n'
    fi
  done <<< "$TOUCHED_FOR_SCOPE"
  VIOLATIONS="$(printf '%s' "$VIOLATIONS" | sed '/^$/d')"
fi
if [ -n "$VIOLATIONS" ]; then
  SCOPE_RESPETADO=false
  echo "diag: fuera de scope: $(printf '%s' "$VIOLATIONS" | tr '\n' ' ')" >&2
fi

# --- oraculo_independiente --------------------------------------------------
file_stem() {
  local base b
  base="$(basename "$1")"
  b="${base%.*}"
  b="${b#test_}"
  b="${b%_test}"
  b="${b%.test}"
  b="${b%.spec}"
  b="${b#test-}"
  b="${b%-test}"
  printf '%s' "$b"
}

ORACULO_INDEPENDIENTE=true
if [ -n "$NEW_TEST_FILES" ]; then
  TOUCHED_STEMS=""
  if [ -n "$TOUCHED_NONTEST" ]; then
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      TOUCHED_STEMS="${TOUCHED_STEMS}$(file_stem "$f")"$'\n'
    done <<< "$TOUCHED_NONTEST"
  fi
  TOUCHED_STEMS="$(printf '%s' "$TOUCHED_STEMS" | sed '/^$/d' | sort -u)"

  BASELINE_TEST_FILES=""
  while IFS= read -r -d '' line; do
    [ -z "$line" ] && continue
    BASELINE_TEST_FILES="${BASELINE_TEST_FILES}${line}"$'\n'
  done < <(gitq -C "$DIR" ls-tree -r --name-only -z "$BASELINE_SHA" 2>/dev/null || true)
  BASELINE_TEST_FILES="$(printf '%s' "$BASELINE_TEST_FILES" | sed '/^$/d' | grep -E "$TEST_PATTERN" || true)"

  BASELINE_TEST_STEMS=""
  if [ -n "$BASELINE_TEST_FILES" ]; then
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      BASELINE_TEST_STEMS="${BASELINE_TEST_STEMS}$(file_stem "$f")"$'\n'
    done <<< "$BASELINE_TEST_FILES"
  fi
  BASELINE_TEST_STEMS="$(printf '%s' "$BASELINE_TEST_STEMS" | sed '/^$/d' | sort -u)"

  AREA_CUBIERTA=false
  if [ -n "$TOUCHED_STEMS" ] && [ -n "$BASELINE_TEST_STEMS" ]; then
    COMUNES="$(comm -12 <(printf '%s\n' "$TOUCHED_STEMS") <(printf '%s\n' "$BASELINE_TEST_STEMS") | sed '/^$/d')"
    [ -n "$COMUNES" ] && AREA_CUBIERTA=true
  fi

  if [ "$AREA_CUBIERTA" = false ]; then
    ORACULO_INDEPENDIENTE=false
    echo "diag: área tocada sin cobertura de test en baseline (0 tests) — los tests nuevos del agente no son oráculo independiente" >&2
  fi
fi

# --- suite_verde: copia desechable, tests restaurados al baseline ---------
WORK="$(mktemp -d)"
TMP_DIRS+=("$WORK")
cp -r "$DIR"/. "$WORK"/

if [ -n "$EXISTING_TESTS_CHANGED" ]; then
  while IFS= read -r tp; do
    [ -z "$tp" ] && continue
    gitq -C "$WORK" checkout "$BASELINE_SHA" -- "$tp" 2>/dev/null || true
  done <<< "$EXISTING_TESTS_CHANGED"
fi
if [ -n "$NEW_TEST_FILES" ]; then
  while IFS= read -r tp; do
    [ -z "$tp" ] && continue
    rm -rf "$WORK/$tp"
  done <<< "$NEW_TEST_FILES"
fi

set +e
SUITE_OUT="$(cd "$WORK" && bash -c "$CMD_SUITE" 2>&1)"
SUITE_RC=$?
set -e

if [ "$SUITE_RC" -eq 126 ] || [ "$SUITE_RC" -eq 127 ]; then
  fail_closed "cmd-suite no se pudo ejecutar (exit $SUITE_RC — comando inexistente o no ejecutable): $CMD_SUITE"
fi

extract_nodeids() {
  awk '
    /^(FAILED|ERROR) [^(]/ { print $2; next }
    /^(FAIL|ERROR): / {
      if (match($0, /\(([^)]+)\)/)) { print substr($0, RSTART+1, RLENGTH-2); next }
    }
    /^not ok [0-9]+ -/ {
      line=$0; sub(/^not ok [0-9]+ - /, "", line); print line; next
    }
  '
}

TESTS_FALLIDOS=""
SUITE_VERDE=true
if [ "$SUITE_RC" -ne 0 ]; then
  SUITE_VERDE=false
  TESTS_FALLIDOS="$(printf '%s\n' "$SUITE_OUT" | extract_nodeids | tr '\n' ' ' | sed -E 's/[[:space:]]+$//')"
  if [ -z "$TESTS_FALLIDOS" ]; then
    echo "diag: suite roja (exit $SUITE_RC) sin nodeids reconocidos por el parser genérico (formato de runner no cubierto)" >&2
  fi
fi

echo "tests_fallidos: ${TESTS_FALLIDOS}" >&2

emit_json "$TESTS_INTACTOS" "$SUITE_VERDE" "$SCOPE_RESPETADO" "$ORACULO_INDEPENDIENTE"
