# GRAPH — Ronda 4: evidencia determinista + dieta de ceremonia

**Fecha:** 2026-08-31
**Estado:** Diseño aprobado en brainstorming; input para `/graph:do` sobre este repo.
**Origen:** amenazas a la validez declaradas en el cierre de robustez-r3 (maquinaria verificada pero no ejercitada) + los 4 ítems de ceremonia del análisis arquitectónico multi-lente.
**Autorización explícita del usuario:** la deduplicación de `constitution.md` (R4-B2) está firmada en este spec — única vía por la que el sistema puede editarla.

## Bloque A — Evidencia determinista (E5, E6, E7)

Tres escenarios headless nuevos en la suite (scripts hermanos de `e4-convergencia.sh`, invocados desde `run-scenarios.sh` tras E4; mismos patrones: FIXDIR, precheck, aserciones de ARTEFACTOS, mensajes `FAIL E<N>:`/`OK`):

**R4-A1 — E5, bloqueo por pregunta sin firmar.** Fixture con un pedido que fuerza una decisión abierta deliberada (p.ej. dos maneras válidas y excluyentes de cumplirlo, sin criterio para elegir) + archivo de gate con `pedido:` coincidente y `apruebo: sí` pero SIN respuestas. Aserciones: NO existe task record nuevo, `git status` limpio (fuera de `.graph/` preexistente), no existe `.graph/.lock`, y la salida contiene la pantalla del gate (el sistema presentó y terminó). Prueba la regla taxativa "pregunta sin respuesta firmada = bloqueo".

**R4-A2 — E6, retomar + lock.** Plantar estado interrumpido en el fixture: task record parcial (Mini-spec + Efectos con #0 + Diario con exactamente 1 fila plantada reconocible), línea `**En curso:**` en su INDEX y `.graph/.lock` huérfano del mismo slug. Correr `/graph:do --gate-aprobado` con la MISMA tarea. Aserciones: la fila plantada del Diario SOBREVIVE textualmente (no se pisó el record); existe una fila que contiene "retomada tras interrupción"; al cierre no queda `.lock` ni línea `En curso`. Variante en el mismo script: con `.lock` de un slug AJENO y sin archivo de gate, una invocación headless de otra tarea → reporta el lock y termina sin crear record ni mutar. Prueba retomar (R3-2) y lock (R3-3).

**R4-A3 — E7, presupuesto agotado en modo pre-aprobado.** Gate file con `budget:` deliberadamente ínfimo para una tarea que no puede completarse con ese tope. Aserciones: el task record existe y su Estado es `cerrado por bloqueo (pre-aprobado)`; la tabla Efectos no tiene efectos en estado `activo`; no queda `.lock` ni `En curso`; el proceso terminó (exit) sin colgarse. Prueba el enum nuevo y el cierre limpio (R3-1/R-C/R-D).

Los tres toleran variación de prosa del modelo y son estrictos en artefactos. `tests/scenarios.md` se actualiza: I2/I3/I5 pasan a nota "cubierto en su variante determinista por E5/E6/E7; la versión interactiva queda para validar UX".

## Bloque B — Dieta de ceremonia

**R4-B1 — Prosa de efectos a dieta.** En `skills/do/SKILL.md`: compactar la prosa del ledger de efectos (~15 líneas entre Fase 6 y reglas asociadas) a aproximadamente la mitad SIN cambiar semántica alguna (mismos mecanismos: #0, extra-git, LIFO, marcas transitorias, cierres); la plantilla permite que una tabla Efectos con solo el #0 se escriba con la fila única y sin nota adicional. Prohibido tocar el comportamiento — es refactor de texto; el verificador debe poder mapear 1:1 cada regla vieja a la nueva.

**R4-B2 — Deduplicación constitution/conventions (FIRMADA).** `constitution.md` queda solo con líneas rojas NO-relajables que no son convención de estilo: se conservan (renumeradas) las actuales C4 (contrato aditivo/nodos protegidos), C5 (política de tooling), C7 (docs históricos + índice vivo) y C8 (trailer), y se añade como línea roja el no-truncado ("la información nunca se trunca ni se pierde: compresión solo estructural"). C1 (gate/subagentes), C2 (sin contadores), C3 (español) y C6 (evidencia) YA están en conventions.md con más detalle: se eliminan de constitution dejando en su encabezado la nota "las convenciones operativas viven en conventions.md; esto son solo las líneas rojas". `skills/do/SKILL.md` Fase 1 no cambia (sigue citando C-N de lo que exista). `decisions.md` registra la deduplicación citando este spec.

**R4-B3 — Ruta trivial para tier S.** En `skills/do/SKILL.md`: cuando la clasificación da S con UN solo criterio y UN solo archivo implicado, el gate se presenta como UN párrafo (pedido entendido + criterio con método + anti-criterios en una línea citando constitution + "¿apruebas?") y el task record usa el formato compacto: mismas secciones del contrato pero colapsadas (~10 líneas: mini-spec en 3 líneas, Efectos solo la fila #0, Diario 1 fila, Verificación final 1 fila, Resultado 4 líneas). El formato compacto se define con plantilla literal en el skill. Tareas S que no cumplan la condición (más de un criterio o archivo) usan el flujo normal.

**R4-B4 — Cascada de refutación.** En `skills/do/references/workflow-templates.md` (reglas comunes + plantilla 3) y la frase correspondiente del Tier L en `skills/do/SKILL.md`: la refutación multi-lente con 3 modelos queda SOLO para hallazgos de severidad alta o que toquen reglas duras/gate/contrato `.graph/`; el resto pasa primero por UN refutador barato (lente correctitud) y solo si lo sostiene va a la lente riesgo (modelo capaz). El voto por mayoría se mantiene donde aplican las 3 lentes.

## No-objetivos

- Micro-benchmark y modo benchmark completo: ronda futura (E5-E7 no son benchmark, son tests del sistema).
- Tocar E1-E4 existentes (salvo la línea de invocación en run-scenarios y el eco final a E1-E7).
- Cualquier cambio de semántica en efectos/convergencia (B1 es solo prosa).

## Verificación del conjunto

1. E5, E6 y E7 en verde por ejecución real; suite completa E1-E7 exit 0; test-hook y test-symbol-map intactos; validate.
2. B1: verificación adversarial con mapeo 1:1 regla-vieja→regla-nueva (nada semántico perdido).
3. B2: constitution resultante = solo líneas rojas, conventions cubre TODO lo removido (diff cruzado); decisions registra la firma.
4. B3: E-verificación barata — correr un `/graph:do --gate-aprobado` de tarea S trivial en fixture y assertar que el record resultante usa el formato compacto (≤ ~15 líneas) — puede integrarse como caso dentro de E7 o escenario E8 mínimo, a criterio del implementador con aprobación del verificador.
5. Anti-criterios: reglas duras y gate intactos; contrato `.graph/` compatible (el formato compacto usa las MISMAS secciones); sin truncado jamás; español; cero dependencias; docs históricos intactos; índice vivo actualizado al cierre.
