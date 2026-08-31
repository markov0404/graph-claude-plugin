# Plantillas de Workflow para tier L

Adapta la plantilla al caso: reemplaza subtareas, prompts y esquemas. Reglas
comunes: cada agente recibe en su prompt el CONTEXTO que necesita (mini-spec
+ paquete de contexto relevante — los agentes de workflow NO ven la
conversación); todo entregable pasa verificación adversarial; el `meta` es un
literal puro; los scripts son JavaScript plano (sin tipos), sin Date.now() ni
Math.random().

Diversidad de modelo en la verificación adversarial (PoLL/ChatEval): el voto
por mayoría falla de forma correlacionada cuando todos los refutadores
comparten modelo — los mismos puntos ciegos se repiten en vez de cancelarse.
Por eso, además de diversidad de LENTE, cada refutador/verificador usa el
tier de modelo que corresponde a su lente:

| Lente | Tier de modelo |
|---|---|
| Correctitud (¿el problema existe tal cual?) | barato (haiku o equivalente) |
| Valor/alcance (¿mejora de verdad? ¿YAGNI?) | medio (sonnet o equivalente) |
| Riesgo (¿rompe suite/invariantes/gate?) | el más capaz disponible |

El barato es débil en juicios sutiles: se le asigna SOLO la lente mecánica
(correctitud), nunca valor/alcance ni riesgo. Se pasa con `model` en las
opciones de `agent()`; si se omite, el agente hereda el modelo de la sesión.

## 1. Implementación multi-frente

Para: feature/refactor con subtareas independientes que mutan archivos.

```javascript
export const meta = {
  name: 'graph-implementacion',
  description: 'Implementa subtareas en paralelo con verificación adversarial',
  phases: [{ title: 'Implementar' }, { title: 'Verificar' }],
}
const SUBTAREAS = args.subtareas  // [{id, prompt, criterios}]
// Cada st.prompt DEBE pedir al implementador terminar su resumen con la ruta de su worktree y su rama; el verificador verifica EN ESA RUTA.
const VEREDICTO = { type: 'object', properties: {
  aprobado: { type: 'boolean' }, problemas: { type: 'array', items: { type: 'string' } } },
  required: ['aprobado', 'problemas'] }

const resultados = await pipeline(
  SUBTAREAS,
  st => agent(st.prompt, { label: `impl:${st.id}`, phase: 'Implementar', isolation: 'worktree' }),
  (res, st) => agent(
    `Verifica adversarialmente esta implementación. Criterios: ${JSON.stringify(st.criterios)}. ` +
    `Resumen del implementador: ${res}. Ejecuta los métodos de verificación de verdad en la ruta de worktree que indica el resumen; ` +
    `en caso de duda, aprobado=false.`,
    // lente riesgo (¿rompe suite/invariantes/gate?) → el más capaz disponible (ver tabla de reglas comunes)
    { label: `verif:${st.id}`, phase: 'Verificar', schema: VEREDICTO, model: 'opus' }
  ).then(v => ({ id: st.id, resumen: res, veredicto: v }))
)
const ok = resultados.filter(Boolean)
const rechazadas = ok.filter(r => !r.veredicto || !r.veredicto.aprobado)
const perdidas = SUBTAREAS.filter(st => !ok.some(r => r.id === st.id)).map(st => st.id)
return { resultados: ok, rechazadas, perdidas }
// El orquestador corrige las rechazadas (loop de tier M) y re-verifica; trata las perdidas como rechazadas.
// Sintetizar = el orquestador mergea las ramas de los worktrees aprobados al repo, resuelve conflictos y corre la verificación integrada (fase 7 del skill do).
```

## 2. Investigación en abanico

Para: pedidos de research/análisis con criterios de evidencia.

```javascript
export const meta = {
  name: 'graph-investigacion',
  description: 'Barrido multi-ángulo y verificación adversarial de afirmaciones',
  phases: [{ title: 'Barrer' }, { title: 'Verificar' }],
}
const ANGULOS = args.angulos  // [{id, prompt}]  — ángulos de búsqueda distintos
const HALLAZGOS = { type: 'object', properties: {
  hallazgos: { type: 'array', items: { type: 'object', properties: {
    afirmacion: { type: 'string' }, fuente: { type: 'string' } },
    required: ['afirmacion', 'fuente'] } } }, required: ['hallazgos'] }
const VERDAD = { type: 'object', properties: {
  sostenida: { type: 'boolean' }, nota: { type: 'string' } }, required: ['sostenida'] }

const porAngulo = await pipeline(
  ANGULOS,
  a => agent(a.prompt, { label: `barrido:${a.id}`, phase: 'Barrer', schema: HALLAZGOS }),
  res => parallel(res.hallazgos.map(h => () =>
    agent(`Intenta REFUTAR con fuentes: "${h.afirmacion}" (fuente declarada: ${h.fuente}). ` +
          `Si no encuentras sustento independiente, sostenida=false.`,
      // lente correctitud (refutación factual contra fuentes) → barato (ver tabla de reglas comunes)
      { phase: 'Verificar', schema: VERDAD, model: 'haiku' }).then(v => ({ ...h, ...v }))))
)
return { confirmados: porAngulo.filter(Boolean).flat().filter(Boolean).filter(h => h.sostenida) }
```

## 3. Auditoría hasta agotar

Para: "revisa/audita todo X" sin tamaño conocido. Usa loop-until-dry: rondas
de buscadores hasta que 2 rondas seguidas no aporten nada nuevo, con dedup
contra TODO lo visto y veredicto por mayoría de 3 refutadores por hallazgo.
Estructura: igual a la plantilla 2 PERO con la etapa Verificar reemplazada:
cada hallazgo fresco va a 3 refutadores en paralelo (`parallel`) — uno por
lente de la tabla de reglas comunes, cada uno con el `model` de su fila —
p. ej. `agent(prompt(lente), { model: MODELO_POR_LENTE[lente], schema: VERDAD })`
por cada `lente` de `['correctitud', 'valor/alcance', 'riesgo']` — y sobrevive
con >=2 sostenida=true; todo envuelto en `while (secas < 2)` relanzando los mismos
ANGULOS por ronda; `Set` de claves vistas (clave = afirmación normalizada)
que acumula TODO lo emitido, refutados incluidos — dedupear solo contra
confirmados hace que el loop nunca seque. Sin topes de cantidad: se agota,
no se corta. Con --budget activo, pásalo en args y añade al while la
condición `(!args.presupuesto || budget.spent() < args.presupuesto)`,
devolviendo lo acumulado al cortar para que el orquestador pause y
pregunte (sección Presupuesto del skill). El único corte legítimo es ese
presupuesto explícito del usuario; nunca topes de cantidad inventados.
