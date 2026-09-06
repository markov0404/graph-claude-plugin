#!/usr/bin/env bash
# Test de tools/exploracion.sh (grafo de exploración, ronda 10): formato
# válido/inválido de .graph/exploracion.md, integridad referencial de
# aristas, ids duplicados, prefijo de id vs tipo, campos obligatorios por
# tipo/estado (preregistro en hipótesis/intento, evidencia en refutado,
# esperado/observado/bifurcacion en anomalía), campos desconocidos o
# fuera de lugar, secciones mal anidadas, `agregar` como append real y
# determinista que nunca toca nodos existentes ni escribe ante un flag
# inválido, `repite` detectando un refutado obvio sin marcar uno distinto
# (nodos con estado=refutado real Y nodos refutados por arista --refuta--
# desde un origen refutado), `resumen` con conteos completos, paths con
# espacios y acentos, fail-closed con python3 roto, determinismo bajo dos
# locales, uso inválido, `agregar` serializado bajo concurrencia (N
# invocaciones paralelas, cero pérdida y cero ids duplicados), la misma
# flag de arista repetida creando una arista por ocurrencia, y tolerancia
# a CRLF al leer.
# Fixtures 100% fuera del árbol del repo (mktemp), como exige
# conventions.md para tests headless.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOL="$ROOT/tools/exploracion.sh"

[ -x "$TOOL" ] || { echo "FAIL: no existe o no es ejecutable $TOOL"; exit 1; }
command -v python3 >/dev/null 2>&1 \
  || { echo "FAIL: falta python3 en el entorno (prerrequisito no declarado)"; exit 1; }

SCRATCH_ROOT="$(mktemp -d)"
trap 'rm -rf "$SCRATCH_ROOT"' EXIT

# seed_skeleton <archivo>: esqueleto mínimo válido (0 nodos, 0 aristas) —
# el mismo que siembra skills/init/SKILL.md (Fase 4.6).
seed_skeleton() {
  cat > "$1" <<'EOF'
# Grafo de exploración · fixture
> Esquema-exploracion: 1 · Sembrado: 2026-09-06 · Última tarea: ninguna

## Resumen
_(sin nodos todavía)_

## Nodos
<!-- exploracion:nodos:start -->
<!-- exploracion:nodos:end -->

## Aristas
<!-- exploracion:aristas:start -->
<!-- exploracion:aristas:end -->

## Huecos
_(ninguno todavía)_
EOF
}

# === (a) validar: esqueleto recién sembrado (0 nodos) → rc=0, sin diag ======
echo "— caso (a): validar sobre el esqueleto recién sembrado (0 nodos, 0 aristas) → rc=0"
FA="$(mktemp -d -p "$SCRATCH_ROOT")/exploracion.md"; mkdir -p "$(dirname "$FA")"
seed_skeleton "$FA"
ERR_A="$(mktemp -p "$SCRATCH_ROOT")"
set +e
"$TOOL" validar "$FA" 2>"$ERR_A"
RC_A=$?
set -e
[ "$RC_A" -eq 0 ] || { echo "FAIL (a): esperaba rc=0, fue $RC_A. stderr: $(cat "$ERR_A")"; exit 1; }
[ -z "$(cat "$ERR_A")" ] || { echo "FAIL (a): validar ok no debería emitir diag. stderr: $(cat "$ERR_A")"; exit 1; }

# === (b) validar: archivo con nodos y aristas bien formados → rc=0 =========
echo "— caso (b): validar con nodos/aristas completos y válidos → rc=0"
FB="$SCRATCH_ROOT/b.md"
cat > "$FB" <<'EOF'
# demo
> Esquema-exploracion: 1

## Nodos
<!-- exploracion:nodos:start -->
### NODO hip-1
- tipo: hipótesis
- estado: vivo
- texto: usar cache LRU compartido entre workers
- preregistro: si el hit-rate baja de 50%, se refuta
- evidencia-refutacion:
- origen: manual
- fecha: 2026-09-06
### NODO int-1
- tipo: intento
- estado: refutado
- texto: probamos el cache LRU compartido en staging
- preregistro: si el hit-rate baja de 50%, se refuta
- evidencia-refutacion: bench: hit-rate 22% con 8 workers
- origen: manual
- fecha: 2026-09-06
### NODO anom-1
- tipo: anomalía
- estado: vivo
- texto: costo 3x en la corrida X
- preregistro:
- evidencia-refutacion:
- origen: auto-aplicacion
- fecha: 2026-09-06
- esperado: costo <=1.15x
- observado: costo fue 3.02x
- bifurcacion: pendiente
### NODO sota-1
- tipo: referencia-sota
- estado: vivo
- texto: paper X propone Y
- preregistro:
- evidencia-refutacion:
- origen: sota
- fecha: 2026-09-06
<!-- exploracion:nodos:end -->

## Aristas
<!-- exploracion:aristas:start -->
- int-1 --refuta--> hip-1
- sota-1 --sostiene--> hip-1
<!-- exploracion:aristas:end -->
EOF
"$TOOL" validar "$FB" || { echo "FAIL (b): archivo válido rechazado"; exit 1; }

# === (c) validar: falta un marcador → rc=1 ===================================
echo "— caso (c): falta el marcador de cierre de Nodos → rc=1 + diag"
FC="$SCRATCH_ROOT/c.md"
printf '# demo\n> Esquema-exploracion: 1\n\n## Nodos\n<!-- exploracion:nodos:start -->\n\n## Aristas\n<!-- exploracion:aristas:start -->\n<!-- exploracion:aristas:end -->\n' > "$FC"
ERR_C="$(mktemp -p "$SCRATCH_ROOT")"
set +e
"$TOOL" validar "$FC" 2>"$ERR_C"; RC_C=$?
set -e
[ "$RC_C" -eq 1 ] || { echo "FAIL (c): esperaba rc=1, fue $RC_C"; exit 1; }
grep -qF "falta el marcador" "$ERR_C" || { echo "FAIL (c): diag no menciona el marcador faltante. stderr: $(cat "$ERR_C")"; exit 1; }

# === (d) validar: ids duplicados → rc=1 =====================================
echo "— caso (d): dos nodos con el mismo id → rc=1 + diag 'duplicado'"
FD="$SCRATCH_ROOT/d.md"
cat > "$FD" <<'EOF'
# demo
> Esquema-exploracion: 1

## Nodos
<!-- exploracion:nodos:start -->
### NODO hip-1
- tipo: hipótesis
- estado: vivo
- texto: uno
- preregistro: x
- evidencia-refutacion:
- origen: z
- fecha: 2026-09-06
### NODO hip-1
- tipo: hipótesis
- estado: vivo
- texto: dos
- preregistro: x
- evidencia-refutacion:
- origen: z
- fecha: 2026-09-06
<!-- exploracion:nodos:end -->

## Aristas
<!-- exploracion:aristas:start -->
<!-- exploracion:aristas:end -->
EOF
ERR_D="$(mktemp -p "$SCRATCH_ROOT")"
set +e
"$TOOL" validar "$FD" 2>"$ERR_D"; RC_D=$?
set -e
[ "$RC_D" -eq 1 ] || { echo "FAIL (d): esperaba rc=1, fue $RC_D"; exit 1; }
grep -qF "id duplicado" "$ERR_D" || { echo "FAIL (d): diag no menciona id duplicado. stderr: $(cat "$ERR_D")"; exit 1; }

# === (e) validar: arista a id inexistente → rc=1 ============================
echo "— caso (e): arista referencia un id que no existe → rc=1 + diag"
FE="$SCRATCH_ROOT/e.md"
cat > "$FE" <<'EOF'
# demo
> Esquema-exploracion: 1

## Nodos
<!-- exploracion:nodos:start -->
### NODO hip-1
- tipo: hipótesis
- estado: vivo
- texto: uno
- preregistro: x
- evidencia-refutacion:
- origen: z
- fecha: 2026-09-06
<!-- exploracion:nodos:end -->

## Aristas
<!-- exploracion:aristas:start -->
- hip-1 --refuta--> hip-99
<!-- exploracion:aristas:end -->
EOF
ERR_E="$(mktemp -p "$SCRATCH_ROOT")"
set +e
"$TOOL" validar "$FE" 2>"$ERR_E"; RC_E=$?
set -e
[ "$RC_E" -eq 1 ] || { echo "FAIL (e): esperaba rc=1, fue $RC_E"; exit 1; }
grep -qF "id inexistente" "$ERR_E" || { echo "FAIL (e): diag no menciona id inexistente. stderr: $(cat "$ERR_E")"; exit 1; }

# === (f) validar: hipótesis sin preregistro, anomalía sin esperado/observado,
#         estado refutado sin evidencia, campo desconocido, prefijo erróneo,
#         auto-referencia, campo de anomalía en tipo no-anomalía ============
echo "— caso (f): batería de violaciones semánticas de campos, todas detectadas"
FF="$SCRATCH_ROOT/f.md"
cat > "$FF" <<'EOF'
# demo
> Esquema-exploracion: 1

## Nodos
<!-- exploracion:nodos:start -->
### NODO hip-1
- tipo: hipótesis
- estado: refutado
- texto: x
- preregistro:
- evidencia-refutacion:
- origen: z
- fecha: 2026-09-06
- campo_raro: valor
### NODO int-1
- tipo: hipótesis
- estado: vivo
- texto: y
- preregistro: p
- evidencia-refutacion:
- origen: z
- fecha: 2026-09-06
### NODO anom-1
- tipo: anomalía
- estado: vivo
- texto: z
- preregistro:
- evidencia-refutacion:
- origen: z
- fecha: 2026-09-06
- bifurcacion: pendiente
<!-- exploracion:nodos:end -->

## Aristas
<!-- exploracion:aristas:start -->
- hip-1 --refuta--> hip-1
<!-- exploracion:aristas:end -->
EOF
ERR_F="$(mktemp -p "$SCRATCH_ROOT")"
set +e
"$TOOL" validar "$FF" 2>"$ERR_F"; RC_F=$?
set -e
[ "$RC_F" -eq 1 ] || { echo "FAIL (f): esperaba rc=1, fue $RC_F"; exit 1; }
ERRTXT="$(cat "$ERR_F")"
grep -qF "exige 'preregistro' no vacío" <<<"$ERRTXT" || { echo "FAIL (f): no detectó preregistro vacío en hipótesis. $ERRTXT"; exit 1; }
grep -qF "exige 'evidencia-refutacion' no vacía" <<<"$ERRTXT" || { echo "FAIL (f): no detectó evidencia vacía con estado refutado. $ERRTXT"; exit 1; }
grep -qF "campo(s) desconocido(s): campo_raro" <<<"$ERRTXT" || { echo "FAIL (f): no detectó campo desconocido. $ERRTXT"; exit 1; }
grep -qF "el prefijo del id no corresponde al tipo" <<<"$ERRTXT" || { echo "FAIL (f): no detectó prefijo/tipo desincronizado (int-1 con tipo hipótesis). $ERRTXT"; exit 1; }
grep -qF "auto-referencia no permitida" <<<"$ERRTXT" || { echo "FAIL (f): no detectó auto-referencia. $ERRTXT"; exit 1; }
grep -qF "exige campo(s) esperado, observado" <<<"$ERRTXT" || { echo "FAIL (f): no detectó esperado/observado faltantes en anomalía. $ERRTXT"; exit 1; }

# === (g) validar: secciones de Nodos/Aristas mal anidadas → rc=1 ============
echo "— caso (g): marcadores de Nodos y Aristas superpuestos → rc=1"
FG="$SCRATCH_ROOT/g.md"
cat > "$FG" <<'EOF'
# demo
> Esquema-exploracion: 1

## Nodos
<!-- exploracion:nodos:start -->
## Aristas
<!-- exploracion:aristas:start -->
<!-- exploracion:nodos:end -->
<!-- exploracion:aristas:end -->
EOF
ERR_G="$(mktemp -p "$SCRATCH_ROOT")"
set +e
"$TOOL" validar "$FG" 2>"$ERR_G"; RC_G=$?
set -e
[ "$RC_G" -eq 1 ] || { echo "FAIL (g): esperaba rc=1, fue $RC_G"; exit 1; }
grep -qF "superponen" "$ERR_G" || { echo "FAIL (g): diag no menciona la superposición. stderr: $(cat "$ERR_G")"; exit 1; }

# === (h) validar: archivo inexistente → rc=1 =================================
echo "— caso (h): validar sobre archivo inexistente → rc=1 + diag"
ERR_H="$(mktemp -p "$SCRATCH_ROOT")"
set +e
"$TOOL" validar "$SCRATCH_ROOT/no-existe-$$.md" 2>"$ERR_H"; RC_H=$?
set -e
[ "$RC_H" -eq 1 ] || { echo "FAIL (h): esperaba rc=1, fue $RC_H"; exit 1; }
grep -qF "diag:" "$ERR_H" || { echo "FAIL (h): stderr sin diag. stderr: $(cat "$ERR_H")"; exit 1; }

# =============================================================================
# agregar
# =============================================================================

# === (i) agregar: crea el primer nodo con el formato exacto =================
echo "— caso (i): agregar sobre esqueleto vacío — formato exacto del bloque escrito"
FI="$SCRATCH_ROOT/i.md"
seed_skeleton "$FI"
OUT_I="$("$TOOL" agregar "$FI" hipotesis "usar cache LRU compartido" --preregistro "si falla el hit-rate, se refuta")"
[ "$OUT_I" = "hip-1" ] || { echo "FAIL (i): esperaba id 'hip-1', fue '$OUT_I'"; exit 1; }
"$TOOL" validar "$FI" || { echo "FAIL (i): el archivo resultante no valida"; exit 1; }
grep -qF "### NODO hip-1" "$FI" || { echo "FAIL (i): no se escribió el encabezado del nodo"; exit 1; }
grep -qF -- "- tipo: hipótesis" "$FI" || { echo "FAIL (i): tipo mal escrito"; exit 1; }
grep -qF -- "- estado: vivo" "$FI" || { echo "FAIL (i): estado default debería ser 'vivo'"; exit 1; }
grep -qF -- "- texto: usar cache LRU compartido" "$FI" || { echo "FAIL (i): texto mal escrito"; exit 1; }
grep -qF -- "- origen: manual" "$FI" || { echo "FAIL (i): origen default debería ser 'manual'"; exit 1; }
grep -qE '^- fecha: [0-9]{4}-[0-9]{2}-[0-9]{2}$' "$FI" || { echo "FAIL (i): fecha con formato inesperado"; exit 1; }

# === (j) agregar: ids secuenciales POR PREFIJO (no globales) ================
echo "— caso (j): ids secuenciales por prefijo — hip-2 e int-1 (no int-2)"
"$TOOL" agregar "$FI" hipotesis "segunda hipotesis" --preregistro "y" >/dev/null
OUT_J="$("$TOOL" agregar "$FI" intento "primer intento" --preregistro "z")"
[ "$OUT_J" = "int-1" ] || { echo "FAIL (j): esperaba 'int-1' (secuencia propia por prefijo), fue '$OUT_J'"; exit 1; }
grep -qF "### NODO hip-2" "$FI" || { echo "FAIL (j): no apareció hip-2"; exit 1; }

# === (k) agregar: NUNCA toca nodos existentes (append real) =================
echo "— caso (k): agregar es append real — el contenido previo no cambia ni una línea"
FK="$SCRATCH_ROOT/k.md"
seed_skeleton "$FK"
"$TOOL" agregar "$FK" hipotesis "primera" --preregistro "p1" >/dev/null
BEFORE_LINES="$(cat "$FK")"
"$TOOL" agregar "$FK" hipotesis "segunda" --preregistro "p2" >/dev/null
# Toda línea de BEFORE_LINES debe seguir presente, en el mismo orden relativo
# (diff sin banderas de contexto: ninguna línea "<" debe aparecer, solo ">").
DIFF_K="$(diff <(printf '%s\n' "$BEFORE_LINES") "$FK" || true)"
if printf '%s\n' "$DIFF_K" | grep -qE '^< '; then
  echo "FAIL (k): agregar modificó o borró una línea existente. diff:"
  printf '%s\n' "$DIFF_K"
  exit 1
fi
grep -qF "### NODO hip-1" "$FK" || { echo "FAIL (k): hip-1 desapareció"; exit 1; }
grep -qF "### NODO hip-2" "$FK" || { echo "FAIL (k): no se agregó hip-2"; exit 1; }

# === (l) agregar: determinista — mismo estado inicial + mismos args → mismo resultado
echo "— caso (l): agregar es determinista (mismo archivo inicial + mismos args → resultado byte-idéntico)"
FL1="$SCRATCH_ROOT/l1.md"; FL2="$SCRATCH_ROOT/l2.md"
seed_skeleton "$FL1"; seed_skeleton "$FL2"
"$TOOL" agregar "$FL1" hipotesis "misma propuesta" --preregistro "mismo criterio" --origen "test" >/dev/null
"$TOOL" agregar "$FL2" hipotesis "misma propuesta" --preregistro "mismo criterio" --origen "test" >/dev/null
diff "$FL1" "$FL2" >/dev/null || { echo "FAIL (l): dos agregar idénticos sobre el mismo estado inicial difieren"; diff "$FL1" "$FL2"; exit 1; }

# === (m) agregar: --refuta crea la arista y valida ==========================
echo "— caso (m): agregar --refuta crea la arista correcta y el archivo sigue válido"
FM="$SCRATCH_ROOT/m.md"
seed_skeleton "$FM"
"$TOOL" agregar "$FM" hipotesis "propuesta original" --preregistro "criterio" >/dev/null
OUT_M="$("$TOOL" agregar "$FM" intento "intento que la prueba" --preregistro "criterio" --estado refutado --evidencia "test X falló" --refuta hip-1)"
[ "$OUT_M" = "int-1" ] || { echo "FAIL (m): id inesperado '$OUT_M'"; exit 1; }
grep -qF -- "- int-1 --refuta--> hip-1" "$FM" || { echo "FAIL (m): no se escribió la arista esperada"; exit 1; }
"$TOOL" validar "$FM" || { echo "FAIL (m): el archivo con la arista nueva no valida"; exit 1; }

# === (n) agregar: multiples aristas simultaneas (--refuta y --sostiene) =====
echo "— caso (n): agregar con dos flags de arista a la vez crea ambas aristas"
FN="$SCRATCH_ROOT/n.md"
seed_skeleton "$FN"
"$TOOL" agregar "$FN" hipotesis "h1" --preregistro "c1" >/dev/null
"$TOOL" agregar "$FN" hipotesis "h2" --preregistro "c2" >/dev/null
"$TOOL" agregar "$FN" referencia-sota "paper Z" --refuta hip-1 --sostiene hip-2 --origen sota >/dev/null
grep -qF -- "- sota-1 --refuta--> hip-1" "$FN" || { echo "FAIL (n): falta arista refuta"; exit 1; }
grep -qF -- "- sota-1 --sostiene--> hip-2" "$FN" || { echo "FAIL (n): falta arista sostiene"; exit 1; }

# === (o) agregar: --refuta a id inexistente → rc=1, archivo INTACTO =========
echo "— caso (o): --refuta a un id inexistente → rc=1, el archivo no se toca"
FO="$SCRATCH_ROOT/o.md"
seed_skeleton "$FO"
HASH_O_BEFORE="$(md5sum "$FO")"
ERR_O="$(mktemp -p "$SCRATCH_ROOT")"
set +e
"$TOOL" agregar "$FO" intento "algo" --preregistro "x" --refuta no-existe-9 2>"$ERR_O"; RC_O=$?
set -e
[ "$RC_O" -eq 1 ] || { echo "FAIL (o): esperaba rc=1, fue $RC_O"; exit 1; }
grep -qF "id inexistente" "$ERR_O" || { echo "FAIL (o): diag no lo explica. stderr: $(cat "$ERR_O")"; exit 1; }
HASH_O_AFTER="$(md5sum "$FO")"
[ "$HASH_O_BEFORE" = "$HASH_O_AFTER" ] || { echo "FAIL (o): el archivo se modificó pese al rc=1"; exit 1; }

# === (p) agregar: tipo inválido, hipótesis sin preregistro, anomalía sin
#         esperado/observado, esperado/observado en tipo no-anomalía → rc=1,
#         SIEMPRE sin escribir ============================================
echo "— caso (p): agregar rechaza tipo inválido / campos obligatorios faltantes, sin escribir"
FP="$SCRATCH_ROOT/p.md"
seed_skeleton "$FP"
HASH_P="$(md5sum "$FP")"

ERR_P1="$(mktemp -p "$SCRATCH_ROOT")"
set +e; "$TOOL" agregar "$FP" "tipo-inventado" "x" 2>"$ERR_P1"; RC_P1=$?; set -e
[ "$RC_P1" -eq 1 ] || { echo "FAIL (p1): esperaba rc=1"; exit 1; }
grep -qF "tipo desconocido" "$ERR_P1" || { echo "FAIL (p1): diag no lo explica"; exit 1; }

ERR_P2="$(mktemp -p "$SCRATCH_ROOT")"
set +e; "$TOOL" agregar "$FP" hipotesis "sin preregistro" 2>"$ERR_P2"; RC_P2=$?; set -e
[ "$RC_P2" -eq 1 ] || { echo "FAIL (p2): esperaba rc=1"; exit 1; }
grep -qF "exige --preregistro" "$ERR_P2" || { echo "FAIL (p2): diag no lo explica"; exit 1; }

ERR_P3="$(mktemp -p "$SCRATCH_ROOT")"
set +e; "$TOOL" agregar "$FP" anomalia "algo raro paso" 2>"$ERR_P3"; RC_P3=$?; set -e
[ "$RC_P3" -eq 1 ] || { echo "FAIL (p3): esperaba rc=1"; exit 1; }
grep -qF "exige --esperado" "$ERR_P3" || { echo "FAIL (p3): diag no exige esperado"; exit 1; }

ERR_P4="$(mktemp -p "$SCRATCH_ROOT")"
set +e; "$TOOL" agregar "$FP" hipotesis "x" --preregistro "y" --esperado "no debería ir aca" 2>"$ERR_P4"; RC_P4=$?; set -e
[ "$RC_P4" -eq 1 ] || { echo "FAIL (p4): esperaba rc=1"; exit 1; }
grep -qF "solo son válidos con tipo anomalía" "$ERR_P4" || { echo "FAIL (p4): diag no lo explica"; exit 1; }

[ "$(md5sum "$FP")" = "$HASH_P" ] || { echo "FAIL (p): el archivo se modificó pese a rc=1 en algún sub-caso"; exit 1; }

# === (q) agregar: paths con espacios y acentos ==============================
echo "— caso (q): agregar sobre un path con espacios y acentos"
DIR_Q="$(mktemp -d -p "$SCRATCH_ROOT")/carpeta con espacios y ñ"
mkdir -p "$DIR_Q"
FQ="$DIR_Q/exploración café.md"
seed_skeleton "$FQ"
OUT_Q="$("$TOOL" agregar "$FQ" hipotesis "la ñoñería del café con azúcar" --preregistro "si no convence, se refuta")"
[ "$OUT_Q" = "hip-1" ] || { echo "FAIL (q): id inesperado '$OUT_Q'"; exit 1; }
"$TOOL" validar "$FQ" || { echo "FAIL (q): no valida tras agregar en path acentuado"; exit 1; }
grep -qF "café con azúcar" "$FQ" || { echo "FAIL (q): el texto con acentos no se preservó"; exit 1; }

# =============================================================================
# repite
# =============================================================================

FIX_REPITE="$SCRATCH_ROOT/repite.md"
seed_skeleton "$FIX_REPITE"
"$TOOL" agregar "$FIX_REPITE" intento "cache LRU en memoria compartida entre workers para acelerar las consultas repetidas" \
  --preregistro "si el hit-rate baja de 50%, se refuta" --estado refutado \
  --evidencia "bench: hit-rate 22% con 8 workers" >/dev/null
"$TOOL" agregar "$FIX_REPITE" hipotesis "usar particionado por rango en vez de hash para el sharding" \
  --preregistro "si el balance de carga empeora, se descarta" >/dev/null

# === (r) repite: detecta un refutado obvio (parafrasis) → REPETIDO =========
echo "— caso (r): repite detecta una parafrasis obvia del nodo refutado → REPETIDO con su id"
OUT_R="$("$TOOL" repite "$FIX_REPITE" "cache LRU compartido en memoria entre los workers para acelerar consultas repetidas")"
[ "$(printf '%s' "$OUT_R" | cut -f1)" = "REPETIDO" ] || { echo "FAIL (r): esperaba REPETIDO, fila: $OUT_R"; exit 1; }
[ "$(printf '%s' "$OUT_R" | cut -f2)" = "int-1" ] || { echo "FAIL (r): esperaba id int-1, fila: $OUT_R"; exit 1; }

# === (s) repite: NO marca un nodo refutado distinto (ni el vivo) para una
#         propuesta no relacionada → NUEVO ==================================
echo "— caso (s): repite con propuesta no relacionada → NUEVO (no marca ningún id)"
OUT_S="$("$TOOL" repite "$FIX_REPITE" "el formato TSV de fuerza produce columnas con tabs que rompen si el motivo contiene saltos de linea")"
[ "$(printf '%s' "$OUT_S" | cut -f1)" = "NUEVO" ] || { echo "FAIL (s): esperaba NUEVO, fila: $OUT_S"; exit 1; }
[ -z "$(printf '%s' "$OUT_S" | cut -f2)" ] || { echo "FAIL (s): NUEVO no debería traer id, fila: $OUT_S"; exit 1; }

# === (t) repite: ignora nodos vivos/sostenidos (solo compara refutados) ====
echo "— caso (t): una propuesta calcada del nodo VIVO (hipótesis de sharding) no lo marca como repetido"
OUT_T="$("$TOOL" repite "$FIX_REPITE" "particionar por rango en vez de hash para el sharding de datos")"
[ "$(printf '%s' "$OUT_T" | cut -f1)" = "NUEVO" ] \
  || { echo "FAIL (t): repite NO debe considerar nodos vivos como 'repetidos' (solo estado=refutado), fila: $OUT_T"; exit 1; }

# === (aa) repite: ve una refutación registrada COMO ARISTA (regla (2) —
#          hallazgo adversarial r10 #1). El patrón prescrito por el propio
#          sistema es `agregar intento ... --refuta <id-hipotesis>
#          --estado refutado`: eso deja el INTENTO en refutado pero la
#          HIPÓTESIS referenciada sigue vivo. Antes del fix, `repite` solo
#          miraba estado=refutado directo y jamás marcaba una propuesta
#          calcada de esa hipótesis. ===================================
echo "— caso (aa): repite ve una hipótesis 'vivo' refutada por ARISTA (--refuta) desde un intento refutado"
FIX_AA="$SCRATCH_ROOT/aa.md"
seed_skeleton "$FIX_AA"
"$TOOL" agregar "$FIX_AA" hipotesis "usar particionado por hash consistente para el balanceo de carga entre nodos" \
  --preregistro "si el balance empeora, se refuta" >/dev/null
"$TOOL" agregar "$FIX_AA" intento "probamos particionado por hash consistente en produccion" \
  --preregistro "si el balance empeora, se refuta" --estado refutado \
  --evidencia "desbalance del 40% observado" --refuta hip-1 >/dev/null
# hip-1 sigue con estado=vivo (agregar --refuta nunca toca el nodo apuntado).
grep -qF -- "- estado: vivo" "$FIX_AA" || { echo "FAIL (aa): precondición rota — hip-1 debería seguir 'vivo'"; exit 1; }
"$TOOL" validar "$FIX_AA" || { echo "FAIL (aa): el fixture no valida"; exit 1; }
OUT_AA="$("$TOOL" repite "$FIX_AA" "particionado por hash consistente para balancear la carga entre los nodos")"
[ "$(printf '%s' "$OUT_AA" | cut -f1)" = "REPETIDO" ] \
  || { echo "FAIL (aa): esperaba REPETIDO (hip-1 es refutada por arista, aunque su propio estado siga 'vivo'), fila: $OUT_AA"; exit 1; }
[ "$(printf '%s' "$OUT_AA" | cut -f2)" = "hip-1" ] \
  || { echo "FAIL (aa): esperaba id hip-1 (destino de la arista --refuta--> desde el intento refutado), fila: $OUT_AA"; exit 1; }

# === (u) repite: archivo inválido → rc=1 ====================================
echo "— caso (u): repite sobre un archivo inválido → rc=1 + diag"
ERR_U="$(mktemp -p "$SCRATCH_ROOT")"
set +e
"$TOOL" repite "$FD" "cualquier cosa" 2>"$ERR_U"; RC_U=$?
set -e
[ "$RC_U" -eq 1 ] || { echo "FAIL (u): esperaba rc=1, fue $RC_U"; exit 1; }
grep -qF "diag:" "$ERR_U" || { echo "FAIL (u): stderr sin diag"; exit 1; }

# =============================================================================
# resumen
# =============================================================================

# === (v) resumen: conteos correctos (todas las combinaciones presentes) ====
echo "— caso (v): resumen — conteos completos por tipo/estado y por arista"
FV="$SCRATCH_ROOT/v.md"
seed_skeleton "$FV"
"$TOOL" agregar "$FV" hipotesis "h1" --preregistro "c" >/dev/null
"$TOOL" agregar "$FV" hipotesis "h2" --preregistro "c" --estado sostenido >/dev/null
"$TOOL" agregar "$FV" intento "i1" --preregistro "c" --estado refutado --evidencia "e" --refuta hip-1 >/dev/null
OUT_V="$("$TOOL" resumen "$FV")"
[ "$(printf '%s\n' "$OUT_V" | awk -F'\t' '$1=="nodo" && $2=="hipótesis" && $3=="vivo"{print $4}')" = "1" ] \
  || { echo "FAIL (v): esperaba 1 hipótesis viva. resumen: $OUT_V"; exit 1; }
[ "$(printf '%s\n' "$OUT_V" | awk -F'\t' '$1=="nodo" && $2=="hipótesis" && $3=="sostenido"{print $4}')" = "1" ] \
  || { echo "FAIL (v): esperaba 1 hipótesis sostenida. resumen: $OUT_V"; exit 1; }
[ "$(printf '%s\n' "$OUT_V" | awk -F'\t' '$1=="nodo" && $2=="intento" && $3=="refutado"{print $4}')" = "1" ] \
  || { echo "FAIL (v): esperaba 1 intento refutado. resumen: $OUT_V"; exit 1; }
[ "$(printf '%s\n' "$OUT_V" | awk -F'\t' '$1=="arista" && $2=="refuta"{print $3}')" = "1" ] \
  || { echo "FAIL (v): esperaba 1 arista refuta. resumen: $OUT_V"; exit 1; }
[ "$(printf '%s\n' "$OUT_V" | awk -F'\t' '$1=="total" && $2=="nodos"{print $3}')" = "3" ] \
  || { echo "FAIL (v): esperaba total nodos=3. resumen: $OUT_V"; exit 1; }
[ "$(printf '%s\n' "$OUT_V" | awk -F'\t' '$1=="total" && $2=="aristas"{print $3}')" = "1" ] \
  || { echo "FAIL (v): esperaba total aristas=1. resumen: $OUT_V"; exit 1; }
N_LINEAS_V="$(printf '%s\n' "$OUT_V" | grep -c .)"
[ "$N_LINEAS_V" = "18" ] || { echo "FAIL (v): esperaba 18 líneas (12 nodo + 4 arista + 2 total), hubo $N_LINEAS_V"; exit 1; }

# === (w) resumen: archivo inválido → rc=1 ===================================
echo "— caso (w): resumen sobre archivo inválido → rc=1 + diag"
ERR_W="$(mktemp -p "$SCRATCH_ROOT")"
set +e
"$TOOL" resumen "$FE" 2>"$ERR_W"; RC_W=$?
set -e
[ "$RC_W" -eq 1 ] || { echo "FAIL (w): esperaba rc=1, fue $RC_W"; exit 1; }
grep -qF "diag:" "$ERR_W" || { echo "FAIL (w): stderr sin diag"; exit 1; }

# =============================================================================
# determinismo bajo dos locales
# =============================================================================

echo "— caso (x): determinismo bajo dos locales — validar, repite y resumen"
LOC1="en_US.utf8"
if ! locale -a 2>/dev/null | grep -qi "^${LOC1}\$"; then
  LOC1="C"
fi
OUT_X1="$(LC_ALL="$LOC1" "$TOOL" validar "$FB" 2>&1; echo "RC=$?")"
OUT_X2="$(LC_ALL=C "$TOOL" validar "$FB" 2>&1; echo "RC=$?")"
[ "$OUT_X1" = "$OUT_X2" ] || { echo "FAIL (x1): validar difiere entre locales. $OUT_X1 vs $OUT_X2"; exit 1; }

OUT_X3="$(LC_ALL="$LOC1" "$TOOL" repite "$FIX_REPITE" "cache LRU compartido en memoria entre los workers")"
OUT_X4="$(LC_ALL=C "$TOOL" repite "$FIX_REPITE" "cache LRU compartido en memoria entre los workers")"
[ "$OUT_X3" = "$OUT_X4" ] || { echo "FAIL (x2): repite difiere entre locales. $OUT_X3 vs $OUT_X4"; exit 1; }

OUT_X5="$(LC_ALL="$LOC1" "$TOOL" resumen "$FV")"
OUT_X6="$(LC_ALL=C "$TOOL" resumen "$FV")"
[ "$OUT_X5" = "$OUT_X6" ] || { echo "FAIL (x3): resumen difiere entre locales"; exit 1; }

# =============================================================================
# fail-closed real (python3 roto) y uso inválido
# =============================================================================

echo "— caso (y): python3 roto → los 4 modos fallan cerrado (rc≠0 + diag; agregar no escribe)"
FAKEBIN="$(mktemp -d -p "$SCRATCH_ROOT")"
cat > "$FAKEBIN/python3" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$FAKEBIN/python3"

FY="$SCRATCH_ROOT/y.md"
seed_skeleton "$FY"
HASH_Y_BEFORE="$(md5sum "$FY")"

for args in "validar $FY" "repite $FY texto-cualquiera" "resumen $FY" "agregar $FY hipotesis texto --preregistro x"; do
  ERR_Y="$(mktemp -p "$SCRATCH_ROOT")"
  set +e
  PATH="$FAKEBIN:$PATH" "$TOOL" $args >/dev/null 2>"$ERR_Y"
  RC_Y=$?
  set -e
  [ "$RC_Y" -ne 0 ] || { echo "FAIL (y): '$args' con python3 roto debería fallar, fue rc=0"; exit 1; }
  grep -qF "diag:" "$ERR_Y" || { echo "FAIL (y): '$args' sin diag ante python3 roto. stderr: $(cat "$ERR_Y")"; exit 1; }
done
HASH_Y_AFTER="$(md5sum "$FY")"
[ "$HASH_Y_BEFORE" = "$HASH_Y_AFTER" ] || { echo "FAIL (y): agregar escribió el archivo pese a python3 roto"; exit 1; }

echo "— caso (z): uso inválido — sin argumentos, modo desconocido, aridad incorrecta"
ERR_Z1="$(mktemp -p "$SCRATCH_ROOT")"
set +e; "$TOOL" >/dev/null 2>"$ERR_Z1"; RC_Z1=$?; set -e
[ "$RC_Z1" -ne 0 ] || { echo "FAIL (z1): sin argumentos debería fallar"; exit 1; }
grep -qF "diag:" "$ERR_Z1" || { echo "FAIL (z1): sin diag"; exit 1; }

ERR_Z2="$(mktemp -p "$SCRATCH_ROOT")"
set +e; "$TOOL" modo-inventado "$FY" >/dev/null 2>"$ERR_Z2"; RC_Z2=$?; set -e
[ "$RC_Z2" -ne 0 ] || { echo "FAIL (z2): modo desconocido debería fallar"; exit 1; }
grep -qF "modo desconocido" "$ERR_Z2" || { echo "FAIL (z2): diag no lo explica"; exit 1; }

ERR_Z3="$(mktemp -p "$SCRATCH_ROOT")"
set +e; "$TOOL" validar >/dev/null 2>"$ERR_Z3"; RC_Z3=$?; set -e
[ "$RC_Z3" -ne 0 ] || { echo "FAIL (z3): validar sin <archivo> debería fallar"; exit 1; }

ERR_Z4="$(mktemp -p "$SCRATCH_ROOT")"
set +e; "$TOOL" repite "$FY" >/dev/null 2>"$ERR_Z4"; RC_Z4=$?; set -e
[ "$RC_Z4" -ne 0 ] || { echo "FAIL (z4): repite sin <descripcion> debería fallar"; exit 1; }

ERR_Z5="$(mktemp -p "$SCRATCH_ROOT")"
set +e; "$TOOL" agregar "$FY" hipotesis >/dev/null 2>"$ERR_Z5"; RC_Z5=$?; set -e
[ "$RC_Z5" -ne 0 ] || { echo "FAIL (z5): agregar sin <texto> debería fallar"; exit 1; }

ERR_Z6="$(mktemp -p "$SCRATCH_ROOT")"
set +e; "$TOOL" agregar "$FY" hipotesis "x" --preregistro "p" --flag-inventada valor >/dev/null 2>"$ERR_Z6"; RC_Z6=$?; set -e
[ "$RC_Z6" -ne 0 ] || { echo "FAIL (z6): flag desconocida en agregar debería fallar"; exit 1; }
grep -qF "flag desconocida" "$ERR_Z6" || { echo "FAIL (z6): diag no lo explica"; exit 1; }

# =============================================================================
# concurrencia y flags de arista repetidos (hallazgos adversariales r10 #2 y #3)
# =============================================================================

# === (bb) agregar bajo concurrencia: N invocaciones en paralelo sobre el
#          MISMO archivo no deben perder nodos ni repartir el mismo id a
#          dos llamadores (antes: read-modify-write sin lock — 8 en
#          paralelo, 6 sobrevivían, ids duplicados impresos). ============
echo "— caso (bb): agregar bajo concurrencia — N invocaciones paralelas no pisan nodos ni reparten ids duplicados"
FBB="$SCRATCH_ROOT/bb.md"
seed_skeleton "$FBB"
N_BB=8
for i in $(seq 1 "$N_BB"); do
  (
    set +e
    OUT_I="$("$TOOL" agregar "$FBB" hipotesis "hipotesis concurrente numero $i" --preregistro "criterio $i" 2>"$SCRATCH_ROOT/bb-err-$i")"
    echo $? > "$SCRATCH_ROOT/bb-rc-$i"
    printf '%s\n' "$OUT_I" > "$SCRATCH_ROOT/bb-out-$i"
  ) &
done
wait

for i in $(seq 1 "$N_BB"); do
  RC_BB="$(cat "$SCRATCH_ROOT/bb-rc-$i")"
  [ "$RC_BB" = "0" ] || { echo "FAIL (bb): la invocación $i falló con rc=$RC_BB. stderr: $(cat "$SCRATCH_ROOT/bb-err-$i")"; exit 1; }
done

N_NODOS_BB="$(grep -c '^### NODO ' "$FBB")"
[ "$N_NODOS_BB" = "$N_BB" ] \
  || { echo "FAIL (bb): esperaba $N_BB nodos en el archivo final, hubo $N_NODOS_BB (pérdida silenciosa bajo concurrencia)"; exit 1; }

N_IDS_UNICOS_BB="$(grep '^### NODO ' "$FBB" | sort -u | wc -l)"
[ "$N_IDS_UNICOS_BB" = "$N_BB" ] \
  || { echo "FAIL (bb): los ids escritos en el archivo no son todos únicos ($N_IDS_UNICOS_BB únicos de $N_BB)"; exit 1; }

N_STDOUT_UNICOS_BB="$(cat "$SCRATCH_ROOT"/bb-out-* | sort -u | wc -l)"
[ "$N_STDOUT_UNICOS_BB" = "$N_BB" ] \
  || { echo "FAIL (bb): el stdout de las $N_BB invocaciones no dio $N_BB ids únicos (hubo $N_STDOUT_UNICOS_BB) — el mismo id se entregó a dos llamadores"; exit 1; }

"$TOOL" validar "$FBB" || { echo "FAIL (bb): el archivo final tras la concurrencia no valida"; exit 1; }

# === (cc) agregar: la MISMA flag de arista repetida crea UNA arista por
#          ocurrencia, ninguna se descarta (antes: --refuta hip-1 --refuta
#          hip-2 solo dejaba la arista a hip-2, sin diag). ===============
echo "— caso (cc): agregar con la misma flag de arista repetida crea una arista por cada ocurrencia"
FCC="$SCRATCH_ROOT/cc.md"
seed_skeleton "$FCC"
"$TOOL" agregar "$FCC" hipotesis "h1 candidata a refutar" --preregistro "c1" >/dev/null
"$TOOL" agregar "$FCC" hipotesis "h2 candidata a refutar" --preregistro "c2" >/dev/null
OUT_CC="$("$TOOL" agregar "$FCC" referencia-sota "paper que refuta ambas" --origen sota --refuta hip-1 --refuta hip-2)"
[ "$OUT_CC" = "sota-1" ] || { echo "FAIL (cc): id inesperado '$OUT_CC'"; exit 1; }
grep -qF -- "- sota-1 --refuta--> hip-1" "$FCC" || { echo "FAIL (cc): falta la arista hacia hip-1 (primera ocurrencia de --refuta)"; exit 1; }
grep -qF -- "- sota-1 --refuta--> hip-2" "$FCC" || { echo "FAIL (cc): falta la arista hacia hip-2 (segunda ocurrencia de --refuta) — se habría descartado en silencio"; exit 1; }
N_ARISTAS_REFUTA_CC="$(grep -c -- '--refuta-->' "$FCC")"
[ "$N_ARISTAS_REFUTA_CC" = "2" ] || { echo "FAIL (cc): esperaba exactamente 2 aristas --refuta-->, hubo $N_ARISTAS_REFUTA_CC"; exit 1; }
"$TOOL" validar "$FCC" || { echo "FAIL (cc): el archivo con las dos aristas repetidas no valida"; exit 1; }

# === (dd) validar: tolera CRLF (fin de línea estilo Windows) sobre un
#          archivo por lo demás válido (hallazgo adversarial r10 #5 —
#          antes cada línea con un "\r" colgante fallaba el parseo línea
#          por línea con diagnósticos genéricos e indepurables). =========
echo "— caso (dd): validar tolera CRLF sobre un archivo por lo demás válido → rc=0, sin diag"
FDD="$SCRATCH_ROOT/dd.md"
sed 's/$/\r/' "$FB" > "$FDD"
[ "$(grep -c $'\r' "$FDD")" -gt 0 ] || { echo "FAIL (dd): precondición rota — el fixture no quedó en CRLF"; exit 1; }
ERR_DD="$(mktemp -p "$SCRATCH_ROOT")"
set +e
"$TOOL" validar "$FDD" 2>"$ERR_DD"; RC_DD=$?
set -e
[ "$RC_DD" -eq 0 ] || { echo "FAIL (dd): esperaba rc=0 sobre archivo CRLF válido, fue $RC_DD. stderr: $(cat "$ERR_DD")"; exit 1; }
[ -z "$(cat "$ERR_DD")" ] || { echo "FAIL (dd): validar sobre CRLF válido no debería emitir diag. stderr: $(cat "$ERR_DD")"; exit 1; }

echo "OK: test-exploracion.sh — todos los casos pasaron"
