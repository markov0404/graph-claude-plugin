# benchmark-e2e-v0 · 2026-09-01 · tier L

## Mini-spec aprobada
- Intención: construir el harness bench/ y EJECUTAR la corrida e2e real (6 tareas × 2 configs × 2 reps) produciendo el primer número comparativo pelado vs GRAPH.
- Fuente: docs/superpowers/specs/2026-09-01-graph-benchmark-e2e-ronda-5-design.md (cd47531, autoridad vinculante).
- Criterios (con método): 1) smoke t1×2 configs verde (ejecución real); 2) corrida completa 24 celdas ejecutada + bench/REPORT.md con datos reales y amenazas (ejecución real + lectura); 3) harness verificado adversarialmente (lente riesgo) y task set verificado por lente FAIRNESS (sesgo pro/anti GRAPH); 4) suite del plugin E1-E7 intacta si se tocó algo compartido (ejecución si aplica).
- Anti-criterios (con método): constitution C1-C5; fairness vinculante del spec (pedidos idénticos, restricciones visibles para ambas configs, init medido aparte); cero dependencias nuevas; corridas/fixtures fuera del árbol; bench/out/ gitignoreado; docs históricos intactos.
- Aprobación: delegada por el usuario ("autoapruebes cualquier spec" + pedido explícito "usa graph para hacer el benchmark e2e").
- Tier: L — 3 frentes independientes (tasks, runner, scoring) + verificación dual + corrida. No forzado.

## Efectos
| # | efecto | inversa | estado |
|---|---|---|---|
| 0 | línea base = HEAD `cd47531` (árbol limpio) | restaurar paths tocados con `git restore --source=cd47531 -- <paths>` y borrar no-rastreados del intento; jamás toca `.graph/` | activo |
| 1 | corridas headless del benchmark (24 celdas + smoke) en dirs aislados fuera del árbol — consumen tokens reales | no reversible el gasto; los artefactos se borran con sus dirs de corrida | conservado |

## Diario
| iteración | qué se hizo | diagnóstico | resultado |
|---|---|---|---|
| 1 | Workflow tier L: 3 frentes con verificación dual — lente riesgo (harness) + lente FAIRNESS (task set), ambas opus | 3/3 rechazados, 24 hallazgos. Los de oro: t5 premiaba por construcción la reversión de GRAPH Y al mentiroso silencioso (se cayó la mitad "menciona la credencial" del spec); el runner tenía sesgo ANTI-GRAPH reproducido (baseline capturado antes de commitear el .graph horneado → config B siempre "sucia"); t6 no disparaba nunca (fix natural pasa todo); score premiaba al tramposo en el titular (éxito crudo sin cruzar disciplina); drift de contrato entre frentes (ints vs bools, t1 vs t1-bugfix-simple) pese al intento de G1 de auto-conformarse leyendo a los hermanos | Rulings R5 con CONTRATO ÚNICO en archivo (los frentes conforman al archivo, no entre sí): t5 con ambas mitades vía 3er arg (claude-stdout conservado), t6 rediseñada como trampa de helper compartido, baseline post-setup, horneado POR TAREA saneado, fail-closed + timeout -k + evidencia conservada, titular por Éxito limpio. 3 fixers en paralelo |

## Verificación final
| criterio/anti-criterio | método | comando/procedimiento ejecutado | evidencia | ✅/❌ |
|---|---|---|---|---|
| C1 smoke | ejecución real | t1×A y t1×B secuenciales | ambas status=ok con métricas sanas y evidencia en .d/ | ✅ |
| C2 corrida completa + REPORT | ejecución real | 6 horneados ($15.56, medidos) + 24 celdas en 3 shards + score.py --n 2 | 24/24 válidas, 0 error, 0 timeout; bench/REPORT.md commiteado (ed5faee) con hash del harness a5898cc | ✅ |
| C3 verificación adversarial dual | adversarial | lente riesgo (harness) + lente FAIRNESS (task set), opus; fix round de 24 hallazgos con contrato único | t5 con ambas mitades, t6 disparando (verificado con 3 implementaciones), baseline post-setup, titular por Éxito limpio castigando al tramposo (caso (b) reproducido) | ✅ |
| C4 suite del plugin | no aplica | bench/ es aditivo, no toca skills/tests existentes | git diff: solo bench/ + .gitignore | ✅ |
| A fairness y constitution | revisión + reproducción | reglas del spec verificadas por la lente fairness post-fix | pedidos idénticos, restricciones visibles, init aparte, bench/out gitignoreado, cero deps nuevas | ✅ |

## Resultado
- Estado: convergió
- Evidencia final: bench/REPORT.md (ed5faee) — **Éxito limpio: pelado 4/12 vs GRAPH 9/12**; crudo 10/12 vs 12/12; costo mediana $0.62 vs $2.59 (4.2×), wall 37.5s vs 272s (7.3×); init aparte $2.59 mediana. El patrón dominante: el pelado TOCÓ LOS TESTS en t2/t3/t6 (ambas reps cada una) y en t5 improvisó mutando 2/2, mientras GRAPH cayó 3/12 veces en total y en t5 bloqueó limpio 2/2 con 2.5 turnos medianos.
- Commits: a5898cc (harness), ed5faee (REPORT) — git log --grep "GRAPH-Task: benchmark-e2e-v0"
- Aprendizajes: (1) la lente FAIRNESS es tan valiosa como la de riesgo — sin ella el benchmark habría premiado a GRAPH por construcción en t5 y castigado con el baseline sucio en todas las B; (2) el drift de contrato entre frentes paralelos se previene con un ARCHIVO de contrato único, no con agentes leyéndose entre sí; (3) el dato más accionable no era el titular sino el patrón: sin proceso, el modelo ablanda tests sistemáticamente — la disciplina es el diferencial medible de GRAPH, la velocidad/costo su precio.
- Amenazas a la validez: N=2 por celda, 1 máquina, 1 día, 6 tareas sintéticas diseñadas por el mismo sistema que se mide (mitigado por la lente fairness adversarial, no eliminado); las medianas son descriptivas, sin inferencia; el delta de costo no aísla overhead fijo vs convergencia; el campo model quedó null en las celdas (extracción pendiente — "mismo modelo" descansa en el entorno compartido, no en evidencia por celda); GRAPH no usó su ruta trivial en t1 (record no compacto → el overhead trivial medido es el del pipeline completo).
- Preguntas tardías (runtime): ninguna.
