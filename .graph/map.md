# Mapa de arquitectura

## Manifiestos (`.claude-plugin/`)
Identidad y distribución del plugin. `plugin.json` declara el plugin `graph` v0.1.0; `marketplace.json` convierte el propio repo en su marketplace (`graph-marketplace`, source `./`). No dependen de nada.

## Hook de contexto (`hooks/`)
`hooks.json` registra un SessionStart que ejecuta `load-index.sh` (timeout 10s): si el repo tiene `.graph/INDEX.md`, lo inyecta al contexto precedido por la línea `GRAPH: contexto del repo (...)`; si no, silencio y exit 0. Depende de: la variable `CLAUDE_PROJECT_DIR` y el formato de INDEX.md.

## Skill `/graph:init` (`skills/init/SKILL.md`)
Setup idempotente por repo: 6 fases — detección previa (nunca arrasa sin preguntar), escaneo paralelo con agentes Explore (Workflow si >200 archivos/monorepo), verificación de comandos por ejecución real, generación de `.graph/` (6 archivos con formatos exactos), corrección temprana con el usuario, y decisión de git (commitear por defecto). Tiene bloque de modo no interactivo (aplica defaults). Produce los formatos que `do` consume.

## Skill `/graph:do` (`skills/do/SKILL.md`)
El orquestador: 7 reglas duras + 8 fases (0 flags/precondiciones, 1 mini-spec con criterios y anti-criterios con método, 2 contexto desde `.graph/` + exploradores dirigidos, 3 preflight de bloqueos, 4 rúbrica de tier, 5 gate único de aprobación, 6 ejecución S/M/L con loop convergente sin contadores y escalada diagnóstico→fan-out→tier, 7 verificación final con evidencia, 8 cierre que actualiza `.graph/`). Tier S tiene ruta de fallo a M; tier forzado nunca se sobrepasa sin preguntar. Depende de: formatos de `.graph/` (de init) y de `references/workflow-templates.md` (tier L).

## Plantillas de Workflow (`skills/do/references/workflow-templates.md`)
3 plantillas adaptables para tier L: implementación multi-frente (worktrees + verificación adversarial + síntesis por merge de ramas aprobadas), investigación en abanico (refutación contra fuentes), auditoría hasta agotar (loop-until-dry con dedup). JavaScript plano para el Workflow tool; meta como literal puro.

## Suite de pruebas (`tests/`)
`test-hook.sh` (2 casos del hook, TDD), `make-fixtures.sh` (genera fixture-js y fixture-py desechables en `GRAPH_FIXTURES_DIR`, default `~/.cache/graph-plugin/fixtures`, fuera del árbol del repo), `run-scenarios.sh` (E1 init genera `.graph/` verificado; E2 gate bloquea headless sin mutación ni task record prematuro; E3 `--quick` crea base parcial sin mutar código), `scenarios.md` (I1-I7 interactivos: convergencia M, preflight, tier forzado, grafo L, presupuesto, hook, tier S). Cobertura solo-interactiva: escalada, Workflow real, presupuesto.

## Documentación (`docs/superpowers/`)
`specs/2026-08-31-graph-plugin-design.md` (autoridad de diseño), `plans/2026-08-31-graph-plugin.md` (plan de implementación en 8 tareas, ejecutado), `specs/2026-08-31-graph-mejoras-sota-design.md` (ronda 1 SOTA, implementada) y `specs/2026-08-31-backlog-ronda-2.md` (pendientes). Registro histórico: no se edita retroactivamente (C7).

## Herramientas propias (`tools/`)
`symbol-map.sh` — extractor de símbolos de nivel superior por archivo (bash+awk, cero dependencias, política de tooling C5): JS/TS, Python y bash; conservador (estado de paridad para strings/docstrings: jamás inventa); testeado por `tests/test-symbol-map.sh` (4 casos). Lo consumen las Fases 2/4 de init para la sección de símbolos de este archivo.

## Símbolos
<!-- symbol-map:start -->
## Símbolos por archivo
_(generado automáticamente por tools/symbol-map.sh — no editar a mano esta sección)_

- `tools/symbol-map.sh`: in_list, join_comma, extract_js, extract_py, extract_sh
<!-- symbol-map:end -->
