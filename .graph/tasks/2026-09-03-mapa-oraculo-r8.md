# mapa-oraculo-r8 · 2026-09-03 · tier L

## Mini-spec aprobada
- Intención: implementar la ronda 8 — `.graph/oraculo.md` (cobertura de intención acumulativa), `tools/oraculo-map.sh`, escritores (init/Fase 8) y consumidor (eje B con vigencia fail-safe) — y correr la ablación pre-registrada del mapa (t7/t8/t9 × R vs R−m).
- Fuente: docs/superpowers/specs/2026-09-03-graph-mapa-oraculo-ronda-8-design.md (97ce0ec, autoridad vinculante; formato del mapa y criterios de ablación fijados ANTES de correr).
- Criterios (con método): 1) oraculo-map.sh determinista + test propio verde (ejecución); 2) init siembra el mapa completo sobre fixture (0 omisiones, hashes correctos — offline) y refresh migra esquema 3→4 sin pérdida; 3) Fase 8 añade filas y el eje B consulta con vigencia (smoke real + caso dudoso con evidencia de fallback); 4) ablación real 12 celdas: R ruteo correcto ≥5/6, Δ(R vs R−m) reportado tal como salga (Δ≈0 se declara); 5) suite E5-E7 + test-red + hook intactos donde aplique.
- Anti-criterios: constitution C1-C5; el mapa jamás menos seguro que sin mapa (vigencia fail-safe, adversarial); pedidos idénticos; contrato celda r5; cero deps; corridas fuera del árbol; docs históricos intactos.
- Aprobación: delegada ("autoapruebes cualquier spec") + pedido explícito ("vamos con la ronda 8").
- Tier: L — 3 frentes heterogéneos (skills, tool, bench-ablación) + verificación dual + corridas. No forzado.

## Efectos
| # | efecto | inversa | estado |
|---|---|---|---|
| 0 | línea base = HEAD `97ce0ec` (árbol limpio) | restaurar paths tocados con `git restore --source=97ce0ec -- <paths>` y borrar no-rastreados del intento; jamás toca `.graph/` | activo |
| 1 | corridas headless (12 celdas ablación + 3 bakes + smokes) fuera del árbol — gasto real | gasto no reversible; artefactos con sus dirs | activo |

## Diario
| iteración | qué se hizo | diagnóstico | resultado |
|---|---|---|---|
| 1 | Workflow tier L: 3 frentes (skills, tool, bench-ablación) con verificación dual — reglas + riesgo + FAIRNESS, opus | 3/3 rechazados, 28 hallazgos. Los que corrigen el SPEC: la vigencia por hash concatenado era incalculable con verify por-archivo; una fila "fuerte" vigente daba verde SIN leer (menos seguro que sin mapa — reproducido con test JS de 0 asserts marcado fuerte por el tool: README bajo tests/ era fila candidata fuerte); fila sin checks = verdad vacía; el refresh duplicaba/sombreaba filas de tarea; la ablación medía valor ABSOLUTO cuando INDEX/map.md filtran cobertura por otra vía (solo el marginal es interpretable); "siempre pipeline" saturaba el criterio de ruteo sin castigo; pelada-nativa rescatada por la red puntuaba como ruteo correcto. Técnicos: argv > MAX_ARG_STRLEN rompe scan en repos >3500 tests; TAB en nombre corrompe TSV; pytest.raises clasificado débil; SIN_MAPA afectaba a B en silencio | Spec ENMENDADO (b1a9b88): vigencia por archivo, regla de aceleración (el mapa ahorra el descubrimiento, no la mirada), huecos con origen, ablación marginal + 4 celdas de control t1 + pipeline-por-escalación = ruteo incorrecto. Contrato de fix r8 (scratchpad) y 3 fixers en paralelo |

| 2 | Fix round (3/3 sin desviaciones) + spec enmendado (b1a9b88) + verificación integrada + commit c530ba1 + 4 horneados con el init nuevo + regresión E5/E7 | Bug propio de bash en mi script de horneado (`local a=$1 b=...$a...` expande antes de asignar bajo set -u) → separado. Los 4 horneados sembraron oraculo.md y su tabla COINCIDE con el scan real (verify rc=0); tampering → hash cambió (fila dudosa mecánicamente probada). Confound archivado: commands.md del horneado ya decía "notificaciones.py 0%" (t7) y la debilidad del assert (t9) | criterio 1 (mecánicos) verde; evidencia de confound guardada para poder leer el Δ |
| 3 | Ablación real: 16 celdas (3 tareas × 2 reps × 2 brazos + control t1 × 2 × 2) | 3ª interrupción por límite de sesión del proyecto: 7 celdas muertas con api_error → re-corridas completas desde plant. Resultado: **Δ ruteo = 0** (R 5/6, R−m 5/6) y **Δ costo = +$4.49 EN CONTRA del mapa**. La evidencia cualitativa explica por qué: R citó "mapa, fila X, verify rc=0, débil → refuerzo" y R−m concluyó lo mismo leyendo commands.md/C4 — la señal ya estaba en la narrativa (confound declarado ANTES de correr). Colateral de oro: una celda R−m ruteó a pipeline porque "no existe tools/red.sh" — el skill referenciaba los tools por path relativo al repo destino (bug latente también en symbol-map.sh desde r1) | REPORT-R8.md con veredicto honesto; fix de `${CLAUDE_PLUGIN_ROOT}/tools/*` en ambos skills (f1b4e6c) |

## Verificación final
| criterio/anti-criterio | método | comando/procedimiento ejecutado | evidencia | ✅/❌ |
|---|---|---|---|---|
| C1 tool + test | ejecución real | tests/test-oraculo-map.sh (22 casos, adversariales incluidos) | 22/22 verdes; determinismo bajo 2 locales; fail-closed real | ✅ |
| C2 init siembra + migración | ejecución real (4 horneados) + verificación offline | scan real vs tabla sembrada; verify de cada fila; tampering | coincidencia exacta en las 4; verify rc=0; tampering → diag hash cambió | ✅ |
| C3 Fase 8 acumula + eje B consulta | ejecución real (celdas de ablación) | records de evidencia de R | R/t9 cita "mapa, fila ..., verify → rc=0, vigente y débil → refuerzo"; R/t7 "mapa sin fila para notificaciones" | ✅ |
| C4 ablación 12+4 celdas | ejecución real | 16 celdas (7 re-corridas tras límite) + cómputo de Δ | R ruteo 5/6 ✅ (criterio ≥5/6); Δ ruteo 0, Δ costo +$4.49 — reportado sin maquillar en REPORT-R8.md | ✅/⚠️ |
| C5 suite del plugin | ejecución real | E5, E7, test-red, plugin validate | E5 ✅, E7 ✅ (ambas ramas), test-red 15/15, validate ✔ | ✅ |
| A mapa nunca menos seguro / contrato celda / cero deps / fuera del árbol | adversarial + reproducción | lente reglas reprodujo el agujero (fila fuerte sin asserts) → regla de aceleración; fix verificado | 28 hallazgos resueltos por contrato único; corridas en ~/.cache | ✅ |

## Resultado
- Estado: convergió (con la señal medida NEGATIVA y declarada)
- Evidencia final: bench/REPORT-R8.md — **el mapa de oráculo NO mostró valor marginal**: Δ ruteo = 0 (5/6 en ambos brazos) y Δ costo = +$4.49 en contra. Causa medida: la memoria narrativa del horneado (commands.md/INDEX/C4) ya contenía la señal de cobertura, y el brazo sin mapa la leyó. El mecanismo del mapa SÍ funcionó como fue diseñado (consulta + verify de vigencia + decisión citada en el veredicto) — lo que no aportó fue información nueva en repos chicos con `.graph` fresco. Producto colateral más valioso que el titular: primera ejecución REAL del refuerzo de caracterización de r7 (5/6 celdas, ambos brazos) y el bug de paths de tools destapado y corregido.
- Commits: 97ce0ec (spec), b1a9b88 (spec enmendado), c530ba1 (implementación), f1b4e6c (REPORT + fix de paths) — git log --grep "GRAPH-Task: mapa-oraculo-r8"
- Aprendizajes: (1) tercera medición consecutiva de una capa de memoria con resultado 0 (r6 narrativa, r8 mapa): la memoria en repos chicos con contexto que entra completo es overhead, y ninguna estructura la salva — el régimen donde podría pagar (repo grande, memoria envejecida, descubrimiento caro) sigue sin medirse y es LA condición pendiente; (2) la lente FAIRNESS obligó a re-declarar la ablación como MARGINAL antes de correr: sin eso habríamos leído "el mapa no sirve" cuando el dato real es "no agrega sobre lo que ya hay"; (3) los experimentos que no confirman su hipótesis siguen produciendo valor: este destapó un bug de resolución de paths latente desde r1 y ejercitó por primera vez el flujo estrella de r7; (4) mi propio script de horneado tuvo el bug clásico de `local` con expansión adelantada — el orquestador también necesita sus estáticos.
- Amenazas a la validez: las de REPORT-R8.md (N=2, fixtures chicos, confound declarado, 7 celdas re-corridas por la 3ª interrupción de límite de sesión, etiquetado de áreas = prosa del modelo).
- Preguntas tardías (runtime): ninguna.
