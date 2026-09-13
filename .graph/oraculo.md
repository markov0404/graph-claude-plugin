# Mapa de oráculo · graph-plugin
> Esquema-oraculo: 1 · Generado: /graph:init 2026-09-08 · Última tarea: runner-suite-real

| área / comportamiento | checks | fuerza | vigencia | origen |
|---|---|---|---|---|
| escenario end-to-end e4 del pipeline | tests/e4-convergencia.sh (0 tests) | débil | c0faec4 | init 2026-09-08 |
| escenario end-to-end e5 del pipeline | tests/e5-bloqueo.sh (0 tests) | débil | 8b7fbb1 | init 2026-09-08 |
| escenario end-to-end e6 del pipeline | tests/e6-retomar-lock.sh (0 tests) | débil | 47d624b | tarea e6-baseline-con-oraculo |
| escenario end-to-end e7 del pipeline | tests/e7-presupuesto.sh (1 tests) | débil | 17d9e51 | init 2026-09-08 |
| escenario end-to-end e8 del pipeline | tests/e8-escalacion.sh (1 tests) | débil | dbb6465 | init 2026-09-08 |
| generador de fixtures desechables | tests/make-fixtures.sh (1 tests) | fuerte | 1adb2c1 | init 2026-09-08 |
| orquestador de la suite de escenarios | tests/run-scenarios.sh (0 tests), tests/test-run-scenarios.sh (0 tests) | débil | 83ada90,8b6ff23 | tarea runner-suite-real |
| tests/scenarios.md | tests/scenarios.md (0 tests) | débil | 5752a86 | init 2026-09-08 |
| exploracion.sh: grafo de exploración | tests/test-exploracion.sh (0 tests) | débil | 93e073a | init 2026-09-08 |
| hook SessionStart: inyección de INDEX | tests/test-hook.sh (0 tests) | débil | 427c53f | init 2026-09-08 |
| oraculo-map.sh: scan/verify/fuerza y podas | tests/test-oraculo-map.sh (17 tests) | fuerte | 4f746d3 | init 2026-09-08 |
| red.sh: veredicto de la ruta pelada (4 flags + atribuible) | tests/test-red.sh (1 tests) | fuerte | 0cb5355 | tarea e6-baseline-con-oraculo |
| symbol-map.sh: mapa de símbolos | tests/test-symbol-map.sh (0 tests) | débil | 7a74852 | init 2026-09-08 |

**Huecos conocidos (sin check ejecutable):**
- cierre de una retomada sin deuda de anomalías: las dos aserciones `**Anomalías pendientes:**` / `bifurcación: pendiente` de `tests/e6-retomar-lock.sh` solo se ejercitan corriendo ese escenario headless (cuesta); en la tarea que las agregó se verificaron por `bash -n` + inspección del diff, no por ejecución (tarea e6-baseline-con-oraculo)
- que la suite `E1-E8` completa corra verde de punta a punta: `tests/test-run-scenarios.sh` verifica el CABLEADO estáticamente (bash -n + grep/awk), nunca la EJECUCIÓN — e8 dentro del orquestador y la tolerancia a `rc=2` no se observaron en vivo porque correr la suite cuesta tokens (tarea runner-suite-real)
