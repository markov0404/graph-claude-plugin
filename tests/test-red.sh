#!/usr/bin/env bash
# Test de tools/red.sh: casos mínimos de la red de la ruta pelada-con-red
# (ronda 7) — limpio, test tocado, suite roja, scope violado, caracterización
# congelada en baseline, tests nuevos del agente (con y sin cobertura
# previa), error interno (cmd-suite inexistente), y los casos adversariales
# del fix r7 (§7 del contrato): rename de test, borrado de test, DIRECTORIO
# de tests enteramente nuevo (el caso del hallazgo CRÍTICO), paths con
# espacios/acentos, naming no-python (`test/x.test.js`), worktree, y
# determinismo. Fixtures 100% fuera del árbol del repo (mktemp), como exige
# conventions.md para tests headless.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOL="$ROOT/tools/red.sh"

[ -x "$TOOL" ] || { echo "FAIL: no existe o no es ejecutable $TOOL"; exit 1; }

# Raíz única de scratch (fuera del árbol del repo): TODOS los fixtures
# (repos, scope-files, stdout/stderr capturados) se crean DENTRO de ella vía
# `mktemp -p`, así un solo trap alcanza para limpiar todo — evita el error
# clásico de registrar rutas en un array desde una función invocada por
# sustitución de comandos (esa mutación ocurre en una subshell y se pierde).
SCRATCH_ROOT="$(mktemp -d)"
trap 'rm -rf "$SCRATCH_ROOT"' EXIT

CMD_SUITE="python3 -m unittest discover -s tests -p test_*.py"

# --- helpers ----------------------------------------------------------------

# new_repo: crea un repo git fuera del árbol con app/calc.py (add) +
# tests/test_calc.py (cubre add). Imprime la ruta del repo por stdout.
new_repo() {
  local repo
  repo="$(mktemp -d -p "$SCRATCH_ROOT")"
  git -C "$repo" init -q
  git -C "$repo" config user.email "red-test@example.com"
  git -C "$repo" config user.name "red-test"

  mkdir -p "$repo/app" "$repo/tests"
  : > "$repo/app/__init__.py"
  : > "$repo/tests/__init__.py"
  cat > "$repo/app/calc.py" <<'EOF'
def add(a, b):
    return a + b
EOF
  cat > "$repo/tests/test_calc.py" <<'EOF'
import unittest
from app.calc import add


class CalcTest(unittest.TestCase):
    def test_add(self):
        self.assertEqual(add(2, 3), 5)
EOF
  git -C "$repo" add -A
  git -C "$repo" commit -q -m "baseline: add() con cobertura"
  printf '%s' "$repo"
}

# new_scope: crea un scope-file con las líneas dadas. Imprime la ruta.
new_scope() {
  local f
  f="$(mktemp -p "$SCRATCH_ROOT")"
  printf '%s\n' "$@" > "$f"
  printf '%s' "$f"
}

# run_red: corre red.sh y deja el resultado en $RED_JSON / $RED_ERR / $RED_RC.
run_red() {
  local repo="$1" base="$2" cmd="$3" scope="$4"
  local out err
  out="$(mktemp -p "$SCRATCH_ROOT")"; err="$(mktemp -p "$SCRATCH_ROOT")"
  set +e
  "$TOOL" "$repo" "$base" "$cmd" "$scope" >"$out" 2>"$err"
  RED_RC=$?
  set -e
  RED_JSON="$(cat "$out")"
  RED_ERR="$(cat "$err")"
}

assert_field() {
  local field="$1" expected="$2"
  echo "$RED_JSON" | grep -qF "\"$field\":$expected" \
    || { echo "FAIL: esperaba \"$field\":$expected en $RED_JSON"; exit 1; }
}

BASE_SCOPE="$(new_scope app tests)"

# === (a) limpio → 4 true ====================================================
echo "— caso (a): limpio"
REPO_A="$(new_repo)"
BASE_A="$(git -C "$REPO_A" rev-parse HEAD)"
# cambio benigno dentro de scope, no toca tests, no rompe nada.
cat > "$REPO_A/app/calc.py" <<'EOF'
def add(a, b):
    # suma simple
    return a + b
EOF
run_red "$REPO_A" "$BASE_A" "$CMD_SUITE" "$BASE_SCOPE"
[ "$RED_RC" -eq 0 ] || { echo "FAIL (a): exit code $RED_RC (esperaba 0). stderr: $RED_ERR"; exit 1; }
assert_field tests_intactos true
assert_field suite_verde true
assert_field scope_respetado true
assert_field oraculo_independiente true
echo "$RED_ERR" | grep -qE '^tests_fallidos: *$' \
  || { echo "FAIL (a): tests_fallidos debería estar vacía. stderr: $RED_ERR"; exit 1; }

# === (b) test tocado → tests_intactos=false ================================
echo "— caso (b): test existente tocado"
REPO_B="$(new_repo)"
BASE_B="$(git -C "$REPO_B" rev-parse HEAD)"
cat >> "$REPO_B/tests/test_calc.py" <<'EOF'

# comentario agregado por el agente, no cambia el assert
EOF
run_red "$REPO_B" "$BASE_B" "$CMD_SUITE" "$BASE_SCOPE"
assert_field tests_intactos false
assert_field suite_verde true
assert_field scope_respetado true
assert_field oraculo_independiente true
echo "$RED_ERR" | grep -qF "diag: tests tocados:" \
  || { echo "FAIL (b): stderr no reporta tests tocados. stderr: $RED_ERR"; exit 1; }

# === (c) suite roja → suite_verde=false + tests_fallidos con nodeids =======
echo "— caso (c): suite roja (bug en app/calc.py, tests intactos)"
REPO_C="$(new_repo)"
BASE_C="$(git -C "$REPO_C" rev-parse HEAD)"
cat > "$REPO_C/app/calc.py" <<'EOF'
def add(a, b):
    return a + b + 1
EOF
run_red "$REPO_C" "$BASE_C" "$CMD_SUITE" "$BASE_SCOPE"
assert_field tests_intactos true
assert_field suite_verde false
assert_field scope_respetado true
assert_field oraculo_independiente true
echo "$RED_ERR" | grep -qE '^tests_fallidos: .*test_calc\.CalcTest\.test_add' \
  || { echo "FAIL (c): tests_fallidos no incluye el nodeid esperado. stderr: $RED_ERR"; exit 1; }

# === (d) archivo fuera de scope → scope_respetado=false + diag =============
echo "— caso (d): archivo fuera de scope"
REPO_D="$(new_repo)"
BASE_D="$(git -C "$REPO_D" rev-parse HEAD)"
echo "dato fuera de alcance" > "$REPO_D/secret.txt"
run_red "$REPO_D" "$BASE_D" "$CMD_SUITE" "$BASE_SCOPE"
assert_field tests_intactos true
assert_field scope_respetado false
echo "$RED_ERR" | grep -qF "diag: fuera de scope:" \
  || { echo "FAIL (d): stderr no reporta el path fuera de scope. stderr: $RED_ERR"; exit 1; }
echo "$RED_ERR" | grep -qF "secret.txt" \
  || { echo "FAIL (d): stderr no nombra secret.txt. stderr: $RED_ERR"; exit 1; }

# === (e) caracterización congelada en baseline + cambio que la rompe =======
# suite_verde=false: la red defiende la caracterización aunque el agente
# nunca haya tocado ningún archivo de test.
echo "— caso (e): caracterización congelada en baseline, cambio la rompe"
REPO_E="$(mktemp -d -p "$SCRATCH_ROOT")"
git -C "$REPO_E" init -q
git -C "$REPO_E" config user.email "red-test@example.com"
git -C "$REPO_E" config user.name "red-test"
mkdir -p "$REPO_E/app" "$REPO_E/tests"
: > "$REPO_E/app/__init__.py"
: > "$REPO_E/tests/__init__.py"
cat > "$REPO_E/app/calc.py" <<'EOF'
def add(a, b):
    return a + b


def subtract(a, b):
    return a - b
EOF
cat > "$REPO_E/tests/test_calc.py" <<'EOF'
import unittest
from app.calc import add


class CalcTest(unittest.TestCase):
    def test_add(self):
        self.assertEqual(add(2, 3), 5)
EOF
# test de caracterización: capturado del comportamiento VIGENTE de subtract,
# congelado en el mismo commit de baseline (efecto #0).
cat > "$REPO_E/tests/test_char.py" <<'EOF'
import unittest
from app.calc import subtract


class CharTest(unittest.TestCase):
    def test_subtract_comportamiento_vigente(self):
        self.assertEqual(subtract(5, 2), 3)
EOF
git -C "$REPO_E" add -A
git -C "$REPO_E" commit -q -m "baseline: add() + subtract() con caracterización congelada"
BASE_E="$(git -C "$REPO_E" rev-parse HEAD)"
# el agente cambia subtract sin tocar ningún test.
cat > "$REPO_E/app/calc.py" <<'EOF'
def add(a, b):
    return a + b


def subtract(a, b):
    return a - b - 1
EOF
run_red "$REPO_E" "$BASE_E" "$CMD_SUITE" "$BASE_SCOPE"
assert_field tests_intactos true
assert_field suite_verde false
assert_field scope_respetado true
assert_field oraculo_independiente true
echo "$RED_ERR" | grep -qE '^tests_fallidos: .*test_char\.CharTest\.test_subtract_comportamiento_vigente' \
  || { echo "FAIL (e): tests_fallidos no incluye el nodeid de la caracterización rota. stderr: $RED_ERR"; exit 1; }

# === (f) tests nuevos del agente en área SIN cobertura previa ==============
# RULING §3: agregar tests nuevos NO baja tests_intactos. oraculo_independiente
# sí queda en false porque el área tocada (newmod) no tenía test en baseline.
echo "— caso (f): tests nuevos del agente en área sin cobertura previa"
REPO_F="$(new_repo)"
BASE_F="$(git -C "$REPO_F" rev-parse HEAD)"
cat > "$REPO_F/app/newmod.py" <<'EOF'
def mul(a, b):
    return a * b
EOF
cat > "$REPO_F/tests/test_newmod.py" <<'EOF'
import unittest
from app.newmod import mul


class NewmodTest(unittest.TestCase):
    def test_mul(self):
        self.assertEqual(mul(2, 3), 6)
EOF
run_red "$REPO_F" "$BASE_F" "$CMD_SUITE" "$BASE_SCOPE"
assert_field tests_intactos true
assert_field suite_verde true
assert_field scope_respetado true
assert_field oraculo_independiente false
echo "$RED_ERR" | grep -qF "diag: tests nuevos del agente" \
  || { echo "FAIL (f): stderr no registra los tests nuevos del agente. stderr: $RED_ERR"; exit 1; }
echo "$RED_ERR" | grep -qF "sin cobertura de test en baseline" \
  || { echo "FAIL (f): stderr no explica por qué oraculo_independiente=false. stderr: $RED_ERR"; exit 1; }

# === (g) error interno: cmd-suite inexistente → fail-closed 4 false ========
echo "— caso (g): error interno (cmd-suite inexistente) → fail-closed"
REPO_G="$(new_repo)"
BASE_G="$(git -C "$REPO_G" rev-parse HEAD)"
run_red "$REPO_G" "$BASE_G" "/no/existe/este/binario --flag" "$BASE_SCOPE"
[ "$RED_RC" -ne 0 ] || { echo "FAIL (g): esperaba exit != 0, fue $RED_RC"; exit 1; }
assert_field tests_intactos false
assert_field suite_verde false
assert_field scope_respetado false
assert_field oraculo_independiente false
echo "$RED_ERR" | grep -qF "diag:" \
  || { echo "FAIL (g): stderr no trae diag de error interno. stderr: $RED_ERR"; exit 1; }

# === (h) test nuevo del agente en área CON cobertura previa ================
# RULING §3, complemento de (f): agregar test nuevo NO baja tests_intactos,
# y acá además oraculo_independiente queda en true porque el área tocada
# (calc) sí tenía cobertura en baseline (tests/test_calc.py).
echo "— caso (h): test nuevo del agente en área con cobertura previa"
REPO_H="$(new_repo)"
BASE_H="$(git -C "$REPO_H" rev-parse HEAD)"
cat > "$REPO_H/app/calc.py" <<'EOF'
def add(a, b):
    # variante con cobertura previa
    return a + b
EOF
cat > "$REPO_H/tests/test_calc_v2.py" <<'EOF'
import unittest
from app.calc import add


class CalcV2Test(unittest.TestCase):
    def test_add_again(self):
        self.assertEqual(add(10, 5), 15)
EOF
run_red "$REPO_H" "$BASE_H" "$CMD_SUITE" "$BASE_SCOPE"
assert_field tests_intactos true
assert_field suite_verde true
assert_field scope_respetado true
assert_field oraculo_independiente true
echo "$RED_ERR" | grep -qF "diag: tests nuevos del agente" \
  || { echo "FAIL (h): stderr no registra el test nuevo. stderr: $RED_ERR"; exit 1; }

# === (i) rename de test existente → tests_intactos=false ===================
# --no-renames fuerza a ver esto como borrado (path viejo) + alta (path
# nuevo), nunca como "R viejo -> nuevo" (hallazgo MEDIO #4).
echo "— caso (i): rename de test existente"
REPO_I="$(new_repo)"
BASE_I="$(git -C "$REPO_I" rev-parse HEAD)"
mv "$REPO_I/tests/test_calc.py" "$REPO_I/tests/test_calc_renamed.py"
git -C "$REPO_I" add -A
run_red "$REPO_I" "$BASE_I" "$CMD_SUITE" "$BASE_SCOPE"
assert_field tests_intactos false
assert_field suite_verde true
assert_field scope_respetado true
echo "$RED_ERR" | grep -qF "diag: tests tocados:" \
  || { echo "FAIL (i): stderr no reporta el path viejo como tocado. stderr: $RED_ERR"; exit 1; }
echo "$RED_ERR" | grep -qF "tests/test_calc.py" \
  || { echo "FAIL (i): stderr no nombra el path viejo tests/test_calc.py. stderr: $RED_ERR"; exit 1; }
echo "$RED_ERR" | grep -qF " -> " \
  && { echo "FAIL (i): stderr contiene una flecha de rename cruda ('R viejo -> nuevo'), --no-renames no se aplicó. stderr: $RED_ERR"; exit 1; }
echo "$RED_ERR" | grep -qF "diag: tests nuevos del agente" \
  || { echo "FAIL (i): stderr no registra el path nuevo como test nuevo. stderr: $RED_ERR"; exit 1; }

# === (j) borrado de test existente → tests_intactos=false ==================
echo "— caso (j): borrado de test existente"
REPO_J="$(new_repo)"
BASE_J="$(git -C "$REPO_J" rev-parse HEAD)"
rm "$REPO_J/tests/test_calc.py"
run_red "$REPO_J" "$BASE_J" "$CMD_SUITE" "$BASE_SCOPE"
assert_field tests_intactos false
assert_field suite_verde true
assert_field scope_respetado true
assert_field oraculo_independiente true
echo "$RED_ERR" | grep -qF "diag: tests tocados:" \
  || { echo "FAIL (j): stderr no reporta el borrado. stderr: $RED_ERR"; exit 1; }

# === (k) DIRECTORIO de tests enteramente nuevo (repro del hallazgo CRÍTICO) =
# Antes del fix: `git status` colapsaba un directorio untracked nuevo a una
# sola línea `?? tests/newarea/`, y el `rm -f` sobre esa "ruta" (en realidad
# un directorio) abortaba el script bajo `set -e` (stdout vacío, rc=1). Acá
# el agente crea TODO un subdirectorio tests/newarea/ nuevo con dos test
# files, más app/newarea.py (área sin cobertura previa). Con -uall cada
# archivo se expande individualmente: JSON válido, fail-closed correcto por
# semántica §3 (son tests nuevos → tests_intactos=true), oraculo según
# cobertura previa (newarea no tenía test en baseline → false).
echo "— caso (k): directorio de tests enteramente nuevo (repro CRÍTICO)"
REPO_K="$(new_repo)"
BASE_K="$(git -C "$REPO_K" rev-parse HEAD)"
mkdir -p "$REPO_K/tests/newarea"
cat > "$REPO_K/app/newarea.py" <<'EOF'
def combine(a, b):
    return a + b + a
EOF
: > "$REPO_K/tests/newarea/__init__.py"
cat > "$REPO_K/tests/newarea/test_combine.py" <<'EOF'
import unittest
from app.newarea import combine


class CombineTest(unittest.TestCase):
    def test_combine(self):
        self.assertEqual(combine(2, 3), 7)
EOF
cat > "$REPO_K/tests/newarea/test_combine_extra.py" <<'EOF'
import unittest
from app.newarea import combine


class CombineExtraTest(unittest.TestCase):
    def test_combine_zero(self):
        self.assertEqual(combine(0, 0), 0)
EOF
run_red "$REPO_K" "$BASE_K" "$CMD_SUITE" "$BASE_SCOPE"
[ "$RED_RC" -eq 0 ] || { echo "FAIL (k): esperaba exit 0 (JSON válido, no fail-closed), fue $RED_RC. stderr: $RED_ERR"; exit 1; }
[ -n "$RED_JSON" ] || { echo "FAIL (k): stdout vacío (el CRÍTICO sigue roto)"; exit 1; }
assert_field tests_intactos true
assert_field suite_verde true
assert_field scope_respetado true
assert_field oraculo_independiente false
echo "$RED_ERR" | grep -qF "diag: tests nuevos del agente" \
  || { echo "FAIL (k): stderr no registra los tests nuevos del agente. stderr: $RED_ERR"; exit 1; }

# === (l) paths con espacios y acentos → scope correcto, sin falsos positivos
echo "— caso (l): paths con espacios y acentos"
REPO_L="$(new_repo)"
BASE_L="$(git -C "$REPO_L" rev-parse HEAD)"
cat > "$REPO_L/app/cálculo raro.py" <<'EOF'
def calcular_raro(x):
    return x * 2
EOF
run_red "$REPO_L" "$BASE_L" "$CMD_SUITE" "$BASE_SCOPE"
[ "$RED_RC" -eq 0 ] || { echo "FAIL (l): exit code $RED_RC (esperaba 0). stderr: $RED_ERR"; exit 1; }
assert_field tests_intactos true
assert_field suite_verde true
assert_field scope_respetado true
echo "$RED_ERR" | grep -qF "fuera de scope" \
  && { echo "FAIL (l): falso positivo de scope con acentos/espacios. stderr: $RED_ERR"; exit 1; }
true

# === (m) `test/x.test.js` reconocido como test (naming no-python) =========
echo "— caso (m): test/calc.test.js reconocido como test"
REPO_M="$(new_repo)"
BASE_M="$(git -C "$REPO_M" rev-parse HEAD)"
mkdir -p "$REPO_M/test"
cat > "$REPO_M/test/calc.test.js" <<'EOF'
// placeholder de test JS, no ejecutado por la suite python de este fixture
EOF
run_red "$REPO_M" "$BASE_M" "$CMD_SUITE" "$BASE_SCOPE"
[ "$RED_RC" -eq 0 ] || { echo "FAIL (m): exit code $RED_RC (esperaba 0). stderr: $RED_ERR"; exit 1; }
assert_field tests_intactos true
assert_field scope_respetado true
echo "$RED_ERR" | grep -qF "diag: tests nuevos del agente" \
  || { echo "FAIL (m): stderr no clasifica test/calc.test.js como test nuevo. stderr: $RED_ERR"; exit 1; }
echo "$RED_ERR" | grep -qF "test/calc.test.js" \
  || { echo "FAIL (m): stderr no nombra test/calc.test.js. stderr: $RED_ERR"; exit 1; }
echo "$RED_ERR" | grep -qF "fuera de scope" \
  && { echo "FAIL (m): test/calc.test.js no debería violar scope (exento por ser test nuevo). stderr: $RED_ERR"; exit 1; }
true

# === (n) worktree aceptado (no rechazado por `[ -d .git ]`) ================
echo "— caso (n): worktree aceptado"
REPO_N="$(new_repo)"
BASE_N="$(git -C "$REPO_N" rev-parse HEAD)"
WT_N="$(mktemp -d -p "$SCRATCH_ROOT")"
rmdir "$WT_N"
git -C "$REPO_N" worktree add -q --detach "$WT_N" "$BASE_N"
cat > "$WT_N/app/calc.py" <<'EOF'
def add(a, b):
    # variante en worktree
    return a + b
EOF
run_red "$WT_N" "$BASE_N" "$CMD_SUITE" "$BASE_SCOPE"
[ "$RED_RC" -eq 0 ] || { echo "FAIL (n): worktree rechazado, exit code $RED_RC. stderr: $RED_ERR"; exit 1; }
assert_field tests_intactos true
assert_field suite_verde true
assert_field scope_respetado true
assert_field oraculo_independiente true

# === (o) determinismo: 2 corridas idénticas → salida byte-idéntica ========
echo "— caso (o): determinismo (2 corridas → byte-idéntico)"
REPO_O="$(new_repo)"
BASE_O="$(git -C "$REPO_O" rev-parse HEAD)"
cat >> "$REPO_O/app/calc.py" <<'EOF'


def sub(a, b):
    return a - b
EOF
run_red "$REPO_O" "$BASE_O" "$CMD_SUITE" "$BASE_SCOPE"
FIRST_JSON="$RED_JSON"; FIRST_ERR="$RED_ERR"; FIRST_RC="$RED_RC"
run_red "$REPO_O" "$BASE_O" "$CMD_SUITE" "$BASE_SCOPE"
[ "$RED_JSON" = "$FIRST_JSON" ] \
  || { echo "FAIL (o): stdout no determinístico: '$FIRST_JSON' vs '$RED_JSON'"; exit 1; }
[ "$RED_ERR" = "$FIRST_ERR" ] \
  || { echo "FAIL (o): stderr no determinístico: '$FIRST_ERR' vs '$RED_ERR'"; exit 1; }
[ "$RED_RC" -eq "$FIRST_RC" ] \
  || { echo "FAIL (o): exit code no determinístico: $FIRST_RC vs $RED_RC"; exit 1; }

echo "OK: red.sh (limpio, test tocado, suite roja, scope violado, caracterización congelada, tests nuevos con/sin cobertura, error interno fail-closed, rename, borrado, directorio de tests nuevo/CRÍTICO, espacios/acentos, naming no-python, worktree, determinismo)"
