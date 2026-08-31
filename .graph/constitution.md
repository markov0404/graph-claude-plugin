# Constitution

- C1: Nada muta el repo del usuario antes del OK del gate; las reglas duras del skill `do` aplican también a TODO subagente (los exploradores son de solo lectura estricta).
- C2: Sin contadores de intentos en ningún proceso: la salida es por criterios cumplidos; el estancamiento dispara escalada (diagnóstico → fan-out → subir tier), jamás rendición.
- C3: Todo texto visible al usuario se escribe en español (claves JSON y flags técnicos sin traducir).
- C4: El contrato `.graph/` entre `init` y `do` solo cambia de forma aditiva; `decisions.md`, `constitution.md` y `tasks/` jamás se regeneran ni se borran.
- C5: Tooling solo dentro de lo instalable: open source pinneado/vendoreado, o rehecho en casa con tests propios; cero prerrequisitos externos.
- C6: Toda verificación lleva método explícito y evidencia real ejecutada; prohibido "debería funcionar".
- C7: `docs/superpowers/` es registro histórico: specs y planes no se editan retroactivamente.
- C8: Los commits de tareas GRAPH llevan el trailer `GRAPH-Task: <slug>`.
