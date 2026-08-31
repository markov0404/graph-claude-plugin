# GRAPH — Plugin de Claude Code para escalado por capas

**Fecha:** 2026-08-31
**Estado:** Diseño aprobado en brainstorming; pendiente de plan de implementación.

## 1. Propósito

Un meta-sistema embebible en cualquier repo que convierte un prompt corto ("quiero A") en la ejecución disciplinada de la escalera completa de ingeniería de agentes:

1. **Prompt engineering** — enriquecimiento del pedido en una mini-spec.
2. **Context engineering** — curación de contexto desde una base de conocimiento por repo.
3. **Harness engineering** — comandos y herramientas verificados del repo.
4. **Loop engineering** — iteración implementar → verificar → corregir hasta converger.
5. **Graph engineering** — orquestación de múltiples agentes vía Workflow cuando la tarea lo amerita.

El usuario aporta el prompt y una aprobación; el sistema aporta todo lo demás.

**Decisiones de alcance (del brainstorming):**
- Propósito **general**: "A" puede ser código, investigación, documentos — depende del proyecto.
- Motor: **Claude Code** (skills, hooks, subagentes, Workflow tool). No se construye runtime propio.
- Escalado **adaptativo** con **override manual** (flags y ajuste en el gate).
- Un solo checkpoint de **aprobación**: el gate en el plan. Otras interacciones son preguntas, no aprobaciones: 1-2 aclaratorias durante el enriquecimiento y, excepcionalmente, tardías en runtime (§6).
- **Conocimiento acumulativo** por repo, persistente entre tareas.

## 2. No-objetivos (v1)

- Runner headless / CI (Agent SDK sin terminal): v2.
- Soporte multi-usuario o sincronización de `.graph/` entre colaboradores más allá de git normal.
- UI propia: la interfaz es la conversación de Claude Code.

## 3. Arquitectura general

Dos piezas con separación estricta:

| Pieza | Contiene | Vive en | Se actualiza |
|---|---|---|---|
| Plugin `graph` | **Proceso**: cómo escalar, verificar, plantillas de grafo | Repo propio, instalado una vez como plugin de Claude Code | Un fix beneficia a todos los repos |
| `.graph/` | **Conocimiento**: qué es este repo, cómo se trabaja aquí | Raíz de cada repo del usuario | Cada tarea lo lee y lo enriquece |

Borrar `.graph/` no rompe nada: se pierde memoria y se regenera con `/graph:init`.

### 3.1 Estructura del plugin

```
graph-plugin/
  .claude-plugin/plugin.json
  skills/
    init/SKILL.md        → /graph:init   (setup del repo)
    do/SKILL.md          → /graph:do     (comando maestro, las 5 capas)
  hooks/
    hooks.json           → declara el hook SessionStart
    load-index.sh        → script del hook: inyecta .graph/INDEX.md al contexto si existe
```

Los skills contienen el proceso completo (incluidas las plantillas de Workflow para tier L y las plantillas de los archivos de `.graph/`). Si durante la implementación un skill crece demasiado, se divide en archivos de referencia dentro del mismo skill (`references/`), no en skills nuevos visibles al usuario: la superficie pública es solo `init` y `do`.

### 3.2 Estructura de `.graph/` (por repo)

```
.graph/
  INDEX.md          → 1 pantalla: qué es el proyecto, stack, top-5 archivos, comandos clave
  map.md            → mapa de arquitectura: módulos, responsabilidades, entry points
  conventions.md    → estilo, patrones, "cómo se hacen las cosas aquí"
  commands.md       → build/test/lint verificados por ejecución real, con output esperado
  decisions.md      → log de decisiones: fecha, decisión, porqué
  tasks/            → un archivo por tarea: mini-spec, tier, plan, resultado (éxito o fallo con causa)
```

`INDEX.md` es lo único que el hook inyecta en cada sesión; el resto se consulta bajo demanda.

**Git:** `.graph/` se commitea por defecto (es conocimiento del repo). `/graph:init` pregunta una sola vez si el usuario prefiere agregarlo a `.gitignore`.

## 4. `/graph:init` — setup por repo

Se corre una vez por repo (idempotente):

1. **Detección previa.** Si `.graph/` existe, ofrece modo refresh (re-escanear solo lo desactualizado) en vez de arrasar.
2. **Escaneo paralelo.** Agentes exploradores sobre dimensiones distintas: estructura y módulos; convenciones de código; dependencias y stack; tests existentes. Vía Workflow en repos grandes (orientativo: >200 archivos de código o monorepo), agentes sueltos en repos chicos.
3. **Verificación de comandos.** Los candidatos a build/test/lint se **ejecutan**; solo lo que corrió de verdad entra a `commands.md`, con su output esperado. Lo que falla por prerrequisito se anota como tal ("requiere: npm install"), nunca se registra como funcionando.
4. **Generación de `.graph/`** completo, con `INDEX.md` como destilado.
5. **Corrección temprana.** Muestra al usuario un resumen de lo que entendió; las correcciones del usuario se guardan de inmediato (primer aprendizaje del repo).

Costo objetivo para el usuario: un comando + 1-2 preguntas. Duración: minutos, proporcional al repo.

## 5. `/graph:do` — el comando maestro

Sintaxis: `/graph:do <prompt>` con flags opcionales:
- `--tier S|M|L` — fuerza el tier (`--quick` y `--full` son alias de `--tier S` y `--tier L`).
- `--budget <tokens>` — presupuesto opcional por tarea (ver §6).

### 5.1 Pipeline

1. **Enriquecimiento (capa prompt).** Agente toma el prompt + `INDEX.md` y produce la **mini-spec**:
   - Intención y alcance (qué entra / qué no).
   - **Criterios de aceptación** verificables ("A funciona cuando X pasa").
   - **Anti-criterios**: qué no tocar, qué no romper, qué no cambiar.
   - **Método de verificación por criterio**, según el tipo de tarea: para código, output real de tests/comandos; para investigación, verificación adversarial de las afirmaciones contra fuentes citadas; para documentos, revisión de completitud por agente independiente. Un criterio sin método verificable se reformula, o se marca como tal en el gate para que el usuario decida. (El harness también depende del tipo: `commands.md` para código; herramientas de búsqueda/lectura para investigación.)
   - Pregunta al usuario solo ante ambigüedad que cambie el diseño (máx. 1-2 preguntas).
2. **Contexto (capa context).** Consulta `.graph/` + exploradores dirigidos solo a zonas relevantes. Produce un paquete de contexto: archivos implicados, patrones a seguir, riesgos.
3. **Preflight de bloqueos.** Responsabilidad explícita de las capas 1-2: detectar TODO lo que dependa del humano **antes** de ejecutar — credenciales/accesos necesarios, criterios contradictorios, decisiones de diseño abiertas, dependencias externas dudosas. Sale como sección "necesito de ti" del gate.
4. **Clasificación → tier** (salvo override por flag). Rúbrica de decisión:
   - **S** — un solo frente de trabajo, verificable con una sola comprobación, cabe en un contexto: ejecución directa con prompt + contexto.
   - **M** — un solo frente pero con criterios que pueden fallar y corregirse (requiere iteración): + harness + loop implementar → verificar → corregir.
   - **L** — múltiples subtareas independientes, expertise heterogénea, o volumen que excede un contexto: + Workflow autorado por el sistema: fan-out de subtareas en paralelo (worktrees si mutan los mismos archivos), verificación adversarial, síntesis.
   En duda entre dos tiers, el mayor.
5. **Gate (único checkpoint de aprobación).** Una pantalla: mini-spec, tier y su porqué, plan de ejecución, topología del grafo (si L), y la sección "necesito de ti" con las preguntas del preflight. El usuario aprueba, corrige alcance, cambia tier, y responde lo pendiente — todo en una pasada, vía pregunta de aprobación explícita (AskUserQuestion). **Nada se ejecuta antes del OK** — donde "ejecutar" significa mutar el repo o producir efectos externos; las fases 1-4 son de solo lectura (sí gastan agentes de análisis).
6. **Ejecución** según tier (ver §6 para el modelo de convergencia).
7. **Verificación final.** Cada criterio de aceptación se comprueba con su método definido en la mini-spec (§5.1 paso 1) — evidencia real, nunca "debería funcionar" — y cada anti-criterio se comprueba intacto.
8. **Cierre.** Registro en `.graph/tasks/`; si la tarea reveló algo estructural, actualiza `map.md` / `decisions.md` / `conventions.md`.

## 6. Modelo de convergencia (sin contadores de intentos)

**Salida exitosa única del loop:** todos los criterios cumplidos con evidencia Y ningún anti-criterio violado. Ambos lados se verifican en cada iteración. Los criterios se fijan en el gate: son del usuario, no del sistema.

**No hay contador de intentos.** El mecanismo es:

1. **Detección de estancamiento** — no "van N intentos" sino "la última iteración no produjo información nueva" (mismo criterio fallando por la misma causa raíz). El loop mantiene un diario por criterio en el registro de la tarea (iteración → diagnóstico → resultado); "misma causa" la determina un agente verificador comparando diagnósticos. El estancamiento dispara escalada, no parada.
2. **Escalada de expertise**, en orden:
   a. Diagnóstico sistemático de causa raíz (agentes dedicados al *porqué*, no a re-intentar el fix).
   b. Fan-out de perspectivas distintas: replantear el enfoque, cuestionar el diseño, revisar si el test/criterio está mal formulado.
   c. Subida de tier — regla: **la maquinaria escala sola; el alcance no.** Si los criterios y anti-criterios aprobados en el gate no cambian, el sistema sube de tier autónomamente (S→M→L): más expertos para la misma tarea aprobada. Dos excepciones: (1) si el estancamiento revela que el alcance aprobado era otro, se vuelve al gate (§7); (2) si el tier fue **forzado por el usuario** (flag o ajuste en el gate), el sistema no lo sobrepasa solo — lo trata como bloqueo humano-dependiente y pregunta (punto 3).
3. **Preguntas tardías (excepcionales).** Si en runtime aparece algo humano-dependiente que el preflight no pudo ver (un token expira, un servicio externo cae), el sistema **no se detiene: pregunta**. Pausa en el punto exacto, presenta la pregunta con contexto mínimo, y continúa con la respuesta. La frecuencia de preguntas tardías es la métrica de calidad del preflight: si se vuelven comunes, es un bug del preflight y se registra en `.graph/` para mejorar la detección.

**La "parada sin converger" no existe como estado normal.** Solo ocurre si el usuario aborta.

**Dial opcional del usuario:** `--budget <tokens>` por tarea. Al agotarse, el sistema no para en silencio: pausa, presenta estado y evidencia de lo avanzado, y pregunta — ampliar presupuesto o abortar (coherente con "la parada sin converger solo la decide el usuario"). Por defecto sin tope: convergencia manda. Nunca hay límites ocultos.

## 7. Manejo de fallos y casos borde

- **Trinquete de tier de una sola vía:** la subida por estancamiento de convergencia es autónoma (§6, punto 2.c). En cambio, una tarea que revela **complejidad de alcance** — la mini-spec aprobada ya no describe lo que hay que hacer — se detiene y vuelve al gate con la mini-spec corregida, reutilizando la exploración ya ganada (no se paga dos veces). Nunca se degrada tier a mitad de tarea.
- **`.graph/` auto-reparable:** si un comando de `commands.md` falla en uso, se re-verifica y corrige el archivo en el momento.
- **`/graph:do` sin `.graph/`:** ofrece `/graph:init` primero; con `--quick` puede hacer escaneo mínimo inline (escribe un `.graph/` parcial, marcado como incompleto en `INDEX.md`) y dejar el init completo para después.
- **Tareas fallidas/abortadas también se registran** en `tasks/` con su causa: la próxima tarea similar arranca sabiendo qué no funcionó.

## 8. Estrategia de pruebas

El plugin es proceso en markdown (skills), así que se prueba **ejecutándolo contra repos fixture**:

- 2-3 repos de muestra: JS chico, Python, idealmente un monorepo.
- Checklist de escenarios: `init` genera `.graph/` correcto y verifica comandos de verdad; `do` se comporta según tier en S/M/L; los flags fuerzan tier; el gate bloquea ejecución hasta el OK; el preflight detecta bloqueos plantados a propósito; el loop escala en vez de rendirse; el cierre actualiza `.graph/`.
- Los escenarios se codifican como suite repetible con `claude plugin eval` (early access; si no está disponible, la misma checklist se corre como script manual documentado en el repo del plugin), no como prueba manual única.

## 9. Roadmap posterior (fuera de v1)

- Runner headless (Agent SDK) para CI/cron, con política de gate para modo no-interactivo.
- Métricas agregadas entre repos (qué tiers se usan, frecuencia de preguntas tardías).
- Plantillas de grafo adicionales por dominio (investigación profunda, auditoría, migraciones).
