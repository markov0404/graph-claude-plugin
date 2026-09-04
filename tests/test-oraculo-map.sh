#!/usr/bin/env bash
# Test de tools/oraculo-map.sh (mapa de oráculo, ronda 8 + fix): caso
# normal con hashes verificables, test trivial → débil, archivo con solo
# asserts reales → fuerte, verify ok/hash-cambiado/archivo-borrado, naming
# no-python (conteo de asserts/expects), paths con espacios y acentos,
# determinismo (2 corridas byte-idénticas) y error interno fail-closed.
# Ronda de fix (contrato §2, r8-contrato-fix.md): README.md bajo tests/
# con 'expect(' en prosa → débil (n_tests==0 manda siempre), helpers.js
# sin ninguna declaración it(/test( → débil, TAB en nombre de archivo →
# rc=1 fail-closed, symlink que matchea el patrón → diag de omisión (no
# silencio), determinismo bajo dos LC_ALL distintos, pytest.raises
# (with-item) → fuerte, y stdin con ~50 archivos (la vía nueva que
# reemplaza argv para no pisar MAX_ARG_STRLEN).
# Fixtures 100% fuera del árbol del repo (mktemp), como exige
# conventions.md para tests headless.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOL="$ROOT/tools/oraculo-map.sh"

[ -x "$TOOL" ] || { echo "FAIL: no existe o no es ejecutable $TOOL"; exit 1; }
command -v python3 >/dev/null 2>&1 \
  || { echo "FAIL: falta python3 en el entorno (prerrequisito no declarado)"; exit 1; }

# Raíz única de scratch (fuera del árbol del repo): todos los fixtures se
# crean dentro de ella vía `mktemp -p`, un solo trap limpia todo.
SCRATCH_ROOT="$(mktemp -d)"
trap 'rm -rf "$SCRATCH_ROOT"' EXIT

# md5_7 <archivo>: hash independiente (misma fórmula que el tool) para
# verificar que el TSV no inventa hashes.
md5_7() {
  python3 -c 'import hashlib,sys; sys.stdout.write(hashlib.md5(open(sys.argv[1],"rb").read()).hexdigest()[:7])' "$1"
}

# tsv_row <tsv> <archivo>: imprime la fila del TSV cuyo primer campo es
# EXACTAMENTE <archivo> (evita matches parciales por substring).
tsv_row() {
  awk -F'\t' -v want="$2" '$1 == want { print; found=1 } END { if (!found) exit 1 }' <<< "$1"
}

# === (a) caso normal: scan completo + hashes verificables ===================
echo "— caso (a): scan completo, hashes verificables"
REPO_A="$(mktemp -d -p "$SCRATCH_ROOT")"
mkdir -p "$REPO_A/app" "$REPO_A/tests"
cat > "$REPO_A/app/calc.py" <<'EOF'
def add(a, b):
    return a + b
EOF
cat > "$REPO_A/tests/test_calc.py" <<'EOF'
from app.calc import add


def test_add_basico():
    assert add(2, 3) == 5


def test_add_negativos():
    assert add(-1, -1) == -2
EOF
: > "$REPO_A/tests/__init__.py"

OUT_A="$("$TOOL" scan "$REPO_A")"
RC_A=$?
[ "$RC_A" -eq 0 ] || { echo "FAIL (a): exit code $RC_A"; exit 1; }

ROW_CALC="$(tsv_row "$OUT_A" "tests/test_calc.py")" \
  || { echo "FAIL (a): no apareció tests/test_calc.py en el TSV: $OUT_A"; exit 1; }
[ "$(printf '%s' "$ROW_CALC" | cut -f2)" = "2" ] \
  || { echo "FAIL (a): n_tests esperado 2, fila: $ROW_CALC"; exit 1; }
[ "$(printf '%s' "$ROW_CALC" | cut -f3)" = "fuerte" ] \
  || { echo "FAIL (a): fuerza esperada 'fuerte', fila: $ROW_CALC"; exit 1; }
EXPECTED_HASH="$(md5_7 "$REPO_A/tests/test_calc.py")"
GOT_HASH="$(printf '%s' "$ROW_CALC" | cut -f4)"
[ "$GOT_HASH" = "$EXPECTED_HASH" ] \
  || { echo "FAIL (a): hash7 no coincide (esperaba $EXPECTED_HASH, obtuvo $GOT_HASH)"; exit 1; }
# tests/__init__.py SÍ debe aparecer (todo archivo bajo tests/ cuenta, sea
# cual sea su nombre — TEST_PATTERN contractual, verbatim de red.sh r7),
# vacío → 0 tests, fuerza débil (fail-closed: nunca se inventa un test).
ROW_INIT="$(tsv_row "$OUT_A" "tests/__init__.py")" \
  || { echo "FAIL (a): tests/__init__.py debería aparecer (cualquier archivo bajo tests/ cuenta): $OUT_A"; exit 1; }
[ "$(printf '%s' "$ROW_INIT" | cut -f2)" = "0" ] \
  || { echo "FAIL (a): tests/__init__.py debería tener n_tests=0, fila: $ROW_INIT"; exit 1; }
[ "$(printf '%s' "$ROW_INIT" | cut -f3)" = "débil" ] \
  || { echo "FAIL (a): tests/__init__.py debería ser 'débil' (0 tests), fila: $ROW_INIT"; exit 1; }

# === (b) test trivial → débil ===============================================
echo "— caso (b): test trivial (assert True / assertTrue(True) / sin asserts) → débil"
REPO_B="$(mktemp -d -p "$SCRATCH_ROOT")"
mkdir -p "$REPO_B/tests"
cat > "$REPO_B/tests/test_trivial.py" <<'EOF'
import unittest


def test_plain_trivial():
    assert True


class TrivialCase(unittest.TestCase):
    def test_method_trivial(self):
        self.assertTrue(True)

    def test_no_assert(self):
        pass
EOF
OUT_B="$("$TOOL" scan "$REPO_B")"
ROW_TRIV="$(tsv_row "$OUT_B" "tests/test_trivial.py")" \
  || { echo "FAIL (b): no apareció tests/test_trivial.py en el TSV: $OUT_B"; exit 1; }
[ "$(printf '%s' "$ROW_TRIV" | cut -f2)" = "3" ] \
  || { echo "FAIL (b): n_tests esperado 3, fila: $ROW_TRIV"; exit 1; }
[ "$(printf '%s' "$ROW_TRIV" | cut -f3)" = "débil" ] \
  || { echo "FAIL (b): fuerza esperada 'débil', fila: $ROW_TRIV"; exit 1; }

# === (c) archivo con solo asserts reales → fuerte ===========================
echo "— caso (c): archivo con solo asserts reales → fuerte"
REPO_C="$(mktemp -d -p "$SCRATCH_ROOT")"
mkdir -p "$REPO_C/tests"
cat > "$REPO_C/tests/test_real.py" <<'EOF'
def compute(x):
    return x * x


def test_compute_square():
    assert compute(3) == 9


def test_compute_zero():
    assert compute(0) == 0
EOF
OUT_C="$("$TOOL" scan "$REPO_C")"
ROW_REAL="$(tsv_row "$OUT_C" "tests/test_real.py")" \
  || { echo "FAIL (c): no apareció tests/test_real.py en el TSV: $OUT_C"; exit 1; }
[ "$(printf '%s' "$ROW_REAL" | cut -f2)" = "2" ] \
  || { echo "FAIL (c): n_tests esperado 2, fila: $ROW_REAL"; exit 1; }
[ "$(printf '%s' "$ROW_REAL" | cut -f3)" = "fuerte" ] \
  || { echo "FAIL (c): fuerza esperada 'fuerte', fila: $ROW_REAL"; exit 1; }

# === (d) verify ok ===========================================================
echo "— caso (d): verify ok (hash coincide)"
HASH_REAL="$(printf '%s' "$ROW_REAL" | cut -f4)"
OUT_D="$(mktemp -p "$SCRATCH_ROOT")"; ERR_D="$(mktemp -p "$SCRATCH_ROOT")"
set +e
"$TOOL" verify "$REPO_C" tests/test_real.py "$HASH_REAL" >"$OUT_D" 2>"$ERR_D"
RC_D=$?
set -e
[ "$RC_D" -eq 0 ] || { echo "FAIL (d): esperaba rc=0, fue $RC_D. stderr: $(cat "$ERR_D")"; exit 1; }
[ -z "$(cat "$ERR_D")" ] || { echo "FAIL (d): verify ok no debería emitir diag. stderr: $(cat "$ERR_D")"; exit 1; }

# === (e) verify hash-cambiado → rc=1 ========================================
echo "— caso (e): verify con hash cambiado → rc=1 + diag"
cat >> "$REPO_C/tests/test_real.py" <<'EOF'


def test_extra():
    assert compute(4) == 16
EOF
OUT_E="$(mktemp -p "$SCRATCH_ROOT")"; ERR_E="$(mktemp -p "$SCRATCH_ROOT")"
set +e
"$TOOL" verify "$REPO_C" tests/test_real.py "$HASH_REAL" >"$OUT_E" 2>"$ERR_E"
RC_E=$?
set -e
[ "$RC_E" -eq 1 ] || { echo "FAIL (e): esperaba rc=1, fue $RC_E"; exit 1; }
grep -qF "diag:" "$ERR_E" \
  || { echo "FAIL (e): stderr sin diag. stderr: $(cat "$ERR_E")"; exit 1; }
grep -qF "$HASH_REAL" "$ERR_E" \
  || { echo "FAIL (e): diag no menciona el hash esperado. stderr: $(cat "$ERR_E")"; exit 1; }

# === (f) verify archivo-borrado → rc=1 ======================================
echo "— caso (f): verify con archivo borrado → rc=1 + diag"
rm "$REPO_C/tests/test_real.py"
OUT_F="$(mktemp -p "$SCRATCH_ROOT")"; ERR_F="$(mktemp -p "$SCRATCH_ROOT")"
set +e
"$TOOL" verify "$REPO_C" tests/test_real.py "$HASH_REAL" >"$OUT_F" 2>"$ERR_F"
RC_F=$?
set -e
[ "$RC_F" -eq 1 ] || { echo "FAIL (f): esperaba rc=1, fue $RC_F"; exit 1; }
grep -qF "diag: falta" "$ERR_F" \
  || { echo "FAIL (f): stderr no reporta 'falta'. stderr: $(cat "$ERR_F")"; exit 1; }

# === (g) naming no-python (test/x.test.js) — fuerza por conteo =============
echo "— caso (g): naming no-python (test/x.test.js), fuerza por conteo de asserts"
REPO_G="$(mktemp -d -p "$SCRATCH_ROOT")"
mkdir -p "$REPO_G/test"
cat > "$REPO_G/test/x.test.js" <<'EOF'
const assert = require('assert');

test('doubles a number', () => {
  assert.strictEqual(double(2), 4);
});

it('also passes', () => {
  assert.strictEqual(double(0), 0);
});
EOF
OUT_G="$("$TOOL" scan "$REPO_G")"
ROW_JS="$(tsv_row "$OUT_G" "test/x.test.js")" \
  || { echo "FAIL (g): no apareció test/x.test.js en el TSV: $OUT_G"; exit 1; }
[ "$(printf '%s' "$ROW_JS" | cut -f2)" = "2" ] \
  || { echo "FAIL (g): n_tests esperado 2 (it+test), fila: $ROW_JS"; exit 1; }
[ "$(printf '%s' "$ROW_JS" | cut -f3)" = "fuerte" ] \
  || { echo "FAIL (g): fuerza esperada 'fuerte' (hay asserts), fila: $ROW_JS"; exit 1; }

echo "— caso (g2): naming no-python sin ningún assert/expect → débil"
REPO_G2="$(mktemp -d -p "$SCRATCH_ROOT")"
mkdir -p "$REPO_G2/test"
cat > "$REPO_G2/test/y.test.js" <<'EOF'
test('no verifica nada', () => {
  double(2);
});
EOF
OUT_G2="$("$TOOL" scan "$REPO_G2")"
ROW_JS2="$(tsv_row "$OUT_G2" "test/y.test.js")" \
  || { echo "FAIL (g2): no apareció test/y.test.js en el TSV: $OUT_G2"; exit 1; }
[ "$(printf '%s' "$ROW_JS2" | cut -f3)" = "débil" ] \
  || { echo "FAIL (g2): fuerza esperada 'débil' (sin asserts), fila: $ROW_JS2"; exit 1; }

# === (h) paths con espacios y acentos =======================================
echo "— caso (h): paths con espacios y acentos"
REPO_H="$(mktemp -d -p "$SCRATCH_ROOT")"
mkdir -p "$REPO_H/app" "$REPO_H/tests"
cat > "$REPO_H/app/cálculo módulo.py" <<'EOF'
def compute(x):
    return x + 1
EOF
cat > "$REPO_H/tests/test_cálculo básico.py" <<'EOF'
def test_uno():
    assert 1 + 1 == 2
EOF
OUT_H="$("$TOOL" scan "$REPO_H")"
ROW_ACC="$(tsv_row "$OUT_H" "tests/test_cálculo básico.py")" \
  || { echo "FAIL (h): no apareció el archivo con espacio/acento en el TSV: $OUT_H"; exit 1; }
[ "$(printf '%s' "$ROW_ACC" | cut -f2)" = "1" ] \
  || { echo "FAIL (h): n_tests esperado 1, fila: $ROW_ACC"; exit 1; }
[ "$(printf '%s' "$ROW_ACC" | cut -f3)" = "fuerte" ] \
  || { echo "FAIL (h): fuerza esperada 'fuerte', fila: $ROW_ACC"; exit 1; }
EXPECTED_HASH_H="$(md5_7 "$REPO_H/tests/test_cálculo básico.py")"
[ "$(printf '%s' "$ROW_ACC" | cut -f4)" = "$EXPECTED_HASH_H" ] \
  || { echo "FAIL (h): hash7 no coincide para el archivo con espacio/acento"; exit 1; }
# verify también debe funcionar con esos paths.
set +e
"$TOOL" verify "$REPO_H" "tests/test_cálculo básico.py" "$EXPECTED_HASH_H"
RC_H2=$?
set -e
[ "$RC_H2" -eq 0 ] || { echo "FAIL (h): verify con path acentuado/espaciado esperaba rc=0, fue $RC_H2"; exit 1; }
# el módulo no-test con espacio/acento no debe colarse como fila de test.
! tsv_row "$OUT_H" "app/cálculo módulo.py" >/dev/null 2>&1 \
  || { echo "FAIL (h): app/cálculo módulo.py no debería aparecer como archivo de test"; exit 1; }

# === (i) determinismo: 2 corridas byte-idénticas ============================
echo "— caso (i): determinismo (2 corridas byte-idénticas)"
REPO_I="$(mktemp -d -p "$SCRATCH_ROOT")"
mkdir -p "$REPO_I/tests" "$REPO_I/spec"
cat > "$REPO_I/tests/test_a.py" <<'EOF'
def test_a():
    assert 1 == 1
EOF
cat > "$REPO_I/tests/test_b.py" <<'EOF'
def test_b():
    assert 2 == 2
EOF
cat > "$REPO_I/spec/widget.spec.js" <<'EOF'
test('widget spec', () => {
  expect(1).toBe(1);
});
EOF
OUT_I1="$("$TOOL" scan "$REPO_I")"
OUT_I2="$("$TOOL" scan "$REPO_I")"
[ "$OUT_I1" = "$OUT_I2" ] \
  || { echo "FAIL (i): dos corridas de scan sobre el mismo árbol difieren. out1: $OUT_I1 --- out2: $OUT_I2"; exit 1; }
[ -n "$OUT_I1" ] || { echo "FAIL (i): scan no encontró ningún archivo de test"; exit 1; }

# === (j) error interno (python3 roto) → fail-closed, nunca vacío-silencioso =
echo "— caso (j): error interno → fail-closed (rc=1 + diag, stdout vacío)"
FAKEBIN="$(mktemp -d -p "$SCRATCH_ROOT")"
cat > "$FAKEBIN/python3" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$FAKEBIN/python3"
REPO_J="$(mktemp -d -p "$SCRATCH_ROOT")"
mkdir -p "$REPO_J/tests"
cat > "$REPO_J/tests/test_x.py" <<'EOF'
def test_x():
    assert True
EOF
OUT_J="$(mktemp -p "$SCRATCH_ROOT")"; ERR_J="$(mktemp -p "$SCRATCH_ROOT")"
set +e
PATH="$FAKEBIN:$PATH" "$TOOL" scan "$REPO_J" >"$OUT_J" 2>"$ERR_J"
RC_J=$?
set -e
[ "$RC_J" -ne 0 ] || { echo "FAIL (j): esperaba exit != 0 con python3 roto, fue $RC_J"; exit 1; }
[ -z "$(cat "$OUT_J")" ] \
  || { echo "FAIL (j): stdout debería quedar vacío ante error interno (nunca TSV parcial). stdout: $(cat "$OUT_J")"; exit 1; }
grep -qF "diag:" "$ERR_J" \
  || { echo "FAIL (j): stderr sin diag ante error interno. stderr: $(cat "$ERR_J")"; exit 1; }

echo "— caso (j2): error interno también fail-closed en verify"
OUT_J2="$(mktemp -p "$SCRATCH_ROOT")"; ERR_J2="$(mktemp -p "$SCRATCH_ROOT")"
set +e
PATH="$FAKEBIN:$PATH" "$TOOL" verify "$REPO_J" tests/test_x.py 0000000 >"$OUT_J2" 2>"$ERR_J2"
RC_J2=$?
set -e
[ "$RC_J2" -ne 0 ] || { echo "FAIL (j2): esperaba exit != 0 con python3 roto, fue $RC_J2"; exit 1; }
[ -z "$(cat "$OUT_J2")" ] \
  || { echo "FAIL (j2): stdout debería quedar vacío. stdout: $(cat "$OUT_J2")"; exit 1; }
grep -qF "diag:" "$ERR_J2" \
  || { echo "FAIL (j2): stderr sin diag. stderr: $(cat "$ERR_J2")"; exit 1; }

# === (k) uso inválido → fail-closed con diag ================================
echo "— caso (k): uso inválido (sin argumentos) → rc=1 + diag"
OUT_K="$(mktemp -p "$SCRATCH_ROOT")"; ERR_K="$(mktemp -p "$SCRATCH_ROOT")"
set +e
"$TOOL" >"$OUT_K" 2>"$ERR_K"
RC_K=$?
set -e
[ "$RC_K" -ne 0 ] || { echo "FAIL (k): esperaba exit != 0 sin argumentos, fue $RC_K"; exit 1; }
grep -qF "diag:" "$ERR_K" \
  || { echo "FAIL (k): stderr sin diag. stderr: $(cat "$ERR_K")"; exit 1; }

# === (l) README.md bajo tests/ con 'expect(' en prosa → débil ==============
echo "— caso (l): README.md bajo tests/ menciona 'expect(' en prosa → débil (n_tests==0 manda)"
REPO_L="$(mktemp -d -p "$SCRATCH_ROOT")"
mkdir -p "$REPO_L/tests"
cat > "$REPO_L/tests/test_ok.py" <<'EOF'
def test_ok():
    assert 1 == 1
EOF
cat > "$REPO_L/tests/README.md" <<'EOF'
# Cómo correr esta suite

Cada caso debe expect(resultado).toBe(esperado) para pasar. No hay
código ejecutable acá, es solo prosa que menciona 'expect(' de paso.
EOF
OUT_L="$("$TOOL" scan "$REPO_L")"
ROW_README="$(tsv_row "$OUT_L" "tests/README.md")" \
  || { echo "FAIL (l): no apareció tests/README.md en el TSV: $OUT_L"; exit 1; }
[ "$(printf '%s' "$ROW_README" | cut -f2)" = "0" ] \
  || { echo "FAIL (l): n_tests esperado 0, fila: $ROW_README"; exit 1; }
[ "$(printf '%s' "$ROW_README" | cut -f3)" = "débil" ] \
  || { echo "FAIL (l): fuerza esperada 'débil' (n_tests==0 manda siempre), fila: $ROW_README"; exit 1; }

# === (m) helpers.js sin ninguna declaración it(/test( → débil ===============
echo "— caso (m): helpers.js con 'expect(' interno pero sin it(/test( → débil"
REPO_M="$(mktemp -d -p "$SCRATCH_ROOT")"
mkdir -p "$REPO_M/tests"
cat > "$REPO_M/tests/helpers.js" <<'EOF'
function expectPositive(n) {
  expect(n > 0).toBe(true);
}

module.exports = { expectPositive };
EOF
OUT_M="$("$TOOL" scan "$REPO_M")"
ROW_HELPERS="$(tsv_row "$OUT_M" "tests/helpers.js")" \
  || { echo "FAIL (m): no apareció tests/helpers.js en el TSV: $OUT_M"; exit 1; }
[ "$(printf '%s' "$ROW_HELPERS" | cut -f2)" = "0" ] \
  || { echo "FAIL (m): n_tests esperado 0 (sin it(/test(), fila: $ROW_HELPERS"; exit 1; }
[ "$(printf '%s' "$ROW_HELPERS" | cut -f3)" = "débil" ] \
  || { echo "FAIL (m): fuerza esperada 'débil' (n_tests==0 manda pese a haber expect()), fila: $ROW_HELPERS"; exit 1; }

# === (n) TAB en nombre de archivo → rc=1 fail-closed =========================
echo "— caso (n): TAB en el nombre de un archivo de test → rc=1 + diag (nunca TSV malformado)"
REPO_N="$(mktemp -d -p "$SCRATCH_ROOT")"
mkdir -p "$REPO_N/tests"
TABFILE="$REPO_N/tests/weird$(printf '\t')name.py"
cat > "$TABFILE" <<'EOF'
def test_x():
    assert 1 == 1
EOF
OUT_N="$(mktemp -p "$SCRATCH_ROOT")"; ERR_N="$(mktemp -p "$SCRATCH_ROOT")"
set +e
"$TOOL" scan "$REPO_N" >"$OUT_N" 2>"$ERR_N"
RC_N=$?
set -e
[ "$RC_N" -eq 1 ] || { echo "FAIL (n): esperaba rc=1, fue $RC_N. stderr: $(cat "$ERR_N")"; exit 1; }
[ -z "$(cat "$OUT_N")" ] \
  || { echo "FAIL (n): stdout debería quedar vacío (nunca TSV malformado). stdout: $(cat "$OUT_N")"; exit 1; }
grep -qF "diag:" "$ERR_N" \
  || { echo "FAIL (n): stderr sin diag. stderr: $(cat "$ERR_N")"; exit 1; }
grep -qi "tab" "$ERR_N" \
  || { echo "FAIL (n): diag debería mencionar el TAB como causa. stderr: $(cat "$ERR_N")"; exit 1; }

# === (o) symlink que matchea el patrón → diag de omisión, no silencio ======
echo "— caso (o): symlink bajo tests/ → diag de omisión, no aparece en el TSV, resto sigue con rc=0"
REPO_O="$(mktemp -d -p "$SCRATCH_ROOT")"
mkdir -p "$REPO_O/tests"
cat > "$REPO_O/tests/real_test.py" <<'EOF'
def test_real():
    assert 1 == 1
EOF
ln -s real_test.py "$REPO_O/tests/link_test.py"
ERR_O="$(mktemp -p "$SCRATCH_ROOT")"
OUT_O="$("$TOOL" scan "$REPO_O" 2>"$ERR_O")"
RC_O=$?
[ "$RC_O" -eq 0 ] || { echo "FAIL (o): esperaba rc=0 (el symlink omitido no debe abortar el scan), fue $RC_O. stderr: $(cat "$ERR_O")"; exit 1; }
tsv_row "$OUT_O" "tests/real_test.py" >/dev/null \
  || { echo "FAIL (o): tests/real_test.py debería seguir apareciendo en el TSV: $OUT_O"; exit 1; }
! tsv_row "$OUT_O" "tests/link_test.py" >/dev/null 2>&1 \
  || { echo "FAIL (o): el symlink tests/link_test.py NO debería aparecer como fila del TSV: $OUT_O"; exit 1; }
grep -qF "diag: symlink omitido: tests/link_test.py" "$ERR_O" \
  || { echo "FAIL (o): stderr debería avisar la omisión del symlink (no en silencio). stderr: $(cat "$ERR_O")"; exit 1; }

# === (p) determinismo bajo DOS LC_ALL distintos (byte-idéntico) ============
echo "— caso (p): determinismo — mismo árbol, dos LC_ALL distintos del invocador → bytes idénticos"
REPO_P="$(mktemp -d -p "$SCRATCH_ROOT")"
mkdir -p "$REPO_P/tests"
cat > "$REPO_P/tests/test_ñandú.py" <<'EOF'
def test_ñandú():
    assert 1 == 1
EOF
cat > "$REPO_P/tests/test_p.py" <<'EOF'
def test_p():
    assert 2 == 2
EOF
OUT_P1="$(LC_ALL=en_US.utf8 "$TOOL" scan "$REPO_P")"
OUT_P2="$(LC_ALL=C "$TOOL" scan "$REPO_P")"
[ "$OUT_P1" = "$OUT_P2" ] \
  || { echo "FAIL (p): scan bajo LC_ALL=en_US.utf8 difiere de LC_ALL=C (debería ser locale-independiente). out1: $OUT_P1 --- out2: $OUT_P2"; exit 1; }
[ -n "$OUT_P1" ] || { echo "FAIL (p): scan no encontró ningún archivo de test"; exit 1; }

# === (q) pytest.raises (with-item) → fuerte =================================
echo "— caso (q): 'with pytest.raises(...):' cuenta como assert real → fuerte"
REPO_Q="$(mktemp -d -p "$SCRATCH_ROOT")"
mkdir -p "$REPO_Q/tests"
cat > "$REPO_Q/tests/test_raises.py" <<'EOF'
import pytest


def divide(a, b):
    return a / b


def test_divide_by_zero():
    with pytest.raises(ZeroDivisionError):
        divide(1, 0)
EOF
OUT_Q="$("$TOOL" scan "$REPO_Q")"
ROW_RAISES="$(tsv_row "$OUT_Q" "tests/test_raises.py")" \
  || { echo "FAIL (q): no apareció tests/test_raises.py en el TSV: $OUT_Q"; exit 1; }
[ "$(printf '%s' "$ROW_RAISES" | cut -f2)" = "1" ] \
  || { echo "FAIL (q): n_tests esperado 1, fila: $ROW_RAISES"; exit 1; }
[ "$(printf '%s' "$ROW_RAISES" | cut -f3)" = "fuerte" ] \
  || { echo "FAIL (q): fuerza esperada 'fuerte' (pytest.raises cuenta como assert real), fila: $ROW_RAISES"; exit 1; }

# === (r) STDIN con ~50 archivos (vía nueva que reemplaza argv) ==============
# No hace falta reproducir la escala completa de MAX_ARG_STRLEN (miles de
# archivos) para verificar el fix: la lista de rutas ahora viaja por
# stdin, no por argv, así que el límite del kernel para un solo argumento
# de execve() ya no aplica por construcción. Este caso solo ejercita esa
# vía (lectura de stdin + split + loop) a una escala razonable para un
# test rápido y declara que la corrección es estructural, no empírica.
echo "— caso (r): scan con ~50 archivos de test (ejercita la vía stdin, ya no argv)"
REPO_R="$(mktemp -d -p "$SCRATCH_ROOT")"
mkdir -p "$REPO_R/tests"
for i in $(seq -w 0 49); do
  # comparación de strings (no enteros): "assert 00 == 00" sería
  # SyntaxError en python3 (ceros a la izquierda inválidos en literales
  # enteros) — usamos el índice como string para un assert real y válido.
  cat > "$REPO_R/tests/test_bulk_$i.py" <<EOF
def test_bulk_$i():
    assert "$i" == "$i"
EOF
done
OUT_R="$("$TOOL" scan "$REPO_R")"
N_ROWS_R="$(printf '%s\n' "$OUT_R" | grep -c . || true)"
[ "$N_ROWS_R" = "50" ] \
  || { echo "FAIL (r): esperaba 50 filas en el TSV, hubo $N_ROWS_R"; exit 1; }
N_FUERTE_R="$(printf '%s\n' "$OUT_R" | awk -F'\t' '$3 == "fuerte"' | wc -l)"
[ "$N_FUERTE_R" = "50" ] \
  || { echo "FAIL (r): esperaba las 50 filas 'fuerte', hubo $N_FUERTE_R"; exit 1; }

# === (s) directorio ilegible bajo <dir> → find falla → fail-closed =========
# (root ignora los permisos de lectura de directorio, así que este caso
# solo es reproducible corriendo como usuario sin privilegios; si el
# harness corre como root, se declara y se salta en vez de dar falso OK).
if [ "$(id -u)" = "0" ]; then
  echo "— caso (s): SALTEADO (corriendo como root, chmod 000 no bloquea la lectura)"
else
  echo "— caso (s): directorio ilegible bajo <dir> → find falla → rc=1 + diag (no TSV incompleto silencioso)"
  REPO_S="$(mktemp -d -p "$SCRATCH_ROOT")"
  mkdir -p "$REPO_S/tests/locked"
  : > "$REPO_S/tests/locked/secret_test.py"
  cat > "$REPO_S/tests/real_test.py" <<'EOF'
def test_real():
    assert 1 == 1
EOF
  chmod 000 "$REPO_S/tests/locked"
  OUT_S="$(mktemp -p "$SCRATCH_ROOT")"; ERR_S="$(mktemp -p "$SCRATCH_ROOT")"
  set +e
  "$TOOL" scan "$REPO_S" >"$OUT_S" 2>"$ERR_S"
  RC_S=$?
  set -e
  chmod 755 "$REPO_S/tests/locked"
  [ "$RC_S" -eq 1 ] || { echo "FAIL (s): esperaba rc=1, fue $RC_S. stderr: $(cat "$ERR_S")"; exit 1; }
  [ -z "$(cat "$OUT_S")" ] \
    || { echo "FAIL (s): stdout debería quedar vacío (nunca TSV incompleto y silencioso). stdout: $(cat "$OUT_S")"; exit 1; }
  grep -qF "diag:" "$ERR_S" \
    || { echo "FAIL (s): stderr sin diag. stderr: $(cat "$ERR_S")"; exit 1; }
  grep -qF "find" "$ERR_S" \
    || { echo "FAIL (s): diag debería mencionar que fue find quien falló. stderr: $(cat "$ERR_S")"; exit 1; }
fi

echo "— caso (t): artefactos de ejecución podados (__pycache__/*.pyc, .pytest_cache) — hallazgo un repo grande externo"
REPO_T="$(mktemp -d -p "$SCRATCH_ROOT")"
mkdir -p "$REPO_T/tests/__pycache__" "$REPO_T/tests/.pytest_cache/v/cache"
printf 'def test_real():\n    assert 1 == 1\n' > "$REPO_T/tests/test_real.py"
printf '\x03\xf3 binario' > "$REPO_T/tests/__pycache__/test_real.cpython-311.pyc"
printf 'x' > "$REPO_T/tests/.pytest_cache/v/cache/lastfailed"
printf 'x' > "$REPO_T/tests/test_suelto.pyc"
OUT_T="$(mktemp -p "$SCRATCH_ROOT")"
"$TOOL" scan "$REPO_T" >"$OUT_T" 2>/dev/null
[ "$(wc -l < "$OUT_T")" -eq 1 ] || { echo "FAIL (t): se esperaba 1 fila, hubo $(wc -l < "$OUT_T"): $(cat "$OUT_T")"; exit 1; }
grep -q "^tests/test_real.py" "$OUT_T" || { echo "FAIL (t): la fila no es el test real: $(cat "$OUT_T")"; exit 1; }
! grep -qE "pycache|[.]pyc|pytest_cache" "$OUT_T" || { echo "FAIL (t): artefactos no podados: $(cat "$OUT_T")"; exit 1; }

echo "OK: test-oraculo-map.sh — todos los casos pasaron (incl. poda de artefactos)"
