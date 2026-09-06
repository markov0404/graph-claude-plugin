# GRAPH — Ronda 9: captura de intención por ejemplos ejecutables

**Fecha:** 2026-09-04
**Estado:** Diseño auto-aprobado por delegación; input para `/graph:do`.
**Origen:** re-encuadre del usuario tras el nivel 3 — *"nunca fue un pipeline disciplinado; fue una técnica para capturar la intención de mejor forma, sin excederse en el prompt para no sobrescribir aprendizajes del modelo, pero suficiente para que genere todo de forma inequívoca: desarrollo por ejemplo, la retroalimentación de TDD y SDD"*.

## La tesis (y por qué reemplaza a la anterior)

Ocho rondas se explicaron como "disciplina vs indisciplina". Los mismos datos se explican mejor así: **lo que decide el resultado es si la intención quedó capturada de forma inequívoca y ejecutable.**

| medición propia | lectura vieja | lectura por intención |
|---|---|---|
| r6, secuencia spec-by-test: 20/20 todas las configs | "el proceso no paga" (nulo) | los tests capturaban la intención completa → no faltaba nada que agregar |
| Nivel 3, tareas reales de un repo grande externo: empate | "el diferencial se evapora" | los tests del autor ya capturaban la intención |
| r5, 6 tareas con trampa: 4/12 vs 9/12 (router 11/12) | "GRAPH tiene más disciplina" | las 6 trampas son **huecos de intención**: t5 no dice qué hacer sin credencial; t6 no captura "no rompas al otro consumidor"; t3 admite "hacer pasar el test" como intención alternativa |

Y lo que ganó en r5 no fue la ceremonia sino tres piezas de captura: **mini-spec con criterios y anti-criterios, preflight que expone huecos, y gate**. Bajo este marco, "ablandar un test" no es desobediencia: es **redefinir la intención después de acordada** — y el enforcement (`red.sh`, congelar los ejemplos) pasa a ser *integridad de la intención*, no vigilancia de conducta.

**Evidencia externa convergente (barridas SOTA de este proyecto):** la ambigüedad multiplica la trampa ×10-20 (EvilGenie: 0.7-2% → 22-44%); la subespecificación del target es el predictor #1 de violaciones de alcance (UnderSpecBench); un paso explícito de clarificación da **+8.2pp** en SWE-bench real (ask-vs-assume); quitar la declaración de alcance del prompt multiplica ×2-4 las acciones fuera de alcance (Overeager); **pedirle al agente que escriba más tests mide impacto CERO** (arXiv 2602.07900) y los scaffolds "inteligentes" no le ganan a ReAct pelado en tareas largas (METR). Todo apunta a lo mismo: **el QUÉ inequívoco paga; el CÓMO no paga o resta.**

## El cambio de diseño: el gate aprueba EJEMPLOS, no prosa

Hoy la Fase 1 produce criterios en prosa y el gate aprueba un plan. A partir de r9, para toda tarea cuya intención admita captura ejecutable:

**El agente traduce el pedido a los ejemplos ejecutables que lo capturan, y ESO es lo que se aprueba.**

### Taxonomía de intención capturada (cada pieza con su hogar mecánico)

| pieza | qué es | dónde vive |
|---|---|---|
| **Ejemplo positivo** | el comportamiento pedido, como test que hoy falla | test nuevo (efecto #1) |
| **Anti-ejemplo** | comportamiento vigente que NO debe cambiar | test de caracterización (el refuerzo de r7, ya implementado) |
| **Restricción de alcance** | "no toques X" | `scope` de `tools/red.sh` — mecánico, no es un test |
| **Hueco** | criterio que NO se puede volver ejemplo ejecutable | **pregunta del gate** (ask-vs-assume) |

La cuarta fila es el corazón: **un criterio que no se puede escribir como ejemplo es exactamente un hueco de intención**, y aparece ANTES de escribir código en vez de a mitad de ejecución.

### Flujo

1. **Fase 1 (solo lectura, regla dura 1 intacta):** el agente redacta los ejemplos —código de test, no prosa— y los anti-ejemplos, y lista los huecos que no logró volver ejecutables.
2. **Gate:** la pantalla muestra **el código de los ejemplos** + las restricciones de alcance + las preguntas por cada hueco. Se aprueba eso. `--gate-aprobado` funciona igual (el archivo firma los ejemplos).
3. **Post-gate, efecto #1:** se escriben los ejemplos aprobados y se **verifica que fallan** (RED real, evidencia citada). Un ejemplo aprobado que ya pasa es un error de captura: se reporta, no se sigue.
4. **Ejecución:** el modelo implementa con total libertad de CÓMO. Cero instrucciones de implementación.
5. **Cierre:** `red.sh` verifica que los ejemplos aprobados siguen intactos (integridad de la intención) + suite completa verde + alcance respetado.

### Ruta barata preservada (y esto importa)

Si el eje B del router (r7) ya encuentra oráculo fuerte que cubre el pedido —el caso r6/nivel-3—, **los ejemplos ya existen**: el gate se reduce a *"el oráculo que ya está captura tu pedido: `<tests>` — ¿es eso lo que querés?"* y no se escribe ningún test nuevo. La técnica no agrega costo donde la intención ya estaba capturada; ese es el punto.

### Cuando la intención NO admite ejemplos ejecutables

Documentación, configuración, exploración, decisiones de diseño. Fallback declarado: criterios en prosa con método de verificación (el formato actual), **marcado explícitamente como captura débil** en el record y en `oraculo.md` (huecos conocidos). No se finge que hay oráculo donde no lo hay.

## Cambios de superficie

- `skills/do/SKILL.md`: Fase 1 reescrita (ejemplos, anti-ejemplos, alcance, huecos); Fase 5 (gate) muestra código de ejemplos; Fase 6 con el efecto #1 de ejemplos aprobados + verificación RED obligatoria; el refuerzo de caracterización de r7 se re-encuadra como "anti-ejemplos" (mismo mecanismo, nombre coherente); plantillas de record con la sección **Intención capturada**.
- `skills/init/SKILL.md`: `oraculo.md` gana semántica de "intenciones con captura ejecutable"; los huecos conocidos son el registro de intención no capturada (ya existe la sección — cambia el significado, no el formato).
- `tools/red.sh`: sin cambios de contrato; los ejemplos aprobados entran por el mismo `baseline de red` (r7).
- Sin dependencias nuevas.

## Validación PRE-REGISTRADA (criterios fijados aquí, antes de correr)

Config nueva **E** (gate por ejemplos) sobre el banco de trampas de r5 — que bajo este marco es un **banco de huecos de intención**, exactamente el instrumento correcto.

6 tareas × 2 reps = 12 celdas, contra las referencias ya medidas (A 4/12, B 9/12, R 11/12):

1. **Limpieza:** `Éxito limpio(E) ≥ 9/12` — igualar al pipeline completo.
2. **Costo (la predicción fuerte del marco):** `costo mediana(E) ≤ 0.6 × costo mediana(R)` — si la ceremonia era el envoltorio y la captura era el valor, quitar la ceremonia debe abaratar sin perder limpieza. **Este criterio es el que puede falsar la tesis.**
3. **Captura de huecos (métrica propia del marco):** en t5 (credencial faltante) el hueco debe aparecer como **pregunta del gate** en ≥3/4 de las celdas E de esa tarea, no como implementación improvisada. Y a nivel global: `preguntas tardías(E) ≤ preguntas tardías(R)` — el registro de preguntas tardías ya existe en el record como métrica de calidad del preflight.
4. **No-regresión en el caso limpio:** sobre la secuencia de r6 (donde el oráculo ya captura todo), `costo(E) ≤ 1.3 × costo(A)` — la ruta barata debe seguir siendo barata; si E encarece el caso limpio, el diseño falló.
5. Suite del plugin (E5-E7, test-red, test-oraculo-map) intacta; `plugin validate` verde.
6. Anti-criterios: constitution C1-C5; regla dura 1 (los ejemplos se escriben POST-gate); regla 2 (sin contadores); gate único; contrato de celda r5 sin divergencia; cero deps; corridas fuera del árbol.

**Qué falsaría la tesis:** que E iguale la limpieza de R pero **sin abaratar** (criterio 2). Eso significaría que la ceremonia no era envoltorio sino parte del mecanismo, y habría que revisar el marco entero — no maquillar el resultado.

## Amenazas declaradas

- El banco de r5 lo diseñamos nosotros; el nivel 3 (tareas reales) no tiene huecos de intención porque un repo grande externo los tiene bien capturados — o sea que **E no se puede validar contra tareas reales con este banco**. Pendiente honesto: minar tareas de un repo con tests flojos, donde los huecos abundan.
- La calidad de los ejemplos que el agente redacta es prosa-del-modelo hasta que se ejecutan; el RED obligatorio (paso 3) es lo único que la vuelve verificable, y solo prueba que fallan, no que capturen lo correcto — eso lo valida el humano en el gate, que es el punto del diseño.
- "All Smoke, No Alarm": 80.2% de los tests escritos por agentes tienen oráculo débil. Los ejemplos de E los escribe un agente: **la heurística de fuerza mínima de `oraculo-map.sh` debe correr sobre ellos antes del gate**, y su resultado se muestra en la pantalla.
- N=2 por celda, 1 máquina.

## No-objetivos

Sandbox de SO y tests read-only a nivel sistema (ronda 10 — requiere tocar settings de usuario fuera del repo, decisión del humano); mutation testing como gate (medido caro: 59-96% del pipeline; el diff-scoped queda para r10); generación automática de property-based tests; reemplazar el router de r7 (E vive dentro de él: el eje B decide si hay que capturar o ya está capturado).
