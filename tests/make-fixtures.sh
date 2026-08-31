#!/usr/bin/env bash
# Genera repos fixture desechables en tests/build/ (gitignoreado). Idempotente.
set -euo pipefail
BASE="$(cd "$(dirname "$0")" && pwd)/build"
rm -rf "$BASE"; mkdir -p "$BASE"

JS="$BASE/fixture-js"
mkdir -p "$JS/src" "$JS/test"
cat > "$JS/package.json" <<'EOF'
{
  "name": "fixture-js",
  "version": "1.0.0",
  "type": "module",
  "scripts": { "test": "node --test test/**/*.test.js" }
}
EOF
cat > "$JS/src/cart.js" <<'EOF'
export function total(items) {
  return items.reduce((sum, it) => sum + it.price * it.qty, 0);
}
EOF
cat > "$JS/test/cart.test.js" <<'EOF'
import { test } from 'node:test';
import assert from 'node:assert';
import { total } from '../src/cart.js';

test('total suma precio por cantidad', () => {
  assert.equal(total([{ price: 10, qty: 2 }]), 20);
});
EOF
(cd "$JS" && git init -qb main && git add -A && git -c user.email=fx@fx -c user.name=fx commit -qm "fixture inicial")

PY="$BASE/fixture-py"
mkdir -p "$PY/app" "$PY/tests"
: > "$PY/app/__init__.py"
cat > "$PY/app/slug.py" <<'EOF'
def slugify(text: str) -> str:
    return "-".join(text.lower().split())
EOF
cat > "$PY/tests/test_slug.py" <<'EOF'
from app.slug import slugify

def test_slugify_espacios():
    assert slugify("Hola Mundo") == "hola-mundo"
EOF
cat > "$PY/pytest.ini" <<'EOF'
[pytest]
testpaths = tests
EOF
(cd "$PY" && git init -qb main && git add -A && git -c user.email=fx@fx -c user.name=fx commit -qm "fixture inicial")

echo "fixtures listos en $BASE"
