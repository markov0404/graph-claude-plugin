# Instrumento de similitud de propuestas (medida calibrada, con baseline de barajado)

**Fecha:** 2026-09-06
**Estado:** Diseño auto-aprobado por delegación. Independiente de las rondas: es **instrumento de medición**, no maquinaria del pipeline.
**Origen:** la ronda 10 no pudo validarse porque su métrica de solapamiento comparaba prosa por igualdad de string exacto — sesgada a dar 0% ("tesis confirmada"), saturable por cardinalidad, y sin control que lo detectara. El usuario propuso resolverlo por lugar geométrico en un espacio (posiblemente esparso), citando su propio trabajo en `~/qcd-implementation`.

## El problema

Decidir, para dos propuestas en prosa, si son **la misma idea**. Lo necesitan dos consumidores distintos:
- La métrica de solapamiento entre brazos de cualquier experimento de exploración.
- El filtro `repite` de `tools/exploracion.sh`, hoy con Jaccard sobre tokens (umbral 0.40 + ≥3 compartidos) y **falsos positivos ya reproducidos** ("aumentar batch size" vs "reducir batch size" → 0.57, marcado REPETIDO).

## Prior art propio, reusado explícitamente

De `~/qcd-implementation`, dos piezas metodológicas (no código: el repo declara torch/sentence-transformers pero no tiene venv ni checkpoints locales):

1. **`scripts/geometry_phase_b4_inter_intra_distance.py`** — razón inter/intra entre centroides. Se traslada: distancia *intra-brazo* (¿las tres capturas de X son diversas o tres variantes de lo mismo?) vs *inter-brazo* (¿X propone algo distinto de X−g?).
2. **`scripts/v4_random_vector_baseline.py`** — **la pieza decisiva**. Su pregunta textual: *"si barajamos las etiquetas, ¿seguimos obteniendo el mismo resultado? Si sí: es un artefacto geométrico, no estructura categórica."* Ese control habría matado el criterio falsador de r10 en un minuto, sin necesidad del álgebra de cardinalidad.

## Criterio de etiquetado (definición operativa — sin esto el ancla es ruido)

La definición sale de **para qué** se usa la medida (solapamiento entre brazos, y filtro `repite`), y las dos convergen:

> **"Misma"** = si ya tenés una, la otra **no agrega nada**: llevan al mismo trabajo, y **la evidencia que refutaría a una refutaría a la otra**.
> **"Distinta"** = elegir una u otra **cambia lo que hacés**, o pueden caerse por evidencia distinta.

No es "se parecen" ni "hablan de lo mismo". El test es: **¿son intercambiables en la práctica?**

Aplicar el criterio ya corrigió tres etiquetas intuitivas del primer armado, y las tres eran de la misma familia — frases que hablan del mismo tema pero no son sustituibles:
- **regla vs causa** (`p40`: "una ronda, un componente" vs "los defectos aparecen al componer") — la primera prescribe, la segunda observa.
- **principio vs instancia** (`p39`: "detectar no puede salir peor que no detectar" vs el caso concreto de la anomalía que cierra la tarea) — arreglar el caso no agota el principio.
- **fin vs medio** (`p16`: "elegir cuánta ceremonia según la tarea" vs "el router decide por ejes objetivos") — otra implementación satisfaría el fin y refutaría el medio.

Que esa familia sea la que más se equivoca es información sobre el instrumento: cualquier medida —léxica, embeddings o juez— va a tender a marcarlas "misma" porque comparten tema. Es el caso duro real, y por eso está sobre-representado en el set.

## Diseño

### `bench/similitud/` — tres medidas, una interfaz

Todas exponen `medir(a: str, b: str) -> float` en [0,1] y se corren sobre el mismo set:

| # | medida | costo | deps |
|---|---|---|---|
| 1 | **léxica**: TF-IDF sobre el vocabulario del corpus + coseno | nulo | stdlib + numpy (ya presente) |
| 2 | **embeddings**: coseno sobre vectores densos | ~2 GB de instalación | sentence-transformers en venv aislado |
| 3 | **juez ciego**: un agente decide misma/distinta sin saber de qué brazo viene cada propuesta ni en qué orden | tokens por par | ninguna |

### Set de calibración — `bench/similitud/calibracion.jsonl`

Pares `{a, b, etiqueta: misma|distinta, origen}`. Tres fuentes:
- **Reales**: extraídos de los 71 records existentes en `bench/out*/`, `bench/real/`, `bench/seq/`.
- **Sintéticos por reformulación**: mismo contenido con otras palabras → `misma` por construcción (es el caso que la medida léxica debería fallar, y por eso tiene que estar).
- **Ancla humana**: ~20 pares etiquetados por el usuario. Es la única verdad de referencia; todo lo demás se mide contra esto.

### `bench/similitud/evaluar.py` — el reporte

Por cada medida disponible: acuerdo con el ancla humana, **tasa de error desagregada** (falso "misma" vs falso "distinta" — no son intercambiables: el falso "misma" bloquea una propuesta legítima, el falso "distinta" infla la novedad), costo, y el **baseline de barajado** (mezclar las etiquetas de brazo y recomputar; si el resultado no cae, la medida no mide nada). Determinista, salida byte-idéntica entre corridas para la misma entrada.

### Regla de decisión, fijada ANTES de correr

> Se adopta **la medida más barata cuyo acuerdo con el ancla humana esté dentro de 5 puntos porcentuales de la mejor**.

Eso operacionaliza "mejora sustancial" del usuario y hace que la pregunta de las dependencias se responda con datos, no a priori. Corolario: **la medida 2 solo se instala si 1 y 3 discrepan lo suficiente como para que arbitrar cambie la decisión** — si la léxica ya coincide con el juez ciego, los embeddings no aportan y no se instalan.

## Orden de construcción

1 y 3 primero (ambas gratis). Se corre `evaluar.py` con esas dos. Recién si el resultado lo justifica, se levanta el venv para la 2 — declarando el cambio de regla de "cero deps" como **acotado al harness de análisis, nunca al plugin distribuible**.

## Criterios de éxito (pre-registrados)

1. El set de calibración tiene ≥40 pares, con las tres fuentes representadas y ≥20 del ancla humana.
2. El baseline de barajado corre para toda medida reportada; una medida cuyo acuerdo no caiga al barajar se declara **inválida** y no se adopta, sin importar su acuerdo bruto.
3. Se reporta la tasa de error desagregada de la medida adoptada. Sin ese número, la medida no se usa como criterio falsador de nada.
4. `evaluar.py` es determinista y sin deps para las medidas 1 y 3.

## Amenazas declaradas

- El ancla humana es una sola persona y ~20 pares: es referencia, no verdad absoluta.
- El juez ciego es un modelo juzgando salidas de modelos: sus errores pueden estar correlacionados con los del generador, en una dirección que el ancla humana no necesariamente detecta.
- La medida léxica mide solapamiento de vocabulario, no significado; el set incluye a propósito los casos donde eso falla.
- Adoptar una medida calibrada NO arregla los otros defectos del experimento de r10 (los brazos veían 967 archivos contra 10; eso es de harness, no de métrica).

## No-objetivos

Cambiar `repite` en esta ronda (primero se calibra la medida, después se decide si reemplaza al Jaccard); medir novedad global (solo relativa al corpus del repo); tocar el plugin distribuible con dependencias.
