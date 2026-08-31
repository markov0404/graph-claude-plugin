# Convenciones

- Español en todo texto visible al usuario (skills, README, mensajes de scripts, manifiestos); claves JSON y flags técnicos (S/M/L, refresh) sin traducir.
- SKILL.md: frontmatter YAML con `description`; título `# /graph:<nombre>`; cita de `"$ARGUMENTS"`; fases numeradas como `## Fase N — Nombre`; reglas duras numeradas con negativas explícitas ("Nada se ejecuta", "Prohibido", "Nunca"); plantillas de archivos en bloques de código con formato exacto.
- Todo criterio verificable lleva su método de verificación explícito: código → comando exacto + output esperado; investigación → verificación adversarial contra fuentes; documento → revisión independiente. Nunca "debería funcionar".
- En tier M, criterio de código testeable → TDD: test que falla primero (evidencia RED en el diario), luego el fix (GREEN); escape explícito y auditable si no es testeable razonablemente.
- Bash: `#!/usr/bin/env bash` + comentario de una línea + `set -euo pipefail`; raíz con `"$(cd "$(dirname "$0")/.." && pwd)"`; quoting estricto; comandos multi-flag en arrays (`"${CC[@]}"`); temporales con `mktemp -d` + `trap ... EXIT`; condicionales `[ ... ] || { echo "FAIL ..."; exit 1; }`.
- Mensajes de scripts: fallo `FAIL <ID>: <descripción>` + `exit 1`; éxito `OK: <descripción>`; progreso con prefijo `— `.
- Commits: `tipo: descripción` — tipo `feat`/`fix`/`test`/`docs`/`GRAPH` en inglés, descripción corta en español imperativo, contexto tras ` — ` si hace falta.
- Trazabilidad: los commits producidos por una tarea GRAPH llevan el trailer `GRAPH-Task: <slug>` y se navegan con `git log --grep "GRAPH-Task: <slug>"`.
- Sin contadores de intentos en ningún proceso: la salida es por criterios cumplidos; estancamiento (misma causa raíz, o misma acción con mismo resultado dos veces seguidas) → escalada: diagnóstico → fan-out de perspectivas → subir tier.
- Subagentes exploradores: instrucción SOLO LECTURA ESTRICTA obligatoria EN SU PROMPT (jamás ejecutar scripts del repo, tampoco "para ver qué hacen") — los invariantes no se heredan solos.
- Bitácoras como tablas markdown con campos obligatorios (task record: Mini-spec / Diario / Verificación final / Resultado); estado transitorio explícito "en ejecución (transitorio)" mientras la tarea corre.
- Verificación adversarial con lentes diversas Y modelos diversos por lente (correctitud→barato, valor→medio, riesgo→el más capaz) para romper errores correlacionados del voto.
- Política de tooling: solo open source pinneado/vendoreado o rehecho en casa con tests, siempre dentro de lo instalable; cero prerrequisitos externos.
- Tests headless con `--dangerously-skip-permissions` SOLO dentro de los fixtures desechables de `GRAPH_FIXTURES_DIR` (default `~/.cache/graph-plugin/fixtures`, FUERA del árbol del repo — aislamiento estructural); salidas de escenarios en `tests/*.out` (gitignoreadas).
