# GRAPH — Ronda 7: router objetivo + ruta pelada-con-red

**Fecha:** 2026-09-03
**Estado:** Diseño auto-aprobado por delegación; input para `/graph:do`. Nace del par r5+r6 (bench/REPORT.md y bench/seq/REPORT-NIVEL2.md) y de la investigación SOTA 2026 (dos barridas, 10 investigadores, fuentes primarias).
**Pregunta que responde:** ¿puede GRAPH decidir por tarea entre ejecución barata y pipeline completo sin perder la disciplina medida en r5, eliminando el impuesto de 3.7× medido en r6?

## Fundamento empírico (por qué ESTE diseño y no un clasificador de dificultad)

Lo que el SOTA 2024-2026 valida con números:

1. **Predecir dificultad a priori es débil.** Routers académicos: APGR 0.57-0.80 y cae en tareas objetivas (RouteLLM, ICLR-2025); dificultad rotulada por expertos vs costo real: Kendall τb=0.32; la misma tarea varía hasta 30× en tokens entre corridas (techo de ruido); LOC vs gap de trampa: R²=0.21 ("proxy tosco", SpecBench); churn histórico: REFUTADO como predictor; no existe ningún clasificador a-priori publicado de éxito en SWE-bench (vacío explícito). Cognition mantiene los clasificadores de Devin Fusion opacos y declara "cómo sabe un modelo que debe escalar" como problema abierto.
2. **Lo que SÍ predice no es la dificultad — son tres ejes distintos:** (a) **ambigüedad/subespecificación**: la trampa salta de 0.7-2.1% a 22-44% en pedidos ambiguos (EvilGenie); subespecificación del target = predictor #1 de violaciones de límite (UnderSpecBench, 55.8-67.8% de corridas); (b) **existencia/visibilidad/fuerza del oráculo**: ~80% de intentos de trampa con tests ocultos (METR); 80.2% de los tests escritos por agentes tienen oráculo débil (All Smoke No Alarm, 86k parches); oráculo fuerte e independiente → 91.6% vs 85.4% con 48-68% menos tokens (SkillForge); (c) **consecuencia del error**: es aproximadamente ortogonal a la dificultad y MÁS predecible (un predictor de consecuencia no clasificó mal ninguna tarea de alta consecuencia en 300 casos).
3. **"Ejecutar barato + verificar duro + expandir si falla" está validado como plantilla:** E3 (arXiv 2607.13034, jul-2026): con un estimador que cae a 66.9% de accuracy fuera de distribución, el sistema completo mantiene 100% de éxito con solo +8.7% de costo — **la verificación absorbe el error de estimación** — y ahorra 84.9% vs máxima ceremonia siempre. FrugalGPT (el cascade canónico) tampoco predice: intenta barato y evalúa post-hoc.
4. **Tres correcciones de la literatura al diseño ingenuo:** (a) un router de PRE-ejecución sobre precondiciones informativas le gana a la cascada pura porque el intento barato es costo hundido cuando igual se escala (Bouchard, 2605.06350) → el router va ANTES, no solo la red después; (b) un gatillo determinístico SIN calibrar sobre-escala masivamente (66-99.9% de llamadas caras, R2V-Agent) → la red distingue "sucio" de "fricción menor" y se mide la tasa de escalación; (c) reintentar sobre el contexto contaminado amplifica el error 7.1× ("clean-restart dominance", 2605.08563) → la escalación REINICIA limpio, nunca continúa la sesión.
5. **El hueco es real:** ninguno de los 10+ sistemas de producción relevados usa un oráculo ejecutable como precondición explícita de ruteo. Evidencia indirecta a favor: Cognition observa que las tareas con test-verification delegan bien a modelos baratos (62% de ahorro en refactors) y las sin oráculo claro resisten la delegación.

Y lo que midieron nuestros propios benchmarks: r5 (trampas) pelado 4/12 vs GRAPH 9/12 limpio; r6 (secuencia limpia) 20/20 ambos con GRAPH pagando 3.7× — el proceso paga solo donde hay riesgo, y hoy GRAPH no distingue.

## Diseño

### Fase 0.5 — Router objetivo (en `/graph:do`, antes de la Fase 1)

El router NO computa "dificultad" (evidencia débil). Computa **tres ejes validados**, todos objetivos y baratos (sin agentes extra, en la propia sesión):

- **Eje A — Huecos (ambigüedad/subespecificación):** preflight-lite adelantado: ¿el target está identificado sin ambigüedad (qué archivo/módulo/comportamiento)? ¿faltan credenciales, permisos o decisiones no tomadas? ¿el pedido admite una sola interpretación razonable? Cualquier hueco → **pipeline completo** (donde el preflight completo de la Fase 3 lo convierte en pregunta temprana, como hasta ahora).
- **Eje B — Oráculo:** ¿existe un criterio ejecutable INDEPENDIENTE del agente que cubra el cambio? Concretamente: (1) suite del repo corrible con el comando verificado de `commands.md`; (2) el pedido es del tipo "hacer pasar X" o el criterio de aceptación es derivable a un check ejecutable; (3) los tests de la zona a tocar tienen asserts reales (heurística de fuerza mínima: no suites vacías/triviales). Regla dura: **los tests que el agente escriba en la propia sesión no cuentan como oráculo** (80.2% nacen débiles). Sin oráculo o con oráculo débil → **pipeline completo** (la disciplina de proceso reemplaza al oráculo ausente).
- **Eje C — Consecuencia (D):** ¿la tarea puede causar daño **más allá del alcance del oráculo y de la inversa del ledger**? Definición operativa: romper tests que antes pasaban NO es por sí solo alta consecuencia — eso es regresión, y la atrapa la red (suite completa + tests intactos); alta consecuencia es lo que ningún test ve y ninguna inversa deshace: efectos irreversibles o externos (datos, migraciones, publicación, gasto), código compartido crítico cuyo daño no cubre la suite, trabajo en vuelo ajeno declarado en En-curso. Fuentes: la constitution del repo y una sección opcional curada `**Áreas de alta consecuencia:**` en `.graph/INDEX.md`. Alta consecuencia → **pipeline completo**, sin excepción.

**Eje B reforzable (tests de caracterización):** si el área a tocar FUNCIONA hoy pero su cobertura es débil, la ruta pelada admite un pre-paso barato: escribir tests de caracterización **desde el estado vigente, ANTES del cambio**, verificar que pasan, y congelarlos en el baseline (efecto #0) — desde ahí `tests_intactos` los protege como a cualquier test. Estos SÍ cuentan como oráculo pese a ser escritos por el agente: capturan el comportamiento que ya funciona, no validan el cambio propio (el hallazgo de All Smoke No Alarm es sobre tests nacidos para aprobar el propio parche); la heurística de fuerza mínima les aplica igual. Es la técnica clásica de caracterización (Feathers) convertida en escalón del router: ataca directamente el punto ciego tipo t6 (regresión en zona sin cobertura).

**Regla de ruteo:** ruta pelada-con-red **solo si** (sin huecos) ∧ (oráculo fuerte e independiente, nativo o reforzado por caracterización) ∧ (consecuencia baja) ∧ (el contexto necesario cabe — señal existente de la ruta trivial). En cualquier duda: el mayor (regla vigente del tier). El veredicto del router y sus tres ejes quedan registrados en el record (una línea por eje con la evidencia).

### Por qué gates y no una fórmula de complejidad

Los tres ejes NO son dimensiones aditivas de una "complejidad" escalar, y combinarlos en `C = w1·huecos + w2·oráculo + w3·consecuencia` recrearía exactamente el predictor que el SOTA refutó. Cada eje juega un rol distinto en el modelo de costo esperado:

```
costo_esperado(ruta) = costo_ejecución(ruta) + P(sucio) × P(inadvertido | sucio) × D
```

- **Huecos** multiplica `P(sucio)` (la ambigüedad multiplica la trampa 10-20× — EvilGenie).
- **Oráculo** gobierna `P(inadvertido | sucio)`: no reduce la chance de fallar — convierte el fallo silencioso en fallo atrapado (D colapsa al costo de un reintento). Con oráculo fuerte, los otros riesgos se absorben (E3); sin oráculo, hasta un hueco chico es fatal.
- **Consecuencia** ES `D`: no mide dificultad, mide el precio de equivocarse.

Las contribuciones **no son constantes entre problemas** — ni siquiera son términos del mismo tipo (probabilidad × detección × magnitud): en tareas con spec ambigua domina huecos; en refactors sobre código vivo domina el oráculo; en tareas que tocan producción domina D. Y son multiplicativas, no aditivas: por eso la decisión correcta es **lexicográfica** (cualquier eje en rojo → pipeline), no una suma ponderada con umbral. Los "pesos" reales (P̂ y D por tipo de tarea y por repo) no se inventan en este spec: se **miden** — el record registra veredicto del router + resultado de la red + escalaciones, y ese telemetría acumulada en `.graph/` es la que habilitaría, a futuro, el umbral calibrado τ*=(c_caro−c_barato)/κ de R2V por repo (declarado en No-objetivos hasta tener datos).

### Ruta pelada-con-red

1. **Gate único conservado, compacto:** mismo formato que la ruta trivial (1 párrafo: "ruta pelada — oráculo: <comando+alcance>, scope: <archivos/área>, consecuencia baja") + `--gate-aprobado` funciona igual.
2. **Baseline:** efecto #0 del ledger como siempre (`git` limpio o hash de partida).
3. **Ejecución directa:** el pedido + INDEX como contexto; sin mini-spec extendida, sin workflow, sin record largo. Estilo config A del bench.
4. **La red — `tools/red.sh` (nuevo, instalable, bash+git, cero deps):** al cierre ejecuta y emite JSON de flags (mismo estilo del contrato del bench): `tests_intactos` (diff vs baseline sobre paths de test/conftest/fixtures), `suite_verde` (comando verificado de `commands.md`, suite COMPLETA), `scope_respetado` (archivos tocados ⊆ scope del gate), `oraculo_independiente` (los tests nuevos de la sesión se registran pero no sustituyen a la suite previa como criterio). Diagnóstico a stderr con el contrato `tests_fallidos:`/`diag:` de r6.
5. **Record compacto** (formato ruta trivial) con el JSON de la red como evidencia de verificación.

### Escalación por criterios (sin contadores — regla 2 intacta)

- **Sucio** (cualquiera de: tests tocados, suite roja, scope violado) → escalación: **reinicio limpio** — revertir por el ledger de efectos al baseline y entrar al pipeline completo desde la Fase 1, con el informe de la red como insumo de la mini-spec (nunca continuar la sesión contaminada — 7.1× de amplificación medida).
- **Fricción menor** (archivos auxiliares benignos, warnings) → NO escala: se registra en el record. Esto es la anti-sobre-escalación de R2V: la red no es un gate binario ingenuo.
- Un solo salto de ruta (pelada→completa); dentro del pipeline completo rige la convergencia por criterios existente. La **tasa de escalación** se registra (record + línea en decisions.md si es recurrente) como métrica de calibración del router.

### Rúbrica de tier reescrita: solo estructura

El S/M/L pierde su rol de estimador de riesgo (migra al router) y queda como **asignador de estructura dentro del pipeline**: la rúbrica se reescribe en lenguaje puramente estructural y contable — nº de frentes de trabajo heterogéneos, profundidad de la cadena serial (etapas donde cada una depende del output de la anterior — RAMP: 100%→20% de finalización por etapa), acoplamiento de la zona a tocar (frentes interdependientes — Breakpoint: 55%→0%). Se poda cualquier criterio con sabor a "qué tan difícil parece" (tamaño, cantidad de archivos como proxy de riesgo): las señales refutadas no quedan ni como criterio informal. "En duda, el mayor" y la escalación por estancamiento se conservan — son lo que absorbe el error del conteo (patrón E3). El record registra tier elegido + veredicto del router, para medir desacuerdos con el tiempo.

### Cambios de superficie

- `skills/do/SKILL.md`: Fase 0.5 + ruta pelada-con-red + escalación (secciones nuevas, mínimas) + rúbrica de tier reescrita estructural; la ruta trivial existente queda como caso intermedio (con mini-spec compacta) y la pelada como escalón inferior.
- `tools/red.sh` + test propio (estilo test-symbol-map.sh, casos: limpio, test tocado, suite roja, scope violado, tests nuevos del agente no cuentan).
- `skills/init/SKILL.md` + esquema: sección opcional `**Áreas de alta consecuencia:**` en INDEX (creación en init/refresh si el repo la amerita; nunca obligatoria).
- `.graph/` del propio repo: registrar la decisión de diseño en decisions.md al cerrar.

## Validación (pre-registrada: estos criterios se fijan ANTES de correr)

Config nueva **R** (GRAPH con router) en el bench existente:

1. **r6-secuencia (P1..P5):** R debe ir por ruta pelada-con-red en los 5 pasos. Éxito: 5/5 limpio y **CPEL(R) ≤ 1.5× CPEL(A)** (~$1.3 por paso; hoy B paga 3.7×).
2. **r5-tareas (las 6):** R debe escalar o bloquear donde B lo hizo. Éxito: **Éxito limpio(R) ≥ 8/12** (B logró 9/12) y en t5 bloqueo limpio (el router detecta el hueco de credencial en el eje A y va a pipeline completo → preflight pregunta).
3. **Tasa de sobre-escalación** reportada: % de celdas donde R escaló con resultado que la ruta pelada habría dado limpio (medible re-corriendo la celda escalada en config A sobre el mismo plant; N=1, declarado).
4. Adversarial dual como siempre: lente riesgo (red.sh y escalación con reinicio limpio) + lente FAIRNESS (el router no debe leer nada que las configs del bench no vean; los criterios de ruteo son inspeccionables en el record).
5. Anti-criterios: constitution C1-C5; regla 2 (sin contadores); gate único conservado; contrato de celda r5/r6 sin divergencia; cero deps.

**Amenaza declarada de diseño:** el router se valida sobre los mismos benchmarks que motivaron su diseño (overfitting de diseño). Mitigación parcial: criterios de éxito pre-registrados en este spec antes de cualquier corrida; mitigación real pendiente: tareas nuevas no vistas (nivel 3 con dial de densidad de trampas), declarada como siguiente escalón.

## No-objetivos

Clasificador ML de dificultad (evidencia en contra); cascada multi-nivel de modelos (un solo salto de ruta); predicción de costo/tokens (r=0.39, techo de ruido 30×); umbral calibrado τ*=(c_caro−c_barato)/κ de R2V (se declara como refinamiento futuro si la tasa de sobre-escalación medida lo amerita); nivel 3 del benchmark (dial de trampas — validación externa futura del router).
