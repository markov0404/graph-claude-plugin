# GRAPH — escalado por capas para Claude Code

Un prompt corto ("quiero A") → mini-spec → contexto → preflight → tier → gate
→ ejecución convergente → cierre. El plugin contiene el proceso; el
conocimiento de cada repo vive en su `.graph/` y mejora con el uso.

## Instalación (desarrollo)

    claude --plugin-dir <ruta-al-clon>

(carga el plugin solo para esa sesión)

## Instalación (permanente)

Dentro de una sesión de Claude Code:

    /plugin marketplace add <ruta-al-clon>
    /plugin install graph@graph-marketplace

## Uso

1. `/graph:init` — una vez por repo: escanea, verifica comandos reales y
   genera `.graph/` (INDEX, mapa, convenciones, comandos, decisiones, tasks).
2. `/graph:do quiero A` — el comando maestro. Flags opcionales:
   - `--tier S|M|L` fuerza el nivel (`--quick` = S, `--full` = L)
   - `--budget <tokens>` presupuesto por tarea (al agotarse, pregunta)

   Siempre presenta un gate de aprobación (mini-spec + plan + "Necesito de
   ti"); nada muta el repo antes de tu OK.

Con `.graph/` presente, un hook SessionStart inyecta `INDEX.md` al contexto
en cada sesión nueva (silencioso si no existe).

Diseño completo: `docs/superpowers/specs/2026-08-31-graph-plugin-design.md`.

## Pruebas

    tests/run-scenarios.sh      # suite automatizada (hook + fixtures + headless)
    tests/scenarios.md          # escenarios interactivos (tiers S/M/L, preflight, presupuesto, hook)

Requiere claude autenticado, git y Node >=21; lanza sesiones headless reales
(consume tokens) y usa --dangerously-skip-permissions solo dentro de fixtures
desechables en tests/build/.
