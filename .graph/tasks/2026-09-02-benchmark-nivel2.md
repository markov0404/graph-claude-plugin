# benchmark-nivel2 · 2026-09-02 · tier L

## Mini-spec aprobada
- Intención: construir y EJECUTAR el benchmark nivel 2 — secuencias de 5 pasos, 4 configs (A, A-R reintentos K=3, B memoria, C amnésico congelado), checkpoint canónico, curvas CPEL con horizonte de cruce y señal de memoria B−C.
- Fuente: docs/superpowers/specs/2026-09-02-graph-benchmark-nivel2-ronda-6-design.md (9d86fd1, autoridad vinculante).
- Criterios (con método): 1) refs de los 5 pasos pasan la suite acumulada offline; 2) smoke P1×{A,B} verde (ejecución real); 3) corrida completa 4 configs × 5 pasos con REPORT-NIVEL2.md real commiteado (ejecución real); 4) adversarial dual: riesgo (runner/score) + FAIRNESS (secuencia, feedback A-R); 5) fix del campo model aplicado también a run-bench.sh.
- Anti-criterios (con método): constitution C1-C5; contrato de celda de ronda 5 sin divergencia; corridas fuera del árbol; out/ gitignoreados; cero deps; pedidos idénticos entre configs; docs históricos intactos.
- Aprobación: delegada por el usuario ("autoapruebes cualquier spec" + pedido explícito del nivel 2 con horizonte y reintentos).
- Tier: L — 3 frentes heterogéneos + corrida. No forzado.

## Efectos
| # | efecto | inversa | estado |
|---|---|---|---|
| 0 | línea base = HEAD `9d86fd1` (árbol limpio) | restaurar paths tocados con `git restore --source=9d86fd1 -- <paths>` y borrar no-rastreados del intento; jamás toca `.graph/` | activo |
| 1 | corridas headless del nivel 2 (~25 sesiones) fuera del árbol — gasto real de tokens | gasto no reversible; artefactos con sus dirs | activo |

## Diario
| iteración | qué se hizo | diagnóstico | resultado |
|---|---|---|---|
| 1 | Workflow tier L: 3 frentes (secuencia, runner, scoring) con verificación dual — FAIRNESS (secuencia/feedback) + riesgo (runner/score), ambas opus | 3/3 rechazados, 18 hallazgos, la mayoría reproducidos e2e. Los de oro: el criterio de no-duplicación de P3 era un grep de texto disfrazado de AST (falso positivo por un comentario, falso negativo ante la duplicación inline más natural); el feedback de A-R filtraba el oráculo del check (archivo:función a arreglar) que B/C no ven; el revert de A-R bajo `set -e` mataba la secuencia entera si fallaba y `git clean -fdx` no borra repos anidados; la mitad "tests fallidos" del feedback salía siempre vacía (pytest a /dev/null); score-seq perdía de la curva el costo de celdas con contrato roto (fail-open) y afirmaba "en 5 pasos" con menos pasos medidos | Rulings r6 con CONTRATO ÚNICO (scratchpad r6-contrato.md): criterio P3 por AST real con 4 casos obligatorios; stderr con líneas `tests_fallidos:`/`diag:` y feedback fijo de 3 líneas SOLO de flags+tests; re-plant fresco por intento (elimina la clase entera de bugs de revert); pre-flight de los 5 pasos antes de pagar celdas; P5 sin enumerar módulos y exigiendo el identificador exacto; score con glob fijo, costo que siempre suma y horizonte sobre pasos medidos. 3 fixers en paralelo |
| 2 | Fix round cerrado (3/3 sin desviaciones, evidencia con stubs) + verificación integrada del orquestador (pasos reales × runner real) + harness commiteado (87be8e6) + horneado ($1.96/173s) + smokes P1×A y P1×B con claude real | La integrada cazó: (a) checks tomaban solo `^FAILED` de pytest — un árbol sin solución falla en colección (`ERROR`) y el feedback habría dicho "ninguno" con todo rojo (parcheado en los 5, ambas ramas revalidadas); (b) residuo SOLUCION_OK de un stub en la raíz del repo (borrado). Smoke A verde ($0.59, 38s, campo model=claude-fable-5 ✓ — amenaza v0 cerrada). Smoke B: mecánica completa OK (horneado inyectado, graph-vivo arrastrado con record nuevo) pero limpio=false por mutación: B diagnosticó que el entrypoint `pytest` no pone rootdir en sys.path y creó un conftest.py defendible que el check castiga — trampa de ENTORNO no diseñada que ensuciaría todas las configs | `pythonpath = .` en los 6 pytest.ini de la cadena (fix estructural neutral, 5f600c7); cadena p1..p5 revalidada con ambos entrypoints; re-horneado sobre la base corregida y smoke B repetido |

## Verificación final
| criterio/anti-criterio | método | comando/procedimiento ejecutado | evidencia | ✅/❌ |
|---|---|---|---|---|
| C1 refs offline | ejecución real | cadena p1..p5 encadenada (plant + ref + suite acumulada), corrida 3 veces (impl, verificador, post-fix) | 5/10/14/18/22 tests verdes y 4 booleanos ok por eslabón; revalidada tras pythonpath (ambos entrypoints) | ✅ |
| C2 smoke P1×{A,B} | ejecución real | run-seq A y B con claude real, PASOS=1 | A limpio $0.59/38s; B limpio $2.31/218s (tras fix de fixture); campo model=claude-fable-5 presente | ✅ |
| C3 corrida completa + REPORT | ejecución real | full-run 4 configs × 5 pasos + reanudación DESDE=4 post-límite + score-seq | 20/20 celdas limpias, 0 error de contrato; bench/seq/REPORT-NIVEL2.md (c224097) con hash harness ae6c776 | ✅ |
| C4 adversarial dual | adversarial | lente FAIRNESS (secuencia/feedback) + riesgo (runner/score), opus; fix round con contrato único r6 | 18 hallazgos, 3 fixers sin desviaciones + verificación integrada del orquestador (2 hallazgos extra: ERROR de colección, residuo de stub) | ✅ |
| C5 fix campo model | ejecución real | modelUsage fallback en run-bench.sh y run-seq.sh | celdas reales con model=claude-fable-5 | ✅ |
| A contrato r5 / fuera de árbol / gitignore / cero deps / pedidos idénticos | revisión + reproducción | check.sh 3 args + 4 booleanos verificado por lentes; corridas en ~/.cache y scratchpad; bench/seq/out/ y __pycache__/ ignorados; stdlib+bash | git status limpio post-corrida; pedidos byte-idénticos entre configs (mismos archivos) | ✅ |

## Resultado
- Estado: convergió
- Evidencia final: bench/seq/REPORT-NIVEL2.md (c224097) — **20/20 celdas limpias en las 4 configs**. CPEL a P5: A $0.89 / A-R $0.86 / B $3.26 / C $2.84. **Horizonte: no cruza en 5 pasos** (B nunca baja del pelado). **Señal de memoria B−C: 0 en éxito, +$2.10 en costo** (la memoria acumulada costó más que la amnesia y no rindió éxito extra; su costo por paso además CRECE: $2.57→$4.03, mientras C se mantiene plano). **Intentos-hasta-limpio de A-R: mediana 1** — el pelado hizo los 5 pasos bien a la primera y el loop de reintentos jamás se activó.
- Commits: 87be8e6 (harness), 5f600c7 (fix fixture), ae6c776 (reanudación), c224097 (REPORT) — git log --grep "GRAPH-Task: benchmark-nivel2"
- Aprendizajes: (1) el diferencial de GRAPH medido en r5 (disciplina ante trampas) NO aparece en secuencias incrementales spec-by-test con tests visibles y sin trampas: ahí el pelado no falla, y el proceso solo agrega costo — el valor de GRAPH está en tareas con riesgo de indisciplina, no en el caso feliz; (2) la memoria acumulada es costo creciente sin retorno cuando cada paso re-parte de un checkpoint canónico chico — la ablación B/C lo aisló limpiamente; (3) el smoke con claude real caza lo que ningún stub ve (la trampa de pythonpath la expuso B haciendo ingeniería correcta); (4) reanudación por DESDE con memoria preservada = equivalencia demostrable con la corrida continua gracias al re-plant canónico.
- Amenazas a la validez: las del REPORT (N=1 por config, orden fijo, proyecto pequeño que subestima la ventaja de memoria, K=3 nunca ejercitado en real, desalineación memoria-checkpoint, interrupción por límite de sesión con 4 celdas re-ejecutadas — evidencia en cuarentena). El bloque AST de P3 y el loop de reintentos de A-R quedaron verificados solo con stubs/malas-naturales, nunca disparados por un agente real en esta corrida.
- Preguntas tardías (runtime): ninguna.
