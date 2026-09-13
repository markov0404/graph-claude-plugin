#!/usr/bin/env bash
# Test de las descripciones públicas del plugin: plugin.json, marketplace.json y el frontmatter de skills/do/SKILL.md.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

PLUGIN_JSON="$ROOT/.claude-plugin/plugin.json"
MARKET_JSON="$ROOT/.claude-plugin/marketplace.json"
SKILL_DO="$ROOT/skills/do/SKILL.md"

FORMULA='Invocar con /graph:do <pedido> [--tier S|M|L] [--quick] [--full] [--budget <tokens>] [--gate-aprobado <archivo>] [--explorar]'

# Caso 1 — extracción y estructura: los tres archivos existen, ambos JSON parsean, el
# frontmatter de do es un YAML de UNA sola línea con UNA sola clave `description` entre
# comillas dobles, y ningún campo que no sea `description` cambió de valor (requisitos
# (d) y (e) del pedido). La validez YAML se comprueba contra la forma exacta que el
# pedido fija — no se usa PyYAML: la política de tooling del repo es cero dependencias
# externas (C2), así que solo entra la stdlib. Deja las CUATRO descripciones ya
# desescapadas, una por archivo, para que los casos 2-4 las asserten como texto.
PLUGIN_JSON="$PLUGIN_JSON" MARKET_JSON="$MARKET_JSON" SKILL_DO="$SKILL_DO" TMP="$TMP" python3 - <<'PY'
import json, os, re, sys

def fail(n, motivo):
    print("FAIL %d: %s" % (n, motivo))
    sys.exit(1)

plugin_path = os.environ["PLUGIN_JSON"]
market_path = os.environ["MARKET_JSON"]
skill_path = os.environ["SKILL_DO"]
tmp = os.environ["TMP"]

for p in (plugin_path, market_path, skill_path):
    if not os.path.isfile(p):
        fail(1, "falta el archivo %s" % p)

# --- (d) plugin.json: JSON válido y todo campo que no es `description`, intacto ---
try:
    plugin = json.load(open(plugin_path, encoding="utf-8"))
except Exception as e:
    fail(5, "plugin.json no es JSON válido: %s" % e)

ESPERADO_PLUGIN = {
    "name": "graph",
    "displayName": "GRAPH",
    "version": "0.1.0",
    "author": {"name": "markov0404"},
    "license": "MIT",
    "keywords": ["orchestration", "agents", "graph-engineering"],
}
if set(plugin) != set(ESPERADO_PLUGIN) | {"description"}:
    fail(5, "plugin.json cambió su conjunto de claves: %s (esperaba %s)"
         % (sorted(plugin), sorted(set(ESPERADO_PLUGIN) | {"description"})))
for k, v in ESPERADO_PLUGIN.items():
    if plugin[k] != v:
        fail(5, "plugin.json: el campo %r cambió — %r (esperaba %r)" % (k, plugin[k], v))

# --- (d) marketplace.json: JSON válido y todo campo que no es `description`, intacto ---
try:
    market = json.load(open(market_path, encoding="utf-8"))
except Exception as e:
    fail(5, "marketplace.json no es JSON válido: %s" % e)

if set(market) != {"name", "description", "owner", "plugins"}:
    fail(5, "marketplace.json cambió su conjunto de claves: %s" % sorted(market))
if market["name"] != "graph-marketplace":
    fail(5, "marketplace.json: el campo 'name' cambió — %r" % (market["name"],))
if market["owner"] != {"name": "dani"}:
    fail(5, "marketplace.json: el campo 'owner' cambió — %r" % (market["owner"],))
if not isinstance(market["plugins"], list) or len(market["plugins"]) != 1:
    fail(5, "marketplace.json: plugins[] debe tener exactamente una entrada, tiene %r"
         % (market["plugins"],))
entrada = market["plugins"][0]
if set(entrada) != {"name", "source", "description"}:
    fail(5, "marketplace.json: plugins[0] cambió su conjunto de claves: %s" % sorted(entrada))
if entrada["name"] != "graph":
    fail(5, "marketplace.json: plugins[0].name cambió — %r" % (entrada["name"],))
if entrada["source"] != "./":
    fail(5, "marketplace.json: plugins[0].source cambió — %r" % (entrada["source"],))

# --- (e) frontmatter de do: YAML válido, UNA clave `description`, UNA sola línea ---
texto_skill = open(skill_path, encoding="utf-8").read()
lineas = texto_skill.split("\n")
if not lineas or lineas[0] != "---":
    fail(6, "skills/do/SKILL.md no abre con una línea '---' de frontmatter")
try:
    cierre = lineas.index("---", 1)
except ValueError:
    fail(6, "skills/do/SKILL.md no cierra el frontmatter con una línea '---'")
bloque = lineas[1:cierre]
if len(bloque) != 1:
    fail(6, "el frontmatter de do debe ocupar UNA sola línea, ocupa %d: %r" % (len(bloque), bloque))
linea = bloque[0]
if "\t" in linea:
    fail(6, "el frontmatter de do contiene un tabulador (YAML no admite indentación con tabs)")
m = re.match(r'^description: "(.*)"$', linea)
if not m:
    fail(6, "el frontmatter de do no es exactamente una clave `description` con valor "
            "entre comillas dobles en una sola línea: %r" % linea)
crudo = m.group(1)
# Escalar YAML de comillas dobles: toda comilla interna debe venir escapada, y toda
# barra invertida debe abrir un escape válido. Si no, el YAML no parsearía.
i = 0
while i < len(crudo):
    c = crudo[i]
    if c == '"':
        fail(6, "el valor de `description` tiene una comilla doble sin escapar en la posición %d" % i)
    if c == "\\":
        if i + 1 >= len(crudo) or crudo[i + 1] not in '"\\/nrt':
            fail(6, "el valor de `description` tiene una barra invertida que no abre un "
                    "escape YAML válido en la posición %d" % i)
        i += 2
        continue
    i += 1
desc_skill = (crudo.replace('\\"', '"').replace("\\/", "/").replace("\\n", "\n")
                   .replace("\\r", "\r").replace("\\t", "\t").replace("\\\\", "\\"))

# --- (e bis) caracterización: el CUERPO de SKILL.md sigue entero ---
cuerpo = "\n".join(lineas[cierre + 1:])
SENTINELAS = [
    "# /graph:do — pipeline GRAPH",
    '"$ARGUMENTS"',
    "## Reglas duras",
    "## Fase 0 —",
    "## Fase 0.5 —",
    "## Fase 1 —",
    "## Fase 2 —",
    "## Fase 3 —",
    "## Fase 4 —",
    "## Fase 5 —",
    "## Fase 6 —",
    "## Fase 7 —",
    "## Fase 8 —",
]
for s in SENTINELAS:
    if s not in cuerpo:
        fail(7, "el cuerpo de skills/do/SKILL.md perdió la sentinela %r — "
                "el cambio de descripción no debe tocar nada fuera del frontmatter" % s)

# Las cuatro descripciones, ya desescapadas, una por archivo (las asserta el bash).
for nombre, valor in (
    ("d-plugin.txt", plugin["description"]),
    ("d-market.txt", market["description"]),
    ("d-market-plugin.txt", entrada["description"]),
    ("d-skill.txt", desc_skill),
):
    if not isinstance(valor, str) or not valor.strip():
        fail(1, "descripción vacía o no textual en %s: %r" % (nombre, valor))
    with open(os.path.join(tmp, nombre), "w", encoding="utf-8") as fh:
        fh.write(valor)
PY

IDS=(
  "plugin.json · description"
  "marketplace.json · description del marketplace"
  "marketplace.json · description del plugin en plugins[]"
  "skills/do/SKILL.md · description del frontmatter"
)
DESCS=(
  "$TMP/d-plugin.txt"
  "$TMP/d-market.txt"
  "$TMP/d-market-plugin.txt"
  "$TMP/d-skill.txt"
)

# Caso 2 — (a): ninguna descripción nombra el pipeline interno por capas ni usa flechas.
# En SKILL.md se evalúa SOLO la línea `description` del frontmatter, nunca el cuerpo
# (que sí describe las fases con flechas, y debe poder seguir haciéndolo).
for prohibido in 'escalado por capas' 'por capas' '→'; do
  i=0
  while [ "$i" -lt "${#DESCS[@]}" ]; do
    if grep -qF -- "$prohibido" "${DESCS[$i]}"; then
      echo "FAIL 2: ${IDS[$i]} todavía contiene '$prohibido' — $(cat "${DESCS[$i]}")"
      exit 1
    fi
    i=$((i + 1))
  done
done

# Caso 3 — (b): las cuatro hablan de `ejemplos`; plugin.json y el frontmatter de do
# hablan además de `evidencia`.
i=0
while [ "$i" -lt "${#DESCS[@]}" ]; do
  grep -qF -- 'ejemplos' "${DESCS[$i]}" || {
    echo "FAIL 3: ${IDS[$i]} no contiene la palabra 'ejemplos' — $(cat "${DESCS[$i]}")"
    exit 1
  }
  i=$((i + 1))
done
for idx in 0 3; do
  grep -qF -- 'evidencia' "${DESCS[$idx]}" || {
    echo "FAIL 3: ${IDS[$idx]} no contiene la palabra 'evidencia' — $(cat "${DESCS[$idx]}")"
    exit 1
  }
done

# Caso 4 — (c): el frontmatter de do conserva TEXTUALMENTE la fórmula de invocación,
# que es lo que el autocompletado de /graph:do muestra al usuario.
grep -qF -- "$FORMULA" "$TMP/d-skill.txt" || {
  echo "FAIL 4: el frontmatter de do perdió la fórmula de invocación textual '$FORMULA' — $(cat "$TMP/d-skill.txt")"
  exit 1
}

echo "OK: manifiestos (sin 'por capas' ni flechas, con 'ejemplos'/'evidencia', fórmula de invocación, JSON y frontmatter intactos)"
