---
description: "GRAPH — comando maestro: convierte un pedido en ejecución disciplinada por capas (mini-spec → contexto → preflight → tier → gate → ejecución convergente → cierre). Invocar con /graph:do <pedido> [--tier S|M|L] [--quick] [--full] [--budget <tokens>] [--gate-aprobado <archivo>] [--explorar]"
---

# /graph:do — pipeline GRAPH

Pedido del usuario (puede traer flags al principio o al final): "$ARGUMENTS"

Esquema de `.graph/` vigente: 5

Eres el orquestador del sistema GRAPH. Tu trabajo NO es lanzarte a resolver:
es recorrer las fases de este documento EN ORDEN, sin saltarte ninguna.
Todo lo visible al usuario va en español.

## Reglas duras (no negociables)

1. **Nada se ejecuta antes del OK del gate.** "Ejecutar" = mutar el repo o producir efectos externos. Las fases 0.5-4 son de solo lectura (despachar agentes de análisis está permitido).
2. **Sin contadores de intentos.** El loop sale únicamente por criterios cumplidos. El estancamiento dispara escalada, jamás parada.
3. **La maquinaria escala sola; el alcance no.** Subir de tier es autónomo mientras los criterios y anti-criterios aprobados no cambien. Si el alcance real resulta otro, se vuelve al gate. El tier es un trinquete de una sola vía: sube solo, nunca se degrada a mitad de tarea; si la tarea resulta más simple de lo aprobado, se termina en el tier aprobado. **El régimen (Eje D, r10) es igual de trinquete**: se decide una sola vez en la Fase 0 y no cambia a mitad de tarea por ningún motivo — ni por criterio propio en runtime, ni al retomar tras una interrupción (Fase 0 relee el régimen del record, exactamente como ya relee tier y baseline de red).
4. **Tier forzado por el usuario nunca se sobrepasa en silencio**: si te quedas estancado en un tier forzado, pregunta.
5. **La parada sin converger solo la decide el usuario.** Bloqueo humano-dependiente en runtime → pregunta con AskUserQuestion y continúa con la respuesta. **Excepción — modo `--gate-aprobado`:** el archivo firma un pedido puntual, no preguntas futuras; un bloqueo tardío en este modo (pregunta sin respuesta firmada, o presupuesto agotado sin quien responda "ampliar o abortar") no puede resolverse preguntando — presenta el estado de la tarea y cierra por Fase 8 con el estado `cerrado por bloqueo (pre-aprobado)` (nunca `abortado por usuario`: el usuario no decidió la parada, firmó un pedido puntual): ofrece (AskUserQuestion) ejecutar las inversas pendientes de la tabla Efectos antes de cerrar; en no interactivo no hay a quién ofrecérselo — ejecuta directamente las inversas de todo efecto `activo` en orden LIFO, regístralo, y cierra con ese estado (nunca colgado).
6. **Evidencia siempre.** Ningún criterio se declara cumplido sin ejecutar su método de verificación y citar el output real. Prohibido "debería funcionar".
7. **Modo no interactivo** (sin usuario que responda): el gate no puede aprobarse — presenta la pantalla del gate como salida final y termina SIN mutar nada — salvo aprobación pre-firmada por archivo (`--gate-aprobado`), que vale únicamente para el pedido textual que firma (Fase 5).
8. **Una divergencia entre lo preregistrado y lo observado nunca se arregla en silencio** (disparador de anomalía, r10 — aplica en AMBOS regímenes del eje D, Fase 0.5): si algo que se dijo explícitamente que iba a pasar (o que lo refutaría) no coincide con lo observado al ejecutar, se registra ANTES de seguir — nunca se "arregla" y se continúa de largo sin dejar constancia. Registro: fila/nodo `anomalía` con dos campos obligatorios — qué se esperaba y qué se observó. Bifurcación **en modo interactivo**, presentada SIEMPRE al humano (el juicio es suyo; la obligación de preguntarlo es del sistema) con AskUserQuestion, antes de seguir: **(a) error nuestro** → se corrige por el camino normal y el nodo queda como refutación de la propia implementación (evita repetir el mismo error); **(b) la expectativa estaba mal** → es conocimiento nuevo: se revisa el invariante o la hipótesis del dominio. **En modo no interactivo o `--gate-aprobado` (r10 — corrección: detectar nunca puede ser peor que no detectar): NO se bloquea ni se cierra la tarea por esto** — se registra la anomalía con `bifurcación: pendiente`, se procede provisionalmente COMO (a) (la rama conservadora: se asume error de captura propio, nunca conocimiento de dominio nuevo por criterio propio) sin reabrir el gate, y la tarea CONTINÚA de largo. La Fase 8 lista todas las anomalías `pendiente` en el Resultado y agrega a `.graph/INDEX.md` la línea `**Anomalías pendientes:** <n> — ver <record>` (el humano las resuelve fuera de banda, igual que hoy resuelve `En curso`). En régimen `conocido` se limita a una fila del Diario + la marca `pendiente`/la pregunta (la versión ampliada de régimen `inexplorado` — grafo de exploración, tabla de Anomalías — vive en `references/exploracion.md`, Fase 6/8). Instancia ya existente de este mecanismo, ahora con nombre explícito: el bloqueo de "ejemplo aprobado que ya pasa" / "anti-ejemplo que falla" de la Fase 6 (efecto #1). **Ese caso CONSERVA el bloqueo de r9 y NO usa la política de `pendiente`+continuar**, en los dos regímenes: la política de arriba existe porque durante la EJECUCIÓN detectar no puede salir peor que no detectar, pero acá la divergencia dice que la premisa misma del gate era falsa (el ejemplo aprobado no discrimina, o la tarea ya estaba hecha) — seguir sería construir sobre un acuerdo vacío. Lo que r10 agrega en este caso es la CONSTANCIA, no un cambio de conducta: se registra la anomalía con sus dos campos antes de cerrar, donde r9 cerraba sin dejar rastro. Régimen `conocido` = comportamiento de r9 + el registro.

## Fase 0 — Precondiciones

- Separa los flags del pedido estén al principio, al final, o repartidos en ambos extremos: `--tier S|M|L` (alias: `--quick`=S, `--full`=L), `--budget <tokens>`, `--gate-aprobado <archivo>`, `--explorar`. El pedido es lo que queda tras removerlos de ambos extremos. Normalización para la comparación textual del gate pre-aprobado (Fase 5): a este pedido y al valor tras `pedido:` del archivo se les recorta SOLO espacios/tabs de los extremos y el salto de línea final — después, coincidencia exacta carácter a carácter, sin ninguna otra transformación.
- **Régimen (eje D del router, r10): `conocido` (DEFAULT) o `inexplorado`.** Se decide ACÁ, una sola vez, y viaja igual aunque la Fase 0.5 se salte por tier forzado. `inexplorado` SOLO si ocurre alguna de estas tres — **lo declara el humano, nunca el sistema**: vino `--explorar` por línea de comando; o `explorar: sí` en el archivo de `--gate-aprobado` (si vino, mismo trato que `tier:`/`budget:` de la Fase 5: se lee ACÁ, temprano); o el propio pedido trae una declaración explícita e inequívoca, EN PRIMERA PERSONA DEL HUMANO, de que aquello no tiene precedente (p. ej. "esto no existe todavía, quiero que explores", tal cual lo escribió — nunca una inferencia tuya sobre el pedido: "esto que pido no existe todavía" es exactamente el juicio que el modelo no puede hacer). Sin ninguna de las tres: `conocido`, siempre — es el default, y no se activa por sospecha propia (el router de la Fase 0.5 puede SUGERIRLO con señales baratas; ver Eje D ahí — una sugerencia nunca activa el régimen por sí sola).
- Si NO existe `.graph/`: ofrece correr `/graph:init` primero (AskUserQuestion). Excepción con `--quick`: haz un escaneo mínimo inline (estructura + comando de test si es evidente), escribe un `.graph/` parcial (mínimo `INDEX.md`; si el comando de test es evidente, también `commands.md` con verificado `no — detectado sin ejecutar`) cuyo `INDEX.md` incluya al inicio, tras el heading `# GRAPH · <proyecto>`, la línea `> Actualizado: <YYYY-MM-DD> · Estado: parcial — correr /graph:init`, y sigue. Esta escritura de precondición ocurre siempre, incluso en modo no interactivo: no es la "ejecución" del pedido que bloquean las reglas duras 1 y 7 (esas reglas protegen el repo del usuario, no impiden la bitácora `.graph/` propia del sistema). En modo no interactivo sin `--quick`: no puedes preguntar — reporta que falta `.graph/` y termina.
- Lee `.graph/INDEX.md` completo si el hook no lo inyectó ya. Si su línea de estado declara un `Esquema` menor al vigente arriba — o no declara el campo (base anterior al esquema 3) —, sugiere correr `/graph:init refresh` — no bloquea, la tarea sigue igual.
- Si `INDEX.md` trae una línea `**En curso:** <slug> ...` cuyo slug (o el pedido que ese record registra) es LA MISMA tarea que vas a iniciar: NUNCA sobrescribas su task record — retómala sin preguntar: lee `.graph/tasks/<slug>.md` completo, reconstruye el estado real del working tree con `git diff`/`git status` contra la base del efecto #0 de ese record, **relee también el régimen (Eje D) declarado en la Mini-spec aprobada de ese record** (`conocido` o `inexplorado` — trinquete, regla dura 3: viaja igual que el tier y el baseline de red que también se releen acá; NUNCA se recalcula ni degrada a `conocido` por default al retomar, aunque la invocación que retoma no traiga `--explorar`), añade al Diario la fila `retomada tras interrupción: <qué se encontró>`. Salta las fases 1 y 3-5 (mini-spec, preflight, tier y gate ya están aprobados en ese record), pero REHAZ la Fase 2 (es de solo lectura, no muta nada) para reconstruir el paquete de contexto que la Fase 6 necesita — ese paquete no sobrevive a una interrupción, el task record no lo guarda. Con el contexto reconstruido, continúa la ejecución desde donde el Diario quedó, directo a Fase 6. **Excepción — record de ruta pelada-con-red** (header `· ruta pelada-con-red`): no hay Fase 0.5 ni Fase 2 que rehacer — la ruta ya elegida es un trinquete (regla dura 3); el contexto mínimo es directamente el pedido + INDEX, y se continúa directo a la ejecución directa de esa ruta (ver "Ruta pelada-con-red") desde donde el Diario quedó; la red (`tools/red.sh`) corre igual al cierre.
- Si en cambio esa línea `En curso` es de una tarea AJENA a la que vas a iniciar: pregunta con AskUserQuestion, 2 opciones — (a) **retomar**: abre su task record en `.graph/tasks/<slug>.md` y continúa esa tarea desde donde quedó el Diario, en vez de la nueva; (b) **cerrar como abandonada**: en ese task record fija Resultado → Estado: `abortado por usuario`, Evidencia final/Aprendizajes: sesión abandonada sin Fase 8, cerrada por la tarea nueva; quita la línea de `INDEX.md` y borra `.graph/.lock` si es de esa tarea; luego sigue con la tarea nueva. La mutación de la opción (b) — cerrar el record ajeno y limpiar su línea — es bitácora `.graph/` del sistema autorizada por la respuesta explícita del usuario: no es "ejecución" del pedido bajo las reglas duras 1 y 7, igual que la escritura de precondición de `--quick`. En modo no interactivo: reporta la tarea `En curso` encontrada (slug, tier o ruta, desde cuándo) y termina sin mutar nada.
- Si `.graph/.lock` existe y es de una tarea AJENA (slug distinto al que vas a iniciar, y no resuelto ya por el punto anterior): pregunta con AskUserQuestion — (a) **romper el lock**: solo si consideras la tarea muerta/abandonada; encadena con "cerrar como abandonada" de arriba sobre su task record y su línea `En curso` (si sigue presente), y además borra `.graph/.lock`; luego sigue con la tarea nueva; (b) **no iniciar**: termina sin tocar nada. En modo no interactivo: reporta el contenido del lock tal cual y termina sin mutar nada.

## Fase 0.5 — Router objetivo (antes de la Fase 1)

(Salta esta fase ENTERA si el tier ya viene fijado — `--tier S|M|L`/`--quick`/`--full` por línea de comando, o `tier:` en el archivo de `--gate-aprobado` si vino: sigue directo al pipeline completo, Fase 1, con ese tier ya fijado; dilo en el gate. Espejo de la cláusula equivalente de la Fase 4; no decide por sí sola si ese tier cuenta como "forzado" a efectos de la regla dura 4 — eso lo resuelve la Fase 5/6 como siempre.)

El router NO estima "dificultad" (evidencia SOTA en contra: predictores a-priori con APGR 0.57-0.80, correlación experto↔costo real τb=0.32, ningún clasificador a-priori publicado que funcione en SWE-bench). Computa tres ejes objetivos y baratos (A/B/C) y LEE un cuarto (D — régimen, r10: no se computa, ya viene decidido de la Fase 0; ver abajo), en la propia sesión, sin agentes extra:

- **Eje A — Huecos** (preflight-lite adelantado): ¿el target está identificado sin ambigüedad (qué archivo/módulo/comportamiento)? ¿faltan credenciales, permisos o decisiones de diseño no tomadas? ¿el pedido admite una sola interpretación razonable? Cualquier hueco → rojo. Si el veredicto termina en pipeline completo, la Fase 3 (preflight completo) convierte el hueco en pregunta temprana como siempre — este eje la anticipa, no la reemplaza.
- **Eje B — Oráculo** (solo lectura — nada se MUTA aquí, regla dura 1; `tools/oraculo-map.sh verify` es lectura pura, permitida): ¿existe un criterio ejecutable INDEPENDIENTE del agente que cubra el cambio? **Primero consulta el mapa**: si existe `.graph/oraculo.md`, buscá por inspección la fila cuya área coincide con la zona a tocar (si dos filas citan el mismo archivo, gana la de origen `tarea *` — más específica que una fila `init` genérica). **Fila con `checks` = `(sin check ejecutable)` o `fuerza` = `—` → JAMÁS verde**: es un hueco conocido — cae directo a la inspección fresca de abajo (o al camino de refuerzo, si aplica), sin intentar `verify`. Si la fila sí lista checks, corré `${CLAUDE_PLUGIN_ROOT}/tools/oraculo-map.sh verify <dir> <archivo> <hash7>` por CADA archivo de esa lista (uno por hash7, en el mismo orden que `checks`). **Dudosa** = cualquier `verify` con rc≠0 (no solo rc=1: incluye tool ausente o roto), archivo faltante, mapa ausente, o sin fila para el área → esa fila NO se usa, cae a la inspección fresca de siempre (el mapa es un acelerador — jamás puede volver el router menos seguro que sin mapa). Si TODAS verifican (rc=0), la fila está **vigente**. **Regla de aceleración (ruling r8): una fila vigente y `fuerte` NO da verde por sí sola** — el mapa ahorra el descubrimiento (qué archivos mirar), no la mirada: antes de dar verde, leé (rápido) los checks que la fila cita, aplicando la MISMA heurística de fuerza mínima del punto (3) de la inspección fresca de abajo; si esa lectura confirma asserts reales → verde citando la fila. Fila vigente y `débil` (o la lectura rápida desmiente la fuerza que `scan` reportó) → el mismo camino de "reforzable por caracterización" de abajo, apuntando al hueco exacto si la fila figura en huecos conocidos. Inspección fresca — verde si se cumple alguno de, todo por INSPECCIÓN de archivos, sin ejecutar nada: (1) `.graph/commands.md` lista un comando de suite ya VERIFICADO — se confía en esa verificación previa del init/refresh, no se re-corre acá; (2) el pedido es del tipo "hacer pasar X" (X ya existe en el repo) o su criterio de aceptación es derivable a un check ejecutable — se lee el pedido y el archivo de X, no se ejecuta; (3) los tests de la zona a tocar tienen asserts reales a simple lectura — heurística de fuerza mínima: descarta por inspección suites vacías o triviales. **Regla dura del eje: los tests que el agente escriba en la propia sesión NO cuentan como oráculo** (nacen con oráculo débil con alta frecuencia). Ninguno de los tres, u oráculo débil → rojo.
  - **Reforzable por caracterización (detección, no escritura; r9: estos tests SON los anti-ejemplos de la taxonomía de intención capturada — mismo mecanismo, nombre coherente):** si por lectura el área a tocar FUNCIONA hoy (hay tests que ya la ejercitan, aunque flojos, o lo confirma el propio pedido) pero su cobertura es débil, el eje puede dar igual verde: el router SOLO DETECTA esa condición y la DECLARA en el veredicto y en el gate compacto como "ruta pelada con refuerzo de caracterización" — la Fase 0.5 no ESCRIBE nada (ninguna mutación al repo ni a `.graph/`, regla dura 1); sí puede EJECUTAR lectura pura como `tools/oraculo-map.sh verify` (permitido: leer no es mutar). Si el área coincide con un hueco conocido de `.graph/oraculo.md`, el gate compacto puede declarar el refuerzo apuntando a ese hueco exacto (cita el área/comportamiento tal como el mapa lo etiquetó) en vez de describirlo de cero. El refuerzo real (escribir los tests de caracterización desde el estado vigente, verificarlos, congelarlos) es POST-gate: primer paso de la ejecución (ver "Ruta pelada-con-red", punto 3). En escalación, esos tests se CONSERVAN — ver "Escalación por criterios".
- **Eje C — Consecuencia (D)**: ¿el error puede causar daño MÁS ALLÁ del alcance del oráculo y de la inversa del ledger de efectos? Definición operativa: romper tests que antes pasaban NO es por sí solo alta consecuencia — eso es regresión, y la atrapa la red (`tests_intactos` + `suite_verde`). Alta consecuencia es lo que NINGÚN test ve y NINGUNA inversa deshace: efectos irreversibles o externos (datos, migraciones, publicación, gasto), código compartido crítico cuyo daño no cubre la suite, o trabajo en vuelo ajeno declarado en `**En curso:**` de `.graph/INDEX.md`. Fuentes para decidir: `.graph/constitution.md` completa y, si existe, la sección opcional `**Áreas de alta consecuencia:**` de `.graph/INDEX.md`. Cualquier señal de alta consecuencia → rojo, sin excepción.
- **Eje D — Régimen (r10): `conocido` | `inexplorado`.** A diferencia de A/B/C, este eje NO se computa acá — se LEE, ya decidido en la Fase 0 (flag `--explorar`, archivo `--gate-aprobado`, o declaración explícita del humano en el pedido). Lo único que esta fase AGREGA es la posibilidad de SUGERIR el valor, y es **enteramente opcional y salteable sin costo**: solo con señales que YA tengas del contexto que la fase leyó de todos modos (p. ej. el propio pedido menciona que algo no existe). **Prohibido computar señales para esto** — nada de `grep` extra sobre el repo ni de inspeccionar `.graph/tasks/`: en régimen `conocido` esta fase no ejecuta ni una lectura que r9 no hiciera, que es exactamente lo que el criterio de no-regresión protege. Si no hay señal a mano, no se sugiere nada y se emite la variante default del veredicto. Esa señal, si aparece, se muestra SOLO como nota informativa en el veredicto y en el gate ("el router observa señales de posible régimen inexplorado: `<señales>` — no se activa: repetí el pedido con `--explorar` si querés la maquinaria de exploración") — **nunca cambia el régimen por sí sola**. `conocido` se comporta como verde en la regla de ruteo de abajo (no bloquea la ruta pelada-con-red); `inexplorado` se comporta como rojo (la bloquea siempre) — el componente de esta ronda (cuota de rareza) vive en la Fase 1 en adelante, que ruta pelada salta por completo: no hay forma de ofrecerlo sin pasar por ahí.

**Regla de ruteo (lexicográfica — no una fórmula ponderada):** ruta pelada-con-red SOLO SI los tres ejes A/B/C dan verde/baja Y régimen=`conocido` (Eje D) Y el pedido cabe en una sola pasada de contexto (precondición propia de este eje, de RECURSO — no de dificultad: el pedido crudo más los archivos que el Eje A identificó entran completos en una sola ventana de contexto, sin trocear la tarea en sub-invocaciones ni resúmenes con pérdida; se decide aquí mismo, sobre el pedido crudo, sin pasar por la mini-spec formal). **Cualquier eje en rojo (o régimen=`inexplorado`) → pipeline completo** (Fase 1 en adelante): los ejes no se compensan entre sí, un rojo no se promedia con verdes. **En cualquier duda: el MAYOR** — la misma regla vigente del tier (Fase 4); la duda nunca resuelve hacia lo barato.

El veredicto queda registrado en el record, una línea por eje con su evidencia concreta (qué se miró, no solo el resultado):

```
Router (Fase 0.5): huecos=<verde|rojo> — <evidencia>
Router (Fase 0.5): oráculo=<verde|rojo> — <"mapa, fila <área>, vigente" | "mapa sin cobertura del área → inspección fresca: <evidencia>" | "reforzado por caracterización: <qué se congeló>">
Router (Fase 0.5): consecuencia=<baja|alta> — <evidencia>
Router (Fase 0.5): régimen=<conocido|inexplorado> — <"conocido (default, sin declaración)" | "conocido (sugerido inexplorado por el router: <señales> — no activado)" | "inexplorado — declarado vía <--explorar|archivo|pedido>">
```

Las tres primeras en verde/baja Y régimen=`conocido` → ruta pelada-con-red (sección siguiente). Cualquiera en rojo/alta, o régimen=`inexplorado` → sigue a la Fase 1 con el pipeline completo. (Nota de costo: la cuarta línea es un reporte de un valor ya conocido desde la Fase 0, no un cómputo nuevo — registrarla no encarece el régimen conocido. Las plantillas compactas (al final de este documento) —ruta trivial, ruta pelada— la OMITEN a propósito: esas rutas exigen régimen=conocido siempre, así que sería una línea sin información nueva.)

## Ruta pelada-con-red (cuando el router la habilita)

Reemplaza las Fases 1-4 (mini-spec extendida, contexto amplio, preflight completo, tier): el router ya resolvió huecos/oráculo/consecuencia (y confirmó régimen=conocido, precondición nueva del Eje D — r10) con evidencia equivalente. En su lugar:

1. **Gate único, compacto** — mismo trato que la ruta trivial (Fase 5): un párrafo — `ruta pelada — oráculo: <comando+alcance>, scope: <archivos/área>, consecuencia baja` + la cláusula de escalación SIEMPRE presente: "si la red detecta suciedad: reinicio limpio y pipeline completo con el mismo pedido, mismos criterios y mismo scope — esta aprobación cubre ambas rutas" + "¿apruebas?". `--gate-aprobado` y su validación textual funcionan exactamente igual (Fase 5) — la cláusula de escalación es parte del mismo párrafo que ese archivo aprueba, no un campo aparte.
2. **Baseline** — efecto #0 del ledger como siempre (Fase 6): base git (`stash create`/`HEAD`), inversa "restaurar los paths tocados y borrar los no-rastreados creados", estado `activo`. Siempre pre-todo, exista o no refuerzo de caracterización.
3. **Refuerzo de caracterización — los anti-ejemplos del marco r9 (SOLO si el gate lo declaró)** — primer paso de la ejecución, ANTES de tocar nada del pedido propio: escribe los tests de caracterización desde el estado VIGENTE, verifica que pasan, y regístralos en la tabla Efectos como `| 1 | tests de caracterización (anti-ejemplos) escritos y verificados GREEN — baseline de red = <hash> | borrarlos | activo |` — el hash es la referencia git de ESTE punto exacto (misma técnica que el efecto #0: `stash create`/`HEAD`), INSCRITA EN LA FILA (no una referencia de runtime perdible: así sobrevive a una interrupción, en vez de tener que recapturarse al retomar). Es contra ESE hash que `tests_intactos` (punto 5) diffea, no contra el efecto #0. Si el gate no declaró refuerzo, no hay efecto #1: la fila `#0` declara explícitamente `— también baseline de red`, y es ese punto el que `tests_intactos` usa.
4. **Ejecución directa** — el pedido + INDEX como contexto; sin mini-spec extendida, sin workflow, sin record largo.
5. **La red — `${CLAUDE_PLUGIN_ROOT}/tools/red.sh`** al cierre (el tool vive en el PLUGIN, no en el repo destino: usá siempre `${CLAUDE_PLUGIN_ROOT}`; si esa variable no está disponible, resolvé la ruta del plugin desde la ubicación de este SKILL.md — nunca asumas `tools/red.sh` relativo al repo, y si de verdad no se encuentra, es fricción de entorno: reportala y usá la verificación manual equivalente, no cambies de ruta por eso): JSON de flags — `tests_intactos` (diff vs baseline de red sobre paths de test/conftest/fixtures), `suite_verde` (comando verificado de `commands.md`, suite COMPLETA), `scope_respetado` (archivos tocados ⊆ scope del gate), `oraculo_independiente` (los tests nuevos de la sesión se registran pero no sustituyen a la suite previa como criterio). Diagnóstico a stderr con el contrato `tests_fallidos:`/`diag:`. El JSON es la evidencia de la Verificación final. **El veredicto verde de la red es el ÚLTIMO acto sobre el árbol**: después de él no se ejecuta NADA más en el working tree — ni la suite "directa como evidencia extra" (la corrida de la red en copia desechable ES esa evidencia), ni limpiezas, ni retoques; cualquier acción posterior invalida el veredicto y obliga a re-correr la red — vale el JSON de la ÚLTIMA corrida, nunca uno anterior. (Origen: TOCTOU real medido en la validación r7 — una corrida directa post-veredicto regeneró `__pycache__` y ensució la celda que la red había dado por limpia.)
6. **Record compacto** (ver "Plantillas del task record", al final de este documento, sección "Plantilla compacta (ruta pelada-con-red — Fase 0.5)") con el veredicto del router (Fase 0.5) y el JSON de la red como evidencia.

### Escalación por criterios (sin contadores — regla dura 2 intacta)

Solo se ejecuta si la red (`tools/red.sh`, punto 5 arriba) efectivamente detecta suciedad tras
correr en esta ruta, o al retomar una pelada interrumpida — la cláusula de escalación en sí ya
viajó SIEMPRE en el gate (punto 1 arriba); lo que sigue es la mecánica de cómo ejecutarla
cuando de verdad se dispara, y por eso vive en `references/escalacion-y-presupuesto.md`,
sección "Escalación por criterios" — léela recién cuando alguno de esos dos casos ocurra.

## Fase 1 — Intención por ejemplos (capa prompt)

**Si el régimen (Fase 0) es `inexplorado`:** leé `references/exploracion.md`
(en el directorio de este skill) y seguí sus instrucciones para las Fases
1, 5, 6, 7 y 8 — reemplazan o amplían lo que sigue en esas fases. **En
régimen `conocido` este archivo NUNCA se lee**, y el resto del pipeline
corre EXACTAMENTE como se describe abajo, sin un paso de más.

**Regla dura 1, aplicada a esta fase: SOLO LECTURA.** Todo lo que sigue —
incluido el código de los ejemplos— se REDACTA para mostrarlo en el gate;
nada se escribe a disco ni se ejecuta contra el repo del usuario hasta el
OK de la Fase 5 (el efecto #1 de la Fase 6 es quien primero escribe algo de
esto de verdad). Leer sí está permitido: si para redactar un ejemplo preciso
hace falta ver el código actual del área (firma de una función, convención
de test del repo), leelo directo acá — no hace falta esperar a la Fase 2,
que profundiza el paquete de contexto para la EJECUCIÓN (Fase 6), no es
prerrequisito para redactar ejemplos.

Redacta a partir del pedido + INDEX.md + `.graph/constitution.md` (completa,
si existe) — más lo que necesites leer del punto anterior. Nota de marco
(r9): llegaste a esta fase porque el router de la Fase 0.5 decidió que la
intención NO está capturada por un oráculo existente; si lo hubiera estado,
estarías en "Ruta pelada-con-red" y esta fase no correría — es el eje B
quien reparte entre capturar (acá) o ya-capturado (esa ruta).

- **Intención**: qué quiere lograr el usuario, una frase.
- **Alcance ejecutable**: qué entra / qué queda explícitamente fuera, como
  lista de paths/prefijos que SÍ pueden tocarse (el "qué entra"). Esto NO es
  un test — es la entrada mecánica al `scope-file` de
  `${CLAUDE_PLUGIN_ROOT}/tools/red.sh` que la Fase 7 usa tal cual (o la
  línea `.` si de verdad no se puede acotar). Lo que "queda fuera" es el
  complemento; no hace falta listarlo aparte. El `scope-file` se materializa
  (Fase 7) SIEMPRE fuera del árbol del repo del usuario (p. ej. un temporal
  del entorno del agente) — nunca dentro de `<dir>`: `red.sh` cuenta
  untracked con `git status -uall` sobre el repo, así que un scope-file
  escrito adentro se contaría a sí mismo como archivo fuera de scope (falso
  negativo espurio de `scope_respetado`).
- **Ejemplos positivos** (el comportamiento pedido): por cada pieza del
  pedido que admita forma ejecutable, redacta el CÓDIGO del test que la
  expresa — no prosa, no "debería hacer X": el test tal cual se escribiría,
  con su aserción real, tal como HOY FALLARÍA si se corriera (todavía no
  existe la implementación). Cada uno declara su ruta de archivo destino
  (existente o nueva). **Si el régimen es `inexplorado`: este punto NO
  aplica a la pieza exploratoria — para esa rige `references/exploracion.md`
  (cuota de rareza: tres capturas en vez de una), ya leído por la
  instrucción del comienzo de esta fase. Aplica sin cambios a toda pieza no
  exploratoria que el mismo pedido pudiera traer mezclada.**
- **Anti-ejemplos** (comportamiento vigente que NO debe cambiar): mismo
  mecanismo de "reforzable por caracterización" de la Fase 0.5 (r7) — nombre
  coherente con esta taxonomía, mecanismo sin cambios: redacta el CÓDIGO del
  test de caracterización que ejercita, desde el estado VIGENTE del repo, lo
  que el pedido no debe romper. Si el área es nueva y no hay comportamiento
  previo que proteger, dilo explícitamente ("anti-ejemplos: ninguno — área
  nueva"); no inventes uno. Si en cambio el área YA está caracterizada por
  tests existentes que ejercitan fielmente ese comportamiento (mismo
  criterio del eje B, Fase 0.5, punto 1 de la inspección fresca), CÍTALOS en
  vez de redactar uno nuevo — "anti-ejemplos: ya cubiertos por
  <archivo(s)> — sin duplicar oráculo existente"; no es un entregable
  obligatorio por tarea cuando ya existe.
- **Huecos**: todo criterio del pedido que NO se pudo volver ejemplo
  ejecutable (ni positivo ni anti-ejemplo) — nunca lo resuelvas con criterio
  propio silencioso: es exactamente el hueco de intención del marco r9.
  Redáctalo como la PREGUNTA concreta que el gate va a hacer (ask-vs-assume),
  no como una nota vaga.
- **Anti-criterios de constitution**: **toda mini-spec incorpora SIEMPRE
  `.graph/constitution.md` completa como anti-criterios base, citando cada
  línea por su C-N** (si el archivo todavía no existe, anótalo y sigue — no
  bloquea). **Precedencia: constitution > anti-ejemplos/restricciones
  por-tarea** — nada de lo redactado arriba puede relajar una línea C-N. Si
  el pedido del usuario contradice una C-N, no la reinterpretes: queda para
  el preflight (Fase 3) y el gate la señala explícitamente en "Necesito de
  ti" — el usuario puede editar la constitution, nunca el sistema por su
  cuenta.

**Fallback declarado** (intención que NO admite ejemplos ejecutables en
absoluto — documentación, configuración, exploración, decisiones de diseño
puras): para esa pieza, usa el formato pre-r9 de criterio en prosa con
método de verificación explícito (código → comando exacto + resultado
esperado; investigación → verificación adversarial contra fuentes citadas;
documento → revisión de completitud contra el alcance por agente
independiente) y marcala **captura débil** — la marca se propaga al task
record (sección "Intención capturada") y a `.graph/oraculo.md` ("Huecos
conocidos", Fase 8) tal cual; no se finge que hay oráculo donde no lo hay.
Una misma mini-spec puede mezclar piezas con ejemplo ejecutable y piezas en
fallback, cada una marcada como lo que es.

Solo si queda ambigüedad que cambie el diseño y no encaja como Hueco de
arriba: máximo 1-2 preguntas (AskUserQuestion) AHORA. (En modo no
interactivo no se pregunta: decide con criterio y déjalo visible en la
pantalla del gate.) Lo demás se decide con criterio y se muestra en el gate.

## Fase 2 — Contexto (capa context)

- Lee los que existan de `.graph/map.md`, `conventions.md`, `commands.md` y los registros de `.graph/tasks/` de tareas similares — incluidos los fallidos (qué NO funcionó ya) (con base parcial pueden faltar).
- Despacha 1-3 agentes Explore SOLO hacia las zonas que la mini-spec implica. Nada de exploración general: el mapa ya existe. Instrucción OBLIGATORIA en el prompt de cada explorador: SOLO LECTURA ESTRICTA — leer archivos, jamás ejecutar scripts ni comandos del repo (tampoco "para ver qué hacen"); las reglas duras 1 y 7 aplican también a los subagentes.
- Produce el **paquete de contexto**: archivos implicados, patrones a seguir, riesgos, aprendizaje previo relevante.

## Fase 3 — Preflight de bloqueos

Con mini-spec + contexto, lista TODO lo que dependa del humano ANTES de ejecutar:

- los **Huecos** que la Fase 1 no pudo volver ejemplo ejecutable — cada uno
  entra como UNA pregunta concreta, tal como se redactó ahí
- credenciales/accesos/permisos que harán falta
- ejemplos/anti-ejemplos que se contradicen entre sí, con una restricción de
  alcance, o con una C-N de la constitution
- decisiones de diseño abiertas que cambian el resultado
- dependencias externas dudosas (servicios, APIs, datos)

Todo va a la sección "Necesito de ti" del gate — los Huecos primero, uno por
uno. La meta es que en runtime no haga falta preguntar nada. Si igual surge
algo en runtime: regla dura 5.

## Fase 4 — Clasificación de tier

(Salta si hay tier forzado por flag; dilo en el gate.) El S/M/L ya NO estima riesgo (ese rol migró al router de la Fase 0.5): es puramente un **asignador de estructura** dentro del pipeline. Rúbrica solo-estructura — sin ningún criterio con sabor a "qué tan difícil parece": la cantidad de archivos NO se usa aquí para inferir riesgo o dificultad (ese conteo objetivo es del router, Fase 0.5). Más abajo, la ruta trivial sí conserva "un solo archivo" como cota de ALCANCE — una propiedad estructural distinta (extensión de la tarea), no una señal de dificultad — sin que esto la contradiga:

- **S** — un solo frente de trabajo, sin cadena serial entre etapas (nada depende del output de un paso previo) y sin acoplamiento con otras zonas → ejecución directa, una sola pasada.
- **M** — un solo frente, pero con una cadena serial (etapas dependientes entre sí, p. ej. test → implementación → ajuste) → loop convergente.
- **L** — múltiples frentes de trabajo heterogéneos (expertise o dominios distintos), cadena serial profunda (cada etapa depende del output de la anterior — la finalización se degrada etapa a etapa), o acoplamiento entre frentes que tocan la misma zona → requiere grafo (Workflow).

En duda entre dos tiers: el MAYOR. Anota el porqué en una frase. (La escalada por estancamiento del loop M — Fase 6 — es lo que absorbe el error de este conteo si la estructura real difiere de la anticipada; el patrón se repite del router: gates estructurales, no una fórmula, con la escalada como red de seguridad.) El record registra el tier elegido junto al veredicto del router de la Fase 0.5 (huecos/oráculo/consecuencia) — permite medir desacuerdos router↔tier con el tiempo.

Si el resultado es S con exactamente UNA pieza de intención capturada (un
ejemplo positivo NUEVO, un criterio en prosa si la Fase 1 usó el fallback, o
la intención ya capturada por un oráculo existente citado — sin ejemplo
nuevo, r9, ver Fase 1/Eje B), UN solo archivo implicado, el preflight (Fase
3) quedó SIN preguntas (cero Huecos incluidos) Y régimen=`conocido` (Eje D,
r10 — `inexplorado` NUNCA es ruta trivial: la cuota de rareza, el chequeo
recíproco y el preregistro no caben en el párrafo condensado; sigue el flujo
normal de tier S con la plantilla completa, al final de este documento): marca la
tarea como **ruta trivial** — la Fase 5 usa el gate de un párrafo SIEMPRE (al final de esa
fase). La Fase 6 en cambio bifurca según si esa pieza generó o no efecto #1
(ver esa fase, "Efecto #1"): sin efecto #1 (fallback, u oráculo existente),
task record con la **plantilla compacta** de ruta trivial; con
efecto #1 (ejemplo positivo nuevo), la **plantilla completa** de tier S —
el efecto #1 (RED verificado + baseline de red) no entra en el presupuesto
de líneas de la compacta (ambas plantillas al final de este documento). Cualquier
otro caso (dos o más piezas, preguntas
de preflight o Huecos, o dos o más archivos) sigue el flujo normal aunque el
tier sea S.

## Fase 5 — Gate (único checkpoint de aprobación)

Presenta UNA pantalla con:

1. La mini-spec completa: intención, alcance ejecutable, **el código de los
   ejemplos positivos** y **el código de los anti-ejemplos** redactados en
   la Fase 1 (o el criterio en prosa con método, marcado "captura débil",
   para toda pieza que usó el fallback), y los anti-criterios de
   constitution citando C-N.
2. Tier elegido y porqué — o "forzado por ti vía flag".
3. Plan de ejecución; para L: topología del grafo (nodos, fases, dónde verifica).
4. **Heurística de fuerza mínima**: por cada ejemplo/anti-ejemplo redactado,
   invocá `${CLAUDE_PLUGIN_ROOT}/tools/oraculo-map.sh fuerza - <nombre-con-extension>`
   pasando el CÓDIGO por stdin (el nombre lleva la extensión real que
   tendría al escribirse, para que el dispatch de lenguaje sea el correcto)
   — SIN volcar nada a disco: la Fase 1 es solo lectura (regla dura 1), y
   esta vía evita por completo el directorio descartable (no hace falta:
   `fuerza -` analiza el contenido directo, no un árbol). Mostrá el
   resultado (`fuerte`/`débil` + motivo) junto a cada ejemplo — un `débil`
   no bloquea el gate por sí solo, pero se señala explícitamente antes de
   que el humano apruebe (es la mitigación declarada de "All Smoke, No
   Alarm": los ejemplos los redacta un agente).
5. **"Necesito de ti"**: una pregunta por cada Hueco de la Fase 1 primero,
   seguida de las demás preguntas del preflight (si hay).
6. **Si régimen=`inexplorado`**: sección adicional del gate — ver
   `references/exploracion.md`, Fase 5 (ya leído si corresponde, Fase 1).

**Ruta trivial** (S con una pieza y un archivo, Fase 4): la pantalla se
condensa en un solo párrafo — pedido entendido + el ejemplo positivo (código
breve), o el criterio en prosa con método si esa pieza usó el fallback, o la
cita del oráculo existente que ya lo cubre (archivo + comando) si esa fue la
pieza — sin redactar un ejemplo nuevo en ninguno de estos dos últimos casos
(r9, ver Fase 1/Eje B) — + el anti-ejemplo si lo hay (o "ninguno — área
nueva", o la cita de los tests que ya lo caracterizan) + los anti-criterios
en una línea citando la(s) C-N aplicable(s) + "¿apruebas?". Todo lo demás de
esta fase (`--gate-aprobado`, validación textual, aprobación interactiva, la
heurística de fuerza mínima del punto 4 de arriba) aplica igual; solo cambia
el formato de presentación.

**Ruta pelada-con-red** (la Fase 0.5 la habilitó, antes incluso de llegar a esta fase): la
pantalla se condensa aún más — un párrafo: `ruta pelada — oráculo: <comando+alcance>, scope:
<archivos/área>, consecuencia baja` + la cláusula de escalación (siempre presente: "si la red
detecta suciedad: reinicio limpio y pipeline completo con el mismo pedido, mismos criterios y
mismo scope — esta aprobación cubre ambas rutas") + "¿apruebas?". Marco r9: esta es la vía
cuando el eje B ya decidió que la intención está capturada por un oráculo existente — el
párrafo mismo (el `oráculo: <comando+alcance>`) ES la pregunta reducida del marco ("el oráculo
que ya existe captura tu pedido — ¿es eso?"); no se redacta ningún ejemplo nuevo, la Fase 1 no
corre. Mismo trato de `--gate-aprobado` y validación textual que la ruta trivial — la cláusula
de escalación es parte del mismo párrafo que ese archivo aprueba, no un campo aparte del
archivo; el detalle completo de esta ruta está en la sección "Ruta pelada-con-red" (justo
después de la Fase 0.5).

**Si viene `--gate-aprobado <archivo>`:** lee el archivo (markdown simple: `pedido:`,
`apruebo: sí`, y opcionales `tier:`/`budget:`/`explorar: sí` — más una
respuesta por cada pregunta de "Necesito de ti" que el preflight haya anticipado;
`explorar:` ya se leyó en la Fase 0 para fijar el régimen, no se vuelve a leer acá).
`tier:` del archivo (si `--tier` no vino ya por línea de comando, que manda) vale como el
tier APROBADO EN EL GATE (como si el usuario lo hubiera fijado al aprobar) — NO es
forzado: la escalada autónoma de la regla dura 3 aplica con normalidad, y solo `--tier`
por línea de comando cuenta como "forzado" a efectos de la regla dura 4. `budget:` sí
equivale a `--budget` si ese flag no vino ya por línea de comando.
Validación ESTRICTA: al `pedido:` del archivo y al pedido recibido en esta invocación (ya
separado de sus flags, Fase 0) se les recorta SOLO espacios/tabs de los extremos y el
salto de línea final — sin ninguna otra transformación. Si tras eso no coinciden
TEXTUALMENTE (carácter a carácter), el gate NO se considera aprobado —
se presenta la pantalla igual que en modo headless normal y termina (regla dura 7). Si
coincide, trae `apruebo: sí`, y TODA pregunta de "Necesito de ti" tiene su respuesta
firmada en el archivo: el gate queda aprobado sin AskUserQuestion — regístralo en el
task record (al crearlo en Fase 6) como "aprobado por archivo `<ruta>`", e incorpora las
respuestas del archivo antes de continuar. Si falta la respuesta a alguna pregunta: es
bloqueo, nunca se asume — se presenta la pantalla y termina, igual que si no coincidiera
el pedido. Esta es la única excepción a la regla dura 7 y vale ÚNICAMENTE para el pedido
textual exacto que el archivo firma. **Régimen `inexplorado`:** el manejo del campo
`captura:` de este archivo — ver `references/exploracion.md`, Fase 5 (ya leído si
corresponde, Fase 1).

Sin gate aprobado por archivo: pregunta con AskUserQuestion: aprobar / corregir alcance /
cambiar tier — **régimen `inexplorado`: suma una opción — ver `references/exploracion.md`,
Fase 5**. Incorpora las respuestas (si el alcance cambió, rehaz la mini-spec y vuelve a
presentar). **Nada muta antes del OK.**

## Fase 6 — Ejecución

Si el task record `.graph/tasks/<YYYY-MM-DD>-<slug-corto>.md` NO EXISTE: créalo — leé
"Plantillas del task record" (al final de este documento) y elegí la plantilla que
corresponda: la **completa** — o, si Fase 4 marcó **ruta trivial** Y la pieza única NO va a
generar efecto #1 (fallback en prosa, u oráculo existente que ya la cubre), la **compacta de
ruta trivial** (si en cambio la pieza única SÍ es un ejemplo positivo nuevo, con efecto #1
real: usa esta misma plantilla completa, no la compacta — ver Fase 4 y Fase 6 "Efecto #1") —,
o si la **Fase 0.5** habilitó la **ruta pelada-con-red**, la **compacta de esa ruta** —, con su
Mini-spec (aprobada) llena (el campo `Aprobación:` dice `gate interactivo`, o `aprobado por
archivo <ruta>` si el gate vino de `--gate-aprobado`, Fase 5).
Es la bitácora de la tarea. Si YA EXISTE (estás retomando la MISMA tarea, Fase 0):
CONTINÚALO, jamás lo pises — no reescribas Mini-spec ni la tabla Efectos ya registrada,
solo sigue añadiendo Diario/Efectos nuevos desde donde quedó. Escribe también en
`.graph/INDEX.md`, bajo la línea de estado (`> Actualizado: ...`), la línea `**En curso:**
<slug> (tier <X>, desde <YYYY-MM-DD>)` (<X> = el tier ya aprobado en el gate) — o, si la Fase
0.5 habilitó la ruta pelada-con-red, `**En curso:** <slug> (ruta pelada, desde <YYYY-MM-DD>)`
— sáltalo si ya está (retomando). Crea `.graph/.lock` con el contenido `<slug> · <YYYY-MM-DD HH:MM>`
(fecha y hora de este arranque) — sáltalo si ya existe para este mismo slug (retomando).
Todo commit que produzcas para esta tarea lleva el trailer `GRAPH-Task: <slug>` (navegable
después con `git log --grep "GRAPH-Task: <slug>"`).

Acto seguido, si el record es nuevo, registra el **efecto #0** en `##
Efectos`: base git (`stash create`, o `HEAD` si el árbol está limpio, sin
moverlo), inversa "restaurar los paths tocados y borrar los no-rastreados
creados (el stash no los captura)", estado `activo`. La INVERSA jamás toca
`.graph/` (protegido por C1); el EFECTO #0 cubre todo archivo del repo sin
listarlo aparte; si retomas, no lo dupliques.

**Extra-git** (comando lateral, llamada externa, archivo fuera del repo):
regístralo ANTES de ejecutar, con inversa concreta y estado `activo`; sin
inversa → `irreversible` (previsible: debía estar en el preflight/gate;
imprevisto en runtime: pregunta tardía de la regla dura 5, antes de
ejecutar). Todo esto es post-gate estricto (fases 0.5-4 no registran efectos,
regla dura 1); la tabla con solo el #0 —fila única, con la nota `— también
baseline de red` si no hay efecto #1 (ver abajo)— es el caso normal.

**Efecto #1 — ejemplos aprobados** (post-gate, ANTES de cualquier otro
trabajo del pedido propio; no confundir con el efecto #1 de "Ruta
pelada-con-red", que es su propia sección y ya cubre este mismo rol para esa
ruta). **Existe SOLO SI la Fase 1 redactó ejemplos o anti-ejemplos NUEVOS**:
si la intención ya estaba capturada por un oráculo existente (el criterio
"hacer pasar X, que ya existe" de la Fase 1/Eje B) o la mini-spec fue 100%
fallback en prosa (captura débil), NO HAY efecto #1 — saltá directo a "Tier
S"/"Tier M" de abajo; la tabla Efectos queda con el `#0` solo, y esa fila
declara explícitamente `— también baseline de red` (ver más abajo). Cuando
SÍ hay ejemplos nuevos: escribe TODOS los que el gate aprobó — los ejemplos
positivos como tests nuevos y los anti-ejemplos como tests de
caracterización — en las rutas que la Fase 1 declaró. Corré ambos conjuntos
y citá evidencia real, nunca prevista:

- Cada **ejemplo positivo** debe FALLAR (RED) al correrlo por primera vez.
  Si alguno YA PASA, es un **error de captura** (el test no expresaba de
  verdad algo que faltara) — esta es la instancia ya existente de la regla
  dura 8 (disparador de anomalía, r10): lo preregistrado (RED antes de
  implementar) diverge de lo observado; regístralo como tal (qué se
  esperaba/qué se observó) antes de decidir entre las dos opciones de abajo
  — esto aplica SOLO en la PRIMERA escritura del
  efecto #1 (nunca en una retomada: ver guarda más abajo): repórtalo en el
  Diario con la evidencia citada y NO sigas — no lo "arregles" en silencio
  ni continúes a la ejecución (regla dura 1 sigue vigente hasta
  resolverlo). Es un bloqueo de la regla dura 5: en modo interactivo,
  pregunta con AskUserQuestion — (a) **volver a la Fase 5** (gate) con la
  mini-spec corregida: reformular un ejemplo ya aprobado es cambiar el
  criterio aprobado, y la regla dura 3 manda que eso vuelva al gate, nunca
  se reformula en runtime sin pasar por ahí; (b) **confirmar que el pedido
  ya estaba resuelto y cerrar** — Estado: `convergió`, con nota explícita
  en Evidencia final ("ejemplo(s) aprobado(s) ya pasaba(n) antes de
  implementar: pedido ya resuelto"). **En modo no interactivo o
  `--gate-aprobado` sin quien responda (r10 — corrección: detectar nunca
  puede ser peor que no detectar, ver regla dura 8): NO bloquea ni cierra.**
  Registrá la anomalía con `bifurcación: pendiente` y procedé
  provisionalmente COMO (a) — sin reabrir el gate ni reformular el
  ejemplo (eso sigue exigiendo el gate, regla dura 3) y SIN asumir (b) por
  criterio propio: tratá el ejemplo como ya satisfecho (está GREEN, que es
  la meta de Tier S/M) y seguí verificando con normalidad el resto de
  ejemplos/anti-ejemplos/criterios pendientes — nunca cierres la tarea como
  `convergió` solo por este ejemplo sin que el resto también converja. La
  Fase 8 lista esta anomalía entre las `pendiente` del Resultado y en
  `.graph/INDEX.md`; el humano decide fuera de banda si el pedido ya estaba
  resuelto. En régimen `inexplorado`, además entra al grafo con el mismo
  mecanismo descrito en `references/exploracion.md` (Tier M, paso 4).
- Cada **anti-ejemplo** debe PASAR (GREEN) contra el estado vigente. Si
  alguno falla, la Fase 1 malinterpretó el comportamiento actual del área —
  misma anomalía de la regla dura 8 (GREEN esperado, FALLA observada): mismo
  tratamiento que arriba (bloqueo humano-dependiente en modo interactivo;
  `pendiente` + continuar en no interactivo/`--gate-aprobado` — nunca se
  "corrige" el anti-ejemplo en silencio para que pase).

**Preregistro (solo régimen `inexplorado` — EXIGIDO, no sugerido)**: ver
`references/exploracion.md`, Fase 6 (ya leído si corresponde, Fase 1) —
declara ANTES de ejecutar qué observación REFUTARÍA cada intento, en la
tabla de Preregistro de la sección `## Exploración` del record; sin esa
fila, la Fase 8 no cierra el grafo.

Registra este trabajo en la tabla Efectos como `| 1 | ejemplos aprobados
escritos y verificados RED/GREEN — baseline de red = <hash> | borrarlos |
activo |` — el hash es la referencia git de ESTE punto exacto (misma
técnica del efecto #0: `stash create`/`HEAD`), capturada e INSCRITA EN LA
FILA (no una referencia de runtime que se pierda: sobrevive a una
interrupción — Fase 0 la relee del record al retomar). Es el **baseline de
red** que la Fase 7 usa para invocar `tools/red.sh` — contra ESE punto
diffea `tests_intactos`, no contra el efecto #0 (mismo principio ya vigente
en "Ruta pelada-con-red", punto 3). Estado `activo` (pasa a `conservado` al
converger — es el oráculo ya aprobado en el gate, no trabajo especulativo).

**Si retomas** una tarea cuyo record YA registra el efecto #1 en la tabla
Efectos: NO re-escribas los ejemplos ni re-exijas RED — los ejemplos ya
existen y pueden estar en cualquier estado, incluido GREEN (es progreso de
la ejecución, no un error de captura); continúa desde donde el Diario
quedó, usando el `baseline de red = <hash>` que esa fila ya declara. El
bloqueo de "ejemplo aprobado que ya pasa" de arriba aplica SOLO en la
PRIMERA escritura del efecto #1, nunca en una retomada — espejo exacto de
la guarda del efecto #0 ("si retomas, no lo dupliques", más arriba).

### Tier S

Ejecuta directo con el paquete de contexto: una pasada que hace pasar
(GREEN) los ejemplos positivos del efecto #1 (si existe) sin romper los
anti-ejemplos, más la verificación de todo criterio en fallback (prosa) que
hubiera, de todo criterio ya cubierto por un oráculo existente (corré ESE
oráculo — el mismo que citó la mini-spec, no uno nuevo), y de todos los
anti-criterios.

Si la verificación falla, pasa al loop convergente de tier M y anótalo en el task record; si el tier S fue forzado por el usuario, aplica la regla dura 4 (pregunta antes de subir).

### Tier M — loop convergente

Repite hasta converger:

> El ejemplo (positivo o anti-ejemplo) de todo criterio testeable que generó
> efecto #1 YA fue escrito y verificado RED/GREEN en Fase 6, antes de este
> loop — esta fase NO vuelve a escribirlo, solo itera hasta volver GREEN
> los ejemplos positivos pendientes sin romper los anti-ejemplos, que ya
> están GREEN. Si algún criterio quedó en fallback (prosa, sin ejemplo —
> captura débil) o ya estaba cubierto por un oráculo existente (sin ejemplo
> nuevo), se declara en el diario ("sin ejemplo: <porqué>") y se verifica
> por su método alternativo (o el oráculo ya citado) de la mini-spec.

1. Implementa o corrige lo mínimo para el ejemplo (o criterio en fallback) pendiente más importante.
2. Verifica TODOS los ejemplos (positivos y anti-ejemplos) del efecto #1, todo criterio en fallback con su método, y TODOS los anti-criterios.
3. Anota en el diario del task record: `iteración → qué se hizo → diagnóstico de cada fallo → resultado` — en régimen `inexplorado`, suma la columna de Preregistro (`references/exploracion.md`, Fase 6): `criterio de refutación preregistrado: <cita> → ¿se cumplió? sí/no + evidencia`.
4. **Anomalía (regla dura 8) en régimen `inexplorado`**: mecánica ampliada —
   ver `references/exploracion.md`, Fase 6 (ya leído si corresponde, Fase
   1). En `conocido` este paso no aplica: la única instancia de la regla
   dura 8 en ese régimen es el chequeo de "efecto #1" de arriba, no un paso
   por-iteración — un ejemplo que sigue en RED tras una iteración es
   simplemente no-convergencia todavía, jamás una anomalía por sí solo.
5. **Estancamiento** = el diario muestra el mismo criterio fallando por la misma causa raíz que la iteración anterior. También hay estancamiento si el diario registra la misma acción con el mismo resultado en dos iteraciones consecutivas — esa repetición literal dispara la escalada de inmediato, sin esperar el juicio de "misma causa". En duda, pide a un agente independiente comparar los dos diagnósticos. Estancado → escalada EN ORDEN:
   a. **Diagnóstico**: agente dedicado SOLO a explicar la causa raíz (con systematic-debugging si está disponible); tiene prohibido proponer el fix. Además marca cada efecto `activo` de la tabla Efectos del intento como `revertir` (default) o `conservar` (trabajo válido que el tier nuevo aprovecha, con una frase de porqué) — el efecto #1 (ejemplos aprobados) casi siempre es `conservar`: es el oráculo ya aprobado en el gate, no trabajo especulativo. La marca es transitoria y se anota en el DIARIO, no en la columna `estado` (que solo admite su enum): el estado cambia a `revertido`/`conservado` recién cuando la escalada ejecuta la decisión.
   b. **Fan-out de perspectivas**: 2-3 agentes en paralelo — uno replantea el enfoque, uno cuestiona el diseño, uno audita si el criterio/test está mal formulado.
   c. **Subir tier a L** — autónomo si el tier no fue forzado; si fue forzado, pregunta (regla dura 4). Antes de arrancar el tier nuevo, ejecuta las inversas de los efectos marcados `revertir` en orden LIFO (el efecto #0 al final); cada uno pasa a estado `revertido` y queda anotado en el diario. Los marcados `conservar` pasan a estado `conservado`. El tier nuevo arranca con el estado de efectos declarado explícitamente, nunca heredado a ciegas.
6. Si descubres que el alcance aprobado ya no describe la tarea (complejidad de alcance, no de convergencia): STOP → vuelve a la fase 5 con la mini-spec corregida, reutilizando todo lo explorado.

### Tier L — grafo

Lee `references/workflow-templates.md` (en el directorio de este skill) y
autora un Workflow con la plantilla que corresponda (implementación
multi-frente / investigación / auditoría) — ese archivo trae también el
resto del procedimiento (cuándo se activa, cascada de refutación,
worktrees, síntesis). Esta instrucción constituye el opt-in del usuario
para usar el Workflow tool.

### Presupuesto

Sin `--budget`: sin tope, convergencia manda — nunca inventes topes. Con
`--budget <tokens>` (o su equivalente `budget:` de `--gate-aprobado`), o si
el presupuesto se agota en runtime: la mecánica completa (qué consume
presupuesto y qué no, cómo se estima el gasto, el trato en modo
`--gate-aprobado`) vive en `references/escalacion-y-presupuesto.md`,
sección "Presupuesto" — léela recién cuando alguno de esos dos casos
ocurra.

## Fase 7 — Verificación final

Tabla en la sección ## Verificación final del task record y en tu resumen: criterio/ejemplo → método → comando/
procedimiento ejecutado → evidencia (output real citado) → ✅/❌. Cada
ejemplo positivo y cada anti-ejemplo del efecto #1 (si existe) es una fila
(método = correrlo); cada criterio en fallback (prosa), o ya cubierto por un
oráculo existente, usa su método alternativo de la mini-spec. Sumale una
fila de **integridad de ejemplos** (en la plantilla compacta, si el espacio
aprieta, plegala dentro de la fila del criterio en vez de abrir una fila
nueva — el JSON sigue citado igual, en la celda de evidencia): corré
SIEMPRE
`${CLAUDE_PLUGIN_ROOT}/tools/red.sh <dir> <baseline-de-red> <cmd-suite-completa-de-commands.md> <scope-file-del-alcance-ejecutable-de-la-Fase-1>`
(el `<scope-file>` vive FUERA del árbol de `<dir>` — ver Fase 1, "Alcance
ejecutable" — nunca dentro del repo, o `scope_respetado` da un falso
negativo) — mismo tool y mismo contrato que "Ruta pelada-con-red" (ronda 7),
aplicado también al pipeline completo SIN EXCEPCIÓN: ni siquiera si la
mini-spec fue 100% fallback en prosa (r9 — `scope_respetado`/`suite_verde`
protegen igual una tarea de captura débil, que es justo donde el riesgo de
tocar fuera de alcance es mayor — docs/config/exploración). `<baseline-de-red>`
es el hash que la fila de Efectos ya declaró (Fase 6): el del efecto #1 si
existe, o el del efecto #0 si no. Volcá el JSON: sus 4 flags
(`tests_intactos`, `suite_verde`, `scope_respetado`, `oraculo_independiente`)
cuentan como parte de esta tabla; cualquiera en `false` es ❌. Lo mismo
para anti-criterios de constitution (intactos). Si algo está en ❌, NO estás
en fase 7: sigues en fase 6.

## Fase 8 — Cierre

1. Completa el task record: resultado, evidencia final, amenazas a la validez, aprendizajes, y la lista de commits de la tarea (hash corto + subject, vía `git log --grep "GRAPH-Task: <slug>"`) en la sección Resultado. Completa también "Intención capturada" (ejemplos/anti-ejemplos/restricciones de alcance/huecos y cómo se resolvió cada hueco) si no quedó ya cerrada desde la Fase 1/5; toda pieza que usó el fallback en prosa queda marcada ahí "captura débil". Registra también las preguntas tardías surgidas en runtime (regla dura 5) y qué debió detectar el preflight: su frecuencia es la métrica de calidad del preflight. Si se abortó, o se cerró por bloqueo tardío en modo `--gate-aprobado` (regla dura 5: pregunta sin respuesta firmada, o presupuesto agotado sin quien responda): causa exacta y qué se descartó (vale tanto como un éxito) — este segundo caso usa el estado `cerrado por bloqueo (pre-aprobado)`, nunca `abortado por usuario` (el usuario no decidió la parada); si al cerrar por cualquiera de las dos vías quedan efectos en estado `activo` en la tabla Efectos, ofrece (AskUserQuestion) ejecutar sus inversas pendientes en orden LIFO antes de cerrar el record, y registra el resultado (ejecutadas → `revertido`; declinadas → quedan `activo` con la razón) — en modo `--gate-aprobado` sin quien responda (regla dura 5), ejecuta directamente esas inversas en vez de ofrecerlas. Si la tarea CONVERGE, los efectos aún `activo` pasan a `conservado` — el trabajo es el entregable; ningún record cerrado queda con efectos `activo`. Llena "Amenazas a la validez" con honestidad: qué se midió y qué no, corrida única vs repetida, entorno único, qué quedó sin comparación controlada — **prohibido escribir "ninguna" sin justificar explícitamente** por qué la evidencia es completa. **Anomalías pendientes (r10 §2)**: si el Diario o la tabla Anomalías de `## Exploración` registran algún nodo con `bifurcación: pendiente`, listalos todos en Resultado (uno por línea: qué se esperaba/qué se observó/dónde) — la tarea puede converger igual con anomalías pendientes sin resolver (no son bloqueo, son deuda declarada).
2. Elimina de `.graph/INDEX.md` la línea `**En curso:** <slug> ...` de esta tarea y borra `.graph/.lock` — SIEMPRE, converja o se aborte, ambos en este mismo paso. Si el punto 1 encontró alguna anomalía `pendiente`: agrega (o actualiza, si ya existía de una tarea previa) la línea `**Anomalías pendientes:** <n> — ver <record>` en `.graph/INDEX.md`, junto a la línea de estado — mismo trato que `**En curso:**`. Si `<n>` llega a 0 tras esta tarea (todas las pendientes de este record quedaron resueltas), quita la línea.
3. ¿La tarea reveló algo estructural? → actualiza `map.md` / `conventions.md` / `decisions.md`, respetando el formato existente de cada archivo.
4. **Mapa de oráculo** (`.graph/oraculo.md`, si existe en este repo): agregá o actualizá las filas del área que esta tarea tocó. Vínculos criterio→check: usá los que la mini-spec ya declaró (Fase 1, método de verificación por criterio); en ruta pelada-con-red, la fuente es el JSON de `tools/red.sh` más el oráculo que el gate citó (Fase 0.5). Si hubo refuerzo de caracterización (efecto #1), esos tests dejan de ser un artefacto transitorio y pasan a `checks` del área que refuerzan — si la fila YA tenía checks, agregá el archivo nuevo a la lista de `checks` (separado por coma) y su `hash7` a `vigencia` EN LA MISMA POSICIÓN (mismo orden que `checks`, separados por coma), sin tocar los `hash7` de los archivos que no cambiaron. Todo criterio que la Fase 7 verificó SIN un check ejecutable que lo respalde pasa a "Huecos conocidos" con el formato `- <comportamiento> (tarea <slug>)` (es el objetivo natural del próximo refuerzo) — esto incluye, explícitamente, toda pieza marcada "captura débil" en la Fase 1 (mismo mecanismo, nombre coherente con el marco r9): no se finge oráculo donde el record ya declaró que no lo hay. Actualizá `vigencia` con `${CLAUDE_PLUGIN_ROOT}/tools/oraculo-map.sh` (el `hash7` de `scan`, UNO por archivo de `checks`, en ese mismo orden, separados por coma — un solo archivo → un solo hash7, sin coma) y marcá `origen: tarea <slug>` en toda fila que esta tarea creó o modificó de verdad — nunca pises una fila `origen: tarea *` ajena, ni conviertas una fila `origen: init` a `tarea *` solo por haberla consultado sin cambiarla (C1). Costo objetivo: ≤5 líneas nuevas por tarea típica — no reescribas el archivo entero. Si la tabla supera ~1 pantalla, aplicá la re-normalización sin pérdida del CONTRATO (mover áreas ÍNTEGRAS a un nodo enlazado; "Huecos conocidos" SIEMPRE queda en el archivo raíz). Escribí también `Última tarea: <slug>` en la línea de estado del encabezado del mapa (`> Esquema-oraculo: ... · Generado: ... · Última tarea: <slug>`) — esta Fase, punto 4, es quien la mantiene; init nunca la toca (ni en refresh, Fase 4.5 del skill init).
5. **Grafo de exploración** (`.graph/exploracion.md`, SOLO si régimen=`inexplorado` —
   en `conocido` este punto no existe, cero costo): cablea `agregar`/`validar`
   y cierra los nodos `hipótesis`/`intento` de la corrida — ver
   `references/exploracion.md`, Fase 8 (ya leído si corresponde, Fase 1).
6. ¿Cambió algo de la pantalla principal (stack, comandos, top-5)? → actualiza `INDEX.md`.
7. ¿Algún comando de `commands.md` falló en uso? → corrígelo ahí (auto-reparación).
8. ¿La tarea implementó o superó un spec/plan de `docs/superpowers/`? → actualiza la tabla del índice `docs/superpowers/README.md` (columna estado).
9. Resume al usuario: qué se entregó, con qué evidencia (y sus amenazas a la validez), qué aprendió el sistema.

---

## Plantillas del task record

Esta sección se usa en la Fase 6 (Ejecución), al crear el task record — si
todavía no existe — eligiendo la plantilla que corresponda: **completa** (pipeline normal, tier S/M/L), **compacta de
ruta trivial** (Fase 4 marcó ruta trivial y la pieza única no generó
efecto #1), o **compacta de ruta pelada-con-red** (la Fase 0.5 habilitó
esa ruta). La Fase 6 ya describe cuál corresponde a cada
caso; esta sección solo trae el contenido de cada una — en `conocido` o
`inexplorado` por igual, salvo que `inexplorado` agrega su propia sección
`## Exploración` al record (`references/exploracion.md`, no aquí).

### Plantilla del task record

```markdown
# <slug> · <YYYY-MM-DD> · tier <S|M|L>

## Mini-spec aprobada
- Intención:
- Alcance ejecutable (scope de `tools/red.sh`):
- Anti-criterios de constitution (C-N):
- Router (Fase 0.5):
  - huecos=<verde|rojo> — <evidencia>
  - oráculo=<verde|rojo> — <"mapa, fila <área>, vigente" | "mapa sin cobertura del área → inspección fresca: <evidencia>" | "reforzado por caracterización: <qué se congeló>">
  - consecuencia=<baja|alta> — <evidencia>
  - régimen=<conocido|inexplorado> — <"conocido (default)" | "conocido (sugerido inexplorado: <señales> — no activado)" | "inexplorado — declarado vía <--explorar|archivo|pedido>">
- Tier: <elegido|forzado> — porqué:
- Aprobación: <gate interactivo | aprobado por archivo `<ruta>`>

## Intención capturada
- Ejemplos positivos (código → efecto #1): <archivo(s) + qué expresan> — RED verificado: <evidencia>, o "sin ejemplos — 100% fallback"
- Anti-ejemplos (código de caracterización → efecto #1): <archivo(s) + qué protegen> — GREEN verificado: <evidencia>, o "ninguno — área nueva"
- Restricciones de alcance: <ver Alcance ejecutable arriba>
- Huecos y cómo se resolvieron: <hueco → pregunta del gate → respuesta que lo cerró, uno por línea>, o "ninguno"
- Piezas en fallback (captura débil, si hubo): <criterio en prosa + método> — quedan también en `.graph/oraculo.md`, "Huecos conocidos"

## Exploración (SOLO si régimen=inexplorado — en `conocido` esta sección NO EXISTE en el record, ni el heading; plantilla completa en `references/exploracion.md`)

## Efectos
| # | efecto | inversa | estado |
|---|---|---|---|

(estado ∈ `activo` · `revertido` · `conservado` · `irreversible`)

## Diario
| iteración | qué se hizo | diagnóstico | resultado |
|---|---|---|---|

(régimen `inexplorado`: cada fila suma la columna obligatoria — `criterio de refutación preregistrado: <cita> → ¿se cumplió? sí/no + evidencia`, r10 §5 — sin esa celda la iteración no está registrada)

## Verificación final
| criterio/ejemplo/anti-ejemplo | método | comando/procedimiento ejecutado | evidencia | ✅/❌ |
|---|---|---|---|---|

## Resultado
- Estado: en ejecución (transitorio, solo mientras la Fase 6-7 corre) | convergió | abortado por usuario | cerrado por bloqueo (pre-aprobado) | reescopado
- Evidencia final:
- Amenazas a la validez: <qué se midió y qué no; evidencia de corrida única vs repetida; entorno único; qué quedó sin comparación controlada>
- Anomalías pendientes: <ninguna | n — qué se esperaba/qué se observó/dónde, una por línea>
- Commits: <hash-corto> <subject> (uno por línea) | ninguno
- Aprendizajes:
- Preguntas tardías (runtime): <ninguna | cuáles y por qué el preflight no las vio>
```

### Plantilla compacta (ruta trivial, tier S — Fase 4)

Mismas secciones del contrato, colapsadas a ~10 líneas de contenido. Aplica
SOLO si Fase 4 marcó ruta trivial Y ADEMÁS la pieza única NO generó efecto
#1 (fue 100% fallback en prosa, o la intención ya estaba capturada por un
oráculo existente — r9, ver Fase 6 "Efecto #1"): la tabla Efectos lleva
SIEMPRE una sola fila, la `#0`. **Si la pieza única terminó siendo un
ejemplo positivo NUEVO** (con efecto #1 real), la tarea sigue siendo "ruta
trivial" a efectos del gate de un párrafo (Fase 5), pero el record usa la
**plantilla completa de tier S** de más arriba, no esta — el efecto #1 (RED
verificado + baseline de red) no entra en el presupuesto de líneas de este
formato. Cualquier otro caso (dos o más piezas, preguntas de preflight o
Huecos, o dos o más archivos) también usa la plantilla completa. El resto
del contrato es idéntico: mismo esquema `.graph/` y mismas fases 7-8
(evidencia real, cierre que limpia `En curso`/`.lock`, nunca "ninguna" sin
justificar en amenazas a la validez).

```markdown
# <slug> · <YYYY-MM-DD> · tier S (ruta trivial)

## Mini-spec aprobada
- Intención/alcance: <intención en una frase — qué entra/fuera si aplica>
- Router (Fase 0.5):
  - huecos=<verde|rojo> — <evidencia>
  - oráculo=<verde|rojo> — <"mapa, fila <área>, vigente" | "mapa sin cobertura del área → inspección fresca: <evidencia>" | "reforzado por caracterización: <qué se congeló>">
  - consecuencia=<baja|alta> — <evidencia>
- Tier: S <elegido|forzado> — <porqué en media frase>
- Criterio (sin ejemplo nuevo — sin efecto #1): <el criterio en prosa con método, si fue fallback> | <cita del oráculo existente que ya lo cubre: archivo + comando>
- Anti-ejemplo: ninguno — área nueva | ya caracterizado por <archivo existente>
- Huecos: <ninguno — ruta trivial exige cero, o no habría sido ruta trivial>
- Anti-criterios (C-N) · Aprobación: <anti-criterios en una línea citando C-N> · <gate interactivo | aprobado por archivo `<ruta>`>

## Efectos
| # | efecto | inversa | estado |
|---|---|---|---|
| 0 | base git (`stash create`/`HEAD`) — también baseline de red (sin efecto #1) | restaurar paths + borrar no-rastreados (excluye `.graph/`) | activo |

## Diario
| iteración | qué se hizo | diagnóstico | resultado |
|---|---|---|---|
| 1 | <qué se hizo> | <diagnóstico, o "sin fallos"> | <resultado> |

## Verificación final
| criterio/ejemplo/anti-ejemplo | método | comando/procedimiento ejecutado | evidencia | ✅/❌ |
|---|---|---|---|---|
| <criterio + anti-criterios> | <método del criterio, incluye `tools/red.sh` para integridad> | <comando(s) ejecutado(s)> | <output real citado — criterio y JSON de `red.sh`> | ✅ |

## Resultado
- Estado: en ejecución (transitorio) | convergió | abortado por usuario | cerrado por bloqueo (pre-aprobado) | reescopado
- Evidencia final (con amenazas a la validez, breve): <resumen>
- Anomalías pendientes: ninguna | <n — qué se esperaba/qué se observó/dónde>
- Commits: <hash-corto> <subject> (uno por línea) | ninguno
- Aprendizajes: <resumen>
- Preguntas tardías (runtime): ninguna | <cuáles y por qué el preflight no las vio>
```

### Plantilla compacta (ruta pelada-con-red — Fase 0.5)

Mismas secciones del contrato, colapsadas a ≤22 líneas de contenido (bullets de
Mini-spec + filas de datos de Efectos/Diario/Verificación final + bullets de
Resultado; el diario se mantiene en 1-4 filas). Aplica SOLO si la Fase 0.5 habilitó la ruta
pelada-con-red (los tres ejes en verde/baja); cualquier otro caso usa la plantilla completa
o la compacta de ruta trivial de arriba. El resto del contrato es idéntico: mismo esquema
`.graph/`, mismas fases 7-8 (evidencia real, cierre que limpia `En curso`/`.lock`, nunca
"ninguna" sin justificar en amenazas a la validez). La Verificación final es el JSON de
`tools/red.sh` más UNA sola fila de anti-criterios (TODAS las C-N juntas en esa fila —
NUNCA una fila por C-N: eso es de la plantilla completa), volcado a la misma tabla de 5
columnas que las
demás plantillas. Si el gate declaró refuerzo de caracterización, la tabla Efectos suma la
fila `| 1 | tests de caracterización (anti-ejemplos) escritos y verificados GREEN — baseline
de red = <hash> | borrarlos | activo |` (pasa a `conservado` al cerrar, converja o escale —
ver "Escalación por criterios" en `references/escalacion-y-presupuesto.md`); si NO hubo refuerzo, la fila `#0` declara explícitamente
`— también baseline de red` (ver "Ruta pelada-con-red", punto 3).

```markdown
# <slug> · <YYYY-MM-DD> · ruta pelada-con-red

## Mini-spec aprobada
- Pedido: <el pedido tal cual>
- Router (Fase 0.5):
  - huecos=verde — <evidencia>
  - oráculo=verde — <"mapa, fila <área>, vigente" | "mapa sin cobertura del área → inspección fresca: <evidencia>" | "reforzado por caracterización: <qué se congeló>">
  - consecuencia=baja — <evidencia>
- Gate: `ruta pelada — oráculo: <comando+alcance>, scope: <archivos/área>, consecuencia baja` · anti-criterios (C-N): <cita las C-N aplicables> · escalación: si la red detecta suciedad → reinicio limpio, mismo pedido/criterios/scope (esta aprobación cubre ambas rutas) · Aprobación: <gate interactivo | aprobado por archivo `<ruta>`>

## Efectos
| # | efecto | inversa | estado |
|---|---|---|---|
| 0 | base git (`stash create`/`HEAD`) — también baseline de red si no hubo efecto #1 | restaurar paths + borrar no-rastreados (excluye `.graph/`) | activo |

## Diario
| iteración | qué se hizo | diagnóstico | resultado |
|---|---|---|---|
| 1 | <qué se hizo> | <diagnóstico, o "sin fallos"> | <resultado> |

## Verificación final
| criterio/anti-criterio | método | comando/procedimiento ejecutado | evidencia | ✅/❌ |
|---|---|---|---|---|
| tests_intactos | `tools/red.sh` — diff vs baseline de red sobre paths de test/conftest/fixtures | `tools/red.sh` | <valor JSON `tests_intactos`> | ✅ |
| suite_verde | `tools/red.sh` — comando verificado de `commands.md`, suite completa | `tools/red.sh` | <valor JSON `suite_verde`> | ✅ |
| scope_respetado | `tools/red.sh` — archivos tocados ⊆ scope del gate | `tools/red.sh` | <valor JSON `scope_respetado`> | ✅ |
| oraculo_independiente | `tools/red.sh` — tests nuevos de la sesión registrados, no sustituyen la suite previa | `tools/red.sh` | <valor JSON `oraculo_independiente`> | ✅ |
| anti-criterios (C-N) | revisión del diff/scope contra cada C-N citada arriba | inspección del diff final | <intactos — o detalle de la excepción> | ✅ |

## Resultado
- Estado: en ejecución (transitorio) | convergió | escalado a pipeline completo (reinicio limpio) | abortado por usuario | cerrado por bloqueo (pre-aprobado)
- Escalación: ninguna | sucio (<tests tocados|suite roja|scope violado>) → reinicio limpio, ver sección "## Escalación a pipeline completo" más abajo en este mismo record | fricción menor (no escaló): <qué>
- Evidencia final (con amenazas a la validez, breve): <resumen>
- Anomalías pendientes: ninguna | <n — qué se esperaba/qué se observó/dónde> (obligatorio: regla dura 8 y Fase 8 lo exigen en TODO record, también en el compacto)

**Esta plantilla es CERRADA.** Los bullets de Resultado de arriba son exactamente los
que van: ni uno más. En particular las amenazas a la validez van DENTRO de `Evidencia
final`, nunca como bullet aparte, y la tabla de Verificación final lleva 6 filas (los 4
flags de `red.sh` + el criterio del pedido + UNA de anti-criterios). No copies secciones
ni bullets de la plantilla completa de arriba: si el caso los necesita, entonces no era
ruta pelada y corresponde la plantilla completa.
- Commits: <hash-corto> <subject> (uno por línea) | ninguno
- Aprendizajes: <resumen>
- Preguntas tardías (runtime): ninguna | <cuáles y por qué el preflight no las vio>
```
