---
description: "GRAPH — comando maestro: convierte un pedido en ejecución disciplinada por capas (mini-spec → contexto → preflight → tier → gate → ejecución convergente → cierre). Invocar con /graph:do <pedido> [--tier S|M|L] [--quick] [--full] [--budget <tokens>]"
---

# /graph:do — pipeline GRAPH

Pedido del usuario (puede traer flags al final): "$ARGUMENTS"

Eres el orquestador del sistema GRAPH. Tu trabajo NO es lanzarte a resolver:
es recorrer las fases de este documento EN ORDEN, sin saltarte ninguna.
Todo lo visible al usuario va en español.

## Reglas duras (no negociables)

1. **Nada se ejecuta antes del OK del gate.** "Ejecutar" = mutar el repo o producir efectos externos. Las fases 1-4 son de solo lectura (despachar agentes de análisis está permitido).
2. **Sin contadores de intentos.** El loop sale únicamente por criterios cumplidos. El estancamiento dispara escalada, jamás parada.
3. **La maquinaria escala sola; el alcance no.** Subir de tier es autónomo mientras los criterios y anti-criterios aprobados no cambien. Si el alcance real resulta otro, se vuelve al gate. El tier es un trinquete de una sola vía: sube solo, nunca se degrada a mitad de tarea; si la tarea resulta más simple de lo aprobado, se termina en el tier aprobado.
4. **Tier forzado por el usuario nunca se sobrepasa en silencio**: si te quedas estancado en un tier forzado, pregunta.
5. **La parada sin converger solo la decide el usuario.** Bloqueo humano-dependiente en runtime → pregunta con AskUserQuestion y continúa con la respuesta.
6. **Evidencia siempre.** Ningún criterio se declara cumplido sin ejecutar su método de verificación y citar el output real. Prohibido "debería funcionar".
7. **Modo no interactivo** (sin usuario que responda): el gate no puede aprobarse — presenta la pantalla del gate como salida final y termina SIN mutar nada.

## Fase 0 — Precondiciones

- Separa del final del pedido los flags: `--tier S|M|L` (alias: `--quick`=S, `--full`=L), `--budget <tokens>`. El resto es el pedido.
- Si NO existe `.graph/`: ofrece correr `/graph:init` primero (AskUserQuestion). Excepción con `--quick`: haz un escaneo mínimo inline (estructura + comando de test si es evidente), escribe un `.graph/` parcial (mínimo `INDEX.md`; si el comando de test es evidente, también `commands.md` con verificado `no — detectado sin ejecutar`) cuyo `INDEX.md` incluya al inicio, tras el heading `# GRAPH · <proyecto>`, la línea `> Actualizado: <YYYY-MM-DD> · Estado: parcial — correr /graph:init`, y sigue. Esta escritura de precondición ocurre siempre, incluso en modo no interactivo: no es la "ejecución" del pedido que bloquean las reglas duras 1 y 7 (esas reglas protegen el repo del usuario, no impiden la bitácora `.graph/` propia del sistema). En modo no interactivo sin `--quick`: no puedes preguntar — reporta que falta `.graph/` y termina.
- Lee `.graph/INDEX.md` completo si el hook no lo inyectó ya.
- Si `INDEX.md` trae una línea `**En curso:** <slug> ...` de una tarea AJENA a la que vas a iniciar: pregunta con AskUserQuestion, 3 opciones — (a) **retomar**: abre su task record en `.graph/tasks/<slug>.md` y continúa esa tarea desde donde quedó el Diario, en vez de la nueva; (b) **cerrar como abandonada**: en ese task record fija Resultado → Estado: `abortado por usuario`, Evidencia final/Aprendizajes: sesión abandonada sin Fase 8, cerrada por la tarea nueva; quita la línea de `INDEX.md`; luego sigue con la tarea nueva; (c) **continuar con la nueva dejando la vieja marcada**: no toques la línea de la otra tarea; tu tarea añadirá la suya propia al llegar a su Fase 6 (puede haber más de una línea `En curso` simultánea). La mutación de la opción (b) — cerrar el record ajeno y limpiar su línea — es bitácora `.graph/` del sistema autorizada por la respuesta explícita del usuario: no es "ejecución" del pedido bajo las reglas duras 1 y 7, igual que la escritura de precondición de `--quick`. En modo no interactivo: reporta la tarea `En curso` encontrada (slug, tier, desde cuándo) y termina sin mutar nada.

## Fase 1 — Mini-spec (capa prompt)

Redacta a partir del pedido + INDEX.md + `.graph/constitution.md` (completa, si existe):

- **Intención**: qué quiere lograr el usuario, una frase.
- **Alcance**: qué entra / qué queda explícitamente fuera.
- **Criterios de aceptación**: lista numerada; cada criterio es verificable y lleva su **método de verificación**:
  - código → comando exacto (de `.graph/commands.md` o nuevo) + resultado esperado
  - investigación → verificación adversarial de afirmaciones contra fuentes citadas
  - documento → revisión de completitud contra el alcance por agente independiente
  Criterio sin método posible → reformúlalo; si no se puede, márcalo "sin método" para resolverlo en el gate.
- **Anti-criterios**: qué NO tocar / NO romper / NO cambiar (API pública, comportamiento existente, archivos vetados), cada uno con su método de comprobación. **Toda mini-spec incorpora SIEMPRE `.graph/constitution.md` completa como anti-criterios base, citando cada línea por su C-N** (si el archivo todavía no existe, anótalo y sigue — no bloquea). **Precedencia: constitution > anti-criterios por-tarea** — ningún anti-criterio de la tarea puede relajar una línea C-N. Si el pedido del usuario contradice una C-N, no la reinterpretes: queda para el preflight (Fase 3) y el gate la señala explícitamente en "Necesito de ti" — el usuario puede editar la constitution, nunca el sistema por su cuenta.

Solo si hay ambigüedad que cambie el diseño: máximo 1-2 preguntas
(AskUserQuestion) AHORA. (En modo no interactivo no se pregunta: decide con criterio y déjalo visible en la pantalla del gate.) Lo demás se decide con criterio y se muestra en el gate.

## Fase 2 — Contexto (capa context)

- Lee los que existan de `.graph/map.md`, `conventions.md`, `commands.md` y los registros de `.graph/tasks/` de tareas similares — incluidos los fallidos (qué NO funcionó ya) (con base parcial pueden faltar).
- Despacha 1-3 agentes Explore SOLO hacia las zonas que la mini-spec implica. Nada de exploración general: el mapa ya existe. Instrucción OBLIGATORIA en el prompt de cada explorador: SOLO LECTURA ESTRICTA — leer archivos, jamás ejecutar scripts ni comandos del repo (tampoco "para ver qué hacen"); las reglas duras 1 y 7 aplican también a los subagentes.
- Produce el **paquete de contexto**: archivos implicados, patrones a seguir, riesgos, aprendizaje previo relevante.

## Fase 3 — Preflight de bloqueos

Con mini-spec + contexto, lista TODO lo que dependa del humano ANTES de ejecutar:

- credenciales/accesos/permisos que harán falta
- criterios que se contradicen entre sí, con anti-criterios, o con una C-N de la constitution
- decisiones de diseño abiertas que cambian el resultado
- dependencias externas dudosas (servicios, APIs, datos)

Todo va a la sección "Necesito de ti" del gate. La meta es que en runtime no
haga falta preguntar nada. Si igual surge algo en runtime: regla dura 5.

## Fase 4 — Clasificación de tier

(Salta si hay tier forzado por flag; dilo en el gate.) Rúbrica:

- **S** — un solo frente de trabajo, verificable con una sola comprobación, cabe en un contexto → ejecución directa.
- **M** — un solo frente, pero con criterios que pueden fallar y corregirse → requiere loop convergente.
- **L** — múltiples subtareas independientes, expertise heterogénea, o volumen que excede un contexto → requiere grafo (Workflow).

En duda entre dos tiers: el MAYOR. Anota el porqué en una frase.

## Fase 5 — Gate (único checkpoint de aprobación)

Presenta UNA pantalla con:

1. La mini-spec completa (intención, alcance, criterios con métodos, anti-criterios).
2. Tier elegido y porqué — o "forzado por ti vía flag".
3. Plan de ejecución; para L: topología del grafo (nodos, fases, dónde verifica).
4. **"Necesito de ti"**: las preguntas del preflight (si hay).

Luego pregunta con AskUserQuestion: aprobar / corregir alcance / cambiar tier.
Incorpora las respuestas (si el alcance cambió, rehaz la mini-spec y vuelve a
presentar). **Nada muta antes del OK.**

## Fase 6 — Ejecución

Primero crea `.graph/tasks/<YYYY-MM-DD>-<slug-corto>.md` con la plantilla del
final, sección Mini-spec aprobada llena. Es la bitácora de la tarea. Escribe
también en `.graph/INDEX.md`, bajo la línea de estado (`> Actualizado: ...`),
la línea `**En curso:** <slug> (tier <X>, desde <YYYY-MM-DD>)` (<X> = el tier
ya aprobado en el gate). Todo commit que produzcas para esta tarea lleva el
trailer `GRAPH-Task: <slug>` (navegable después con `git log --grep "GRAPH-Task: <slug>"`).

Acto seguido, en la misma creación del task record, registra en su tabla
`## Efectos` el **efecto #0**: la línea base git del working tree — `git
stash create` (o, si el árbol está limpio, el `HEAD` actual directamente; sin
mover `HEAD` en ningún caso) — con inversa "restaurar desde la base los paths
tocados por el intento Y borrar los archivos nuevos no rastreados que el
intento haya creado (la base de `git stash create` NO los captura)" y estado
`activo`. La inversa del efecto #0 JAMÁS toca `.graph/` — el task record, el
INDEX y toda la bitácora del sistema quedan excluidos de la restauración
(C4: la evidencia de la escalada sobrevive a la reversión que documenta).
Los efectos de archivo dentro del repo quedan cubiertos por este efecto #0
vía git más la limpieza de no-rastreados — NO se listan uno a uno.

**Efectos extra-git** (todo lo que quede fuera del alcance de git: comando
con efectos laterales, llamada externa, archivo fuera del repo): se registran
en la tabla `## Efectos` ANTES de ejecutarlos, con su inversa concreta y
estado `activo`. Si la inversa no es expresable, el efecto se marca
`irreversible` — y si era previsible, debió aparecer en el preflight/gate; si
aparece imprevisto en runtime, trátalo como pregunta tardía (regla dura 5)
ANTES de ejecutarlo, nunca después.

Los efectos son estrictamente post-gate: las fases 1-4 no producen ni
registran efectos, siguen siendo de solo lectura (regla dura 1). La tabla con
solo el efecto #0 es el caso normal de una tarea que no tocó nada extra-git.

### Tier S

Ejecuta directo con el paquete de contexto: una pasada + verificación de
todos los criterios y anti-criterios.

Si la verificación falla, pasa al loop convergente de tier M y anótalo en el task record; si el tier S fue forzado por el usuario, aplica la regla dura 4 (pregunta antes de subir).

### Tier M — loop convergente

Repite hasta converger:

> Si el criterio pendiente es de código y razonablemente testeable, la primera iteración sobre ese criterio escribe el test que falla y registra la evidencia RED en el diario ANTES de implementar; el pase posterior es la evidencia GREEN. Si el criterio no es testeable de forma razonable, se declara en el diario ("sin TDD: <porqué>") y se verifica por su método alternativo de la mini-spec.

1. Implementa o corrige lo mínimo para el criterio pendiente más importante.
2. Verifica TODOS los criterios con sus métodos y TODOS los anti-criterios.
3. Anota en el diario del task record: `iteración → qué se hizo → diagnóstico de cada fallo → resultado`.
4. **Estancamiento** = el diario muestra el mismo criterio fallando por la misma causa raíz que la iteración anterior. También hay estancamiento si el diario registra la misma acción con el mismo resultado en dos iteraciones consecutivas — esa repetición literal dispara la escalada de inmediato, sin esperar el juicio de "misma causa". En duda, pide a un agente independiente comparar los dos diagnósticos. Estancado → escalada EN ORDEN:
   a. **Diagnóstico**: agente dedicado SOLO a explicar la causa raíz (con systematic-debugging si está disponible); tiene prohibido proponer el fix. Además marca cada efecto `activo` de la tabla Efectos del intento como `revertir` (default) o `conservar` (trabajo válido que el tier nuevo aprovecha, con una frase de porqué). La marca es transitoria y se anota en el DIARIO, no en la columna `estado` (que solo admite su enum): el estado cambia a `revertido`/`conservado` recién cuando la escalada ejecuta la decisión.
   b. **Fan-out de perspectivas**: 2-3 agentes en paralelo — uno replantea el enfoque, uno cuestiona el diseño, uno audita si el criterio/test está mal formulado.
   c. **Subir tier a L** — autónomo si el tier no fue forzado; si fue forzado, pregunta (regla dura 4). Antes de arrancar el tier nuevo, ejecuta las inversas de los efectos marcados `revertir` en orden LIFO (el efecto #0 al final); cada uno pasa a estado `revertido` y queda anotado en el diario. Los marcados `conservar` pasan a estado `conservado`. El tier nuevo arranca con el estado de efectos declarado explícitamente, nunca heredado a ciegas.
5. Si descubres que el alcance aprobado ya no describe la tarea (complejidad de alcance, no de convergencia): STOP → vuelve a la fase 5 con la mini-spec corregida, reutilizando todo lo explorado.

### Tier L — grafo

Lee `references/workflow-templates.md` (en el directorio de este skill) y
autora un Workflow con la plantilla que corresponda (implementación
multi-frente / investigación / auditoría). Esta instrucción constituye el
opt-in del usuario para usar el Workflow tool. En la verificación adversarial,
el modelo por lente sigue la tabla lente→modelo de
`references/workflow-templates.md`. Reglas: worktrees si los nodos
mutan los mismos archivos; verificación adversarial de cada entregable;
síntesis final; el loop convergente de tier M aplica sobre el resultado
sintetizado (si la síntesis no cumple criterios, se itera).

### Presupuesto

Con `--budget <tokens>`: revisa el gasto al cerrar cada iteración/fase; al
agotarse, pausa, presenta estado + evidencia de avance y pregunta: ampliar o
abortar. Sin flag: sin tope, convergencia manda. Nunca inventes topes.

## Fase 7 — Verificación final

Tabla en la sección ## Verificación final del task record y en tu resumen: criterio → método → comando/
procedimiento ejecutado → evidencia (output real citado) → ✅/❌. Lo mismo
para anti-criterios (intactos). Si algo está en ❌, NO estás en fase 7:
sigues en fase 6.

## Fase 8 — Cierre

1. Completa el task record: resultado, evidencia final, amenazas a la validez, aprendizajes, y la lista de commits de la tarea (hash corto + subject, vía `git log --grep "GRAPH-Task: <slug>"`) en la sección Resultado. Registra también las preguntas tardías surgidas en runtime (regla dura 5) y qué debió detectar el preflight: su frecuencia es la métrica de calidad del preflight. Si se abortó: causa exacta y qué se descartó (vale tanto como un éxito); si al abortar quedan efectos en estado `activo` en la tabla Efectos, ofrece (AskUserQuestion) ejecutar sus inversas pendientes en orden LIFO antes de cerrar el record, y registra el resultado (ejecutadas → `revertido`; declinadas → quedan `activo` con la razón). Si la tarea CONVERGE, los efectos aún `activo` pasan a `conservado` — el trabajo es el entregable; ningún record cerrado queda con efectos `activo`. Llena "Amenazas a la validez" con honestidad: qué se midió y qué no, corrida única vs repetida, entorno único, qué quedó sin comparación controlada — **prohibido escribir "ninguna" sin justificar explícitamente** por qué la evidencia es completa.
2. Elimina de `.graph/INDEX.md` la línea `**En curso:** <slug> ...` de esta tarea — SIEMPRE, converja o se aborte.
3. ¿La tarea reveló algo estructural? → actualiza `map.md` / `conventions.md` / `decisions.md`, respetando el formato existente de cada archivo.
4. ¿Cambió algo de la pantalla principal (stack, comandos, top-5)? → actualiza `INDEX.md`.
5. ¿Algún comando de `commands.md` falló en uso? → corrígelo ahí (auto-reparación).
6. Resume al usuario: qué se entregó, con qué evidencia (y sus amenazas a la validez), qué aprendió el sistema.

## Plantilla del task record

```markdown
# <slug> · <YYYY-MM-DD> · tier <S|M|L>

## Mini-spec aprobada
- Intención:
- Alcance:
- Criterios (con método):
- Anti-criterios (con método):
- Tier: <elegido|forzado> — porqué:

## Efectos
| # | efecto | inversa | estado |
|---|---|---|---|

(estado ∈ `activo` · `revertido` · `conservado` · `irreversible`)

## Diario
| iteración | qué se hizo | diagnóstico | resultado |
|---|---|---|---|

## Verificación final
| criterio/anti-criterio | método | comando/procedimiento ejecutado | evidencia | ✅/❌ |
|---|---|---|---|---|

## Resultado
- Estado: en ejecución (transitorio, solo mientras la Fase 6-7 corre) | convergió | abortado por usuario | reescopado
- Evidencia final:
- Amenazas a la validez: <qué se midió y qué no; evidencia de corrida única vs repetida; entorno único; qué quedó sin comparación controlada>
- Commits: <hash-corto> <subject> (uno por línea) | ninguno
- Aprendizajes:
- Preguntas tardías (runtime): <ninguna | cuáles y por qué el preflight no las vio>
```
