# Régimen `inexplorado` — maquinaria de exploración (Eje D, r10)

Este archivo se lee SOLO cuando el régimen (Fase 0 de `SKILL.md`) es
`inexplorado` — la Fase 1 de `SKILL.md` trae el puntero que dispara esta
lectura, apenas se entra al pipeline completo (`inexplorado` nunca toma
ruta pelada ni trivial, así que siempre pasa por ahí). **En régimen
`conocido` este archivo NUNCA se lee**: nada de lo que sigue aplica, y su
costo de tokens no lo paga esa ruta. Contiene las instrucciones ampliadas
para las Fases 1, 5, 6, 7 y 8 del pipeline de `SKILL.md` — reemplazan o
amplían lo que ese documento describe para esas fases cuando el régimen es
`inexplorado`; todo lo demás (Fase 0, Fase 0.5, Fase 2-4, Tier S/L,
Presupuesto) corre igual, sin cambios, esté o no activo este régimen.

## Fase 1 — Intención por ejemplos: cuota de rareza

Reemplaza, para LA pieza EXPLORATORIA del pedido (la que motiva el
régimen — **una sola por tarea, r10 §8**: si el pedido trae dos o más
piezas que ameritan régimen `inexplorado`, eso es alcance para dos tareas,
no una — declaralo en el gate y acotá esta tarea a una sola pieza; el
resto queda fuera de alcance explícito, para una tarea siguiente), el paso
"Ejemplos positivos" de la Fase 1 de `SKILL.md` — Anti-ejemplos, Huecos y
Anti-criterios de constitution no cambian.

**Cuota de rareza, filtrada por no-refutación** — reemplaza "Ejemplos
positivos" para la pieza exploratoria: en vez de UNA captura, redactá TRES,
mismo mecanismo de código ejecutable que "Ejemplos positivos" (test real,
con su aserción, tal como HOY FALLARÍA), con roles FIJOS:

| rol | qué es |
|---|---|
| **la obvia** | lo que redactarías vos solo. Solo puede etiquetarse `ATRACTOR — rechazable` en el gate si se funda en **precedente LOCAL verificable** (r10 §6): un archivo/símbolo/patrón de ESTE repo que ya resuelve algo equivalente, citado por ruta — nunca por juicio introspectivo del propio agente ("esto es lo obvio" no es una fuente: es la misma clase de juicio que el régimen ya le niega al modelo — "no podés juzgar qué no existe" aplica igual a "qué es obvio"). **Sin precedente citable, no se reclama la etiqueta**: declará "sin atractor identificable" y las tres capturas van al gate sin rol privilegiado |
| **la transferida** | cómo lo resolvería alguien de un dominio lejano — transferencia forzada, razonada directamente por el propio agente (sin insumo de investigación externa) |
| **la improbable** | la que vos mismo declarás poco probable pero NO imposible — la que no aparece si nadie la pide |

**Chequeo recíproco entre las tres, ANTES del filtro de no-refutación y
del gate** (r10 §7): compará cada captura contra las OTRAS DOS, no solo
contra el cementerio de refutados del grafo — dos capturas que colapsan en
el mismo código (misma aserción salvo variables cosméticas) son la misma
captura repetida bajo dos roles. Par colapsado → descartá una de las dos y
declaralo tal cual en el gate ("la transferida colapsó con la obvia: se
presenta una sola"). Tres capturas idénticas nunca llegan al gate sin esta
marca aplicada a los tres pares.

**Filtro previo obligatorio, ANTES de mostrar nada en el gate**: sobre las
capturas que sobrevivieron el chequeo recíproco, descartá toda captura que
viole un invariante vivo (`.graph/constitution.md`, C-N) o que repita un
nodo ya refutado del grafo de exploración — consultá
`${CLAUDE_PLUGIN_ROOT}/tools/exploracion.sh repite .graph/exploracion.md
"<descripción breve>"` (DOS argumentos siempre: el archivo del grafo y la
descripción — la firma real del tool los exige a ambos y falla cerrado con
uno solo) por cada captura sobreviviente; una respuesta positiva la
descarta sin mostrarla, con el motivo citado. **Degradación SOLO si el
tool NO EXISTE** en este repo (r10 §1): mismo patrón que `symbol-map.sh` en
`init` — dejá constancia explícita ("sin `exploracion.sh` disponible:
`<motivo>` — filtro de no-refutación no verificado esta ronda") y seguí
sin bloquear la Fase 1, con el aviso visible en el gate. **Si el tool
EXISTE pero la invocación falla** (código de salida ≠0 por cualquier otro
motivo: archivo del grafo corrupto, argumentos rechazados, etc.): es un
**error**, no una degradación silenciosa — bloqueá acá mismo citando el
stderr real; nunca lo tratés como si el tool hubiera degradado. Nota de
diseño (spec r10 §3): forzar rareza sin filtro es generar disparates
caros — el filtro no es opcional, y la atención del humano en el gate es
el recurso escaso. Las sobrevivientes (una, dos o las tres) van al gate;
si el filtro descarta las TRES, es un **Hueco** ("ningún candidato
exploratorio sobrevivió al filtro de no-refutación") — nunca se inventa
una cuarta para completar, ni se relaja el filtro.

## Fase 5 — Gate: sección adicional y manejo de `captura:`

Además de los puntos 1-5 del gate (Fase 5 de `SKILL.md`), en régimen
`inexplorado` suma:

6. **Sección adicional** — régimen y por qué (vía `--explorar` / archivo /
   cita textual del pedido); el resultado del chequeo recíproco entre las
   tres capturas (ningún par colapsado, o cuál se descartó por colapso y
   con cuál otra); las capturas SOBREVIVIENTES al filtro de no-refutación
   (la obvia etiquetada `ATRACTOR — rechazable` SOLO si citó precedente
   local verificable — si no, "sin atractor identificable" y las tres sin
   rol privilegiado; la transferida; la improbable), CADA UNA citando el
   veredicto real de `exploracion.sh repite` que la dejó pasar (`NUEVO`, no
   un supuesto) — es la evidencia de que el filtro corrió de verdad, no
   solo que se declaró; con el motivo de cualquier descarte (invariante
   violado, o nodo ya refutado citando cuál — veredicto `REPETIDO`), o el
   aviso de degradación si `exploracion.sh` no existía. Si el filtro
   descartó las tres, mostralo como el Hueco correspondiente de la Fase 3
   (de `SKILL.md`) en vez de esta sección.

**`--gate-aprobado` (r10):** el archivo de `--gate-aprobado` (formato y
validación textual: ver Fase 5 de `SKILL.md`) debe traer además, en
régimen `inexplorado`, el campo `captura: obvia|transferida|improbable`
(cuál de las sobrevivientes seguir) — sin ese campo, la elección de
captura es exactamente el mismo bloqueo que una pregunta sin respuesta
firmada: se presenta la pantalla y termina. Si `captura:` nombra un rol
que el filtro de no-refutación o el chequeo recíproco ya DESCARTÓ (r10
§8) — mismo trato: es un bloqueo, no una elección con criterio propio; se
presenta la pantalla (citando cuál rol sobrevivió de verdad) y termina.

**Gate interactivo (sin archivo de aprobación):** la pregunta de
aprobación de la Fase 5 (aprobar / corregir alcance / cambiar tier) suma,
en régimen `inexplorado`, una opción más: elegir cuál de las capturas
sobrevivientes seguir, o pedir una ronda nueva — esa elección es la que la
Fase 6 ejecuta como el ejemplo positivo aprobado.

## Fase 6 — Preregistro y Tier M, paso 4

**Preregistro (EXIGIDO, no sugerido, r10 §5)**: antes de escribir la
primera línea de implementación real para la captura elegida en el gate (y
antes de cada intento posterior del loop de Tier M si el enfoque cambia de
forma sustancial), declará por escrito en la tabla de Preregistro de la
sección `## Exploración` del record qué observación REFUTARÍA este
intento — una frase concreta y verificable, ANTES de ejecutar nada (esta
fila del record ES el compromiso que cuenta; el nodo `intento` que lo
formaliza en el grafo se escribe recién al cerrar, Fase 8, con este mismo
texto citado tal cual). Sin ese compromiso previo una refutación no cuenta
(spec r10 §5): no se vale decir después "total no era eso" sin haberlo
dicho antes — **saltear este paso vuelve vacuamente falsa la condición de
anomalía entera, así que cada fila del Diario de un intento exploratorio
suma una columna más**: `criterio de refutación preregistrado: <cita
textual del compromiso de arriba> → ¿se cumplió? sí/no + evidencia`. Sin
esa celda, la iteración no está registrada (aunque el resto de sus
columnas esté completo) — la Fase 8 (punto de cierre del grafo) falla el
cierre si hay algún intento exploratorio sin su fila de Preregistro
correspondiente. Ver regla dura 8 (`SKILL.md`): si lo observado diverge de
lo preregistrado (acá, o del RED/GREEN esperado en régimen `conocido` —
ver Fase 6 de `SKILL.md`, efecto #1, y Tier S/M), es una anomalía — se
registra (qué se esperaba/qué se observó) y se presenta la bifurcación
(a)/(b) al humano en modo interactivo (o `pendiente` + continuar en no
interactivo/`--gate-aprobado`, regla dura 8) ANTES de seguir "arreglando"
en silencio.

(Las capturas que llegaron al gate — elegida y descartadas por el HUMANO —
se escriben al grafo de exploración recién en Fase 8, al cerrar la tarea,
a partir de lo que esta tabla de Preregistro y la sección `## Exploración`
del record ya dejaron por escrito; ver Fase 8, punto 5 (más abajo).
`agregar` no tiene modo de edición, así que escribirlas de una sola vez al
cierre —en vez de crear un nodo temprano que Fase 8 tendría que
referenciar por id a través de una interrupción posible— evita duplicar
nodos si la tarea se retoma.)

**Tier M, paso 4 — Anomalía (regla dura 8), SOLO régimen `inexplorado`**
(en `conocido` la única instancia de esta regla es el chequeo único de
"efecto #1" de la Fase 6 de `SKILL.md`, no un paso por-iteración: un
ejemplo que sigue en RED tras una iteración es simplemente
no-convergencia todavía, jamás una anomalía por sí solo): si lo observado
en el paso 2 del loop de Tier M coincide con lo que el preregistro de este
intento (Fase 6 de este documento, o el de la iteración anterior si el
enfoque no cambió) declaró que lo REFUTARÍA — no una mera falta de
convergencia — no lo "arregles" y sigas de largo: registralo primero en la
tabla Anomalías de `## Exploración` DEL RECORD (qué se esperaba/qué se
observó), y decidí la bifurcación ANTES de escribir el nodo al grafo
(`agregar` no tiene modo de edición: el nodo se crea UNA sola vez, con la
bifurcación YA resuelta — nunca "pendiente, y después editada"). **En modo
interactivo**: presentá la bifurcación al humano ANTES de la siguiente
iteración — (a) error nuestro (se corrige acá mismo, camino normal) / (b)
la expectativa estaba mal (revisá el invariante o la hipótesis del dominio
antes de seguir implementando sobre una expectativa que ya se sabe
incorrecta) — y recién con esa respuesta en mano, agregá el nodo:
`${CLAUDE_PLUGIN_ROOT}/tools/exploracion.sh agregar .graph/exploracion.md
anomalía "<qué se intenta>" --esperado "<qué se esperaba>" --observado
"<qué se observó>" --bifurcacion a|b --origen "tarea <slug>"`.
**En modo no interactivo o `--gate-aprobado` sin quien responda (r10 —
corrección: detectar nunca puede ser peor que no detectar): NO se bloquea
ni se cierra la corrida.** Agregá el nodo directo con `--bifurcacion
pendiente` (sin preguntarle nada a nadie), procedé provisionalmente COMO
(a) (la rama conservadora: se sigue tratando el intento como si el error
fuera propio, nunca se asume conocimiento de dominio nuevo por criterio
propio, y nunca se corrige nada de fondo sin esa confirmación) y la
iteración siguiente CONTINÚA con normalidad. Degradación (cualquier modo)
SOLO si el tool no existe (mismo aviso de la Fase 1 de este documento); si
existe y falla, es error — bloqueá y citá el stderr. La Fase 8 lista todo
nodo `pendiente` en el Resultado del record y en `.graph/INDEX.md`
(`**Anomalías pendientes:** <n> — ver <record>`); el humano resuelve la
bifurcación fuera de banda.

## Fase 7 — sin pasos adicionales

La Fase 7 (Verificación final) no suma pasos propios de este régimen: la
tabla se completa igual que en `conocido` (ver Fase 7 de `SKILL.md`). Las
columnas de Preregistro (Diario, Fase 6) y la tabla de Anomalías (sección
`## Exploración`) se llenan al ejecutar, no acá; su cierre y su chequeo de
completitud ocurren en la Fase 8 (`validar`, punto 5 de abajo).

## Fase 8, punto 5 — Grafo de exploración

5. **Grafo de exploración** (`.graph/exploracion.md`, SOLO si
   régimen=`inexplorado` — en `conocido` este punto no existe, cero
   costo): escribí y cerrá los nodos de la corrida EN ESTE PUNTO (una sola
   vez, al cierre — no antes: `agregar` no tiene modo de edición, así que
   escribir todo junto acá evita nodos duplicados si la tarea se retomó a
   mitad de camino). Por cada captura que llegó al gate (elegida y
   descartadas por el HUMANO; las que el filtro de no-refutación o el
   chequeo recíproco ya descartaron antes de mostrarse NO entran acá —
   nunca llegaron a decisión humana), agregá un nodo `hipótesis`:
   `${CLAUDE_PLUGIN_ROOT}/tools/exploracion.sh agregar .graph/exploracion.md
   hipótesis "<resumen de la captura: rol + qué propone>" --preregistro
   "<para la elegida: el texto YA preregistrado en la tabla de Preregistro
   del record; para las descartadas: 'no aplica — descartada en el gate,
   no se implementó'>" --origen "tarea <slug>"` — guardá el `<id>` que el
   tool imprime a stdout (una línea). Con el `<id>` de la elegida, cerrala
   agregando un nodo `intento`: `... agregar .graph/exploracion.md intento
   "<resultado final>" --preregistro "<el mismo texto preregistrado>"
   --sostiene <id-hipótesis-elegida>` si el resultado la sostiene
   (convergió, ejemplo positivo GREEN, sin anomalía tipo (b) confirmada), o
   con `--refuta <id-hipótesis-elegida> --estado refutado --evidencia
   "<evidencia real>"` si (b) se confirmó (la expectativa estaba mal). Las
   descartadas quedan como nodo `hipótesis` sin arista de sostén — sin más
   acción. Las anomalías con bifurcación ya resuelta (a/b) durante la
   ejecución ya están en el grafo con esa bifurcación desde que se crearon
   (Tier M paso 4 de este documento / efecto #1 de `SKILL.md` — el tool no
   tiene modo de edición, así que no hay nada que "cerrar" en ellas acá);
   las que quedaron `pendiente` siguen `pendiente` — Fase 8 las LISTA
   (punto 1 de `SKILL.md`), no las resuelve. Mismo principio de
   re-normalización sin pérdida que el mapa de oráculo (Fase 8, punto 4 de
   `SKILL.md`) si el archivo crece más allá de una pantalla. **Antes de
   cerrar el record, corré
   `${CLAUDE_PLUGIN_ROOT}/tools/exploracion.sh validar .graph/exploracion.md`**
   (r10 §4): si no valida (rc≠0, gramática rota), es **bloqueo** — la Fase
   8 NO cierra la tarea hasta que el grafo vuelva a validar (arreglalo o,
   si la corrupción es previa a esta tarea, repórtalo como bloqueo
   explícito citando el diagnóstico de `validar`); nunca es un aviso que
   se ignora. **Degradación SOLO si
   `${CLAUDE_PLUGIN_ROOT}/tools/exploracion.sh` no existe todavía en este
   repo** (ninguna invocación de `agregar` o `validar` corrió en ninguna
   fase anterior de esta misma tarea): degradá con aviso, igual que en la
   Fase 1 (arriba) — dejá constancia y anotá el cierre directamente en el
   record; no bloquea esta fase. Si el tool SÍ existe (aunque sea alguna
   de sus invocaciones la que fallara en runtime): es error, nunca
   degradación silenciosa.

## Plantilla — sección `## Exploración` del record

Se inserta en el task record (plantilla completa de `SKILL.md`) entre
`## Intención capturada` y `## Efectos`, SOLO si régimen=`inexplorado` (en
`conocido` esta sección NO EXISTE en el record, ni el heading):

```markdown
## Exploración (SOLO si régimen=inexplorado — en `conocido` esta sección NO EXISTE en el record, ni el heading)
- Régimen: inexplorado — declarado vía: <--explorar | archivo gate-aprobado | cita textual del pedido>
- Chequeo recíproco entre las tres capturas (ANTES del filtro): <ningún par colapsado | "<rol> colapsó con <rol>: se presenta una sola">
- Capturas (cuota de rareza) — filtro de no-refutación aplicado (`exploracion.sh repite`, o degradado: <motivo>):
  - la obvia (ATRACTOR — rechazable SOLO con precedente local citado; si no, "sin atractor identificable"): <resumen> — <precedente: archivo/símbolo citado, o "sin atractor identificable"> — <sobrevivió | descartada: motivo> — nodo grafo: <id o "sin exploracion.sh">
  - la transferida: <resumen> — <sobrevivió | descartada: motivo> — nodo grafo: <id o "sin exploracion.sh">
  - la improbable: <resumen> — <sobrevivió | descartada: motivo> — nodo grafo: <id o "sin exploracion.sh">
  - Elegida en el gate: <cuál, o "ninguna sobrevivió — ver Hueco"> — nodo `intento` de cierre (Fase 8): <id, --sostiene|--refuta <id-hipótesis>>
- Preregistro (por intento, declarado ANTES de ejecutar — EXIGIDO, r10 §5: sin fila acá, Fase 8 no cierra):
  | intento | qué lo refutaría |
  |---|---|
- Anomalías (regla dura 8):
  | qué se esperaba | qué se observó | bifurcación (pendiente/a=error nuestro/b=expectativa equivocada) | resolución |
  |---|---|---|---|
```
