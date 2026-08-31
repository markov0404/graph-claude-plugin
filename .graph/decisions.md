# Log de decisiones

| fecha | decisión | porqué |
|---|---|---|
| 2026-08-31 | `.graph/` se commitea al repo | Es conocimiento del repo, útil para cualquier clon y para el hook de sesión; confirmado por el usuario en /graph:init |
| 2026-08-31 | El resumen del escaneo inicial se fijó sin correcciones | El usuario validó el destilado de INDEX.md en la corrección temprana |
| 2026-08-31 | Deuda diferida: solo se implementa la re-confirmada por auditoría | Política aprobada en el gate de auditoria-integral; lo refutado se descarta con notas (10 hallazgos) |
| 2026-08-31 | La entrada del plugin en marketplace.json no lleva version | plugin.json es la única fuente de la versión; validate pasa sin el campo (también --strict) |
| 2026-08-31 | Política de tooling: solo open source pinneado/vendoreado o rehecho en casa con tests, siempre dentro de lo instalable | Decidida por el usuario en el brainstorming de mejoras SOTA; primer caso: tools/symbol-map.sh (bash+awk propio) |
| 2026-08-31 | Los subagentes exploradores reciben instrucción explícita de solo-lectura estricta | Un explorador ejecutó make-fixtures del repo padre y destruyó los fixtures anidados (causa raíz del FAIL E2 en mejoras-sota-r1) |
