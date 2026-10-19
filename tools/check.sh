#!/usr/bin/env bash
# Prüft und baut das Spiel:  ./tools/check.sh          (Syntax + alle Tests + Build)
#                             ./tools/check.sh --schnell  (nur Syntax)
set -uo pipefail
cd "$(dirname "$0")/.."
LUAU_DIR="${LUAU_DIR:-$(dirname "$(command -v luau 2>/dev/null || echo tools/bin/luau)")}"
LUAU="$LUAU_DIR/luau"; COMPILE="$LUAU_DIR/luau-compile"
if [ ! -x "$LUAU" ]; then
  echo "Luau fehlt – lade herunter nach tools/bin ..."
  mkdir -p tools/bin && curl -sSL -o /tmp/luau.zip https://github.com/luau-lang/luau/releases/latest/download/luau-ubuntu.zip \
    && unzip -oq /tmp/luau.zip -d tools/bin && chmod +x tools/bin/* || { echo "Download fehlgeschlagen"; exit 1; }
  LUAU=tools/bin/luau; COMPILE=tools/bin/luau-compile
fi
fehler=0
echo "== Syntax"
for f in src/*.lua karte/*.lua; do
  if ! out=$("$COMPILE" "$f" 2>&1 >/dev/null); then echo "  ✗ $f"; echo "$out" | head -5; fehler=1; fi
done
[ $fehler = 0 ] && echo "  ✓ alle Dateien" || exit 1
# Roblox: Script.Source darf höchstens 199.999 Zeichen haben (sonst lässt Studio den Code nicht setzen, v54)
for f in src/*.lua; do
  n=$(wc -c < "$f")
  if [ "$n" -ge 195000 ]; then echo "  ✗ $f hat $n Zeichen (Roblox-Grenze 200.000, Puffer 5.000) – Teile in ein Modul auslagern"; fehler=1; fi
done
[ $fehler = 0 ] || exit 1
[ "${1:-}" = "--schnell" ] && exit 0
echo "== Build"
python3 tools/build.py | sed 's/^/  /' || exit 1
echo "== Tests"
tmp=$(mktemp -d)
for t in tests/*.luau; do
  python3 tools/runner.py "$t" "$tmp/run.luau" >/dev/null
  out=$(timeout 300 "$LUAU" "$tmp/run.luau" 2>&1); code=$?
  if [ $code != 0 ] || echo "$out" | grep -q '^ERROR'; then
    echo "  ✗ $(basename $t)"; echo "$out" | grep -A2 '^ERROR' | head -12; echo "$out" | tail -3; fehler=1
  else echo "  ✓ $(basename $t)"; fi
done
rm -rf "$tmp"
[ $fehler = 0 ] && echo "ALLES OK – Dateien in dist/" || { echo "FEHLER – nicht ausliefern"; exit 1; }
