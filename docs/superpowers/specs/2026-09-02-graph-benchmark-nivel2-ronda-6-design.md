# GRAPH — Ronda 6: benchmark nivel 2 (secuencias, amnesia, horizonte de cruce, reintentos)

**Fecha:** 2026-09-02
**Estado:** Diseño auto-aprobado por delegación; input para `/graph:do`. Extiende `bench/` (ronda 5, REPORT v0 en ed5faee).
**Preguntas que responde:** (1) ¿la memoria acumulativa de GRAPH compone valor? (ablación B vs C); (2) ¿en qué paso el costo acumulado por éxito limpio de GRAPH cruza por debajo del de un pelado que reintenta hasta hacerlo bien? (horizonte); (3) ¿cuántos intentos/costo necesita un pelado para lograr éxito LIMPIO? (A-R).

## La secuencia (`bench/seq/`)

Mini-proyecto Python "inventario" que evoluciona en 5 pasos encadenados; cada paso se define spec-by-test (tests nuevos del paso, visibles) y hereda la suite acumulada como regresión:

- P1 `stock`: modelo de ítems + stock (alta/baja/consulta).
- P2 `reservas`: reservas sobre el stock de P1 (toca código de P1 sin romperlo).
- P3 `descuentos`: reglas que deberían REUSAR el cálculo de P2 (la tentación medible es duplicar lógica — se mide con un check de no-duplicación ejecutable: el helper de P2 debe ser el único sitio del cálculo, verificado por grep estructural declarado en el check).
- P4 `reporte`: integra P1-P3 (multi-archivo).
- P5 `refactor transversal`: renombrar un concepto usado en todos los módulos con la suite entera verde (el paso donde mapa/convenciones/records deberían pagar).

Estructura: `bench/seq/pasos/p1..p5/` con `plant.sh` (aplica al dir la SOLUCIÓN DE REFERENCIA del paso anterior — checkpoint canónico — y planta los tests del paso; commit "plant-p<i>" e imprime hash), `pedido.txt` (idéntico para todas las configs), `gate.md` (para B y C), `check.sh` (contrato de ronda 5: 3 args, 4 booleanos; `regresiones_ok` = suite acumulada verde; en P3 `exito` incluye el criterio de no-duplicación), y `ref/` (solución de referencia del paso, verificada offline con la suite acumulada — es también el checkpoint del paso siguiente).

## Las 4 configs

- **A pelado**: 1 intento por paso.
- **A-R pelado-reintentos**: hasta K=3 intentos por paso; tras un intento con limpio=false, el runner revierte el working tree al plant del paso y reintenta con el pedido + feedback estructurado del check (tests fallidos, disciplina violada — formato fijo del runner, igual para todos los reintentos). Métricas extra: intentos_hasta_limpio (o `>K`), costo acumulado del paso.
- **B GRAPH memoria**: `/graph:do --gate-aprobado`; su `.graph/` inicial es el horneado sobre P0 (fixture inicial) y SE ARRASTRA entre pasos (el runner lo preserva y lo re-inyecta sobre cada checkpoint — records, decisions y aprendizajes acumulan; el resto del árbol es el checkpoint canónico). Nota declarada: su memoria describe lo que B construyó, el checkpoint es la referencia — desalineación realista y medida, no bug.
- **C GRAPH amnésico**: ídem B pero su `.graph/` es SIEMPRE la copia CONGELADA del horneado inicial (sin records ni decisiones de la secuencia). Ablación pura de la acumulación.

Fairness: pedidos idénticos; el feedback de A-R viene del check (disponible conceptualmente para todos: B/C tienen su propia verificación interna); K=3 declarado; misma base y mismos checkpoints para todos.

## Runner y scoring

- `bench/seq/run-seq.sh <config> <out-dir>`: corre la secuencia completa de una config: por paso — plant (checkpoint) → preparar memoria según config → celda (mismas mecánicas de celda que run-bench.sh: aislamiento, timeout -k, fail-closed, evidencia en `<out-dir>/p<i>-<intento>.d/`) → check → (A-R: loop de reintentos) → registrar JSON por intento con {config, paso, intento, ...contrato ronda 5..., limpio}. El paso SIEMPRE avanza al checkpoint siguiente aunque haya quedado sucio (costo registrado).
- **Fix del campo model** (amenaza v0): extraerlo de `modelUsage` (primera clave) del JSON de claude cuando `model` no esté al tope — aplica a run-bench.sh y run-seq.sh.
- `bench/seq/score-seq.py` (stdlib): por config — tabla por paso (limpio, intentos, costo, wall) + CURVAS acumuladas (costo acumulado, éxitos limpios acumulados, CPEL = costo acumulado / éxitos limpios acumulados, con CPEL=∞ mientras no haya éxito) + **horizonte**: primer paso donde CPEL(B) < CPEL(A-R) (y también vs A), o "no cruza en 5 pasos"; **señal de memoria**: delta por paso B−C en limpio y en costo; **intentos-hasta-limpio** de A-R (mediana y distribución). Salida `bench/seq/REPORT-NIVEL2.md` con Lecturas neutrales y Amenazas obligatorias (N=1 por config — UNA secuencia, sin varianza muestreada; el orden de pasos fijo; la desalineación memoria-checkpoint de B; K=3 arbitrario; mismas amenazas estructurales de v0).

## Verificación del conjunto

1. Las soluciones de referencia de los 5 pasos pasan la suite acumulada offline (la cadena de checkpoints es válida por construcción, verificado ANTES de correr).
2. Smoke: P1 con config A y config B end-to-end.
3. Corrida e2e completa: 4 configs × secuencia de 5 pasos (A-R con sus reintentos) — REPORT-NIVEL2.md real commiteado con hash del harness.
4. Adversarial dual como en ronda 5: lente riesgo (runner/score) + lente FAIRNESS (secuencia y feedback de A-R).
5. Anti-criterios: constitution C1-C5; contrato de celda de ronda 5 reutilizado (no divergir); corridas fuera del árbol; `bench/out/` y `bench/seq/out/` gitignoreados; cero deps nuevas.

## No-objetivos

N>1 secuencias (declarado como siguiente escalón); ablación C2 (re-horneado sin records — aísla mapa vs records) queda documentada como variante futura; comparar contra otros frameworks; secuencias más largas que 5.
