Índice vivo — no es registro histórico; se actualiza.

# docs/superpowers — índice de specs y planes

Este índice cubre los documentos de diseño de `docs/superpowers/`. A diferencia
de los documentos que enlaza (protegidos por C3 de `.graph/constitution.md`:
"registro histórico: specs y planes no se editan retroactivamente"), este
README queda exento por la propia aclaración de C3 ("su README índice es
vivo y sí se actualiza"): la tabla se actualiza cada vez que una tarea GRAPH
implementa o supera un spec, obligación que impone la Fase 8 de `do` (C3
permite la excepción; no es C3 quien la exige).

Estados posibles: **vigente** (autoridad activa, aún no implementada del
todo o es la referencia corriente) · **implementada** (su contenido ya vive
en el código/skills, el documento queda como archivo) · **superada**
(reemplazada por un diseño posterior) · **histórica** (documento de proceso,
no de diseño vigente).

La columna `notas` es una adición deliberada al formato mínimo
`| spec/plan | estado |`: aporta contexto de trazabilidad por fila sin
alterar el vocabulario de estados.

| documento | estado | notas |
|---|---|---|
| [`specs/2026-08-31-graph-plugin-design.md`](specs/2026-08-31-graph-plugin-design.md) | superada | Diseño original del plugin. Superada por las rondas 1-3 (`graph-mejoras-sota-design.md`, `graph-mejoras-ronda-2-design.md`, `graph-robustez-ronda-3-design.md`) en todo lo que tocan sobre `.graph/` y los skills `init`/`do`; el resto (propósito, arquitectura general) sigue siendo la referencia de origen. |
| [`plans/2026-08-31-graph-plugin.md`](plans/2026-08-31-graph-plugin.md) | histórica | Plan de implementación tarea-a-tarea del diseño original. Documento de proceso ya ejecutado; se conserva como historial. |
| [`specs/2026-08-31-graph-mejoras-sota-design.md`](specs/2026-08-31-graph-mejoras-sota-design.md) | implementada | Ronda 1: mejoras tomadas del estado del arte (Superpowers, Spec Kit, Aider, OpenHands, PoLL/ChatEval, CCPM). Ya incorporada a los skills. |
| [`specs/2026-08-31-backlog-ronda-2.md`](specs/2026-08-31-backlog-ronda-2.md) | implementada | Backlog de dos ideas (efectos+inversa, threats-to-validity) que dio origen a la ronda 2; ambas ya especificadas e implementadas en `graph-mejoras-ronda-2-design.md`. |
| [`specs/2026-08-31-graph-mejoras-ronda-2-design.md`](specs/2026-08-31-graph-mejoras-ronda-2-design.md) | implementada | Ronda 2: ledger de efectos con inversa explícita, honestidad metodológica, fixtures fuera del árbol. Ya incorporada a los skills. |
| [`specs/2026-08-31-graph-robustez-ronda-3-design.md`](specs/2026-08-31-graph-robustez-ronda-3-design.md) | implementada | Ronda 3: los 5 riesgos altos de robustez operacional (gate pre-aprobado + convergencia determinista, retomar tarea interrumpida, lock de concurrencia, defensa de `.graph/` con esquema versionado, este mismo índice vivo). Implementada por la tarea GRAPH robustez-r3 (E4 verde end-to-end). |
| [`specs/2026-08-31-graph-evidencia-dieta-ronda-4-design.md`](specs/2026-08-31-graph-evidencia-dieta-ronda-4-design.md) | implementada | Ronda 4: evidencia determinista E5-E7 (bloqueo sin firma, retomar+lock, presupuesto con ambas ramas ejercitadas) + dieta de ceremonia (prosa de efectos, constitution solo líneas rojas C1-C5, ruta trivial S con record compacto, cascada de refutación). Implementada por la tarea GRAPH evidencia-dieta-r4. |
| [`specs/2026-09-01-graph-benchmark-e2e-ronda-5-design.md`](specs/2026-09-01-graph-benchmark-e2e-ronda-5-design.md) | implementada | Ronda 5: benchmark e2e v0 corrido de verdad — REPORT en bench/REPORT.md: Éxito limpio pelado 4/12 vs GRAPH 9/12; costo 4.2×, wall 7.3×. Implementada por la tarea GRAPH benchmark-e2e-v0. |
| [`specs/2026-09-02-graph-benchmark-nivel2-ronda-6-design.md`](specs/2026-09-02-graph-benchmark-nivel2-ronda-6-design.md) | implementada | Ronda 6: benchmark nivel 2 corrido de verdad — secuencia encadenada de 5 pasos, 4 configs (A, A-R K=3, B memoria, C amnésico), REPORT en bench/seq/REPORT-NIVEL2.md: 20/20 limpias, horizonte de CPEL no cruza en 5 pasos, memoria B−C = 0 en éxito y +$2.10 en costo, A-R mediana 1 intento. Implementada por la tarea GRAPH benchmark-nivel2. |
| [`specs/2026-09-03-graph-router-ronda-7-design.md`](specs/2026-09-03-graph-router-ronda-7-design.md) | implementada y validada (veredicto partido) | Ronda 7: router objetivo (3 ejes validados: huecos/oráculo/consecuencia — no "dificultad") + ruta pelada-con-red (ejecución directa + tools/red.sh determinístico) + escalación con reinicio limpio. Fundada en r5+r6 propios y SOTA 2026 (E3, R2V-Agent, SpecBench, EvilGenie, All Smoke No Alarm, clean-restart dominance). Validación pre-registrada: config R sobre ambos benchmarks — RESULTADO en bench/REPORT-R7.md: 11/12 limpio en r5 (supera a B 9/12) con t5 bloqueada limpia y 0 sobre-escalaciones ✅; CPEL 3.40× en la secuencia limpia → criterio ≤1.5× FALLÓ ❌ (la ruta pelada disciplina mejor pero no abarata); hallazgo TOCTOU convertido en regla del skill. |
| [`specs/2026-09-03-backlog-ronda-8.md`](specs/2026-09-03-backlog-ronda-8.md) | idea anotada | Semilla de ronda 8: mapa de oráculo — cobertura de intención (spec⇄tests) acumulada en `.graph/` como señal de ruteo; el primer caso de uso donde la memoria tendría retorno demostrable (re-medible con la ablación B/C). Precondición: que r7 valide. |
