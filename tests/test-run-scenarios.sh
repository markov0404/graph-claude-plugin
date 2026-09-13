#!/usr/bin/env bash
# Test del cableado de tests/run-scenarios.sh y de la documentación que lo describe.
# Determinista y gratis: NUNCA ejecuta run-scenarios.sh, ningún tests/e*.sh ni claude.
# Solo `bash -n` y grep/awk/sed sobre los archivos. Cero dependencias externas.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RS="$ROOT/tests/run-scenarios.sh"
CMDS="$ROOT/.graph/commands.md"
INDEX="$ROOT/.graph/INDEX.md"

fail() { echo "FAIL $1: $2"; exit 1; }

echo "— A1: tests/run-scenarios.sh es sintácticamente válido (sin ejecutarlo)"
[ -f "$RS" ] || fail A1 "no existe $RS"
bash -n "$RS" 2>/dev/null || fail A1 "bash -n tests/run-scenarios.sh falló"

echo "— A2: los cinco tests deterministas gratis corren ANTES del primer \${CC[@]}"
CC_LINE=$(grep -n -F '${CC[@]}' "$RS" | head -1 | cut -d: -f1 || true)
[ -n "$CC_LINE" ] || fail A2 "run-scenarios.sh no tiene ninguna línea que use \${CC[@]}"
for t in test-hook.sh test-red.sh test-oraculo-map.sh test-exploracion.sh test-symbol-map.sh; do
  L=$(grep -n -F "\$ROOT/tests/$t" "$RS" | head -1 | cut -d: -f1 || true)
  [ -n "$L" ] || fail A2 "falta la invocación de $t en run-scenarios.sh"
  [ "$L" -lt "$CC_LINE" ] \
    || fail A2 "$t se invoca en la línea $L, no antes de la primera línea con \${CC[@]} (línea $CC_LINE)"
done

echo "— A3: e8-escalacion.sh cableado tras e7 y tolerando rc=2 (INCONCLUSO)"
E8LINE='set +e; "$ROOT/tests/e8-escalacion.sh"; rc=$?; set -e'
GUARD='[ $rc -ne 1 ] || exit 1'
E7_N=$(grep -n -F '"$ROOT/tests/e7-presupuesto.sh"' "$RS" | head -1 | cut -d: -f1 || true)
[ -n "$E7_N" ] || fail A3 "falta la invocación de e7-presupuesto.sh en run-scenarios.sh"
E8_N=$(grep -n -x -F "$E8LINE" "$RS" | head -1 | cut -d: -f1 || true)
[ -n "$E8_N" ] || fail A3 "falta la línea literal «$E8LINE»"
[ "$E8_N" -gt "$E7_N" ] \
  || fail A3 "la línea de e8 (línea $E8_N) no es posterior a la de e7-presupuesto.sh (línea $E7_N)"
NEXT=$(sed -n "$((E8_N + 1))p" "$RS")
[ "$NEXT" = "$GUARD" ] \
  || fail A3 "la línea siguiente a la de e8 es «$NEXT», se esperaba «$GUARD» (rc=2 no debe abortar la suite)"

echo "— A4: el último echo del archivo anuncia E1-E8"
ESPERADO='OK: escenarios automatizados (E1-E8)'
LAST_ECHO=$(awk '/^[[:space:]]*echo /{s=$0} END{print s}' "$RS")
[ -n "$LAST_ECHO" ] || fail A4 "run-scenarios.sh no tiene ninguna línea que empiece con echo"
MSG=${LAST_ECHO#*echo }
MSG=${MSG#\"}; MSG=${MSG%\"}
MSG=${MSG#\'}; MSG=${MSG%\'}
[ "$MSG" = "$ESPERADO" ] || fail A4 "el último echo dice «$MSG», se esperaba «$ESPERADO»"

echo "— A5: la documentación describe la suite tal cual (sin E1-E3, con E1-E8)"
for f in "$CMDS" "$INDEX"; do
  rel="${f#"$ROOT"/}"
  [ -f "$f" ] || fail A5 "no existe $rel"
  N=$(grep -c 'E1-E3' "$f" || true)
  [ "$N" -eq 0 ] || fail A5 "$rel menciona E1-E3 $N vez/veces; la suite ya no termina en E3"
  grep -q 'E1-E8' "$f" || fail A5 "$rel no menciona E1-E8"
done

echo "OK: run-scenarios (cableado: tests gratis antes del primer claude, e8 tolerando rc=2, E1-E8, docs sin E1-E3)"
