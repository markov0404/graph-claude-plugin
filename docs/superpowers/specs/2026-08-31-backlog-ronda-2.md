# Backlog para specs de ronda 2 (pendientes de brainstorming)

Anotado por pedido del usuario el 2026-08-31, a partir de arXiv 2608.25512 (Cordis / composabilidad espaciotemporal):

1. **Efecto + inversa explícita para la escalada de tiers.** Que el loop convergente registre cada acción con efectos (edición, comando mutante) junto a su inversa, y la escalada de tier revierta quirúrgicamente (LIFO) lo que el intento no convergido instaló — en vez de depender de que cada paso "recuerde limpiar" o de reiniciar contexto completo (el antipatrón coarse-grained que el paper documenta). Encaje natural: el diario del task record ya registra acciones; ganaría una columna "inversa".

2. **Sección "Threats to validity" como práctica de reporte.** Cuando GRAPH reporte evidencia propia (cierres de tarea, eventuales benchmarks), incluir honestidad metodológica al estilo del paper: qué se midió, en qué ecosistema único, qué NO se comparó de forma controlada. Encaje natural: plantilla del task record y/o el resumen de Fase 8.

Ambas requieren su propio brainstorming → spec antes de implementarse. No son parte de la ronda 1.
