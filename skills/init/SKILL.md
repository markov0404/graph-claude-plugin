---
description: "GRAPH — setup del repo: escanea el proyecto, verifica comandos reales y genera la base de conocimiento .graph/. Idempotente (con .graph/ existente ofrece refresh). Invocar con /graph:init"
---

# /graph:init — setup de GRAPH en este repo

Argumentos: "$ARGUMENTS" (vacío = setup normal; "refresh" = re-escaneo directo).

Tu trabajo es generar o refrescar `.graph/`, la base de conocimiento de ESTE
repo. Recorre las fases en orden. Todo lo que escribas va en español.

## Fase 1 — Detección previa

Si existe `.graph/` y los argumentos no dicen "refresh": muestra la fecha de
actualización de `INDEX.md` y pregunta con AskUserQuestion: refrescar todo /
refrescar solo lo desactualizado / cancelar. NUNCA arrases `.graph/` sin
preguntar. En modo no interactivo sin "refresh": reporta que ya existe y termina.

**Modo no interactivo** (sin usuario que pueda responder): omite todas las
preguntas de este skill — en fase 5 imprime el resumen sin esperar
correcciones, y en fase 6 aplica el default (commitear `.graph/`)
registrándolo en `decisions.md`.

## Fase 2 — Escaneo paralelo (solo lectura)

Despacha agentes Explore EN PARALELO (una sola respuesta con todas las
invocaciones), uno por dimensión:

1. **Estructura**: árbol de módulos, entry points, responsabilidad de cada área.
2. **Convenciones**: estilo, naming, patrones de test, idioma de comentarios.
3. **Stack**: lenguajes, frameworks, versiones, gestor de dependencias, candidatos a comandos de build/test/lint (leer package.json, pyproject.toml, Makefile, CI configs).
4. **Testing**: dónde viven los tests, cómo se corren, qué cubren a simple vista.

Repos grandes (orientativo: >200 archivos de código, o monorepo con varios
paquetes): en vez de 4 agentes globales, usa el Workflow tool con un agente
por paquete/área más un sintetizador (esta instrucción de skill constituye el
opt-in del usuario para usar Workflow).

## Fase 3 — Verificación de comandos (la ÚNICA fase que ejecuta cosas)

Toma los candidatos a build/test/lint de la fase 2 y EJECÚTALOS uno a uno:

- Corre bien → entra a `commands.md` con "sí" en verificado y su output esperado resumido (p.ej. "1 passing").
- Falla por prerrequisito → entra con "no — requiere: <qué>" (p.ej. "requiere: npm install"). NUNCA lo registres como funcionando.
- Riesgoso o largo (deploy, migraciones, publish) → NO lo corras; entra como "no verificado (riesgoso)".

## Fase 4 — Generar `.graph/`

Crea los archivos con EXACTAMENTE estos formatos (rellenando con lo escaneado):

`.graph/INDEX.md`:

```markdown
# GRAPH · <nombre del proyecto>
> Actualizado: <YYYY-MM-DD> · Estado: completo

**Qué es:** <1-2 frases>
**Stack:** <lenguajes y frameworks clave>
**Comandos clave:** test: `<cmd>` · build: `<cmd o "n/a">` · lint: `<cmd o "n/a">` (detalle en commands.md)
**Top-5 archivos/módulos:**
1. `<ruta>` — <por qué importa>
(hasta 5)
**Convenciones esenciales:** <máximo 3 bullets; detalle en conventions.md>
```

`.graph/map.md`: título `# Mapa de arquitectura`, luego una sección `##` por
módulo/área con: responsabilidad (1 frase), archivos clave, de qué depende.

`.graph/conventions.md`: título `# Convenciones`, bullets concretos y
accionables ("tests con node:test en test/*.test.js", "imports relativos"),
nunca vaguedades ("código limpio").

`.graph/commands.md`: título `# Comandos verificados`, tabla:

```markdown
| comando | qué hace | verificado | output esperado |
|---|---|---|---|
| `npm test` | corre los tests | sí (<YYYY-MM-DD>) | 1 passing |
```

`.graph/decisions.md`: título `# Log de decisiones`, tabla `| fecha | decisión | porqué |` (arranca con la fila del propio init: qué se decidió sobre git).

`.graph/tasks/README.md`: una línea: `Un archivo por tarea de /graph:do — ver la plantilla en el skill do.`

## Fase 5 — Corrección temprana

Muestra al usuario un resumen de UNA pantalla: qué entendió el sistema (lo
esencial de INDEX.md). Pregunta con AskUserQuestion si hay algo que corregir.
Cada corrección se aplica DE INMEDIATO al archivo correspondiente: es el
primer aprendizaje del repo.

## Fase 6 — Git

Pregunta UNA vez (AskUserQuestion): ¿commitear `.graph/` (recomendado, es
conocimiento del repo) o agregarlo a `.gitignore`? Ejecuta la elección,
regístrala en `decisions.md`, y si es commit: `git add .graph && git commit -m "GRAPH: base de conocimiento inicial"`.
En repos sin git: solo genera los archivos y dilo en el resumen.
