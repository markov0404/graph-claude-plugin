# Plantillas de Workflow para tier L

Adapta la plantilla al caso: reemplaza subtareas, prompts y esquemas. Reglas
comunes: cada agente recibe en su prompt el CONTEXTO que necesita (mini-spec
+ paquete de contexto relevante — los agentes de workflow NO ven la
conversación); todo entregable pasa verificación adversarial; el `meta` es un
literal puro; los scripts son JavaScript plano (sin tipos), sin Date.now() ni
Math.random().

## 1. Implementación multi-frente

Para: feature/refactor con subtareas independientes que mutan archivos.

```javascript
export const meta = {
  name: 'graph-implementacion',
  description: 'Implementa subtareas en paralelo con verificación adversarial',
  phases: [{ title: 'Implementar' }, { title: 'Verificar' }, { title: 'Sintetizar' }],
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
    { label: `verif:${st.id}`, phase: 'Verificar', schema: VEREDICTO }
  ).then(v => ({ id: st.id, resumen: res, veredicto: v }))
)
const rechazadas = resultados.filter(Boolean).filter(r => !r.veredicto || !r.veredicto.aprobado)
return { resultados, rechazadas }
// El orquestador corrige las rechazadas (loop de tier M) y re-verifica.
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
      { phase: 'Verificar', schema: VERDAD }).then(v => ({ ...h, ...v }))))
)
return { confirmados: porAngulo.filter(Boolean).flat().filter(h => h.sostenida) }
```

## 3. Auditoría hasta agotar

Para: "revisa/audita todo X" sin tamaño conocido. Usa loop-until-dry: rondas
de buscadores hasta que 2 rondas seguidas no aporten nada nuevo, con dedup
contra TODO lo visto y veredicto por mayoría de 3 refutadores por hallazgo.
Estructura: igual a la plantilla 2, envuelta en `while (secas < 2)` con un
`Set` de claves vistas. Sin topes de cantidad: se agota, no se corta.
