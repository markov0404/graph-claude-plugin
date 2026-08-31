# Comandos verificados

| comando | qué hace | verificado | output esperado |
|---|---|---|---|
| `tests/run-scenarios.sh` | suite completa: hook + fixtures + escenarios headless E1-E3 (~10-15 min, lanza sesiones claude anidadas) | sí (2026-08-31) | termina en `OK: escenarios automatizados (E1-E3)`, exit 0 |
| `tests/test-hook.sh` | test unitario del hook SessionStart (2 casos) | sí (2026-08-31) | `OK: hook` |
| `tests/make-fixtures.sh` | regenera los repos fixture desechables en tests/build/ (idempotente) | sí (2026-08-31) | `fixtures listos en .../tests/build` |
| `claude plugin validate .` | valida plugin.json y marketplace.json | sí (2026-08-31) | `✔ Validation passed` |
| escenarios I1-I7 (`tests/scenarios.md`) | checklist interactiva: convergencia M, preflight, tier forzado, grafo L, presupuesto, hook, tier S | no verificado (interactivo — requiere sesión con usuario) | ver criterios por escenario en el archivo |

Notas: no hay build ni lint — el plugin es markdown + bash + JSON sin compilación. La suite anidada usa `--dangerously-skip-permissions` SOLO dentro de fixtures desechables.
