# Backlog — semilla de ronda 8: mapa de oráculo (cobertura de intención acumulativa)

**Fecha:** 2026-09-03
**Estado:** idea anotada (no especificada). Nace de la discusión de r7 sobre spec⇄tests.

## La idea

La doble flecha spec⇄tests (BDD/Specification-by-Example: "lo que quiero → debe cumplir" y "debe cumplir → lo que quiero") existe hace 20 años como método de construcción. Lo que no existe es usarla como **señal de ruteo**: medir la cobertura de *intención* (no de líneas) para decidir si la ruta barata es confiable, y **acumularla por repo**.

- GRAPH ya fuerza la mitad por-tarea: la mini-spec exige método de verificación por criterio (matriz de trazabilidad), y el eje B del router (r7) exige criterio derivable a check ejecutable.
- La pieza nueva: al cierre de cada tarea, registrar los vínculos criterio→test en `.graph/` (mapa de oráculo del repo: qué comportamientos declarados tienen check ejecutable, cuáles no, y con qué fuerza). El router consulta el mapa en vez de recomputar el eje B desde cero.
- **Por qué importa para la memoria:** la ablación B/C de r6 dio que la memoria narrativa no paga (0 mejora, +$2.10). Un mapa de oráculo es memoria que CADA tarea futura consulta para rutear — el primer caso de uso donde la capa de memoria tendría retorno demostrable, medible con la misma ablación (B con mapa vs C sin él, sobre tareas que requieren rutear).
- Medición mecánica complementaria (mutation-lite) mide fuerza, no intención: el mapa es lo único que puede decir *qué falta*.

## Precondición

Que la validación pre-registrada de r7 pase (config R sobre ambos benchmarks). Si el router no valida, el mapa no tiene consumidor.
