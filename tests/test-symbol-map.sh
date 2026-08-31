#!/usr/bin/env bash
# Test de tools/symbol-map.sh: símbolos conocidos en fixtures reales + caso sin cobertura.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOL="$ROOT/tools/symbol-map.sh"

"$ROOT/tests/make-fixtures.sh" > /dev/null

JS="$ROOT/tests/build/fixture-js"
PY="$ROOT/tests/build/fixture-py"

[ -x "$TOOL" ] || { echo "FAIL: no existe o no es ejecutable $TOOL"; exit 1; }

echo "— caso JS: 'total' asociado a src/cart.js"
out_js="$("$TOOL" "$JS")"
echo "$out_js" | grep -qE '^- `src/cart\.js`:.*\btotal\b' \
  || { echo "FAIL: no encontró 'total' asociado a src/cart.js"; exit 1; }

echo "— caso Python: 'slugify' asociado a app/slug.py"
out_py="$("$TOOL" "$PY")"
echo "$out_py" | grep -qE '^- `app/slug\.py`:.*\bslugify\b' \
  || { echo "FAIL: no encontró 'slugify' asociado a app/slug.py"; exit 1; }

echo "— caso lenguaje sin cobertura: .rb no inventa símbolos"
mkdir -p "$PY/app/legacy"
cat > "$PY/app/legacy/old.rb" <<'EOF'
def legacy_thing
  "cosa vieja"
end

class LegacyWidget
end
EOF
out_rb="$("$TOOL" "$PY")"

echo "$out_rb" | grep -qF '`app/legacy/old.rb`' \
  || { echo "FAIL: el archivo .rb no aparece en la salida"; exit 1; }

! echo "$out_rb" | grep -qE '`app/legacy/old\.rb`:' \
  || { echo "FAIL: el .rb aparece con símbolos (debe listarse sin cobertura, nunca inventar)"; exit 1; }

! echo "$out_rb" | grep -q "legacy_thing" \
  || { echo "FAIL: se inventó un símbolo ('legacy_thing') para un lenguaje sin cobertura"; exit 1; }

echo "$out_rb" | awk '/[Ss]in cobertura/{seen=1} seen && /old\.rb/{f=1} END{exit !f}' \
  || { echo "FAIL: el .rb no aparece bajo la nota de 'sin cobertura'"; exit 1; }

echo "— caso adversarial: símbolo falso dentro de template literal JS / docstring Python no se inventa"
mkdir -p "$JS/src"
cat > "$JS/src/weird.js" <<'EOF'
export function realThing() {
  return 'real';
}

const tpl = `
line one
export function fakeSymbol() {
  return 'fake';
}
line two
`;
EOF

mkdir -p "$PY/app"
cat > "$PY/app/weird.py" <<'EOF'
def real_fn():
    return 'real'


DOC = """
line one
def fake_fn():
    return 'fake'
line two
"""
EOF

out_weird_js="$("$TOOL" "$JS")"
out_weird_py="$("$TOOL" "$PY")"

echo "$out_weird_js" | grep -qE '^- `src/weird\.js`:.*\brealThing\b' \
  || { echo "FAIL: no encontró 'realThing' asociado a src/weird.js"; exit 1; }

! echo "$out_weird_js" | grep -q "fakeSymbol" \
  || { echo "FAIL: se inventó 'fakeSymbol' desde dentro de un template literal JS"; exit 1; }

echo "$out_weird_py" | grep -qE '^- `app/weird\.py`:.*\breal_fn\b' \
  || { echo "FAIL: no encontró 'real_fn' asociado a app/weird.py"; exit 1; }

! echo "$out_weird_py" | grep -q "fake_fn" \
  || { echo "FAIL: se inventó 'fake_fn' desde dentro de un docstring triple-quoted"; exit 1; }

echo "OK: symbol-map (JS, Python, caso sin cobertura, caso adversarial template/docstring)"
