# GRAPH · graph-plugin
> Actualizado: 2026-09-03 · Estado: completo · Esquema: 4

**Qué es:** Plugin de Claude Code que convierte un prompt corto en ejecución disciplinada por capas (mini-spec → contexto → preflight → tier S/M/L → gate → ejecución convergente → cierre), con conocimiento acumulativo por repo en `.graph/`.
**Stack:** Sistema de plugins de Claude Code (SKILL.md + hooks + JSON), bash + awk propios (política: cero dependencias externas), markdown en español. Fixtures de prueba en Node (`node:test`) y Python (`pytest`).
**Comandos clave:** test: `tests/run-scenarios.sh` · build: n/a · lint: n/a (detalle en commands.md)
**Testing:** suite automatizada E1-E7 (convergencia, bloqueo, retomar+lock, presupuesto) + tests de hook y symbol-map, verificado por ejecución; benchmark e2e con datos reales: v0 en `bench/REPORT.md` (limpio 4/12 vs 9/12) y nivel 2 en `bench/seq/REPORT-NIVEL2.md` (20/20 limpias; horizonte no cruza en 5 pasos, memoria +$2.10 sin rendimiento); ablación del mapa de oráculo en `bench/REPORT-R8.md` (Δ ruteo 0, Δ costo +$4.49: sin valor marginal en repos chicos); **nivel 3 con tareas REALES minadas de un repo ajeno en `bench/REPORT-NIVEL3.md` (el diferencial de disciplina se evapora con harness justo: el valor de GRAPH es condicional a tareas con trampa)**; validación r7 del router en `bench/REPORT-R7.md` (config R: 11/12 limpio en r5 — la mejor medida — pero CPEL 3.4× en secuencia limpia: criterio de costo pre-registrado FALLADO y declarado); I1-I7 interactivos aún sin ejercitar (detalle en commands.md y map.md)
**Top-5 archivos/módulos:**
1. `skills/do/SKILL.md` — el orquestador: 8 fases, 7 reglas duras, tiers S/M/L, constitution y estado en-curso
2. `skills/init/SKILL.md` — setup/refresh por repo: escaneo solo-lectura, comandos verificados, generación de `.graph/`
3. `skills/do/references/workflow-templates.md` — 3 plantillas de Workflow tier L con tabla lente→modelo
4. `tests/run-scenarios.sh` — suite automatizada E1-E3 (init+constitution, gate/no-mutación, --quick)
5. `tools/symbol-map.sh` — tooling propio bash+awk: símbolos por archivo, endurecido contra strings (test propio con caso adversarial)
**Convenciones esenciales:**
- Español en todo lo visible; bash con `set -euo pipefail` y mensajes `FAIL`/`OK`; commits `tipo: descripción` + trailer `GRAPH-Task: <slug>` en tareas
- Verificación con método explícito y evidencia real; sin contadores de intentos; constitution (C1-C8) precede a los anti-criterios por tarea
- Subagentes exploradores: SOLO LECTURA ESTRICTA, siempre en su prompt (detalle en conventions.md)
