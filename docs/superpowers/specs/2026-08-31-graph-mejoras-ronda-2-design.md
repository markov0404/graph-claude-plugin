# GRAPH — Mejoras ronda 2 (efectos reversibles, honestidad metodológica, fixtures fuera del árbol)

**Fecha:** 2026-08-31
**Estado:** Diseño aprobado en brainstorming; input para `/graph:do` sobre este repo.
**Origen:** backlog de ronda 2 (arXiv 2608.25512 / Cordis: efectos con inversa y threats-to-validity) + el aprendizaje del incidente del explorador en la tarea `mejoras-sota-r1` (fixtures anidados contaminables).
**Decisión del usuario (vinculante):** al escalar de tier, **el diagnóstico decide qué se conserva; el default es revertir**.

## Mejora R2-1 — Ledger de efectos con inversa explícita

Se aplica a `skills/do/SKILL.md` y a la plantilla del task record.

- **Nueva sección del task record:** `## Efectos` — tabla `| # | efecto | inversa | estado |`, con estado ∈ `activo | revertido | conservado | irreversible`.
- **Línea base git como efecto #0:** al entrar a Fase 6 (tras crear el task record), `do` registra una línea base del working tree (p.ej. `git stash create` o ref temporal equivalente, sin mover HEAD) como efecto #0, cuya inversa es "restaurar desde la base los paths tocados por el intento". Los efectos de archivo dentro del repo quedan cubiertos por git — NO se listan uno a uno.
- **Efectos extra-git:** todo efecto fuera del alcance de git (comando con efectos laterales, llamada externa, archivo fuera del repo) se registra en la tabla ANTES de ejecutarlo, con su inversa concreta. Si la inversa no es expresable, el efecto se marca `irreversible` — y si era previsible en el preflight, debió aparecer en el gate; uno imprevisto se trata como pregunta tardía (regla dura 5) antes de ejecutarlo.
- **Reversión en la escalada de tier** (Fase 6, punto de escalada c): el diagnóstico de causa raíz marca cada efecto del intento no convergido como `revertir` (default) o `conservar` (trabajo válido que el tier nuevo aprovecha, con una frase de porqué). La escalada ejecuta las inversas de lo marcado `revertir` en orden LIFO (efecto #0 al final) y lo registra en el diario. El tier nuevo arranca con estado declarado, no heredado a ciegas.
- **Aborto del usuario:** al abortar con efectos `activo`, `do` ofrece ejecutar las inversas pendientes (LIFO) antes de cerrar el record.
- Los efectos son estrictamente post-gate (las fases 1-4 siguen siendo de solo lectura); la tabla vacía con solo el efecto #0 es el caso normal de una tarea que no tocó nada extra-git.

**Impacto esperado:** + escalada desde estado garantizado y aborto limpio, sin descartar trabajo bueno; − burocracia por efecto extra-git (mitigada porque git cubre gratis los de archivo). Honestidad de diseño: la garantía es disciplinaria (proceso en prosa), no formal — GRAPH no es un runtime con teoremas.

## Mejora R2-2 — Amenazas a la validez en el reporte

Se aplica a `skills/do/SKILL.md` (Fase 8 y plantilla del task record).

- La sección Resultado de la plantilla gana la línea: `- Amenazas a la validez: <qué se midió y qué no; evidencia de corrida única vs repetida; entorno único; qué quedó sin comparación controlada>`.
- Fase 8 instruye llenarla con honestidad; **prohibido "ninguna" sin justificación** de por qué la evidencia es completa.
- El resumen final al usuario (Fase 8 punto 5) menciona las amenazas junto a la evidencia.

**Impacto esperado:** + el sistema deja de sobrevender su evidencia, imitando la práctica del paper; − riesgo de boilerplate ritual, mitigado por la prohibición anterior.

## Mejora R2-3 — Fixtures fuera del árbol del repo

Se aplica a `tests/make-fixtures.sh`, `tests/run-scenarios.sh`, `tests/test-symbol-map.sh`, `.gitignore` y `README.md`.

- `make-fixtures.sh` escribe en `GRAPH_FIXTURES_DIR` (default: `${XDG_CACHE_HOME:-$HOME/.cache}/graph-plugin/fixtures`), fuera del árbol del repo; sigue siendo idempotente (`rm -rf` + recreación) y al terminar imprime la ruta.
- `run-scenarios.sh` y `test-symbol-map.sh` resuelven la MISMA variable/default (definirla una sola vez por script, mismo one-liner) y dejan de usar `tests/build/`.
- `tests/build/` desaparece como concepto: se elimina su entrada de `.gitignore` (la de `tests/*.out` se queda) y cualquier resto local.
- README (sección Pruebas) documenta `GRAPH_FIXTURES_DIR` en una línea.
- Efecto estructural buscado: el `rm -rf` de fixtures ya no puede tocar el repo, y un agente que explore hacia arriba desde un fixture encuentra el cache del usuario, no el plugin — la defensa contra la contaminación de anidamiento pasa de disciplinaria (prompt de solo-lectura) a estructural (aislamiento físico). Ambas capas conviven.

**Impacto esperado:** + elimina de raíz la clase de bug del incidente E2 de `mejoras-sota-r1`; − los fixtures ya no se limpian con `git clean` (irrelevante: cada corrida hace su propio `rm -rf`) y una variable más que documentar.

## No-objetivos

- Runtime real de efectos (hooks que intercepten comandos, verificación automática de inversas): fuera — GRAPH es capa de proceso.
- Vendorear Cordis o cualquier librería: fuera (política de tooling C5).
- Tocar `docs/superpowers/` histórico (C7) o los formatos `.graph/` de forma no aditiva (C4).

## Verificación del conjunto

- R2-3: `tests/run-scenarios.sh` completa en verde usando el directorio externo (su propia prueba de fuego), `tests/test-symbol-map.sh` verde, `claude plugin validate .` verde, y `git status` sin `tests/build/` residual.
- R2-1 y R2-2: verificación adversarial del diff de `skills/do/SKILL.md` contra este spec (consistencia con reglas duras, C1-C8 y contrato del task record); su ejercicio real queda para la próxima tarea que escale o cierre (anotarlo como amenaza a la validez en el propio cierre — R2-2 aplicada a sí misma).
- Anti-criterios: gate y reglas duras intactos; contrato `.graph/` solo aditivo; español; cero dependencias nuevas.
