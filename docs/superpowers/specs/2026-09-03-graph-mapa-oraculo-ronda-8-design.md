# GRAPH — Ronda 8: mapa de oráculo (cobertura de intención acumulativa)

**Fecha:** 2026-09-03
**Estado:** Diseño auto-aprobado por delegación; input para `/graph:do`. Nace del backlog `2026-09-03-backlog-ronda-8.md` (pregunta del usuario: spec⇄tests como señal) y de la validación de r7 (`bench/REPORT-R7.md`).
**Pregunta que responde:** ¿la señal más importante del router (eje B: ¿hay oráculo ejecutable y fuerte?) puede acumularse por repo en vez de recomputarse por tarea — y es ESA la forma de memoria que por fin paga? (la narrativa dio 0 mejora y +$2.10 en la ablación r6).

## La idea en una línea

La doble flecha spec⇄tests (BDD/Specification-by-Example) existe hace 20 años como método de construcción; usarla como **señal de ruteo acumulada por repo** no existe en el SOTA relevado (2 barridas, 10 investigadores). GRAPH ya fuerza la mitad por-tarea (mini-spec con método de verificación por criterio; eje B del router). La ronda 8 la persiste.

## CONTRATO — `.graph/oraculo.md` (formato vinculante; los frentes conforman a ESTO)

```markdown
# Mapa de oráculo · <proyecto>
> Esquema-oraculo: 1 · Generado: /graph:init <fecha> · Última tarea: <slug>

| área / comportamiento | checks | fuerza | vigencia | origen |
|---|---|---|---|---|
| stock: alta/baja/consulta con validaciones | tests/test_stock.py (5 tests) | fuerte | a1b2c3 | init 2026-09-03 |
| descuentos: reuso de disponible() (no-duplicación) | (sin check ejecutable) | — | — | tarea p3-descuentos |

**Huecos conocidos (sin check ejecutable):** <lista de comportamientos declarados sin oráculo — el objetivo natural del refuerzo de caracterización>
```

- **área/comportamiento**: etiqueta de intención en prosa corta (la escribe el modelo — es la parte semántica; una fila por área coherente, no por test).
- **checks**: archivos de test (y nº de tests) que la cubren, tal como los reporta `tools/oraculo-map.sh` (mecánico).
- **fuerza**: `fuerte` / `débil` por la heurística mecánica del tool (asserts reales vs triviales/ausentes — misma familia de heurística que red.sh); nunca juicio del modelo solo.
- **vigencia**: hash corto (md5 primeros 7) del CONTENIDO concatenado de los archivos de check listados, calculado por el tool al registrar. **Regla de vigencia:** antes de confiar en una fila, el consumidor re-corre `tools/oraculo-map.sh verify` — si el hash no coincide o falta un archivo, la fila es `dudosa` y NO se usa: se re-inspecciona fresco (el mapa es un índice acelerador, jamás una autoridad que pueda volver al router menos seguro que sin mapa).
- **origen**: `init <fecha>` o `tarea <slug>`.
- Re-normalización sin pérdida: si el mapa crece más de ~1 pantalla, las áreas se mueven íntegras a nodos enlazados (regla vigente del esquema); la sección de huecos conocidos SIEMPRE queda en el archivo raíz.

## Escritores

1. **`/graph:init` (y refresh)**: siembra el mapa — corre `tools/oraculo-map.sh scan` (mecánico: archivos de test por el patrón contractual, tests por archivo, fuerza, hash) y el modelo etiqueta las áreas leyendo los tests (solo-lectura, como todo init). Refresh: crea `oraculo.md` si falta (migración esquema 3→4, misma regla "créalo solo esa primera vez"); jamás pisa filas de origen `tarea *` — re-siembra solo las de origen `init`.
2. **`/graph:do` Fase 8 (cierre)**: añade/actualiza las filas del área tocada — los vínculos criterio→check que la mini-spec ya declara (o el JSON de la red + oráculo usado, en ruta pelada), los tests de caracterización creados (efecto #1 → pasan a checks del área), y los **huecos descubiertos** (criterios verificados sin check ejecutable → a huecos conocidos). Actualiza vigencia con el tool. Costo objetivo: ≤5 líneas nuevas por tarea típica.

## Consumidores

1. **Fase 0.5, eje B**: PRIMERO consulta el mapa (¿el área a tocar tiene filas vigentes? ¿fuerza? ¿figura en huecos?) con `verify` de vigencia; solo si el mapa calla o la fila es dudosa, cae a la inspección fresca actual. El veredicto del eje B cita la fila usada ("eje B: mapa, fila <área>, vigente") o declara "mapa sin cobertura del área → inspección fresca".
2. **Refuerzo de caracterización**: los huecos conocidos son su lista de objetivos — el gate compacto puede declarar el refuerzo apuntando al hueco exacto.

## Tooling — `tools/oraculo-map.sh` (instalable, bash + python3 stdlib, determinista)

- `scan <dir>`: emite TSV a stdout — `archivo<TAB>n_tests<TAB>fuerza<TAB>hash7` por archivo de test hallado con el patrón contractual (VERBATIM el de red.sh r7: `(^|/)tests?/`, `(^|/)spec/`, `test_*`, `*_test.*`, `*.test.*`, `*.spec.*`, `conftest*`, `fixtures/` — se fija acá para que ambos tools no deriven). Fuerza por AST (python) o heurística de asserts (otros lenguajes: conteo de asserts/expects; sin asserts → débil). Determinista (2 corridas → byte-idéntico).
- `verify <dir> <archivo> <hash7>`: rc=0 si el archivo existe y su hash coincide; rc=1 con `diag:` si no.
- Test propio `tests/test-oraculo-map.sh`: caso normal, test trivial (débil), archivo borrado/modificado (verify rc=1), naming no-python, determinismo, paths con espacios.

## Validación (PRE-REGISTRADA — criterios fijados aquí, antes de correr)

Ablación del mapa con 3 tareas nuevas de ruteo-sensible en `bench/tasks/` (contrato de celda r5 intacto; el check de estas tareas añade `ruta_correcta` leyendo el record de evidencia de la config R):

- **t7-cobertura-parcial**: el módulo a tocar FUNCIONA pero no tiene tests (otro módulo sí); ruta esperada: refuerzo de caracterización o pipeline — NUNCA pelada nativa. El mapa lo sabe por huecos conocidos; sin mapa hay que descubrirlo.
- **t8-sin-oraculo**: repo sin suite corrible (commands.md sin comando de test verificado); ruta esperada: pipeline completo.
- **t9-oraculo-debil**: tests del área existen pero triviales (débil por heurística); ruta esperada: refuerzo o pipeline — no pelada nativa sobre oráculo débil.

Configs: **R** (mapa sembrado por init real) vs **R−m** (idéntica pero el harness elimina `oraculo.md` del `.graph` inyectado — ablación pura; env `GRAPH_BENCH_SIN_MAPA=1` en el runner). N=2 reps → 12 celdas.

Criterios de éxito:
1. Mecánicos (antes de gastar): `oraculo-map.sh` determinista con test verde; init sobre fixture siembra el mapa con TODOS los archivos de test reales (0 omisiones, hashes correctos — verificación offline); cierre de una tarea real (smoke) añade sus filas; fila dudosa (test borrado tras sembrar) NO se usa (evidencia en record de que cayó a inspección fresca).
2. **Ruteo**: R rutea correcto ≥5/6 celdas (según la ruta esperada declarada arriba, verificada por el check desde la evidencia).
3. **Señal del mapa** (la pregunta de la ronda): Δ(ruteos correctos) y Δ(costo) entre R y R−m, reportados tal como salgan — **si Δ≈0, se declara que el mapa no mostró valor con N=2** (mismo estándar que la ablación r6; el mapa se conserva solo como aceleración si al menos no empeora nada).
4. Suite del plugin E5-E7 + test-red + hook intactos donde aplique; esquema 4 migrado sin pérdida (refresh sobre un `.graph` v3 real).
5. Anti-criterios: constitution C1-C5; el mapa jamás vuelve al router menos seguro que sin mapa (regla de vigencia fail-safe, verificada adversarialmente); pedidos idénticos entre configs; contrato de celda r5 sin divergencia; cero deps; corridas fuera del árbol.

**Amenazas declaradas de diseño:** las 3 tareas las diseña el mismo sistema que se mide (mitigación: lente FAIRNESS adversarial + ruta esperada declarada ANTES de correr); N=2; el etiquetado de áreas es prosa del modelo (solo la parte mecánica es verificable por ejecución); el valor del mapa crece con el tamaño del repo y estos fixtures son chicos — un Δ≈0 acá no refuta el mapa en repos grandes (se declara, no se extrapola).

## No-objetivos

Dieta de costo de la ruta pelada (pendiente separado, señalado por r7); RAG/embeddings sobre tests; etiquetado automático de intención sin tarea que lo ancle; mapa cross-repo; cobertura de líneas/mutation score real (la fuerza es heurística declarada); tocar el hook (INDEX sigue siendo lo único inyectado).
