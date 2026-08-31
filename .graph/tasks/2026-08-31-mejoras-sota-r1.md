# mejoras-sota-r1 · 2026-08-31 · tier L

## Mini-spec aprobada
- Intención: implementar las 7 mejoras SOTA de la ronda 1 en el propio plugin.
- Fuente de requisitos: docs/superpowers/specs/2026-08-31-graph-mejoras-sota-design.md (commit 0229dfd) — autoridad vinculante.
- Alcance: exactamente las 7 mejoras del spec. Fuera: captura pasiva, consolidación, tree-sitter, backlog ronda 2.
- Criterios (con método):
  1. `tools/symbol-map.sh` + `tests/test-symbol-map.sh` en verde: asserta `total` (fixture-js), `slugify` (fixture-py) y el caso de lenguaje sin cobertura (ejecución real, TDD).
  2. E1 exige `constitution.md` y la suite pasa (ejecución real).
  3. Suite completa `OK: escenarios automatizados (E1-E3)` exit 0 + `tests/test-hook.sh` + `claude plugin validate .` (ejecución real).
  4. Skills/plantillas/conventions consistentes con cada sección del spec (revisión adversarial del diff contra el spec).
- Anti-criterios (con método): gate y reglas duras intactos (E2/E3 + adversarial); contrato `.graph/` solo aditivo (diff); `docs/superpowers/` intacto (git diff --stat); política de tooling respetada — cero dependencias externas (revisión del script).
- Tier: L — elegido por el clasificador: 7 subtareas independientes con expertise heterogénea (condición literal de L). No forzado.

## Diario
| iteración | qué se hizo | diagnóstico | resultado |
|---|---|---|---|
| 1 | Workflow tier L: 5 grupos disjuntos por archivo + verificador adversarial por grupo (10 agentes) | 4/5 aprobados; G5 rechazado: test-symbol-map integrado ANTES de make-fixtures (mi encargo decía "tras test-hook", el verificador juzgó contra el spec) | reorden aplicado por el orquestador; bash -n ✓; test-symbol-map verde directo (RED capturado por G4: "no existe tools/symbol-map.sh"; GREEN: OK symbol-map 3 casos) |
| 2 | Suite integrada corrida | FAIL E2: graph-e2.out inexistente. Causa raíz por transcripts: un subagente explorador de la sesión E2 ejecutó tests/make-fixtures.sh del repo PADRE (los fixtures anidan dentro del plugin) → rm -rf build borró el .out y el .graph del fixture. La regla dura 1 no se transmitía a los subagentes | fix de causa raíz: instrucción SOLO LECTURA ESTRICTA obligatoria a exploradores en do Fase 2 e init Fase 2; .out reubicados a tests/ (fuera del radio de rm -rf, gitignoreados, preservados para depurar) |
| 3 | Verificación adversarial del diff completo | 6 hallazgos: [ALTO] task record de esta tarea incompleto (transitorio — se llena en el cierre; la plantilla ganó el estado "en ejecución (transitorio)"); [MEDIO] opción (b) de "En curso" sin reconciliación textual con reglas 1/7 (frase añadida); [MEDIO, demostrado] symbol-map inventa símbolos dentro de template literals/docstrings (endurecimiento awk + caso de test en curso); [MEDIO] plantilla 2 sin `model` (añadido con lente correctitud→haiku); [BAJO] refresh sobre .graph/ viejo sin constitution (cláusula añadida); [TRIVIAL] gramática conventions (corregida) | 5/6 corregidos por el orquestador; el 6º (awk) en agente dedicado con TDD |

## Verificación final
| criterio/anti-criterio | método | comando/procedimiento ejecutado | evidencia | ✅/❌ |
|---|---|---|---|---|
| C1 symbol-map + test | ejecución real, TDD | `tests/test-symbol-map.sh` (RED capturado: "no existe tools/symbol-map.sh"; y RED del caso adversarial: "se inventó fakeSymbol") | `OK: symbol-map (JS, Python, caso sin cobertura, caso adversarial template/docstring)` | ✅ |
| C2 E1 exige constitution.md | suite | `tests/run-scenarios.sh` (el init nuevo la generó en el fixture) | E1 verde con los 7 archivos | ✅ |
| C3 suite completa | ejecución real | `tests/run-scenarios.sh` tras todos los fixes | `OK: escenarios automatizados (E1-E3)`, exit 0 | ✅ |
| C4 hook + validate | ejecución real | test-hook vía suite; `claude plugin validate .` | `OK: hook`; `✔ Validation passed` | ✅ |
| C4b consistencia con el spec | revisión adversarial del diff | verificador adversarial dedicado | 6 hallazgos → 6 corregidos (iter. 3-4 del diario) → re-verificación verde | ✅ |
| A1 contrato .graph/ aditivo | E1 + diff | suite + revisión | constitution/símbolos aditivos; formatos previos intactos | ✅ |
| A2 gate/reglas sin debilitar | E2/E3 + adversarial | suite + verificador (reconciliaciones textuales añadidas) | E2/E3 verdes; opción (b) de En curso reconciliada con reglas 1/7 | ✅ |
| A3 sin scope creep | diff vs spec | revisión de los 5 grupos + fixes trazados a hallazgos | solo spec + fixes de convergencia registrados en el diario | ✅ |
| A4 docs/ y tooling | git diff --stat + revisión | grep docs/superpowers → 0; symbol-map solo bash/awk/find | política de tooling cumplida | ✅ |

## Resultado
- Estado: convergió
- Evidencia final: suite integrada verde con E1 exigiendo constitution.md y symbol-map con caso adversarial; validate limpio; verificación adversarial cerrada en 6/6.
- Commits: b7931a5 feat: mejoras SOTA r1 — constitution, refutadores diversos, TDD, en-curso, estancamiento objetivo, trazabilidad y symbol-map
- Aprendizajes: (1) la regla dura 1 no se transmitía a subagentes — un explorador ejecutó make-fixtures del repo padre y voló los fixtures anidados: los invariantes deben viajar EN EL PROMPT de cada subagente, no asumirse heredados; (2) los fixtures anidados dentro del repo del plugin son contaminables por exploración hacia arriba — candidato ronda 2: generarlos fuera del árbol; (3) el task record debe reflejar estado transitorio explícito ("en ejecución") o los verificadores lo juzgan como cierre roto; (4) el propio repo del plugin aún no tiene constitution.md ni sección de símbolos en map.md — se generarán en el próximo /graph:init refresh real.
- Preguntas tardías (runtime): ninguna — los bloqueos de la ejecución fueron técnicos (convergencia), no humano-dependientes.
