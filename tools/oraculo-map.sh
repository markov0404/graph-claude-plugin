#!/usr/bin/env bash
# Mapa de oráculo (ronda 8, fix): escanea archivos de test y su fuerza
# mecánica para .graph/oraculo.md. bash + python3 stdlib, cero dependencias
# externas.
#
# Uso:
#   oraculo-map.sh scan <dir>
#     TSV a stdout — archivo<TAB>n_tests<TAB>fuerza<TAB>hash7 — una fila por
#     archivo de test hallado bajo <dir> (patrón contractual más abajo).
#     Determinista: dos corridas sobre el mismo árbol producen bytes
#     idénticos (orden fijado por `sort`, nunca por el orden de `find`) —
#     y esto vale INDEPENDIENTEMENTE del locale del invocador (ver más
#     abajo, sección "Locale y determinismo").
#   oraculo-map.sh verify <dir> <archivo> <hash7>
#     rc=0 si <archivo> (relativo a <dir>) existe y su hash7 actual
#     coincide con <hash7>; rc=1 con `diag:` en stderr si falta o cambió.
#   oraculo-map.sh fuerza <archivo>
#   oraculo-map.sh fuerza - <nombre-con-extension>
#     Ronda 9 (fix r9): evalúa UN archivo suelto (típicamente un
#     ejemplo/test REDACTADO por el agente, ANTES de existir como parte
#     de ningún repo) y no un directorio ya escaneable. Por archivo, la
#     extensión REAL del nombre decide el lenguaje. Por stdin (`-`), el
#     nombre es OBLIGATORIO — es la ÚNICA fuente de extensión posible
#     cuando no hay un path real que abrir — y viaja como segundo
#     argumento: `fuerza - ejemplo.py`. Sin nombre → rc=1 con
#     `diag: fuerza - requiere un nombre de archivo con extensión (ej:
#     fuerza - ejemplo.py)`.
#     Emite UNA sola línea TSV a stdout: <n_tests><TAB><fuerza><TAB><motivo>
#     — mismos valores de n_tests/fuerza que produciría `scan` si ese
#     mismo contenido, con ese mismo nombre, ya estuviera en disco (misma
#     función de análisis Y mismo dispatch de lenguaje, ver abajo), más un
#     <motivo> corto y accionable: 'sin tests (...)', 'sin asserts
#     reales', 'solo assert True (...)' (rama python: hay asserts pero
#     todos triviales), 'no parsea (SyntaxError): <detalle>', u 'ok: N
#     asserts reales en M tests'.
#     No hay hash7 (no hay archivo "vigente" que versionar: el ejemplo
#     recién se redactó) ni columna de archivo (siempre una sola fila).
#     Dispatch python-vs-otros: EXACTAMENTE el de `scan` — extensión
#     ".py" del nombre (real, o del hint por stdin) → rama AST; cualquier
#     otra extensión → rama de conteo de "otros lenguajes". Prohibido
#     adivinar por parseabilidad (probar `ast.parse()`): un nombre sin
#     ".py" SIEMPRE va por "otros", aunque su contenido resulte ser
#     Python válido por azar; y un ".py" que no parsea SIEMPRE es "débil"
#     con motivo 'no parsea (SyntaxError): <detalle>' — nunca cae a la
#     rama de "otros" ni sale "fuerte" (ver ruling r9 §4: el fallback de
#     parseabilidad hacía divergir a `fuerza` de `scan`, y además era
#     fail-open con Python roto; ver "Límites CONOCIDOS" para el límite
#     real que sí queda: el nombre pasado por stdin manda, un hint con la
#     extensión equivocada hace analizar con el lenguaje equivocado).
#     Fail-closed: <archivo> inexistente o no-regular → rc=1 con diag;
#     stdin sin nombre → rc=1 con diag (ver arriba).
#
# TEST_PATTERN: VERBATIM el mismo de tools/red.sh (ronda 7) — se fija acá
# para que ambos tools no diverjan (directorios test/tests/spec a cualquier
# profundidad; test_*, *_test.*, *.test.*, *.spec.*, conftest*, fixtures/).
#
# fuerza (fuerte|débil):
#   - Regla común a AMBAS ramas (python y "otros"): n_tests==0 → SIEMPRE
#     "débil", sin excepción. "fuerte" exige n_tests>0 Y AL MENOS UN assert
#     real. Un README.md bajo tests/ que menciona "expect(" en prosa, o un
#     helpers.js sin ninguna declaración it(/test(, tienen n_tests==0 y por
#     lo tanto SIEMPRE son "débil" — nunca se infiere fuerza de asserts
#     sueltos en un archivo que no declara ni un solo test.
#   - Archivos .py: AST real (módulo python3 `ast`, no regex). Se cuentan
#     las funciones/métodos de nivel superior cuyo nombre empieza con
#     "test" (cubre tanto `test_foo` de pytest como el prefijo `test` que
#     exige unittest); "fuerte" si AL MENOS UNA tiene un assert real;
#     "débil" si el archivo no tiene ninguna función de test, o todas sus
#     asserts son triviales/ausentes. Trivial = `assert True` (constante
#     literal) o `self.assertTrue(True)` / `self.assertFalse(False)` con
#     argumento literal fijo — cualquier otro assert (comparación real,
#     llamada a la función bajo prueba, assertEqual/assertIn/etc.) cuenta
#     como real. `with pytest.raises(...):` / `with raises(...):` (context
#     manager, forma "with-item") TAMBIÉN cuenta como assert real: es la
#     forma estándar de pytest para verificar excepciones y no usar un
#     assert explícito no la vuelve débil. Un archivo que no parsea
#     (SyntaxError) degrada a "débil" sin inventar nada (misma filosofía
#     que tools/symbol-map.sh).
#   - Otros lenguajes: heurística declarada de conteo (no AST): "fuerte" si
#     n_tests>0 Y el archivo tiene AL MENOS UNA llamada a
#     assert*/expect(/.should. en algún punto; "débil" en cualquier otro
#     caso (incluido n_tests==0, ver regla común arriba). n_tests cuenta
#     ocurrencias de `it(` / `test(` (convención JS/Mocha/Jest/node:test) —
#     un lenguaje sin ese patrón puede subcontar n_tests; no se inventa un
#     conteo donde no hay convención reconocida.
#   - `scan` y `fuerza` comparten TANTO el dispatch de lenguaje (extensión
#     del nombre, ver arriba) COMO la función de análisis por lenguaje
#     (`analyze_python_verbose` / `analyze_other_verbose`, python embebido
#     más abajo): para el mismo contenido y el mismo nombre no hay una
#     segunda heurística que pueda divergir. Antes del fix de r9 sí la
#     había — un fallback `ast.parse()` en `fuerza` que no existía en
#     `scan` — y fue eliminado; el invariante scan≡fuerza (mismo n_tests
#     y misma fuerza) se testea explícitamente (tests/test-oraculo-map.sh,
#     caso bb). La función que además devuelve el <motivo> (tercer campo)
#     es la misma que usa `scan` para el veredicto — `fuerza` lo imprime,
#     `scan` lo descarta. En la rama python, `has_real_assert` (la
#     usa también el veredicto de `scan`) está definida en términos de
#     `iter_assert_signals` — el generador que también cuenta los asserts
#     reales para el motivo 'ok: N asserts reales en M tests' — mismo
#     criterio real/trivial en un solo lugar. La distinción de motivo
#     'solo assert True' (hay asserts pero todos triviales) SOLO existe en
#     la rama python (AST puede ver el valor literal); la rama de "otros
#     lenguajes" no distingue trivial de real por regex, así que ahí
#     'sin asserts reales' cubre ambos casos (asimetría ya documentada
#     arriba entre las dos ramas, no una nueva).
#
# hash7: md5 (primeros 7 hex) del CONTENIDO en bytes del archivo, tal cual
# está en disco (sin normalizar fin de línea ni encoding).
#
# Locale y determinismo: el script FIJA su propio locale (LC_ALL=C) y
# fuerza a python3 a decodificar argv/stdin como UTF-8 con
# errors=surrogateescape (PYTHONUTF8=1, PYTHONIOENCODING) — nunca hereda
# LC_ALL/LANG del invocador. Esto evita que dos corridas idénticas
# diverjan en bytes según el locale de quien invoca (p.ej. un nombre de
# archivo con bytes no-UTF8 válido, o `grep -E` comportándose distinto
# bajo una locale multibyte vs C). El CONTENIDO de los archivos (para AST
# / conteo de asserts) se decodifica aparte con errors="replace": ahí no
# hace falta preservar bytes exactos (round-trip), solo un resultado de
# análisis determinista para la misma entrada — por eso se elige un
# criterio distinto (replace) que para las RUTAS (surrogateescape, que sí
# deben poder usarse para abrir el archivo real en disco).
#
# Fail-closed REAL: un trap de EXIT emite un `diag:` genérico + exit 1 si
# el script termina sin haber marcado explícitamente una salida controlada
# (éxito o el rc=1 contractual de verify) — nunca stdout vacío con rc=0
# encubriendo un error interno. `scan` nunca imprime TSV parcial: el
# análisis completo se arma en memoria y se escribe en un solo golpe; si
# python3 falla a mitad de camino, no sale ninguna línea a stdout.
# También es fail-closed cualquier error de `find` al recorrer <dir>
# (directorio ilegible, etc.): nunca un TSV incompleto sin avisar.
#
# Límites CONOCIDOS y declarados (no se ocultan, se documentan):
#   - Un `assert` en código muerto (p.ej. después de un `return`, o en una
#     rama de un `if False:`) cuenta igual que uno alcanzable: la
#     heurística puede sobre-reclamar "fuerte" en ese caso extremo.
#   - Granularidad por ARCHIVO, no por test: un solo assert real en
#     cualquier función de test alcanza para marcar TODO el archivo como
#     "fuerte", aunque el resto de sus tests sean triviales.
#   - Asserts dentro de un helper que la función de test invoca (no
#     inline en el cuerpo de la función `test_*` misma) NO se detectan:
#     el AST solo recorre el cuerpo de la función de nivel superior, no
#     sigue llamadas a funciones definidas aparte. Esto puede marcar
#     "débil" un archivo que en realidad verifica algo indirectamente
#     (falso negativo, nunca falso positivo).
#   - hash7 son 7 hex = 28 bits: hay riesgo de colisión de prefijo con
#     probabilidad no despreciable en árboles muy grandes (no es un hash
#     de integridad criptográfica, es un identificador corto para diffs
#     legibles en el mapa).
#   - Los symlinks que matchean TEST_PATTERN se DETECTAN pero se EXCLUYEN
#     del análisis (no se siguen ni se cuentan como fila del TSV): se
#     avisa con `diag: symlink omitido: <path>` en stderr — nunca en
#     silencio — pero no se resuelve el destino ni se decide su fuerza.
#   - `fuerza - <nombre>`: el dispatch depende ENTERAMENTE del <nombre>
#     que pasa el llamador (no hay path real que inspeccionar por stdin)
#     — si el hint trae la extensión equivocada (p.ej. contenido Python
#     pero <nombre> no termina en ".py"), se analiza con el lenguaje
#     equivocado. Es responsabilidad del llamador pasar el nombre real
#     que el ejemplo va a tener en disco (contrato con la Fase 5, ronda
#     9: `fuerza - <nombre>` sobre cada ejemplo redactado). No se
#     inspecciona el shebang ni ningún otro heurístico adicional — a
#     propósito: es EXACTAMENTE la misma limitación que ya tiene `scan`
#     (decide por extensión del path, no por contenido), no es una
#     limitación nueva de `fuerza`, ahora solo también explícita acá.
set -euo pipefail

TEST_PATTERN='(^|/)tests?/|(^|/)spec/|(^|/)test_[^/]*($|/)|(^|/)[^/]*_test\.[^/]+$|(^|/)[^/]*\.test\.[^/]+$|(^|/)[^/]*\.spec\.[^/]+$|(^|/)conftest[^/]*$|(^|/)fixtures($|/)'

# Determinismo independiente del invocador: nunca heredamos el locale del
# caller. python3 decodifica argv/stdin como UTF-8+surrogateescape pase lo
# que pase con LC_ALL/LANG afuera (PYTHONUTF8 fuerza esa decodificación de
# argv/filesystem; PYTHONIOENCODING cubre stdin/stdout explícitamente).
export LC_ALL=C
export PYTHONUTF8=1
export PYTHONIOENCODING='utf-8:surrogateescape'

DONE=false
declare -a SCAN_TMP=()

on_exit() {
  local rc=$?
  if [ "${#SCAN_TMP[@]}" -gt 0 ]; then
    rm -f "${SCAN_TMP[@]}" 2>/dev/null || true
  fi
  if [ "$DONE" != true ]; then
    echo "diag: error interno inesperado (rc=$rc) — fail-closed" >&2
    exit 1
  fi
}
trap on_exit EXIT

fail_closed() {
  echo "diag: $1" >&2
  DONE=true
  exit 1
}

# Script python embebido (stdlib únicamente: ast, hashlib, os, re, sys).
# UN solo cuerpo para "scan" y "fuerza" (ronda 9): comparten las mismas
# funciones de análisis por lenguaje, así que no hay dos heurísticas de
# fuerza que puedan divergir (ver comentario largo de "fuerza" más
# arriba). Dispatch por argv[1]=modo:
#   modo "scan": argv[2]=raíz absoluta. La LISTA de rutas relativas (ya
#     ordenadas y filtradas por TEST_PATTERN en bash, una por línea) llega
#     por STDIN — no por argv — para no pisar el límite MAX_ARG_STRLEN del
#     kernel en árboles con miles de archivos de test (una lista de
#     ~3500+ rutas como un solo argumento revienta execve; por stdin no
#     hay ese techo). Emite el TSV completo en UN solo write al final
#     (atomicidad: si algo falla antes, no sale nada a stdout).
#   modo "fuerza": argv[2]=nombre que decide la extensión (el path real,
#     si vino de un archivo; el hint obligatorio, si vino de stdin — bash
#     ya validó que no esté vacío antes de invocar python3, nunca llega
#     "-" acá). El CONTENIDO a analizar llega por STDIN (mismo motivo que
#     "scan": nada de tamaño-vía-argv). Emite una sola línea TSV al final.
read -r -d '' PY_ANALYZE <<'PYEOF' || true
import ast
import hashlib
import os
import re
import sys


def sanitize_motivo(texto):
    """Choke point único de saneo: el <motivo> viaja como tercer campo de
    un TSV de una sola línea, así que un TAB o un newline adentro lo
    corrompería (hallazgo r9 #7). Cubre cualquier motivo, incluido el
    detalle de una SyntaxError, que en teoría podría traer algo raro."""
    return texto.replace("\t", " ").replace("\r", " ").replace("\n", " ")


def is_trivial_true(node):
    return isinstance(node, ast.Constant) and node.value is True


def is_trivial_false(node):
    return isinstance(node, ast.Constant) and node.value is False


def collect_test_funcs(tree):
    found = []

    def walk(node):
        for child in ast.iter_child_nodes(node):
            if isinstance(child, (ast.FunctionDef, ast.AsyncFunctionDef)):
                if child.name.startswith("test"):
                    found.append(child)
                # no se recursa dentro del cuerpo de la función: evita
                # contar helpers anidados como tests de nivel superior/método
            elif isinstance(child, ast.ClassDef):
                walk(child)
            else:
                walk(child)

    walk(tree)
    return found


def _call_name(call_node):
    if isinstance(call_node.func, ast.Attribute):
        return call_node.func.attr
    if isinstance(call_node.func, ast.Name):
        return call_node.func.id
    return None


def iter_assert_signals(func_node):
    """Recorre func_node y va emitiendo "real" o "trivial" por cada
    construcción tipo-assert hallada. Fuente ÚNICA de qué cuenta como
    real vs trivial: has_real_assert (el veredicto que usa `scan`) y el
    conteo de motivo que usa `fuerza` llaman AMBOS a este generador — no
    hay una segunda heurística de fuerza que pueda divergir de la
    primera, solo una capa de conteo encima del mismo criterio."""
    for n in ast.walk(func_node):
        if isinstance(n, ast.Assert):
            if is_trivial_true(n.test):
                yield "trivial"
            else:
                yield "real"
        elif isinstance(n, ast.Call):
            fname = _call_name(n)
            if fname == "assertTrue":
                if n.args and is_trivial_true(n.args[0]):
                    yield "trivial"
                else:
                    yield "real"
            elif fname == "assertFalse":
                if n.args and is_trivial_false(n.args[0]):
                    yield "trivial"
                else:
                    yield "real"
            elif fname and fname.startswith("assert"):
                yield "real"
        elif isinstance(n, (ast.With, ast.AsyncWith)):
            # with pytest.raises(...): / with raises(...): cuenta como
            # assert real (falso negativo si no, muy común en pytest).
            for item in n.items:
                ctx = item.context_expr
                if isinstance(ctx, ast.Call) and _call_name(ctx) == "raises":
                    yield "real"


def has_real_assert(func_node):
    return any(kind == "real" for kind in iter_assert_signals(func_node))


def analyze_python_verbose(data):
    """(n_tests, fuerza, motivo) — misma AST/heurística que analyze_python
    usaba antes de r9; ahora también arma el motivo de `fuerza` con la
    MISMA pasada (iter_assert_signals), nunca una heurística aparte."""
    try:
        text = data.decode("utf-8", errors="replace")
        tree = ast.parse(text)
    except (SyntaxError, ValueError) as exc:
        # <detalle> real de la excepción (ruling r9 §4) — no un mensaje
        # genérico. sanitize_motivo() en el choke point de salida cubre
        # cualquier TAB/newline que str(exc) pudiera traer.
        return (0, "débil", "no parsea (SyntaxError): %s" % exc)
    tests = collect_test_funcs(tree)
    if not tests:
        return (0, "débil", "sin tests (ninguna función con prefijo 'test')")
    n = len(tests)
    real_total = 0
    trivial_seen = False
    for f in tests:
        for kind in iter_assert_signals(f):
            if kind == "real":
                real_total += 1
            elif kind == "trivial":
                trivial_seen = True
    if real_total > 0:
        return (n, "fuerte", "ok: %d asserts reales en %d tests" % (real_total, n))
    if trivial_seen:
        return (n, "débil", "solo assert True (aserción trivial, no verifica nada)")
    return (n, "débil", "sin asserts reales")


def analyze_python(data):
    n_tests, fuerza, _motivo = analyze_python_verbose(data)
    return (n_tests, fuerza)


TESTDECL_RE = re.compile(r'\b(?:it|test)\s*\(')
ASSERT_RE = re.compile(r'\bassert\.\w+\s*\(|\bassert\w*\s*\(|\.should\b|\bexpect\s*\(')


def analyze_other_verbose(data):
    """(n_tests, fuerza, motivo) — mismo conteo por regex que analyze_other
    usaba antes de r9; la rama de "otros lenguajes" no distingue trivial
    de real (no hay AST), así que 'sin asserts reales' cubre ambos."""
    text = data.decode("utf-8", errors="replace")
    n_tests = 0
    n_asserts = 0
    for line in text.splitlines():
        n_tests += len(TESTDECL_RE.findall(line))
        n_asserts += len(ASSERT_RE.findall(line))
    if n_tests == 0:
        # sin ninguna declaración it(/test( reconocida: nunca "fuerte",
        # aunque haya asserts/expect sueltos (prosa, helpers, dead code).
        return (0, "débil", "sin tests (ninguna declaración it(/test()")
    if n_asserts > 0:
        return (n_tests, "fuerte", "ok: %d asserts reales en %d tests" % (n_asserts, n_tests))
    return (n_tests, "débil", "sin asserts reales")


def analyze_other(data):
    n_tests, fuerza, _motivo = analyze_other_verbose(data)
    return (n_tests, fuerza)


def main():
    mode = sys.argv[1]

    if mode == "scan":
        root = sys.argv[2]
        raw = sys.stdin.buffer.read()
        filelist = raw.decode("utf-8", errors="surrogateescape")
        rels = [l for l in filelist.split("\n") if l != ""]

        lines_out = []
        for rel in rels:
            abs_path = os.path.join(root, rel)
            with open(abs_path, "rb") as fh:
                data = fh.read()
            h7 = hashlib.md5(data).hexdigest()[:7]
            if rel.endswith(".py"):
                n_tests, fuerza = analyze_python(data)
            else:
                n_tests, fuerza = analyze_other(data)
            lines_out.append("%s\t%d\t%s\t%s" % (rel, n_tests, fuerza, h7))

        out = "\n".join(lines_out)
        if lines_out:
            out += "\n"
        sys.stdout.write(out)

    elif mode == "fuerza":
        # argv[2] = nombre que decide la extensión (path real si vino de
        # archivo, hint obligatorio si vino de stdin — bash ya validó que
        # no esté vacío). El CONTENIDO a analizar siempre llega por stdin
        # — igual de determinista y sin tope de tamaño por argv que la
        # vía "scan". Dispatch EXACTAMENTE el de "scan" (ver arriba): SOLO
        # por extensión, sin fallback de parseabilidad — prohibido por el
        # ruling r9 §4 (adivinar con un `ast.parse()` de prueba hacía
        # divergir a `fuerza` de `scan` para el mismo contenido, y además
        # era fail-open: Python roto caía a la rama de conteo y podía
        # salir "fuerte").
        path_hint = sys.argv[2]
        data = sys.stdin.buffer.read()

        if path_hint.endswith(".py"):
            n_tests, fuerza, motivo = analyze_python_verbose(data)
        else:
            n_tests, fuerza, motivo = analyze_other_verbose(data)
        sys.stdout.write("%d\t%s\t%s\n" % (n_tests, fuerza, sanitize_motivo(motivo)))

    else:
        raise ValueError("modo interno desconocido para PY_ANALYZE: %r" % mode)


try:
    main()
except Exception as exc:  # fail-closed: nunca TSV parcial, siempre diag
    sys.stderr.write("diag: error interno en oraculo-map (python): %s\n" % exc)
    sys.exit(1)
PYEOF

# scan <dir> ------------------------------------------------------------
scan_mode() {
  local dir="${1:-}"
  [ -n "$dir" ] || fail_closed "scan: falta <dir>"
  [ -d "$dir" ] || fail_closed "scan: '$dir' no es un directorio"
  dir="$(cd "$dir" && pwd -P)"

  # Artefactos de ejecución podados: nunca son oráculo y en un repo real
  # inundan el mapa (medido en un repo grande externo: 155 de 307 filas eran __pycache__/*.pyc).
  local -a prune_expr=( \( -name .git -o -name node_modules -o -name .graph -o -name __pycache__ -o -name .pytest_cache -o -name .tox -o -name .venv -o -name venv -o -name dist -o -name build -o -name .mypy_cache -o -name .ruff_cache \) -prune -o )

  local find_files find_links find_err
  find_files="$(mktemp)"; SCAN_TMP+=("$find_files")
  find_links="$(mktemp)"; SCAN_TMP+=("$find_links")
  find_err="$(mktemp)"; SCAN_TMP+=("$find_err")

  local rc_f=0 rc_l=0
  # `|| rc_x=$?` (no `rc_x=$?` suelto): bajo `set -e` una simple command
  # que falla dispara errexit ANTES de que la asignación siguiente llegue
  # a ejecutarse — así el rc queda capturado sin abortar el script acá.
  find "$dir" "${prune_expr[@]}" -type f -print0 >"$find_files" 2>"$find_err" || rc_f=$?
  find "$dir" "${prune_expr[@]}" -type l -print0 >"$find_links" 2>>"$find_err" || rc_l=$?

  # find fail-closed: cualquier error (dir ilegible, etc.) aborta el scan
  # entero con diag — nunca un TSV incompleto y silencioso con rc=0.
  if [ "$rc_f" -ne 0 ] || [ "$rc_l" -ne 0 ] || [ -s "$find_err" ]; then
    local errmsg
    errmsg="$(tr '\n' ' ; ' < "$find_err")"
    fail_closed "find falló al recorrer '$dir' (rc=$rc_f/$rc_l): ${errmsg:-sin detalle en stderr}"
  fi

  local -a rels=()
  local f rel

  # Conjunto de paths IGNORADOS por git, calculado UNA vez (no una llamada por
  # archivo: eso mataría el determinismo de costo en repos grandes). Hallado
  # autoaplicando el plugin a su propio repo (2026-09-08): `tests/graph-e2.out`
  # —salida de una corrida headless, listada en .gitignore y sin rastrear—
  # entraba como fila del mapa de oráculo. El mapa describe la superficie de
  # test del REPO; lo que git ignora no es parte de esa superficie. Generaliza
  # el pruning de .pyc de r8 en vez de acumular denylists por extensión, y no
  # toca TEST_PATTERN (invariante: VERBATIM el de red.sh).
  # Si <dir> no es un repo git, IGNORADOS queda vacío y no se filtra nada.
  local IGNORADOS=""
  IGNORADOS="$(git -C "$dir" ls-files --others --ignored --exclude-standard 2>/dev/null || true)"

  # archivos regulares que matchean TEST_PATTERN -------------------------
  while IFS= read -r -d '' f; do
    rel="${f#"$dir"/}"
    printf '%s' "$rel" | grep -qE "$TEST_PATTERN" || continue
    # ignorado por git → no es superficie de test del repo
    if [ -n "$IGNORADOS" ] && printf '%s\n' "$IGNORADOS" | grep -qxF "$rel"; then continue; fi
    # extensiones compiladas/binarias: fuera aunque el path matchee el patrón
    case "$rel" in
      *.pyc|*.pyo|*.so|*.o|*.class|*.jar|*.wasm) continue ;;
    esac
    case "$rel" in
      *$'\t'*|*$'\n'*)
        fail_closed "archivo de test con TAB o salto de línea en el nombre (no soportado, TSV quedaría malformado): $(printf '%q' "$rel")"
        ;;
    esac
    rels+=("$rel")
  done < "$find_files"

  # symlinks que matchean TEST_PATTERN: NUNCA en silencio, pero tampoco
  # se analizan (límite declarado en el encabezado) ----------------------
  while IFS= read -r -d '' f; do
    rel="${f#"$dir"/}"
    printf '%s' "$rel" | grep -qE "$TEST_PATTERN" || continue
    case "$rel" in
      *$'\t'*|*$'\n'*)
        fail_closed "symlink de test con TAB o salto de línea en el nombre (no soportado): $(printf '%q' "$rel")"
        ;;
    esac
    echo "diag: symlink omitido: $rel" >&2
  done < "$find_links"

  local -a sorted=()
  if [ "${#rels[@]}" -gt 0 ]; then
    while IFS= read -r line; do
      [ -n "$line" ] && sorted+=("$line")
    done < <(printf '%s\n' "${rels[@]}" | LC_ALL=C sort)
  fi

  if [ "${#sorted[@]}" -eq 0 ]; then
    DONE=true
    exit 0
  fi

  printf '%s\n' "${sorted[@]}" | python3 -c "$PY_ANALYZE" scan "$dir"
  DONE=true
}

# fuerza <archivo> | fuerza - <nombre-con-extension> ------------------------
# Ronda 9 (fix r9): evalúa un archivo suelto (ejemplo/test recién
# redactado, no necesariamente parte todavía de ningún árbol) o el
# contenido de stdin — por stdin el nombre (con extensión) es OBLIGATORIO,
# es la única fuente de extensión posible cuando no hay path real que
# abrir. Reusa LA MISMA función de análisis Y el mismo dispatch de
# lenguaje que `scan` (ver PY_ANALYZE arriba: extensión del nombre, nunca
# un `ast.parse()` de prueba) — nada de una heurística paralela.
# Fail-closed simétrico al resto: sin manejo `||` propio, se apoya en
# `set -e` + el trap de EXIT (igual que scan_mode con python3), así un
# error interno de python3 cae por la misma vía genérica ya cubierta por
# los tests existentes.
fuerza_mode() {
  local archivo="${1:-}" nombre="${2:-}"
  [ -n "$archivo" ] \
    || fail_closed "fuerza: falta <archivo> (usar '-' <nombre> para leer de stdin)"

  if [ "$archivo" = "-" ]; then
    # r9 fix (contrato §4): por stdin el nombre es OBLIGATORIO — es la
    # única fuente de extensión posible, y el dispatch ya no admite
    # adivinar por parseabilidad (ver PY_ANALYZE).
    [ -n "$nombre" ] \
      || fail_closed "fuerza - requiere un nombre de archivo con extensión (ej: fuerza - ejemplo.py)"
    python3 -c "$PY_ANALYZE" fuerza "$nombre"
  else
    [ -z "$nombre" ] \
      || fail_closed "uso: oraculo-map.sh fuerza <archivo> (un segundo argumento solo es válido junto con '-')"
    [ -f "$archivo" ] \
      || fail_closed "fuerza: '$archivo' no existe o no es un archivo regular"
    python3 -c "$PY_ANALYZE" fuerza "$archivo" < "$archivo"
  fi
  DONE=true
}

# verify <dir> <archivo> <hash7> ----------------------------------------
verify_mode() {
  local dir="${1:-}" archivo="${2:-}" want="${3:-}"
  [ -n "$dir" ] || fail_closed "verify: falta <dir>"
  [ -d "$dir" ] || fail_closed "verify: '$dir' no es un directorio"
  [ -n "$archivo" ] || fail_closed "verify: falta <archivo>"
  [ -n "$want" ] || fail_closed "verify: falta <hash7>"
  dir="$(cd "$dir" && pwd -P)"

  local abs="$dir/$archivo"
  if [ ! -f "$abs" ]; then
    echo "diag: falta $archivo (no existe bajo $dir)" >&2
    DONE=true
    exit 1
  fi

  local got
  got="$(python3 -c '
import hashlib, sys
with open(sys.argv[1], "rb") as fh:
    data = fh.read()
sys.stdout.write(hashlib.md5(data).hexdigest()[:7])
' "$abs")" || fail_closed "verify: no se pudo calcular el hash de $archivo"

  if [ "$got" != "$want" ]; then
    echo "diag: hash cambió para $archivo (esperado $want, actual $got)" >&2
    DONE=true
    exit 1
  fi

  DONE=true
  exit 0
}

# --- dispatch ---------------------------------------------------------------
[ $# -ge 1 ] || fail_closed "uso: oraculo-map.sh scan <dir> | verify <dir> <archivo> <hash7> | fuerza <archivo> | fuerza - <nombre-con-extension>"
MODE="$1"
shift
case "$MODE" in
  scan)
    [ $# -eq 1 ] || fail_closed "uso: oraculo-map.sh scan <dir> (recibí $# argumentos)"
    scan_mode "$1"
    ;;
  verify)
    [ $# -eq 3 ] || fail_closed "uso: oraculo-map.sh verify <dir> <archivo> <hash7> (recibí $# argumentos)"
    verify_mode "$1" "$2" "$3"
    ;;
  fuerza)
    [ $# -ge 1 ] && [ $# -le 2 ] \
      || fail_closed "uso: oraculo-map.sh fuerza <archivo> | fuerza - <nombre-con-extension> (recibí $# argumentos)"
    fuerza_mode "$@"
    ;;
  *)
    fail_closed "modo desconocido '$MODE' (usar 'scan', 'verify' o 'fuerza')"
    ;;
esac
