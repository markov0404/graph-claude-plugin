# GRAPH — Mejoras tomadas del SOTA (ronda 1)

**Fecha:** 2026-08-31
**Estado:** Diseño aprobado en brainstorming; input para `/graph:do` sobre este repo.
**Contexto:** Investigación SOTA verificada (2026-08-31) contra Superpowers, GitHub Spec Kit, claude-mem, Cline Memory Bank, Aider, OpenHands, PoLL/ChatEval y CCPM. De 9 candidatas evaluadas, el usuario aprobó 7; la captura pasiva de sesiones (claude-mem) quedó excluida por diluir la curación del `.graph/`, y la consolidación de bitácoras (Letta) quedó fuera por falta de volumen que la justifique.

## Política de tooling (vinculante, decidida por el usuario)

GRAPH es capa de proceso (markdown + bash). Se permite tooling SOLO si:
- viaja dentro de lo instalable (en el repo del plugin, no como prerrequisito externo),
- es open source y pinneado si se vendorea, o
- se rehace en casa cuando es fácil, con tests propios.

Esta política queda registrada también en `.graph/decisions.md` al implementarse.

## Mejora 1 — Constitution por repo (de GitHub Spec Kit)

Nuevo archivo del contrato `.graph/`: **`constitution.md`** — principios y líneas rojas ESTABLES del proyecto, formato bullets numerados `C1`, `C2`, … (una línea cada uno, concretos y verificables donde sea posible).

- `/graph:init` Fase 4 lo genera derivándolo del escaneo (invariantes evidentes del proyecto); Fase 5 (corrección temprana) es donde el usuario lo afina — es SU documento.
- `/graph:do` Fase 1: toda mini-spec incorpora la constitution completa como anti-criterios base, citando los C-N. **Precedencia: constitution > anti-criterios por-tarea** — un anti-criterio de tarea no puede relajar una línea C-N; si el pedido del usuario contradice la constitution, el gate lo señala explícitamente en "Necesito de ti" (el usuario puede editar la constitution, nunca el sistema por su cuenta).
- `/graph:init` refresh: `constitution.md` se trata como `decisions.md` — historial curado, NUNCA se regenera si ya existe.
- Suite: E1 añade `constitution.md` a la lista de archivos exigidos.

**Impacto esperado:** + líneas rojas fijadas una vez, mini-specs más baratas y consistentes; − riesgo de contradicción con anti-criterios por-tarea, resuelto por la regla de precedencia.

## Mejora 2 — Refutadores con modelos diversos (de PoLL / ChatEval)

La verificación adversarial del tier L añade diversidad de MODELO a la diversidad de lente, para mitigar errores correlacionados del voto por mayoría (riesgo documentado en la literatura 2026):

| Lente | Tier de modelo |
|---|---|
| Correctitud (¿el problema existe tal cual?) | barato (haiku o equivalente) |
| Valor/alcance (¿mejora de verdad? ¿YAGNI?) | medio (sonnet o equivalente) |
| Riesgo (¿rompe suite/invariantes/gate?) | el más capaz disponible |

- `skills/do/references/workflow-templates.md`: la tabla anterior se añade como regla común, y las plantillas ejemplifican el parámetro `model` por lente.
- `skills/do/SKILL.md` (Tier L): una frase remitiendo a la tabla.

**Impacto esperado:** + ataca el defecto conocido más serio del voto; − el refutador barato es débil en juicios sutiles, por eso se le asigna solo la lente mecánica.

## Mejora 3 — TDD con escape en tier M (de Superpowers)

Nueva regla del loop convergente (`skills/do/SKILL.md`, Tier M, antes del paso 1 actual):

> Si el criterio pendiente es de código y razonablemente testeable, la primera iteración sobre ese criterio escribe el test que falla y registra la evidencia RED en el diario ANTES de implementar; el pase posterior es la evidencia GREEN. Si el criterio no es testeable de forma razonable, se declara en el diario ("sin TDD: <porqué>") y se verifica por su método alternativo de la mini-spec.

**Impacto esperado:** + evidencia RED→GREEN dificulta el autoengaño; − fricción en cambios triviales, acotada por el escape explícito y auditable.

## Mejora 4 — Estado "en curso" (de Cline Memory Bank)

- `/graph:do` al entrar a Fase 6 escribe en `.graph/INDEX.md` (bajo la línea de estado) la línea: `**En curso:** <slug> (tier <X>, desde <YYYY-MM-DD>)`. La Fase 8 la elimina al cerrar (también en cierres por aborto).
- El hook ya inyecta INDEX: la sesión siguiente ve la tarea abierta sin cambios en el hook.
- Si `/graph:do` arranca y encuentra un "En curso" de otra tarea: pregunta (AskUserQuestion) retomar desde su task record / cerrarla como abandonada (registrándolo en el record) / continuar con la nueva dejando la vieja marcada. En modo no interactivo: reporta la tarea abierta y termina.

**Impacto esperado:** + continuidad tras cortes de sesión; − puede quedar stale si la sesión muere sin Fase 8 — mitigado porque el arranque siguiente lo detecta y pregunta.

## Mejora 5 — Señal objetiva de estancamiento (de OpenHands)

En `skills/do/SKILL.md`, Tier M, definición de estancamiento (punto 4), se AÑADE (sin reemplazar el criterio de causa raíz):

> También hay estancamiento si el diario registra la misma acción con el mismo resultado en dos iteraciones consecutivas — esa repetición literal dispara la escalada de inmediato, sin esperar el juicio de "misma causa".

**Impacto esperado:** + detección barata y objetiva que complementa el diagnóstico; − sigue siendo proceso en prosa (límite estructural del plugin, aceptado).

## Mejora 6 — Trazabilidad commits↔tarea (de CCPM)

- Convención nueva en `.graph/conventions.md` y en `skills/do/SKILL.md` (Fases 6 y 8): todo commit producido por una tarea GRAPH lleva el trailer `GRAPH-Task: <slug>`.
- El cierre (Fase 8) lista los commits de la tarea (hash corto + subject) en la sección Resultado del task record.
- Navegación documentada: `git log --grep "GRAPH-Task: <slug>"`.

**Impacto esperado:** + auditoría barata bidireccional; − burocracia leve.

## Mejora 7 — Mapa de símbolos con tooling propio (de Aider, según política de tooling)

Nuevo script **`tools/symbol-map.sh`** (bash + awk, cero dependencias externas, rehecho en casa):

- Entrada: raíz de un repo. Salida (stdout): sección markdown con los símbolos de nivel superior por archivo — funciones, clases y exports — para los lenguajes cubiertos en v1: **JavaScript/TypeScript, Python y bash**. Regexes conservadoras: ante la duda, omitir (nunca inventar).
- Formato de salida: por archivo, una línea `- \`ruta\`: símbolo1, símbolo2, …`; los archivos de lenguajes no cubiertos se listan bajo una nota "sin cobertura de símbolos (prosa en la sección curada)".
- `/graph:init` (Fases 2/4) y su refresh ejecutan el script y escriben su salida en `map.md` DENTRO de marcadores `<!-- symbol-map:start -->` / `<!-- symbol-map:end -->`; todo lo demás de `map.md` sigue siendo prosa curada que el refresh respeta. Si el script falla, la sección lo dice y `map.md` queda como hasta ahora (degradación, nunca bloqueo).
- Test propio **`tests/test-symbol-map.sh`**: corre el script contra `tests/build/fixture-js` y `fixture-py` (tras `make-fixtures.sh`) y asserta símbolos conocidos (`total` en `src/cart.js`, `slugify` en `app/slug.py`); además un caso de lenguaje no cubierto. Se integra a `run-scenarios.sh` como paso barato previo a E1.
- El propio repo del plugin es fixture adicional natural (símbolos bash de sus scripts).

**Impacto esperado:** + la única pieza del `.graph/` con datos no-alucinables, regenerable en cada refresh; − cobertura menor que tree-sitter y regexes propias que mantener — aceptado por la política de tooling (v2 podrá vendorear algo mayor si hace falta).

## No-objetivos de esta ronda

- Captura pasiva de sesiones no-GRAPH (claude-mem): excluida — diluye la curación, que es el diferenciador del `.graph/`.
- Consolidación de bitácoras (Letta sleep-time): fuera hasta que `tasks/` tenga volumen real.
- Vendorear tree-sitter u otro parser: v2 solo si la cobertura del script propio resulta insuficiente en uso real.

## Verificación del conjunto

- `tests/test-symbol-map.sh` nuevo (unitario, barato) integrado a la suite.
- E1 ampliado: exige `constitution.md`.
- `tests/run-scenarios.sh` completo en verde + `tests/test-hook.sh` + `claude plugin validate .` tras implementar.
- Las mejoras 2-6 son proceso: se verifican leyendo los skills modificados contra este spec (consistencia) y quedan cubiertas por los escenarios interactivos existentes (I1: diario con TDD/estancamiento; I4: refutadores con modelos; I3/I7: sin cambios).
- Anti-criterios de la ronda: no debilitar gate ni reglas duras; no romper el contrato `.graph/` existente (los archivos nuevos son aditivos); `docs/superpowers/` intacto salvo este spec.
