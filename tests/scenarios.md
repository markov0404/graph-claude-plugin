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
