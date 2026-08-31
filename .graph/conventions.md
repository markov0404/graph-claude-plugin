# Convenciones

- Español en todo texto visible al usuario (skills, README, mensajes de scripts, manifiestos); claves JSON y flags técnicos (S/M/L, refresh) sin traducir.
- SKILL.md: frontmatter YAML con `description`; título `# /graph:<nombre>`; cita de `"$ARGUMENTS"`; fases numeradas como `## Fase N — Nombre`; reglas duras numeradas con negativas explícitas ("Nada se ejecuta", "Prohibido", "Nunca"); plantillas de archivos en bloques de código con formato exacto.
- Todo criterio verificable lleva su método de verificación explícito: código → comando exacto + output esperado; investigación → verificación adversarial contra fuentes; documento → revisión independiente. Nunca "debería funcionar".
- Bash: `#!/usr/bin/env bash` + comentario de una línea + `set -euo pipefail`; raíz con `"$(cd "$(dirname "$0")/.." && pwd)"`; quoting estricto; comandos multi-flag en arrays (`"${CC[@]}"`); temporales con `mktemp -d` + `trap ... EXIT`.
- Mensajes de scripts: fallo `FAIL <ID>: <descripción>` + `exit 1`; éxito `OK: <descripción>`; progreso con prefijo `— `.
- Condicionales de test con `[ ... ] || { echo "FAIL ..."; exit 1; }`, no `if [ ! ... ]`.
- Commits: `tipo: descripción` — tipo `feat`/`fix`/`test`/`GRAPH` y descripción corta en español imperativo, con contexto tras ` — ` si hace falta.
- Sin contadores de intentos en ningún proceso: la salida es por criterios cumplidos; estancamiento → escalada (diagnóstico → fan-out de perspectivas → subir tier).
- Bitácoras como tablas markdown con campos obligatorios (task record: Mini-spec / Diario / Verificación final / Resultado).
- Tests headless con `--dangerously-skip-permissions` SOLO dentro de fixtures desechables de `tests/build/`.
