# GRAPH · graph-plugin
> Actualizado: 2026-08-31 · Estado: completo

**Qué es:** Plugin de Claude Code que convierte un prompt corto en ejecución disciplinada por capas (mini-spec → contexto → preflight → tier S/M/L → gate → ejecución convergente → cierre), con conocimiento acumulativo por repo en `.graph/`.
**Stack:** Sistema de plugins de Claude Code (SKILL.md + hooks + JSON), bash puro, markdown en español. Sin dependencias externas; fixtures de prueba en Node (`node:test`) y Python (`pytest`).
**Comandos clave:** test: `tests/run-scenarios.sh` · build: n/a · lint: n/a (detalle en commands.md)
**Top-5 archivos/módulos:**
1. `skills/do/SKILL.md` — el orquestador: 8 fases, 7 reglas duras, tiers S/M/L
2. `skills/init/SKILL.md` — setup por repo: escaneo, verificación de comandos, generación de `.graph/`
3. `skills/do/references/workflow-templates.md` — 3 plantillas de Workflow para tier L
4. `tests/run-scenarios.sh` — suite automatizada E1-E3 (init, gate/no-mutación, --quick)
5. `hooks/load-index.sh` — inyecta este INDEX al contexto en cada sesión
**Convenciones esenciales:**
- Todo texto visible al usuario en español; bash con `set -euo pipefail` y mensajes `FAIL`/`OK`
- Commits `tipo: descripción` — tipo en inglés (feat/fix/test/GRAPH), descripción en español imperativo
- Verificación siempre con método explícito y evidencia real — prohibido "debería funcionar" (detalle en conventions.md)
