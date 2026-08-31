# GRAPH Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Plugin de Claude Code llamado `graph` que convierte un prompt corto en ejecución disciplinada por capas (mini-spec → contexto → preflight → tier S/M/L → gate → ejecución convergente → cierre), con base de conocimiento acumulativa `.graph/` por repo.

**Architecture:** El plugin contiene solo PROCESO (2 skills en markdown, 1 hook bash, manifiestos JSON); el CONOCIMIENTO vive en `.graph/` de cada repo del usuario, generado por `/graph:init` y enriquecido por `/graph:do`. No hay runtime propio: Claude Code aporta agentes, loops y Workflow.

**Tech Stack:** Sistema de plugins de Claude Code (SKILL.md + hooks.json + plugin.json), bash para hook y tests, fixtures con `node --test` (JS) y `pytest` (Python).

**Spec:** `docs/superpowers/specs/2026-08-31-graph-plugin-design.md` — el plan argumenta desde el spec; los ejecutores leen ambos.

## Global Constraints

- Superficie pública del plugin: SOLO `/graph:init` y `/graph:do`. Nada más visible al usuario.
- Todo texto visible al usuario y todo archivo de `.graph/` se escribe en **español**.
- **Sin contadores de intentos** en ninguna parte del proceso: la salida del loop es por criterios cumplidos; el estancamiento dispara escalada.
- **"Nada se ejecuta antes del OK del gate"** — "ejecutar" = mutar el repo o producir efectos externos; el análisis pre-gate es de solo lectura.
- **La maquinaria escala sola; el alcance no**: subir tier es autónomo si criterios/anti-criterios no cambian; cambio de alcance vuelve al gate; tier forzado por el usuario nunca se sobrepasa sin preguntar.
- `.graph/` se commitea por defecto (el usuario puede elegir ignorarlo, una sola vez, en init).
- El gate y toda pregunta al usuario usan AskUserQuestion; en modo no interactivo el gate no puede aprobarse: se presenta el plan y se termina sin mutar.
- `claude plugin eval` está en early access y NO disponible: la suite de pruebas es `tests/run-scenarios.sh` (automatizada) + `tests/scenarios.md` (interactiva), según fallback del spec §8.
- Los comandos headless de prueba usan `--dangerously-skip-permissions` SOLO dentro de fixtures desechables generados en `tests/build/` (gitignoreado).

---

### Task 1: Esqueleto del plugin (manifest + README)

**Files:**
- Create: `.claude-plugin/plugin.json`
- Create: `README.md`
- Create: `.gitignore`

**Interfaces:**
- Produces: plugin válido llamado `graph` → los skills de Tasks 4-5 se invocan como `/graph:init` y `/graph:do`.

- [ ] **Step 1: Crear el manifest**

`.claude-plugin/plugin.json`:

```json
{
  "name": "graph",
  "displayName": "GRAPH",
  "version": "0.1.0",
  "description": "Sistema de escalado por capas: convierte un prompt corto en mini-spec, contexto, harness, loop convergente y grafo de agentes, con conocimiento acumulativo por repo en .graph/",
  "author": { "name": "dani", "email": "markov0404@users.noreply.github.com" },
  "license": "MIT",
  "keywords": ["orchestration", "agents", "graph-engineering"]
}
```

- [ ] **Step 2: Crear `.gitignore`**

```
tests/build/
```

- [ ] **Step 3: Crear `README.md`**

```markdown
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
```

- [ ] **Step 4: Validar el plugin**

Run: `claude plugin validate <ruta-al-repo>/graph-plugin`
Expected: `✔ Validation passed` (o mensaje equivalente de éxito; si falla por skills vacíos, anotarlo y re-validar al final de Task 5).

- [ ] **Step 5: Commit**

```bash
git add .claude-plugin/plugin.json README.md .gitignore
git commit -m "feat: esqueleto del plugin graph (manifest, README)"
```

---

### Task 2: Hook SessionStart (TDD)

**Files:**
- Create: `hooks/hooks.json`
- Create: `hooks/load-index.sh`
- Test: `tests/test-hook.sh`

**Interfaces:**
- Consumes: nada (independiente).
- Produces: al iniciar sesión en un repo con `.graph/INDEX.md`, su contenido se inyecta al contexto precedido por la línea `GRAPH: contexto del repo (.graph/INDEX.md — base completa en .graph/):`. Sin `.graph/`, el hook no emite nada.

- [ ] **Step 1: Escribir el test que falla**

`tests/test-hook.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
HOOK="$(cd "$(dirname "$0")/.." && pwd)/hooks/load-index.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Caso 1: sin .graph/ → salida vacía, exit 0
out=$(CLAUDE_PROJECT_DIR="$TMP" bash "$HOOK")
[ -z "$out" ] || { echo "FAIL: esperaba salida vacía sin .graph/"; exit 1; }

# Caso 2: con .graph/INDEX.md → inyecta encabezado + contenido
mkdir -p "$TMP/.graph"
printf '# Proyecto X\nStack: node\n' > "$TMP/.graph/INDEX.md"
out=$(CLAUDE_PROJECT_DIR="$TMP" bash "$HOOK")
echo "$out" | grep -q "GRAPH: contexto del repo" || { echo "FAIL: falta encabezado"; exit 1; }
echo "$out" | grep -q "Proyecto X" || { echo "FAIL: falta contenido de INDEX"; exit 1; }

echo "OK: hook"
```

- [ ] **Step 2: Correrlo y verificar que falla**

Run: `chmod +x tests/test-hook.sh && tests/test-hook.sh`
Expected: FAIL (load-index.sh no existe todavía).

- [ ] **Step 3: Implementar el hook**

`hooks/load-index.sh`:

```bash
#!/usr/bin/env bash
# SessionStart: inyecta .graph/INDEX.md al contexto si existe. Silencioso si no.
set -euo pipefail
INDEX="${CLAUDE_PROJECT_DIR:-.}/.graph/INDEX.md"
if [ -f "$INDEX" ]; then
  echo "GRAPH: contexto del repo (.graph/INDEX.md — base completa en .graph/):"
  cat "$INDEX"
fi
exit 0
```

`hooks/hooks.json`:

```json
{
  "description": "GRAPH: carga .graph/INDEX.md al contexto en cada sesión",
  "hooks": {
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/load-index.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 4: Correr el test y verificar que pasa**

Run: `chmod +x hooks/load-index.sh && tests/test-hook.sh`
Expected: `OK: hook`

- [ ] **Step 5: Commit**

```bash
git add hooks/ tests/test-hook.sh
git commit -m "feat: hook SessionStart que inyecta .graph/INDEX.md"
```

---

### Task 3: Fixtures de prueba

**Files:**
- Create: `tests/make-fixtures.sh`

**Interfaces:**
- Produces: `tests/build/fixture-js` (repo git Node con `npm test` vía `node --test`, sin dependencias externas) y `tests/build/fixture-py` (repo git Python con `pytest`). Tasks 4-7 los usan como repos objetivo.

- [ ] **Step 1: Escribir el generador**

`tests/make-fixtures.sh`:

```bash
#!/usr/bin/env bash
# Genera repos fixture desechables en tests/build/ (gitignoreado). Idempotente.
set -euo pipefail
BASE="$(cd "$(dirname "$0")" && pwd)/build"
rm -rf "$BASE"; mkdir -p "$BASE"

JS="$BASE/fixture-js"
mkdir -p "$JS/src" "$JS/test"
cat > "$JS/package.json" <<'EOF'
{
  "name": "fixture-js",
  "version": "1.0.0",
  "type": "module",
  "scripts": { "test": "node --test test/" }
}
EOF
cat > "$JS/src/cart.js" <<'EOF'
export function total(items) {
  return items.reduce((sum, it) => sum + it.price * it.qty, 0);
}
EOF
cat > "$JS/test/cart.test.js" <<'EOF'
import { test } from 'node:test';
import assert from 'node:assert';
import { total } from '../src/cart.js';

test('total suma precio por cantidad', () => {
  assert.equal(total([{ price: 10, qty: 2 }]), 20);
});
EOF
(cd "$JS" && git init -qb main && git add -A && git -c user.email=fx@fx -c user.name=fx commit -qm "fixture inicial")

PY="$BASE/fixture-py"
mkdir -p "$PY/app" "$PY/tests"
: > "$PY/app/__init__.py"
cat > "$PY/app/slug.py" <<'EOF'
def slugify(text: str) -> str:
    return "-".join(text.lower().split())
EOF
cat > "$PY/tests/test_slug.py" <<'EOF'
from app.slug import slugify

def test_slugify_espacios():
    assert slugify("Hola Mundo") == "hola-mundo"
EOF
cat > "$PY/pytest.ini" <<'EOF'
[pytest]
testpaths = tests
EOF
(cd "$PY" && git init -qb main && git add -A && git -c user.email=fx@fx -c user.name=fx commit -qm "fixture inicial")

echo "fixtures listos en $BASE"
```

- [ ] **Step 2: Generar y verificar que los fixtures funcionan**

Run: `chmod +x tests/make-fixtures.sh && tests/make-fixtures.sh && (cd tests/build/fixture-js && npm test) && (cd tests/build/fixture-py && python3 -m pytest -q)`
Expected: fixtures creados; el test de Node pasa (1 passing) y el de pytest pasa (1 passed). Si `pytest` no está instalado: `pip3 install --user pytest` y reintentar.

- [ ] **Step 3: Commit**

```bash
git add tests/make-fixtures.sh
git commit -m "feat: generador de repos fixture (JS y Python)"
```

---

### Task 4: Skill `/graph:init`

**Files:**
- Create: `skills/init/SKILL.md`

**Interfaces:**
- Consumes: fixtures de Task 3 para la prueba.
- Produces: el directorio `.graph/` con exactamente estos archivos y formatos (Task 5 los consume tal cual): `INDEX.md`, `map.md`, `conventions.md`, `commands.md` (tabla `| comando | qué hace | verificado | output esperado |`), `decisions.md` (tabla `| fecha | decisión | porqué |`), `tasks/README.md`.

- [ ] **Step 1: Escribir el skill completo**

`skills/init/SKILL.md`:

````markdown
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
````

- [ ] **Step 2: Probar headless sobre fixture-js**

Run:

```bash
tests/make-fixtures.sh
cd tests/build/fixture-js
claude -p --plugin-dir <ruta-al-repo>/graph-plugin --dangerously-skip-permissions "/graph:init refresh"
ls .graph/
cat .graph/commands.md
```

Expected: `.graph/` contiene los 5 archivos + `tasks/`; `commands.md` tiene la fila de `npm test` con verificado "sí" (el agente lo ejecutó de verdad). Si el skill no aparece, correr `claude plugin validate <ruta-al-repo>/graph-plugin` y arreglar el frontmatter.

- [ ] **Step 3: Verificar formato de INDEX.md**

Run: `head -20 tests/build/fixture-js/.graph/INDEX.md`
Expected: empieza con `# GRAPH · fixture-js`, tiene línea `> Actualizado:`, secciones Qué es / Stack / Comandos clave / Top-5 / Convenciones esenciales.

- [ ] **Step 4: Commit**

```bash
git add skills/init/SKILL.md
git commit -m "feat: skill /graph:init — escaneo, verificación de comandos y generación de .graph/"
```

---

### Task 5: Skill `/graph:do` (pipeline completo)

**Files:**
- Create: `skills/do/SKILL.md`

**Interfaces:**
- Consumes: los archivos `.graph/` con los formatos exactos de Task 4.
- Produces: registros `.graph/tasks/<YYYY-MM-DD>-<slug>.md` con la plantilla definida abajo; referencia `references/workflow-templates.md` que Task 6 crea (el skill instruye leerlo solo en tier L).

- [ ] **Step 1: Escribir el skill completo**

`skills/do/SKILL.md`:

````markdown
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
3. **La maquinaria escala sola; el alcance no.** Subir de tier es autónomo mientras los criterios y anti-criterios aprobados no cambien. Si el alcance real resulta otro, se vuelve al gate.
4. **Tier forzado por el usuario nunca se sobrepasa en silencio**: si te quedas estancado en un tier forzado, pregunta.
5. **La parada sin converger solo la decide el usuario.** Bloqueo humano-dependiente en runtime → pregunta con AskUserQuestion y continúa con la respuesta.
6. **Evidencia siempre.** Ningún criterio se declara cumplido sin ejecutar su método de verificación y citar el output real. Prohibido "debería funcionar".
7. **Modo no interactivo** (sin usuario que responda): el gate no puede aprobarse — presenta la pantalla del gate como salida final y termina SIN mutar nada.

## Fase 0 — Precondiciones

- Separa del final del pedido los flags: `--tier S|M|L` (alias: `--quick`=S, `--full`=L), `--budget <n>`. El resto es el pedido.
- Si NO existe `.graph/`: ofrece correr `/graph:init` primero (AskUserQuestion). Excepción con `--quick`: haz un escaneo mínimo inline (estructura + comando de test si es evidente), escribe un `.graph/` parcial cuyo `INDEX.md` empiece con `> Estado: parcial — correr /graph:init`, y sigue.
- Lee `.graph/INDEX.md` completo si el hook no lo inyectó ya.

## Fase 1 — Mini-spec (capa prompt)

Redacta a partir del pedido + INDEX.md:

- **Intención**: qué quiere lograr el usuario, una frase.
- **Alcance**: qué entra / qué queda explícitamente fuera.
- **Criterios de aceptación**: lista numerada; cada criterio es verificable y lleva su **método de verificación**:
  - código → comando exacto (de `.graph/commands.md` o nuevo) + resultado esperado
  - investigación → verificación adversarial de afirmaciones contra fuentes citadas
  - documento → revisión de completitud contra el alcance por agente independiente
  Criterio sin método posible → reformúlalo; si no se puede, márcalo "sin método" para resolverlo en el gate.
- **Anti-criterios**: qué NO tocar / NO romper / NO cambiar (API pública, comportamiento existente, archivos vetados), cada uno con su método de comprobación.

Solo si hay ambigüedad que cambie el diseño: máximo 1-2 preguntas
(AskUserQuestion) AHORA. Lo demás se decide con criterio y se muestra en el gate.

## Fase 2 — Contexto (capa context)

- Lee `.graph/map.md`, `conventions.md`, `commands.md` y los registros de `.graph/tasks/` de tareas similares — incluidos los fallidos (qué NO funcionó ya).
- Despacha 1-3 agentes Explore SOLO hacia las zonas que la mini-spec implica. Nada de exploración general: el mapa ya existe.
- Produce el **paquete de contexto**: archivos implicados, patrones a seguir, riesgos, aprendizaje previo relevante.

## Fase 3 — Preflight de bloqueos

Con mini-spec + contexto, lista TODO lo que dependa del humano ANTES de ejecutar:

- credenciales/accesos/permisos que harán falta
- criterios que se contradicen entre sí o con anti-criterios
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
final, sección Mini-spec aprobada llena. Es la bitácora de la tarea.

### Tier S

Ejecuta directo con el paquete de contexto: una pasada + verificación de
todos los criterios y anti-criterios.

### Tier M — loop convergente

Repite hasta converger:

1. Implementa o corrige lo mínimo para el criterio pendiente más importante.
2. Verifica TODOS los criterios con sus métodos y TODOS los anti-criterios.
3. Anota en el diario del task record: `iteración → qué se hizo → diagnóstico de cada fallo → resultado`.
4. **Estancamiento** = el diario muestra el mismo criterio fallando por la misma causa raíz que la iteración anterior. En duda, pide a un agente independiente comparar los dos diagnósticos. Estancado → escalada EN ORDEN:
   a. **Diagnóstico**: agente dedicado SOLO a explicar la causa raíz (con systematic-debugging si está disponible); tiene prohibido proponer el fix.
   b. **Fan-out de perspectivas**: 2-3 agentes en paralelo — uno replantea el enfoque, uno cuestiona el diseño, uno audita si el criterio/test está mal formulado.
   c. **Subir tier a L** — autónomo si el tier no fue forzado; si fue forzado, pregunta (regla dura 4).
5. Si descubres que el alcance aprobado ya no describe la tarea (complejidad de alcance, no de convergencia): STOP → vuelve a la fase 5 con la mini-spec corregida, reutilizando todo lo explorado.

### Tier L — grafo

Lee `references/workflow-templates.md` (en el directorio de este skill) y
autora un Workflow con la plantilla que corresponda (implementación
multi-frente / investigación / auditoría). Esta instrucción constituye el
opt-in del usuario para usar el Workflow tool. Reglas: worktrees si los nodos
mutan los mismos archivos; verificación adversarial de cada entregable;
síntesis final; el loop convergente de tier M aplica sobre el resultado
sintetizado (si la síntesis no cumple criterios, se itera).

### Presupuesto

Con `--budget <n>`: revisa el gasto al cerrar cada iteración/fase; al
agotarse, pausa, presenta estado + evidencia de avance y pregunta: ampliar o
abortar. Sin flag: sin tope, convergencia manda. Nunca inventes topes.

## Fase 7 — Verificación final

Tabla en el task record y en tu resumen: criterio → método → comando/
procedimiento ejecutado → evidencia (output real citado) → ✅/❌. Lo mismo
para anti-criterios (intactos). Si algo está en ❌, NO estás en fase 7:
sigues en fase 6.

## Fase 8 — Cierre

1. Completa el task record: resultado, evidencia final, aprendizajes. Si se abortó: causa exacta y qué se descartó (vale tanto como un éxito).
2. ¿La tarea reveló algo estructural? → actualiza `map.md` / `conventions.md` / `decisions.md`, respetando el formato existente de cada archivo.
3. ¿Cambió algo de la pantalla principal (stack, comandos, top-5)? → actualiza `INDEX.md`.
4. ¿Algún comando de `commands.md` falló en uso? → corrígelo ahí (auto-reparación).
5. Resume al usuario: qué se entregó, con qué evidencia, qué aprendió el sistema.

## Plantilla del task record

```markdown
# <slug> · <YYYY-MM-DD> · tier <S|M|L>

## Mini-spec aprobada
- Intención:
- Alcance:
- Criterios (con método):
- Anti-criterios (con método):
- Tier: <elegido|forzado> — porqué:

## Diario
| iteración | qué se hizo | diagnóstico | resultado |
|---|---|---|---|

## Resultado
- Estado: convergió | abortado por usuario | reescopado
- Evidencia final:
- Aprendizajes:
```
````

- [ ] **Step 2: Probar headless que el gate bloquea**

Run:

```bash
tests/make-fixtures.sh
cd tests/build/fixture-js
claude -p --plugin-dir <ruta-al-repo>/graph-plugin --dangerously-skip-permissions "/graph:init refresh" > /dev/null
git add -A && git -c user.email=fx@fx -c user.name=fx commit -qm "post-init"
claude -p --plugin-dir <ruta-al-repo>/graph-plugin --dangerously-skip-permissions "/graph:do quiero que total aplique un descuento porcentual opcional" | tee /tmp/gate.out
git status --porcelain
```

Expected: la salida contiene la pantalla del gate (mini-spec con criterios y métodos, tier con porqué) y termina ahí (regla dura 7); `git status --porcelain` muestra a lo sumo cambios bajo `.graph/` (task record NO debe existir aún — se crea post-gate; si existe, es un bug del skill: corrígelo).

- [ ] **Step 3: Commit**

```bash
git add skills/do/SKILL.md
git commit -m "feat: skill /graph:do — pipeline de 8 fases con gate y convergencia sin contadores"
```

---

### Task 6: Plantillas de Workflow para tier L

**Files:**
- Create: `skills/do/references/workflow-templates.md`

**Interfaces:**
- Consumes: la fase "Tier L — grafo" de `skills/do/SKILL.md` instruye leer este archivo.
- Produces: plantillas de scripts para el Workflow tool que el orquestador adapta (no ejecuta verbatim).

- [ ] **Step 1: Escribir las plantillas**

`skills/do/references/workflow-templates.md`:

````markdown
# Plantillas de Workflow para tier L

Adapta la plantilla al caso: reemplaza subtareas, prompts y esquemas. Reglas
comunes: cada agente recibe en su prompt el CONTEXTO que necesita (mini-spec
+ paquete de contexto relevante — los agentes de workflow NO ven la
conversación); todo entregable pasa verificación adversarial; el `meta` es un
literal puro; los scripts son JavaScript plano (sin tipos), sin Date.now() ni
Math.random().

## 1. Implementación multi-frente

Para: feature/refactor con subtareas independientes que mutan archivos.

```javascript
export const meta = {
  name: 'graph-implementacion',
  description: 'Implementa subtareas en paralelo con verificación adversarial',
  phases: [{ title: 'Implementar' }, { title: 'Verificar' }, { title: 'Sintetizar' }],
}
const SUBTAREAS = args.subtareas  // [{id, prompt, criterios}]
const VEREDICTO = { type: 'object', properties: {
  aprobado: { type: 'boolean' }, problemas: { type: 'array', items: { type: 'string' } } },
  required: ['aprobado', 'problemas'] }

const resultados = await pipeline(
  SUBTAREAS,
  st => agent(st.prompt, { label: `impl:${st.id}`, phase: 'Implementar', isolation: 'worktree' }),
  (res, st) => agent(
    `Verifica adversarialmente esta implementación. Criterios: ${JSON.stringify(st.criterios)}. ` +
    `Resumen del implementador: ${res}. Ejecuta los métodos de verificación de verdad; ` +
    `en caso de duda, aprobado=false.`,
    { label: `verif:${st.id}`, phase: 'Verificar', schema: VEREDICTO }
  ).then(v => ({ id: st.id, resumen: res, veredicto: v }))
)
const rechazadas = resultados.filter(Boolean).filter(r => !r.veredicto.aprobado)
return { resultados, rechazadas }
// El orquestador corrige las rechazadas (loop de tier M) y re-verifica.
```

## 2. Investigación en abanico

Para: pedidos de research/análisis con criterios de evidencia.

```javascript
export const meta = {
  name: 'graph-investigacion',
  description: 'Barrido multi-ángulo, lectura profunda y verificación de afirmaciones',
  phases: [{ title: 'Barrer' }, { title: 'Profundizar' }, { title: 'Verificar' }],
}
const ANGULOS = args.angulos  // [{id, prompt}]  — ángulos de búsqueda distintos
const HALLAZGOS = { type: 'object', properties: {
  hallazgos: { type: 'array', items: { type: 'object', properties: {
    afirmacion: { type: 'string' }, fuente: { type: 'string' } },
    required: ['afirmacion', 'fuente'] } } }, required: ['hallazgos'] }
const VERDAD = { type: 'object', properties: {
  sostenida: { type: 'boolean' }, nota: { type: 'string' } }, required: ['sostenida'] }

const porAngulo = await pipeline(
  ANGULOS,
  a => agent(a.prompt, { label: `barrido:${a.id}`, phase: 'Barrer', schema: HALLAZGOS }),
  res => parallel(res.hallazgos.map(h => () =>
    agent(`Intenta REFUTAR con fuentes: "${h.afirmacion}" (fuente declarada: ${h.fuente}). ` +
          `Si no encuentras sustento independiente, sostenida=false.`,
      { phase: 'Verificar', schema: VERDAD }).then(v => ({ ...h, ...v }))))
)
return { confirmados: porAngulo.filter(Boolean).flat().filter(h => h.sostenida) }
```

## 3. Auditoría hasta agotar

Para: "revisa/audita todo X" sin tamaño conocido. Usa loop-until-dry: rondas
de buscadores hasta que 2 rondas seguidas no aporten nada nuevo, con dedup
contra TODO lo visto y veredicto por mayoría de 3 refutadores por hallazgo.
Estructura: igual a la plantilla 2, envuelta en `while (secas < 2)` con un
`Set` de claves vistas. Sin topes de cantidad: se agota, no se corta.
````

- [ ] **Step 2: Verificar consistencia con el skill**

Run: `grep -n "workflow-templates" skills/do/SKILL.md`
Expected: la fase Tier L referencia exactamente `references/workflow-templates.md`.

- [ ] **Step 3: Commit**

```bash
git add skills/do/references/workflow-templates.md
git commit -m "feat: plantillas de Workflow para tier L (implementación, investigación, auditoría)"
```

---

### Task 7: Suite de escenarios

**Files:**
- Create: `tests/run-scenarios.sh`
- Create: `tests/scenarios.md`

**Interfaces:**
- Consumes: hook (Task 2), fixtures (Task 3), skills (Tasks 4-6).
- Produces: verificación repetible del plugin completo; `scenarios.md` es la checklist interactiva que el usuario corre a mano.

- [ ] **Step 1: Escribir el runner automatizado**

`tests/run-scenarios.sh`:

```bash
#!/usr/bin/env bash
# Suite automatizada GRAPH. Los escenarios interactivos están en scenarios.md.
# Usa --dangerously-skip-permissions SOLO dentro de fixtures desechables.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC=(claude -p --plugin-dir "$ROOT" --dangerously-skip-permissions)

"$ROOT/tests/test-hook.sh"
"$ROOT/tests/make-fixtures.sh"
JS="$ROOT/tests/build/fixture-js"

echo "— E1: init genera .graph/ con comandos verificados"
(cd "$JS" && "${CC[@]}" "/graph:init refresh" > /dev/null)
for f in INDEX.md map.md conventions.md commands.md decisions.md tasks/README.md; do
  [ -f "$JS/.graph/$f" ] || { echo "FAIL E1: falta .graph/$f"; exit 1; }
done
grep -q "npm test" "$JS/.graph/commands.md" || { echo "FAIL E1: commands.md sin npm test"; exit 1; }

echo "— E2: el gate bloquea en headless (sin mutación fuera de .graph/)"
(cd "$JS" && git add -A && git -c user.email=fx@fx -c user.name=fx commit -qm "post-init")
(cd "$JS" && "${CC[@]}" "/graph:do quiero que total aplique un descuento porcentual opcional") > /tmp/graph-e2.out
grep -qiE "gate|apruéb|aprobar" /tmp/graph-e2.out || { echo "FAIL E2: no presentó el gate"; exit 1; }
mut=$(cd "$JS" && git status --porcelain | grep -v '\.graph/' || true)
[ -z "$mut" ] || { echo "FAIL E2: mutó el repo antes del OK: $mut"; exit 1; }

echo "— E3: --quick sin .graph/ crea base parcial y no muta código"
QT=$(mktemp -d); cp -r "$JS/src" "$JS/test" "$JS/package.json" "$QT/"
(cd "$QT" && git init -qb main && git add -A && git -c user.email=fx@fx -c user.name=fx commit -qm x)
(cd "$QT" && "${CC[@]}" "/graph:do --quick quiero que total redondee a 2 decimales") > /tmp/graph-e3.out || true
[ -f "$QT/.graph/INDEX.md" ] && grep -qi "parcial" "$QT/.graph/INDEX.md" || { echo "FAIL E3: sin INDEX parcial"; exit 1; }
rm -rf "$QT"

echo "OK: escenarios automatizados (E1-E3)"
```

- [ ] **Step 2: Escribir la checklist interactiva**

`tests/scenarios.md`:

```markdown
# Escenarios interactivos GRAPH

Correr en una sesión interactiva: `cd tests/build/fixture-py && claude --plugin-dir <ruta-al-repo>/graph-plugin`
(antes: `tests/make-fixtures.sh`; en fixture-py correr primero `/graph:init`).

## I1 — Tier M converge sin contadores
`/graph:do quiero que slugify elimine tildes y signos de puntuación`
Esperado: gate con criterios (pytest como método) → aprobar → loop hasta que
pytest pase de verdad → task record en .graph/tasks/ con diario poblado.
FALLA si: declara éxito sin output de pytest, o menciona "intento N de M".

## I2 — Preflight caza un bloqueo plantado
`/graph:do quiero publicar el paquete en PyPI con mi cuenta`
Esperado: el gate incluye "Necesito de ti" pidiendo credenciales/decisión
ANTES de ejecutar nada. FALLA si: intenta publicar o pregunta a mitad de ejecución.

## I3 — Tier forzado se respeta
`/graph:do --tier S quiero refactorizar todo el módulo app con validación y logging`
Esperado: gate avisa que S es forzado y probablemente insuficiente; si tras
aprobar se estanca, PREGUNTA antes de subir de tier (nunca sube solo).

## I4 — Tier L autora un grafo
`/graph:do --full quiero un informe de calidad del código: convenciones, tests faltantes y riesgos, verificado`
Esperado: gate muestra topología (nodos, fases) → Workflow real con
verificación adversarial → síntesis con evidencia.

## I5 — Presupuesto agotado pregunta
`/graph:do --budget 1000 quiero que slugify soporte guiones bajos configurables`
Esperado: al agotar el presupuesto pausa, muestra avance y pregunta
ampliar/abortar. FALLA si: para en silencio o ignora el flag.

## I7 — Tier S ejecuta directo
`/graph:do quiero que el README del fixture explique qué hace slugify`
Esperado: clasificado S (un frente, una comprobación) → gate → tras aprobar,
una sola pasada + verificación → task record creado. FALLA si: despliega
loops o grafo para algo trivial.

## I6 — Hook carga el índice
Nueva sesión en fixture-py tras I1: el contexto inicial contiene
"GRAPH: contexto del repo". Preguntar "¿qué comandos de test tiene este repo?"
debe responderse sin explorar (sale de .graph/).
```

- [ ] **Step 3: Correr la suite automatizada**

Run: `chmod +x tests/run-scenarios.sh && tests/run-scenarios.sh`
Expected: `OK: escenarios automatizados (E1-E3)`. Cada FAIL indica el skill a corregir (E1→init, E2/E3→do); corregir y re-correr hasta verde.

- [ ] **Step 4: Commit**

```bash
git add tests/run-scenarios.sh tests/scenarios.md
git commit -m "test: suite de escenarios automatizada e interactiva"
```

---

### Task 8: Instalación permanente (self-marketplace)

**Files:**
- Create: `.claude-plugin/marketplace.json`
- Modify: `README.md` (ya contiene las instrucciones — verificar que coinciden)

**Interfaces:**
- Consumes: plugin completo (Tasks 1-7).
- Produces: el repo del plugin funciona como su propio marketplace: `/plugin marketplace add <ruta-al-repo>/graph-plugin` + `/plugin install graph@graph-marketplace`.

- [ ] **Step 1: Crear el marketplace**

`.claude-plugin/marketplace.json`:

```json
{
  "name": "graph-marketplace",
  "owner": { "name": "dani" },
  "plugins": [
    {
      "name": "graph",
      "source": "./",
      "description": "Sistema de escalado por capas con conocimiento acumulativo por repo",
      "version": "0.1.0"
    }
  ]
}
```

- [ ] **Step 2: Validar todo el plugin**

Run: `claude plugin validate <ruta-al-repo>/graph-plugin`
Expected: validación pasa. Si el esquema de marketplace.json falla, ajustar según el mensaje (el campo `source: "./"` es la pieza clave: el repo se lista a sí mismo).

- [ ] **Step 3: Commit**

```bash
git add .claude-plugin/marketplace.json README.md
git commit -m "feat: self-marketplace para instalación permanente"
```

- [ ] **Step 4: Verificación interactiva final (la hace el usuario)**

En una sesión nueva: `/plugin marketplace add <ruta-al-repo>/graph-plugin`, `/plugin install graph@graph-marketplace`, y en cualquier repo: `/graph:init` seguido de un `/graph:do` real. Los escenarios interactivos completos están en `tests/scenarios.md`.
