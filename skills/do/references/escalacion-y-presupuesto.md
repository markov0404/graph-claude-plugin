# Escalación con reinicio limpio (ruta pelada-con-red) y presupuesto

Este archivo agrupa dos mecánicas del pipeline de `SKILL.md` que solo se leen
si el disparador respectivo realmente ocurre — ninguna corrida las paga por
default:

- **Escalación por criterios**: solo cuando la red (`tools/red.sh`, "Ruta
  pelada-con-red" punto 5 de `SKILL.md`) detecta suciedad tras ejecutar esa
  ruta, o al retomar una pelada interrumpida. La cláusula de escalación en sí
  ("si la red detecta suciedad: reinicio limpio...") ya viaja SIEMPRE en el
  gate de esa ruta (`SKILL.md`, "Ruta pelada-con-red", punto 1) — lo que vive
  acá es la mecánica de cómo ejecutarla cuando de verdad se dispara.
- **Presupuesto**: solo cuando la invocación trae `--budget <tokens>` (o su
  equivalente `budget:` del archivo de `--gate-aprobado`), o cuando el
  presupuesto se agota en runtime. Sin flag: sin tope, convergencia manda —
  esa regla mínima ya queda dicha en `SKILL.md`, Fase 6; el resto de la
  contabilidad vive acá.

## Escalación por criterios (sin contadores — regla dura 2 intacta)

- **Antes de clasificar nada: ¿el rojo es ATRIBUIBLE?** `red.sh` devuelve `atribuible`
  junto al resto del JSON. Solo aplica cuando `suite_verde:false`, y responde una
  pregunta mecánica: corrida la MISMA suite sobre el baseline puro en el mismo
  entorno, ¿hay fallos NUEVOS? (se comparan CONJUNTOS, no rojo/verde: si la base ya
  venía roja, lo que importa es si aparecieron fallos que antes no estaban).
  - `atribuible:true` → el delta es nuestro y la expectativa estaba preregistrada:
    **error determinable**, sigue la regla de "Sucio" de abajo.
  - `atribuible:false` → la base falla igual y no hay fallos nuevos: el cambio NO es
    la causa. Eso **no es suciedad, es una DIVERGENCIA** — algo de lo que nadie
    declaró se movió. **NO se revierte y NO se escala por esa causa**: revertir una
    divergencia es borrar la evidencia antes de mirarla. Se registra como anomalía
    de la regla dura 8 con `bifurcación: pendiente`, y el comportamiento no
    declarado que quedó expuesto va a "Huecos conocidos" de `.graph/oraculo.md`
    (Fase 8) — es material de pregunta del gate, no de rollback. El criterio del
    PEDIDO sigue exigiéndose igual: si el oráculo de la tarea no pasa, no convergió.
  - Si falta la clave (red.sh viejo o doble de prueba): tratala como `true`, que es
    el lado conservador.
  Esto además destraba un caso que el diseño previo hacía imposible: en un repo cuya
  suite YA está roja por causas ajenas, `suite_verde:false` era permanente y ninguna
  tarea podía cerrar nunca.

- **Sucio** (tests tocados, scope violado, o suite roja ATRIBUIBLE) → escalación: **reinicio limpio** — revertir por el ledger de efectos al baseline (inversas en orden LIFO, efecto #0 al final); los tests de caracterización (anti-ejemplos) del efecto #1, si existen, se CONSERVAN (fueron aprobados en el gate y son exactamente el oráculo que el pipeline completo quiere) — su fila pasa a `conservado`, con inversa disponible si el humano pide reversión total — y entrar al pipeline completo desde la Fase 1, con el informe de `tools/red.sh` como insumo de la mini-spec. NUNCA continuar la sesión contaminada. Tras la reversión, registra una fila nueva en Efectos: `base re-tomada (reinicio limpio) = <hash>` — la regla "no dupliques el efecto #0" (Fase 6) aplica a retomar SIN reversión, no a este caso: acá el árbol cambió por el LIFO y el nuevo punto de partida debe quedar explícito.
- **Un solo record, se EXTIENDE**: la escalación NO abre un task record nuevo. Al record compacto ya escrito se le AÑADE la sección `## Escalación a pipeline completo`, seguida de las secciones completas del pipeline (Mini-spec, Intención capturada, Diario, Verificación final, Resultado) con la plantilla **completa** (la sección "Plantillas del task record" de `SKILL.md`). Nada de lo ya escrito en el record compacto se reescribe (regla "jamás lo pises", Fase 6) — la tabla de Efectos es UNA SOLA y sigue numerando desde donde iba.
- **Fricción menor** (archivos auxiliares benignos, warnings) → NO escala: se registra en el record (Diario/Resultado). Es la anti-sobre-escalación: la red no es un gate binario ingenuo.
- **Retomar una pelada interrumpida**: si `.graph/INDEX.md` trae `En curso` de esta MISMA tarea en ruta pelada (Fase 0, mismo trato que cualquier retomada): NO se re-ejecuta la Fase 0.5 (la ruta ya elegida es trinquete, regla dura 3) — contexto mínimo = el pedido + INDEX, directo a la ejecución directa (`SKILL.md`, "Ruta pelada-con-red", punto 4) desde donde el Diario quedó; la red corre igual al cierre.
- La escalación NUNCA amplía el scope; si el pipeline completo necesitara ampliarlo, eso es pregunta tardía/bloqueo por las reglas existentes (regla dura 5), no escalación.
- Un solo salto de ruta (pelada → completa); dentro del pipeline completo rige la convergencia por criterios existente (Fase 6, tier M). La tasa de escalación se registra en el record de cada tarea; si es recurrente, también en `decisions.md` (Fase 8, punto 3) como métrica de calibración del router.

## Presupuesto

El presupuesto rige la EJECUCIÓN post-gate: las fases 1-5 (análisis de solo
lectura) no lo consumen. Si al entrar a Fase 6 el presupuesto ya está
agotado, la Fase 6 igual crea el task record y el lock como siempre — y
cierra ahí mismo por la vía del bloqueo (el record SIEMPRE existe y declara
lo ocurrido). El registro del efecto #0 (baseline git) tampoco consume
presupuesto — es bookkeeping, igual que el record y el lock; el efecto #1,
CUANDO EXISTE (escribir y verificar RED/GREEN los ejemplos aprobados —
`SKILL.md`, Fase 6, "Efecto #1"), SÍ es la primera unidad de ejecución real
y cuenta como tal para el agotamiento — si el presupuesto no alcanza ni
para escribirlo y verificarlo, cierra por bloqueo antes de completarlo. Si
no hay efecto #1 (fallback en prosa, u oráculo existente): la primera
unidad de ejecución real es la primera pasada de Tier S/M (`SKILL.md`,
Fase 6). El gasto post-gate se ESTIMA operativamente — el agente no ve
contadores de tokens: como mínimo, cada iteración del loop y cada subagente
despachado consumen presupuesto, y un presupuesto inferior al costo evidente
de UNA iteración (pocos miles de tokens) queda agotado al cerrar la primera
— si esa primera iteración no convergió, cierra por bloqueo; si la tarea ya
convergió, cierra convergida (el presupuesto limita el trabajo restante,
no anula un éxito ya logrado) y el record documenta el agotamiento con la
frase literal `presupuesto agotado` (en la fila del Diario donde ocurrió
y/o en Resultado — formato fijo, no un sinónimo). Con `--budget <tokens>`: revisa el gasto al cerrar cada iteración/fase; al
agotarse, pausa, presenta estado + evidencia de avance y pregunta: ampliar o
abortar. **En modo `--gate-aprobado` sin quien responda:** no preguntes —
es el mismo bloqueo tardío de la regla dura 5 (excepción `--gate-aprobado`):
cierra por Fase 8 con el estado `cerrado por bloqueo (pre-aprobado)`,
declarando el avance y ejecutando directamente las inversas pendientes en
LIFO (nunca colgado). Sin flag: sin tope, convergencia manda. Nunca inventes
topes.
