---
description: "GRAPH — setup del repo: escanea el proyecto, verifica comandos reales y genera la base de conocimiento .graph/. Idempotente (con .graph/ existente ofrece refresh). Invocar con /graph:init"
---

# /graph:init — setup de GRAPH en este repo

Argumentos: "$ARGUMENTS" (vacío = setup normal; "refresh" = re-escaneo directo).

Tu trabajo es generar o refrescar `.graph/`, la base de conocimiento de ESTE
repo. Recorre las fases en orden. Todo lo que escribas va en español.

Esquema de `.graph/` vigente: 3

## Fase 1 — Detección previa

Si existe `.graph/` y los argumentos no dicen "refresh": muestra la fecha de
actualización de `INDEX.md` y pregunta con AskUserQuestion: refrescar todo /
refrescar solo lo desactualizado / cancelar. NUNCA arrases `.graph/` sin
preguntar. En modo no interactivo sin "refresh": reporta que ya existe y termina.

"Solo lo desactualizado" = corre igual las fases 2-3 y actualiza únicamente
los archivos cuyo contenido contradiga el estado actual del repo, dejando el
resto intacto.

**Modo no interactivo** (sin usuario que pueda responder): omite las
preguntas de las fases 5 y 6 (la fase 1 ya define su propio comportamiento no
interactivo): en fase 5 imprime el resumen sin esperar correcciones, y en
fase 6 aplica el default (commitear `.graph/`) registrándolo en `decisions.md`.

## Fase 2 — Escaneo paralelo (solo lectura)

Despacha agentes Explore EN PARALELO (una sola respuesta con todas las
invocaciones), uno por dimensión. Instrucción OBLIGATORIA en el prompt de
cada explorador: SOLO LECTURA ESTRICTA — leer archivos, jamás ejecutar
scripts ni comandos del repo (tampoco "para ver qué hacen"); ejecutar es
exclusivo de la Fase 3.

1. **Estructura**: árbol de módulos, entry points, responsabilidad de cada área.
2. **Convenciones**: estilo, naming, patrones de test, idioma de comentarios.
3. **Stack**: lenguajes, frameworks, versiones, gestor de dependencias, candidatos a comandos de build/test/lint (leer package.json, pyproject.toml, Makefile, CI configs).
4. **Testing**: dónde viven los tests, cómo se corren, qué cubren a simple vista.

Repos grandes (orientativo: >200 archivos de código, o monorepo con varios
paquetes): en vez de 4 agentes globales, usa el Workflow tool con un agente
por paquete/área más un sintetizador (esta instrucción de skill constituye el
opt-in del usuario para usar Workflow).

Además, en paralelo a los agentes Explore, ejecuta `tools/symbol-map.sh
<raíz del repo>` (bash, cero dependencias externas) para obtener el listado
objetivo de símbolos de nivel superior por archivo. Es lectura pura — no
modifica nada del repo — y su salida es la que la Fase 4 escribe, tal cual,
en la sección de símbolos de `map.md`. Si el script no existe o falla, sigue
con las fases 2-3 igual: la ausencia se resuelve en la Fase 4 (degradación,
nunca bloqueo).

## Fase 3 — Verificación de comandos (la ÚNICA fase que ejecuta comandos de build/test/lint del proyecto)

Toma los candidatos a build/test/lint de la fase 2 y EJECÚTALOS uno a uno:

- Corre bien → entra a `commands.md` con "sí" en verificado y su output esperado resumido (p.ej. "1 passing").
- Falla por prerrequisito → entra con "no — requiere: <qué>" (p.ej. "requiere: npm install"). NUNCA lo registres como funcionando.
- Riesgoso o largo (deploy, migraciones, publish) → NO lo corras; entra como "no verificado (riesgoso)".

`tools/symbol-map.sh` (Fases 2/4) no es un comando del proyecto a verificar:
es tooling propio de GRAPH, de solo lectura y sin efectos secundarios — no
entra en `commands.md`.

## Fase 4 — Generar `.graph/`

En refresh: regenera `conventions.md` y `commands.md` completos, e
`INDEX.md` sujeto a la re-normalización sin pérdida descrita más abajo —
nunca se descarta contenido previo de INDEX sin antes trasladarlo.
En `map.md` regenera SOLO la sección entre `<!-- symbol-map:start -->` y
`<!-- symbol-map:end -->` (volviendo a ejecutar `tools/symbol-map.sh`) —
siempre, sin importar si el usuario eligió "todo" o "solo lo desactualizado"
en la Fase 1: es dato barato y objetivo, se recalcula en cada refresh. El
resto de `map.md` es prosa curada (síntesis de arquitectura + correcciones
del usuario) y el refresh la respeta, nunca la reescribe. `decisions.md`,
`constitution.md` y `tasks/` son historial acumulado o documento propio del
usuario: si ya existen, NUNCA se regeneran ni se borran — solo agrega a
`decisions.md` una fila registrando el refresh (en un arranque sin `.graph/`
previo, todos se crean normalmente; si en un `.graph/` existente falta alguno
de ellos — base creada por una versión anterior — créalo, solo esa primera vez).

Regla de migración por SECCIÓN: una base existente puede tener ya el archivo
pero carecer de una SECCIÓN que el esquema vigente exige — los marcadores
`<!-- symbol-map:start -->`/`<!-- symbol-map:end -->` en `map.md`, el campo
`Esquema:` en la línea de estado de INDEX, o el campo `**Testing:**` de
INDEX. En ese caso: insértala, solo esa primera vez, y actualiza el número de
Esquema de INDEX al vigente. El contenido curado o histórico que ya existe
(la prosa de `map.md`, `constitution.md`, `decisions.md`, `tasks/`) jamás se
toca ni se reescribe (C4) — la migración únicamente añade lo que falta,
nunca reemplaza ni resume lo que ya está.

Crea los archivos con EXACTAMENTE estos formatos (rellenando con lo escaneado):

`.graph/INDEX.md`:

```markdown
# GRAPH · <nombre del proyecto>
> Actualizado: <YYYY-MM-DD> · Estado: completo · Esquema: 3

**Qué es:** <1-2 frases>
**Stack:** <lenguajes y frameworks clave>
**Comandos clave:** test: `<cmd>` · build: `<cmd o "n/a">` · lint: `<cmd o "n/a">` (detalle en commands.md)
**Testing:** <cobertura en 1 línea: qué está automatizado y verificado (con fecha), qué es solo interactivo/manual, o "sin tests" si el repo no tiene> (detalle en commands.md y map.md)
**Top-5 archivos/módulos:**
1. `<ruta>` — <por qué importa>
(hasta 5)
**Convenciones esenciales:** <máximo 3 bullets; detalle en conventions.md>
```

Re-normalización sin pérdida (rige para TODO escritor de `INDEX.md` — init
inicial, refresh, y cualquier otro comando que escriba en él, no solo este
refresh): INDEX es el nodo raíz del grafo de conocimiento y se mantiene en
~1 pantalla (orientativo: ≤4KB). Si al escribirlo el INDEX resultante supera
ese presupuesto, o si en un refresh el INDEX regenerado NO reproduce
contenido que el INDEX previo sí tenía (aportes agregados a mano, exceso ya
presente de una base vieja, restos de un esquema anterior), MUEVE ese
contenido ÍNTEGRO — completo, sin resumir ni truncar — a un archivo
enlazado de `.graph/`, ANTES de sobrescribir o descartar el INDEX previo,
dejando en INDEX un puntero de una línea (`detalle en <archivo>`). Si el
destino es un archivo YA EXISTENTE, el traslado AÑADE el contenido al final
bajo un heading con la fecha (`## Trasladado desde INDEX el <YYYY-MM-DD>`)
— nunca reemplaza lo que ese archivo ya tenía. `constitution.md`,
`decisions.md` y `tasks/` son nodos protegidos: NUNCA son destino de un
traslado; si hace falta mover contenido, créase en su lugar un archivo
nuevo enlazado. Mover, nunca borrar ni resumir con pérdida: es una decisión
vinculante — el contenido siempre sigue existiendo íntegro en algún nodo
del grafo.

`.graph/map.md`: título `# Mapa de arquitectura`, luego una sección `##` por
módulo/área con: responsabilidad (1 frase), archivos clave, de qué depende;
al final, una sección `## Símbolos` con la salida de `tools/symbol-map.sh`
escrita TAL CUAL entre marcadores:

```markdown
# Mapa de arquitectura

## <módulo/área>
- Responsabilidad: <1 frase>
- Archivos clave: <rutas>
- Depende de: <módulos o paquetes>

(una sección así por módulo)

## Símbolos
<!-- symbol-map:start -->
<salida literal de tools/symbol-map.sh>
<!-- symbol-map:end -->
```

Si `tools/symbol-map.sh` falla o no existe: DENTRO de los marcadores escribe
una línea `_sin symbol-map disponible: <motivo breve>_` y deja el resto de
`map.md` exactamente como estaba — nunca bloquea init ni refresh por esto.

`.graph/conventions.md`: título `# Convenciones`, bullets concretos y
accionables ("tests con node:test en test/*.test.js", "imports relativos"),
nunca vaguedades ("código limpio").

`.graph/commands.md`: título `# Comandos verificados`, tabla:

```markdown
| comando | qué hace | verificado | output esperado |
|---|---|---|---|
| `npm test` | corre los tests | sí (<YYYY-MM-DD>) | 1 passing |
```

`.graph/constitution.md`: título `# Constitution`, bullets numerados `C1`,
`C2`, … — una línea cada uno, concretos y verificables donde sea posible,
derivados de invariantes evidentes del escaneo (límites de arquitectura,
reglas de seguridad o de proceso que el propio repo ya impone). Nunca
vaguedades ni relleno: si el escaneo no deja invariantes claros, menos
bullets es mejor que bullets inventados:

```markdown
# Constitution

- C1: <línea concreta y verificable>
- C2: <línea concreta y verificable>
(las que el escaneo justifique)
```

`.graph/decisions.md`: título `# Log de decisiones`, tabla `| fecha | decisión | porqué |` (arranca con la fila del propio init: qué se decidió sobre git).

`.graph/tasks/README.md`: una línea: `Un archivo por tarea de /graph:do — ver la plantilla en el skill do.`

## Fase 5 — Corrección temprana

Muestra al usuario un resumen de UNA pantalla: qué entendió el sistema (lo
esencial de INDEX.md) y el `constitution.md` completo recién generado — es
SU documento, y esta es su primera oportunidad de afinarlo. Pregunta con
AskUserQuestion si hay algo que corregir, en cualquiera de los dos. Cada
corrección se aplica DE INMEDIATO al archivo correspondiente: es el primer
aprendizaje del repo.

## Fase 6 — Git

Pregunta UNA vez (AskUserQuestion): ¿commitear `.graph/` (recomendado, es
conocimiento del repo) o agregarlo a `.gitignore`? Ejecuta la elección,
regístrala en `decisions.md`, y si es commit: `git add .graph && git commit -m "GRAPH: base de conocimiento inicial"`.
En repos sin git: solo genera los archivos y dilo en el resumen.
