# GRAPH — Ronda 10: exploración dirigida (crear sobre lo que no se conoce)

**Fecha:** 2026-09-06
**Estado:** Diseño auto-aprobado por delegación; input para `/graph:do`.
**Origen:** conversación con el usuario tras la investigación de fuentes primarias sobre graph engineering, TiCoder y prior art. Tesis del usuario: *"el modelo no solo no sabe lo que no sabe, tampoco sabe lo que es capaz de crear; hay que darle la capacidad de crear sobre lo que no conoce"*.

## El problema que resuelve

La ronda 9 mide **fuerza** de la captura de intención, no **fidelidad**. Un ejemplo puede matar todos los mutantes y estar capturando la interpretación que el modelo asimiló a lo que ya conoce. Peor: nuestra capa de enforcement —lo mejor que tenemos— **congela esa captura y revierte todo lo que se desvíe**. Un oráculo fuerte sobre una captura errónea encierra; uno débil al menos deja escapar.

Eso importa solo en un régimen: cuando el usuario va hacia algo **sin precedente** — que no está en el entrenamiento porque no existe, es raro, o nadie lo hizo. Ahí el modelo arrastra la construcción nueva hacia el vecino conocido, y lo hace de forma invisible y convincente.

**No es un modo global.** Construir algo 100% conocido es legítimo y frecuente, y ahí toda esta maquinaria es puro costo — el mismo error que ya cometimos con la ceremonia (r6) y con la memoria (r8).

## Marco: no agregamos capacidad, cambiamos la política de búsqueda

La capacidad de producir combinaciones nuevas ya está en los pesos (best-of-N, temperatura con filtro y self-consistency extraen mejores resultados **de los mismos pesos**). Lo que falta es política: el modelo filtra por **probabilidad**. La exploración exige filtrar por **no-refutación** — una opción es admisible si no viola invariantes ni repite algo ya descartado, aunque sea improbable.

El juicio de qué dirección importa **no se mecaniza**: lo pone el humano en el gate. Esta ronda no lo toca.

## Diseño

### 1. Cuarto eje del router: régimen (`conocido` | `inexplorado`)

- **Lo declara el humano** (`--explorar`, o explícito en el pedido). El router puede SUGERIRLO con señales baratas (vocabulario del pedido ausente del repo y raro en general; sin precedente local; el propio pedido dice que no existe), pero **nunca lo asume**: "esto que pido no existe todavía" es exactamente el juicio que el modelo no puede hacer.
- **Default: `conocido`** → todo funciona como r9, sin sobrecosto. La exploración se pide.
- El régimen se registra en el veredicto del router y en el record.

### 2. Sonda de SOTA acotada (solo en régimen `inexplorado`)

El prior del modelo tiene dos huecos distintos: lo posterior al corte de entrenamiento, y lo que existe pero pesa poco en el corpus. La búsqueda en vivo tapa ambos.

- Presupuesto declarado (nº de agentes y tiempo) fijado en el gate; nunca ilimitada.
- Devuelve tres cosas, no una: **qué ya existe** (para no reinventar), **qué se probó y falló** (para no repetir), **qué haría alguien de un dominio lejano** (transferencia forzada).
- Cada resultado entra al grafo de exploración como nodo con `origen: sota` y su fuente.

### 3. Generación con cuota de rareza, filtrada por no-refutación

En vez de una captura, **tres con roles fijos**:

| rol | qué es | para qué |
|---|---|---|
| **la obvia** | lo que el modelo propondría solo | se presenta **etiquetada como el atractor**: nombrarla la vuelve rechazable |
| **la transferida** | cómo lo resolvería alguien de un dominio lejano | rompe el vecino más cercano |
| **la improbable** | que el propio modelo declara poco probable pero no imposible | es la que no aparece si no se pide |

Filtro antes de mostrar: descartar las que violan un invariante vivo o **repiten un nodo ya refutado**. Sobrevivientes al gate. Nota de diseño: forzar rareza sin filtro es generar disparates caros — el filtro no es opcional, y la atención del humano es el recurso escaso (pocas opciones, ya podadas).

### 4. Grafo de exploración — `.graph/exploracion.md`

Nodos: hipótesis, intentos, referencias del SOTA. Aristas: `refuta`, `variante-de`, `deriva-de`, `sostiene`. Todo nodo refutado carga **su evidencia** (el test que falló, la medición, la cita) y, donde se pueda, es **ejecutable** — el patrón del `tests/historical/` de un repo grande externo, con la refutación viva como xfail estricto.

Consumidor concreto y nuevo: el filtro de no-refutación del punto 3. **Sin el grafo ese filtro no puede existir.** Esto lo distingue de los cuatro grafos de memoria que medimos en cero: aquellos describían lo conocido (estructura, cobertura, convenciones) — reconstruible por el modelo; éste describe **la búsqueda** — existe solo porque alguien la hizo.

Re-normalización sin pérdida como todo nodo del esquema.

### 5. Preregistro: lo que hace que una refutación cuente

Antes de ejecutar un intento exploratorio, el nodo declara **qué lo refutaría**. Sin ese compromiso previo, siempre se puede racionalizar que en realidad no falló. Es la metodología que el usuario ya practica a mano en un repo grande externo (preregistro, invariantes canonicos numerados, cementerio ejecutable); acá se abarata la contabilidad, no se inventa el método.

### 6. Auto-aplicación (REQUISITO, no opcional)

La ronda se valida usando su propia maquinaria **sobre GRAPH mismo**, apuntada al grand challenge que el campo declaró abierto (*Intent Formalization at repo scale*, arXiv 2603.17150). Es territorio genuinamente inexplorado —por definición del propio campo—, así que es el caso de prueba honesto: la sonda de SOTA, la cuota de rareza y el grafo de exploración corren sobre la pregunta "cómo capturar intención sin precedente", y lo que se refute queda registrado con su evidencia.

## Validación PRE-REGISTRADA

La métrica **no es velocidad**. Es qué se propone.

Dos brazos sobre los mismos pedidos exploratorios: **X** (maquinaria completa) vs **X−g** (idéntico pero sin grafo de exploración ni cuota de rareza).

1. **Repetición de refutados**: propuestas que repiten un intento ya descartado. Criterio: X → 0; X−g > 0. Si ambos dan 0 porque nunca hubo refutados previos, el experimento no es válido — hay que sembrar el grafo con refutaciones reales primero (las de la auto-aplicación sirven).
2. **Solapamiento entre brazos**: conjunto de propuestas de X vs X−g. Criterio: **solapamiento < 60%**. Si X propone casi lo mismo que X−g, la maquinaria es decorativa. *Este es el criterio falsador.*
3. **Elección humana**: en cuántos casos el humano elige una propuesta que NO es la obvia. Se reporta tal cual salga; con N chico es anécdota declarada, no efecto.
4. **No-regresión del régimen conocido**: en `conocido`, costo dentro de **1.15×** de la config E de r9. La exploración no puede filtrarse al camino barato.
5. Suite del plugin intacta; contrato de celda sin divergencia; cero deps; corridas fuera del árbol.

**Qué falsaría la ronda:** solapamiento ≥60% entre brazos. Significaría que el grafo de exploración es otro acelerador decorativo y hay que enterrarlo junto a los cuatro anteriores, con su medición publicada.

## Amenazas declaradas

- "Novedad" no es mecánicamente definible: el régimen lo declara el humano y el solapamiento entre brazos es un proxy, no una medida de originalidad.
- Quien juzga si una propuesta es "el vecino conocido" es el mismo que diseñó el sistema. Sesgo real, no eliminado — mitigación parcial: el criterio 2 es mecánico (conjuntos de propuestas), no de juicio.
- N chico por construcción: los pedidos exploratorios reales son pocos y caros.
- La sonda de SOTA depende de búsqueda en vivo: resultados no reproducibles entre corridas (se archiva lo devuelto, con fecha).
- Forzar rareza tiene costo: la mayoría de las propuestas improbables serán ruido. El filtro de invariantes es lo único que lo hace viable.

## No-objetivos

Que el sistema fije sus propios criterios de relevancia (eso sí sería otra cosa, y no es esto); property-based testing generado por LLM (medido: propiedades frecuentemente triviales o incorrectas); reemplazar el gate por ejemplos de r9 (la exploración produce candidatos; el gate sigue siendo donde se aprueban); memoria narrativa (ya medida en cero cuatro veces — el grafo de exploración es otra cosa y debe probarlo).
