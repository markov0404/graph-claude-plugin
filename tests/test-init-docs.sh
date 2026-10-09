#!/usr/bin/env bash
# Test de la prosa que lee un usuario nuevo: la línea fija de la Fase 5 de
# skills/init/SKILL.md y lo que la sección Use del README dice de /graph:init.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

SKILL_INIT="$ROOT/skills/init/SKILL.md"
README="$ROOT/README.md"

# La línea fija que la Fase 5 debe mostrar TEXTUAL antes de preguntar nada.
# `SUBCADENA` es el fragmento exacto que fija el pedido; `COMPLETA` es la línea
# entera, que además dice quién puede editarla.
SUBCADENA='se aplican como anti-criterios en cada /graph:do y tienen precedencia sobre lo que pidas; solo vos las editás'
COMPLETA='Estas reglas (C1..CN) se aplican como anti-criterios en cada /graph:do y tienen precedencia sobre lo que pidas; solo vos las editás — el sistema nunca las toca por su cuenta.'

fail() { echo "FAIL $1: $2"; exit 1; }

for f in "$SKILL_INIT" "$README"; do
  [ -f "$f" ] || fail 0 "falta el archivo $f (raíz detectada: $ROOT)"
done

# Extrae una sección markdown: desde el primer heading `## ` cuyo texto empieza con
# <prefijo> hasta el siguiente heading `## ` (exclusivo). Los `## ` que viven dentro
# de bloques de código (las plantillas de `.graph/`) no abren sección: no coinciden
# con el prefijo, y por eso solo cierran una sección ya abierta.
extrae_seccion() { # <archivo> <prefijo-del-heading>
  awk -v p="$2" '
    /^## / { if (dentro) exit; dentro = (index($0, p) == 1); next }
    dentro { print }
  ' "$1"
}

extrae_seccion "$SKILL_INIT" '## Fase 5' > "$TMP/fase5.txt"
extrae_seccion "$README" '## Use' > "$TMP/use.txt"

# Caso 1 — caracterización: las dos secciones existen y conservan lo que ya decían.
# No es un hash del cuerpo (congelarlo haría fallar toda edición legítima futura):
# son sentinelas de lo que el pedido NO debe truncar ni reescribir.
[ -s "$TMP/fase5.txt" ] || fail 1 "skills/init/SKILL.md no tiene una sección '## Fase 5' con contenido"
[ -s "$TMP/use.txt" ] || fail 1 "README.md no tiene una sección '## Use' con contenido"
for s in 'resumen de UNA pantalla' 'AskUserQuestion' 'Cada' 'corrección se aplica DE INMEDIATO'; do
  grep -qF -- "$s" "$TMP/fase5.txt" || fail 1 "la Fase 5 de skills/init/SKILL.md perdió '$s'"
done
for s in '/graph:init' '/graph:do' '`.graph/` knowledge base' 'Useful flags:'; do
  grep -qF -- "$s" "$TMP/use.txt" || fail 1 "la sección Use del README perdió '$s'"
done
for s in '## Fase 6 — Git'; do
  grep -qF -- "$s" "$SKILL_INIT" || fail 1 "skills/init/SKILL.md quedó truncado: falta '$s'"
done
for s in '## Layout' '## Tests' '## License'; do
  grep -qF -- "$s" "$README" || fail 1 "README.md quedó truncado: falta '$s'"
done

# Caso 2 — (a): la Fase 5 trae la línea fija, textual y en UNA sola línea.
grep -qF -- "$SUBCADENA" "$TMP/fase5.txt" || fail 2 \
  "la Fase 5 de skills/init/SKILL.md no dice para qué sirve la constitution: falta textual «$SUBCADENA»"
grep -qF -- "$COMPLETA" "$TMP/fase5.txt" || fail 2 \
  "la Fase 5 tiene el fragmento pero no la línea fija completa: falta textual «$COMPLETA»"

# Caso 3 — (a bis): la línea fija aparece ANTES de la mención a AskUserQuestion,
# porque el usuario tiene que saber qué está leyendo antes de que se le pregunte.
N_LINEA=$(grep -n -F -m 1 -- "$SUBCADENA" "$TMP/fase5.txt" | cut -d: -f1)
N_ASK=$(grep -n -F -m 1 -- 'AskUserQuestion' "$TMP/fase5.txt" | cut -d: -f1)
[ "$N_LINEA" -lt "$N_ASK" ] || fail 3 \
  "en la Fase 5 la línea fija está en la línea $N_LINEA de la sección y AskUserQuestion en la $N_ASK: se pregunta antes de explicar"

# Caso 4 — (b): la sección Use del README nombra constitution.md.
grep -qF -- 'constitution.md' "$TMP/use.txt" || fail 4 \
  "la sección Use del README no nombra 'constitution.md' — un usuario nuevo no se entera de que existe"

# Caso 5 — (b bis): esa misma sección nombra las dos preguntas de init.
grep -qF -- '.gitignore' "$TMP/use.txt" || fail 5 \
  "la sección Use del README no menciona '.gitignore' — falta la segunda pregunta de /graph:init"
if ! grep -qiF -- 'correct' "$TMP/use.txt" && ! grep -qiF -- 'corregir' "$TMP/use.txt"; then
  fail 5 "la sección Use del README no menciona corregir/correct — falta la primera pregunta de /graph:init"
fi

echo "OK: init-docs (Fase 5 explica la constitution antes de preguntar; README nombra constitution.md y las dos preguntas de init)"
