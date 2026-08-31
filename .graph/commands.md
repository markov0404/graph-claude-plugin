# Comandos verificados

| comando | qué hace | verificado | output esperado |
|---|---|---|---|
| `tests/run-scenarios.sh` | suite completa: hook + symbol-map + fixtures + escenarios headless E1-E3 (~10-15 min, lanza sesiones claude anidadas y consume tokens) | sí (2026-08-31) | termina en `OK: escenarios automatizados (E1-E3)`, exit 0 |
| `tests/test-hook.sh` | test unitario del hook SessionStart (2 casos, exit code assertado) | sí (2026-08-31) | `OK: hook` |
| `tests/test-symbol-map.sh` | test del tooling propio: 4 casos (JS, Python, sin cobertura, adversarial strings) | sí (2026-08-31) | `OK: symbol-map (JS, Python, caso sin cobertura, caso adversarial template/docstring)` |
| `tests/make-fixtures.sh` | regenera los repos fixture desechables en tests/build/ (idempotente, `rm -rf` previo) | sí (2026-08-31) | `fixtures listos en .../tests/build` |
| `tools/symbol-map.sh <raíz>` | mapa de símbolos por archivo (JS/TS, Python, bash); solo lectura | sí (2026-08-31) | sección markdown de símbolos por stdout |
| `claude plugin validate .` | valida plugin.json y marketplace.json | sí (2026-08-31) | `✔ Validation passed` |
| escenarios I1-I7 (`tests/scenarios.md`) | checklist interactiva: convergencia M, preflight, tier forzado, grafo L, presupuesto, hook, tier S | no verificado (interactivo — requiere sesión con usuario) | ver criterios por escenario en el archivo |

Notas: no hay build ni lint — el plugin es markdown + bash + JSON sin compilación. `tools/symbol-map.sh` es tooling propio de GRAPH (no comando del proyecto): se lista por utilidad, no entra en la verificación de Fase 3 de init.
