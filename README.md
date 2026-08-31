# GRAPH — escalado por capas para Claude Code

Un prompt corto ("quiero A") → mini-spec, contexto, harness, loop convergente
y grafo de agentes. El plugin contiene el proceso; el conocimiento de cada
repo vive en su `.graph/` y mejora con el uso.

## Instalación (desarrollo)

    claude --plugin-dir <ruta-al-repo>/graph-plugin

## Instalación (permanente)

Dentro de una sesión de Claude Code:

    /plugin marketplace add <ruta-al-repo>/graph-plugin
    /plugin install graph@graph-marketplace

## Uso

1. `/graph:init` — una vez por repo: escanea, verifica comandos reales y
   genera `.graph/` (INDEX, mapa, convenciones, comandos, decisiones, tasks).
2. `/graph:do quiero A` — el comando maestro. Flags opcionales:
   - `--tier S|M|L` fuerza el nivel (`--quick` = S, `--full` = L)
   - `--budget <tokens>` presupuesto por tarea (al agotarse, pregunta)

Diseño completo: `docs/superpowers/specs/2026-08-31-graph-plugin-design.md`.

## Pruebas

    tests/run-scenarios.sh      # suite automatizada (hook + fixtures + headless)
    tests/scenarios.md          # escenarios interactivos (tier M/L, preflight)
