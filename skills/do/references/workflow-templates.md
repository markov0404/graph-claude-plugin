# Plantillas de Workflow para tier L

## Cuándo se activa (Tier L)

Esto se autora cuando la Fase 4 de `SKILL.md` clasifica la tarea como tier
L, con la plantilla que corresponda de las de abajo (implementación
multi-frente / investigación / auditoría) — leerlas y usarlas es en sí el
opt-in del usuario para el Workflow tool (`SKILL.md`, "Tier L — grafo").
En la verificación adversarial, sigue la cascada de refutación de este
archivo: severidad alta, o hallazgos que tocan reglas duras/gate/contrato
`.graph/`, van a las 3 lentes en paralelo con voto por mayoría (tabla
lente→modelo de abajo); el resto pasa primero por un refutador barato en
lente correctitud y, solo si sostiene el hallazgo, a un refutador en lente
riesgo (modelo más capaz). Reglas: worktrees si los nodos mutan los mismos
archivos; verificación adversarial de cada entregable; síntesis final; el
loop convergente de tier M (`SKILL.md`, Fase 6) aplica sobre el resultado
sintetizado (si la síntesis no cumple criterios, se itera).

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

Cascada de refutación: las 3 lentes en paralelo con voto por mayoría (>=2 de
3 sostenida=true) quedan reservadas para hallazgos de severidad alta o que
toquen reglas duras/gate/contrato `.graph/`. Todo el resto usa 2 aprobaciones
en serie en vez de 3 en paralelo: primero UN refutador barato en lente
correctitud; si `sostenida=false` se descarta ahí mismo; solo si
`sostenida=true` pasa a UN refutador en lente riesgo (modelo más capaz), y
ese veredicto decide. Es proporcionalidad: la auditoría original gastaba
~8 refutadores por cada ítem de churn real evitado, y pagar 3 lentes en
paralelo por cada hallazgo de severidad baja no compensa ese costo.

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
contra TODO lo visto. Estructura: igual a la plantilla 2 PERO con la etapa
Verificar reemplazada por la cascada de refutación de las reglas comunes
(el barrido etiqueta cada hallazgo con `severidad` y `tocaReglaDura` para
que la cascada decida la rama):

```javascript
// El schema del barrido de ESTA plantilla extiende el de la plantilla 2:
// HALLAZGOS.items gana severidad ('alta'|'media'|'baja') y tocaReglaDura
// (boolean), ambos en required — sin ellos la cascada no puede decidir la
// rama y caería SIEMPRE en la barata (fail-open sobre los invariantes).
const refutar = (h) => (h.severidad === 'alta' || h.tocaReglaDura)
  ? parallel(['correctitud', 'valor/alcance', 'riesgo'].map(lente => () =>
      agent(prompt(lente, h), { model: MODELO_POR_LENTE[lente], schema: VERDAD })
    )).then(vs => ({ ...h, sostenida: vs.filter(v => v && v.sostenida).length >= 2 }))
  : agent(prompt('correctitud', h), { model: MODELO_POR_LENTE.correctitud, schema: VERDAD })
      .then(c => !(c && c.sostenida) ? { ...h, sostenida: false } :
        agent(prompt('riesgo', h), { model: MODELO_POR_LENTE.riesgo, schema: VERDAD })
          .then(r => ({ ...h, sostenida: !!(r && r.sostenida) })))
// Solo los hallazgos FRESCOS tras el dedup entran a refutar; el cableado
// reemplaza el parallel fijo de la etapa Verificar de la plantilla 2:
//   parallel(hallazgosFrescos.map(h => () => refutar(h)))
// Un refutador caído (null) jamás sostiene: la cascada es fail-closed.
```

que reemplaza el `parallel` de 3 refutadores fijos de antes: severidad
alta/regla dura sigue con las 3 lentes y voto por mayoría (>=2 de 3); el
resto corta en el primer refutador barato si no sostiene, y solo gasta el
segundo (riesgo, modelo capaz) cuando el primero sostuvo. `Set` de claves
vistas (clave = afirmación normalizada) acumula TODO lo emitido, refutados
incluidos — dedupear solo contra confirmados hace que el loop nunca seque.
Todo envuelto en `while (secas < 2)` relanzando los mismos ANGULOS por
ronda. Sin topes de cantidad: se agota, no se corta. Con --budget activo,
pásalo en args y añade al while la condición `(!args.presupuesto ||
budget.spent() < args.presupuesto)`, devolviendo lo acumulado al cortar
para que el orquestador pause y pregunte (sección Presupuesto del skill).
El único corte legítimo es ese presupuesto explícito del usuario; nunca
topes de cantidad inventados.
