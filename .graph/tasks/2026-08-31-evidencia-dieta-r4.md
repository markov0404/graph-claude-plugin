# evidencia-dieta-r4 · 2026-08-31 · tier L

## Mini-spec aprobada
- Intención: implementar la ronda 4 según docs/superpowers/specs/2026-08-31-graph-evidencia-dieta-ronda-4-design.md (commit e9c1921, autoridad vinculante): evidencia determinista E5-E7 + dieta de ceremonia B1-B4.
- Alcance: exactamente R4-A1..A3 y R4-B1..B4. Fuera: benchmark, tocar la semántica de E1-E4, cambios de comportamiento en efectos/convergencia.
- Criterios (con método): 1) E5-E7 verdes y suite E1-E7 exit 0 (ejecución real); 2) B1 mapeo 1:1 sin pérdida semántica (adversarial); 3) B2 diff cruzado constitution→conventions sin hueco (adversarial); 4) B3 demostrada con record compacto real de tarea S (ejecución); 5) test-hook + symbol-map + validate intactos (ejecución).
- Anti-criterios (con método): constitution solo con la edición firmada en el spec (diff); gate/reglas duras intactos (E2/E3/E5 + adversarial); formato compacto = mismas secciones del contrato (revisión); sin truncado jamás (revisión del diff); español; cero deps; docs históricos intactos (git diff --stat); índice vivo actualizado al cierre.
- Aprobación: gate aprobado por el usuario en sesión interactiva.
- Tier: L — rúbrica (4 frentes independientes), no forzado.

## Efectos
| # | efecto | inversa | estado |
|---|---|---|---|
| 0 | línea base del working tree al entrar a Fase 6 = HEAD `e9c1921` (árbol limpio) | restaurar paths tocados con `git restore --source=e9c1921 -- <paths>` y borrar archivos nuevos no rastreados del intento; jamás toca `.graph/` | conservado |

## Diario
| iteración | qué se hizo | diagnóstico | resultado |
|---|---|---|---|
| 1 | Workflow tier L: 4 frentes con verificador lente riesgo (opus) | 4/4 rechazados, 20 hallazgos — graves: 6 citas C-N rotas en archivos vivos por la renumeración de B2; contradicción real introducida en conventions:11; budget:1 se agotaba PRE-gate (donde no puede existir record → E7 imposible); header compacto vs regex de E7-B3 (reproducido); fail-open + regresión null-deref en la cascada de plantilla 3; gate trivial omitía "Necesito de ti"; campo Tier-porqué perdido en plantilla compacta (viola C5-no-pérdida) | 12 fixes del orquestador con rulings: barrido completo de citas C-N (5 archivos), conventions reescrita fiel a reglas 1/7, presupuesto rige solo post-gate (el record SIEMPRE existe), ruta trivial exige preflight vacío, Tier-porqué añadido a la compacta, sujeto gramatical del efecto #0 aclarado, regex E7-B3 acepta "(ruta trivial)", ESTADO con \|\| true, cascada con schema extendido + guards fail-closed + frescos/cableado restaurados, limitación de E6-ajeno documentada. bash -n ×4 + validate ✓ |

## Verificación final
| criterio/anti-criterio | método | comando/procedimiento ejecutado | evidencia | ✅/❌ |
|---|---|---|---|---|
| C1 E5-E7 verdes + suite | ejecución real | suite completa E1-E6 verde en una corrida; E7 verde en corrida propia tras los fixes del loop | `OK: E5/E6` (retomar con fila plantada intacta, lock ajeno respetado); `OK: E7` (bloqueo + B3 compacto 12 líneas); E1-E4 verdes | ✅ |
| C2 B1 mapeo 1:1 | adversarial | verificador riesgo verificó las 21 unidades semánticas una a una | mapeo sostenido; 1 ambigüedad gramatical corregida | ✅ |
| C3 B2 diff cruzado | adversarial + barrido | constitution C1-C5 solo líneas rojas; conventions cubre lo movido; barrido de citas C-N en TODO el árbol vivo (8 corregidas) | grep limpio; contradicción de conventions:11 corregida | ✅ |
| C4 B3 record compacto real | ejecución real | caso B3 de E7 | record S compacto: 12 líneas de contenido, 1 efecto, 1 fila de diario | ✅ |
| C5 hook/symbol-map/validate | ejecución real | vía suite + validate directo | verdes; `✔ Validation passed` | ✅ |
| A invariantes | E2/E3/E5 + adversarial + diff | gate probado en 3 escenarios; sin truncado en el diff; docs históricos 0 cambios; español; cero deps | intactos | ✅ |

## Resultado
- Estado: convergió
- Evidencia final: E1-E7 completos en verde con ejecución real; ambas ramas del presupuesto ejercitadas en corridas distintas (convergió-con-nota y cerrado-por-bloqueo — la variación entre corridas validó la aserción por evidencia); primer record compacto (B3) y constitution reducida a 5 líneas rojas.
- Commits: (se listan en el cierre con git log --grep "GRAPH-Task: evidencia-dieta-r4")
- Aprendizajes: (1) el presupuesto en tokens era prosa inejecutable — el agente no ve contadores: toda regla del skill debe ser OBSERVABLE por quien la ejecuta (la semántica operativa por iteraciones lo arregló); (2) no se puede forzar el número de iteraciones de un buen modelo con tests visibles — los escenarios deben assertar EVIDENCIA de comportamiento, no ramas exactas; y la variación entre corridas (convergió/bloqueo) resultó ser una feature del test, no un defecto; (3) renumerar identificadores citados (C-N) exige barrido global de citas ANTES de commitear — 6 citas rotas en archivos vivos lo demostraron; (4) cuarta ronda consecutiva con rechazo total de frentes por el verificador de riesgo: el costo se paga una vez y compra hallazgos con reproducción — mantener.
- Amenazas a la validez: E5-E7 verdes = 1-2 corridas por escenario en 1 máquina; la rama "convergió con presupuesto documentado" y la rama "bloqueo" se observaron una vez cada una (no hay muestreo de su distribución); la cascada de refutación (B4) quedó escrita y verificada adversarialmente pero NO ejercitada por ningún workflow real todavía; el conteo de 12 líneas del record compacto depende de la operacionalización de "líneas de contenido" que definió G1 (validada contra un record no-compacto, N=1).
- Preguntas tardías (runtime): ninguna.
