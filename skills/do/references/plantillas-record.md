# Plantillas del task record

Este archivo se lee en la Fase 6 de `SKILL.md` (Ejecución), en el momento
de crear el task record — si todavía no existe — eligiendo la plantilla
que corresponda: **completa** (pipeline normal, tier S/M/L), **compacta de
ruta trivial** (Fase 4 marcó ruta trivial y la pieza única no generó
efecto #1), o **compacta de ruta pelada-con-red** (la Fase 0.5 habilitó
esa ruta). La Fase 6 de `SKILL.md` ya describe cuál corresponde a cada
caso; este archivo solo trae el contenido de cada una — en `conocido` o
`inexplorado` por igual, salvo que `inexplorado` agrega su propia sección
`## Exploración` al record (`references/exploracion.md`, no aquí).

## Plantilla del task record

```markdown
# <slug> · <YYYY-MM-DD> · tier <S|M|L>

## Mini-spec aprobada
- Intención:
- Alcance ejecutable (scope de `tools/red.sh`):
- Anti-criterios de constitution (C-N):
- Router (Fase 0.5):
  - huecos=<verde|rojo> — <evidencia>
  - oráculo=<verde|rojo> — <"mapa, fila <área>, vigente" | "mapa sin cobertura del área → inspección fresca: <evidencia>" | "reforzado por caracterización: <qué se congeló>">
  - consecuencia=<baja|alta> — <evidencia>
  - régimen=<conocido|inexplorado> — <"conocido (default)" | "conocido (sugerido inexplorado: <señales> — no activado)" | "inexplorado — declarado vía <--explorar|archivo|pedido>">
- Tier: <elegido|forzado> — porqué:
- Aprobación: <gate interactivo | aprobado por archivo `<ruta>`>

## Intención capturada
- Ejemplos positivos (código → efecto #1): <archivo(s) + qué expresan> — RED verificado: <evidencia>, o "sin ejemplos — 100% fallback"
- Anti-ejemplos (código de caracterización → efecto #1): <archivo(s) + qué protegen> — GREEN verificado: <evidencia>, o "ninguno — área nueva"
- Restricciones de alcance: <ver Alcance ejecutable arriba>
- Huecos y cómo se resolvieron: <hueco → pregunta del gate → respuesta que lo cerró, uno por línea>, o "ninguno"
- Piezas en fallback (captura débil, si hubo): <criterio en prosa + método> — quedan también en `.graph/oraculo.md`, "Huecos conocidos"

## Exploración (SOLO si régimen=inexplorado — en `conocido` esta sección NO EXISTE en el record, ni el heading; plantilla completa en `references/exploracion.md`)

## Efectos
| # | efecto | inversa | estado |
|---|---|---|---|

(estado ∈ `activo` · `revertido` · `conservado` · `irreversible`)

## Diario
| iteración | qué se hizo | diagnóstico | resultado |
|---|---|---|---|

(régimen `inexplorado`: cada fila suma la columna obligatoria — `criterio de refutación preregistrado: <cita> → ¿se cumplió? sí/no + evidencia`, r10 §5 — sin esa celda la iteración no está registrada)

## Verificación final
| criterio/ejemplo/anti-ejemplo | método | comando/procedimiento ejecutado | evidencia | ✅/❌ |
|---|---|---|---|---|

## Resultado
- Estado: en ejecución (transitorio, solo mientras la Fase 6-7 corre) | convergió | abortado por usuario | cerrado por bloqueo (pre-aprobado) | reescopado
- Evidencia final:
- Amenazas a la validez: <qué se midió y qué no; evidencia de corrida única vs repetida; entorno único; qué quedó sin comparación controlada>
- Anomalías pendientes: <ninguna | n — qué se esperaba/qué se observó/dónde, una por línea>
- Commits: <hash-corto> <subject> (uno por línea) | ninguno
- Aprendizajes:
- Preguntas tardías (runtime): <ninguna | cuáles y por qué el preflight no las vio>
```

## Plantilla compacta (ruta trivial, tier S — Fase 4)

Mismas secciones del contrato, colapsadas a ~10 líneas de contenido. Aplica
SOLO si Fase 4 marcó ruta trivial Y ADEMÁS la pieza única NO generó efecto
#1 (fue 100% fallback en prosa, o la intención ya estaba capturada por un
oráculo existente — r9, ver Fase 6 "Efecto #1"): la tabla Efectos lleva
SIEMPRE una sola fila, la `#0`. **Si la pieza única terminó siendo un
ejemplo positivo NUEVO** (con efecto #1 real), la tarea sigue siendo "ruta
trivial" a efectos del gate de un párrafo (Fase 5), pero el record usa la
**plantilla completa de tier S** de más arriba, no esta — el efecto #1 (RED
verificado + baseline de red) no entra en el presupuesto de líneas de este
formato. Cualquier otro caso (dos o más piezas, preguntas de preflight o
Huecos, o dos o más archivos) también usa la plantilla completa. El resto
del contrato es idéntico: mismo esquema `.graph/` y mismas fases 7-8
(evidencia real, cierre que limpia `En curso`/`.lock`, nunca "ninguna" sin
justificar en amenazas a la validez).

```markdown
# <slug> · <YYYY-MM-DD> · tier S (ruta trivial)

## Mini-spec aprobada
- Intención/alcance: <intención en una frase — qué entra/fuera si aplica>
- Router (Fase 0.5):
  - huecos=<verde|rojo> — <evidencia>
  - oráculo=<verde|rojo> — <"mapa, fila <área>, vigente" | "mapa sin cobertura del área → inspección fresca: <evidencia>" | "reforzado por caracterización: <qué se congeló>">
  - consecuencia=<baja|alta> — <evidencia>
- Tier: S <elegido|forzado> — <porqué en media frase>
- Criterio (sin ejemplo nuevo — sin efecto #1): <el criterio en prosa con método, si fue fallback> | <cita del oráculo existente que ya lo cubre: archivo + comando>
- Anti-ejemplo: ninguno — área nueva | ya caracterizado por <archivo existente>
- Huecos: <ninguno — ruta trivial exige cero, o no habría sido ruta trivial>
- Anti-criterios (C-N) · Aprobación: <anti-criterios en una línea citando C-N> · <gate interactivo | aprobado por archivo `<ruta>`>

## Efectos
| # | efecto | inversa | estado |
|---|---|---|---|
| 0 | base git (`stash create`/`HEAD`) — también baseline de red (sin efecto #1) | restaurar paths + borrar no-rastreados (excluye `.graph/`) | activo |

## Diario
| iteración | qué se hizo | diagnóstico | resultado |
|---|---|---|---|
| 1 | <qué se hizo> | <diagnóstico, o "sin fallos"> | <resultado> |

## Verificación final
| criterio/ejemplo/anti-ejemplo | método | comando/procedimiento ejecutado | evidencia | ✅/❌ |
|---|---|---|---|---|
| <criterio + anti-criterios> | <método del criterio, incluye `tools/red.sh` para integridad> | <comando(s) ejecutado(s)> | <output real citado — criterio y JSON de `red.sh`> | ✅ |

## Resultado
- Estado: en ejecución (transitorio) | convergió | abortado por usuario | cerrado por bloqueo (pre-aprobado) | reescopado
- Evidencia final (con amenazas a la validez, breve): <resumen>
- Anomalías pendientes: ninguna | <n — qué se esperaba/qué se observó/dónde>
- Commits: <hash-corto> <subject> (uno por línea) | ninguno
- Aprendizajes: <resumen>
- Preguntas tardías (runtime): ninguna | <cuáles y por qué el preflight no las vio>
```

## Plantilla compacta (ruta pelada-con-red — Fase 0.5)

Mismas secciones del contrato, colapsadas a ≤22 líneas de contenido (bullets de
Mini-spec + filas de datos de Efectos/Diario/Verificación final + bullets de
Resultado; el diario se mantiene en 1-4 filas). Aplica SOLO si la Fase 0.5 habilitó la ruta
pelada-con-red (los tres ejes en verde/baja); cualquier otro caso usa la plantilla completa
o la compacta de ruta trivial de arriba. El resto del contrato es idéntico: mismo esquema
`.graph/`, mismas fases 7-8 (evidencia real, cierre que limpia `En curso`/`.lock`, nunca
"ninguna" sin justificar en amenazas a la validez). La Verificación final es el JSON de
`tools/red.sh` más UNA sola fila de anti-criterios (TODAS las C-N juntas en esa fila —
NUNCA una fila por C-N: eso es de la plantilla completa), volcado a la misma tabla de 5
columnas que las
demás plantillas. Si el gate declaró refuerzo de caracterización, la tabla Efectos suma la
fila `| 1 | tests de caracterización (anti-ejemplos) escritos y verificados GREEN — baseline
de red = <hash> | borrarlos | activo |` (pasa a `conservado` al cerrar, converja o escale —
ver "Escalación por criterios" en `references/escalacion-y-presupuesto.md`); si NO hubo refuerzo, la fila `#0` declara explícitamente
`— también baseline de red` (ver "Ruta pelada-con-red", punto 3).

```markdown
# <slug> · <YYYY-MM-DD> · ruta pelada-con-red

## Mini-spec aprobada
- Pedido: <el pedido tal cual>
- Router (Fase 0.5):
  - huecos=verde — <evidencia>
  - oráculo=verde — <"mapa, fila <área>, vigente" | "mapa sin cobertura del área → inspección fresca: <evidencia>" | "reforzado por caracterización: <qué se congeló>">
  - consecuencia=baja — <evidencia>
- Gate: `ruta pelada — oráculo: <comando+alcance>, scope: <archivos/área>, consecuencia baja` · anti-criterios (C-N): <cita las C-N aplicables> · escalación: si la red detecta suciedad → reinicio limpio, mismo pedido/criterios/scope (esta aprobación cubre ambas rutas) · Aprobación: <gate interactivo | aprobado por archivo `<ruta>`>

## Efectos
| # | efecto | inversa | estado |
|---|---|---|---|
| 0 | base git (`stash create`/`HEAD`) — también baseline de red si no hubo efecto #1 | restaurar paths + borrar no-rastreados (excluye `.graph/`) | activo |

## Diario
| iteración | qué se hizo | diagnóstico | resultado |
|---|---|---|---|
| 1 | <qué se hizo> | <diagnóstico, o "sin fallos"> | <resultado> |

## Verificación final
| criterio/anti-criterio | método | comando/procedimiento ejecutado | evidencia | ✅/❌ |
|---|---|---|---|---|
| tests_intactos | `tools/red.sh` — diff vs baseline de red sobre paths de test/conftest/fixtures | `tools/red.sh` | <valor JSON `tests_intactos`> | ✅ |
| suite_verde | `tools/red.sh` — comando verificado de `commands.md`, suite completa | `tools/red.sh` | <valor JSON `suite_verde`> | ✅ |
| scope_respetado | `tools/red.sh` — archivos tocados ⊆ scope del gate | `tools/red.sh` | <valor JSON `scope_respetado`> | ✅ |
| oraculo_independiente | `tools/red.sh` — tests nuevos de la sesión registrados, no sustituyen la suite previa | `tools/red.sh` | <valor JSON `oraculo_independiente`> | ✅ |
| anti-criterios (C-N) | revisión del diff/scope contra cada C-N citada arriba | inspección del diff final | <intactos — o detalle de la excepción> | ✅ |

## Resultado
- Estado: en ejecución (transitorio) | convergió | escalado a pipeline completo (reinicio limpio) | abortado por usuario | cerrado por bloqueo (pre-aprobado)
- Escalación: ninguna | sucio (<tests tocados|suite roja|scope violado>) → reinicio limpio, ver sección "## Escalación a pipeline completo" más abajo en este mismo record | fricción menor (no escaló): <qué>
- Evidencia final (con amenazas a la validez, breve): <resumen>
- Anomalías pendientes: ninguna | <n — qué se esperaba/qué se observó/dónde> (obligatorio: regla dura 8 y Fase 8 lo exigen en TODO record, también en el compacto)

**Esta plantilla es CERRADA.** Los bullets de Resultado de arriba son exactamente los
que van: ni uno más. En particular las amenazas a la validez van DENTRO de `Evidencia
final`, nunca como bullet aparte, y la tabla de Verificación final lleva 6 filas (los 4
flags de `red.sh` + el criterio del pedido + UNA de anti-criterios). No copies secciones
ni bullets de la plantilla completa de arriba: si el caso los necesita, entonces no era
ruta pelada y corresponde la plantilla completa.
- Commits: <hash-corto> <subject> (uno por línea) | ninguno
- Aprendizajes: <resumen>
- Preguntas tardías (runtime): ninguna | <cuáles y por qué el preflight no las vio>
```
