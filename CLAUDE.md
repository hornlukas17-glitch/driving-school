# Driving School (Roblox) – Projektnotizen

Roblox-Fahrschulspiel von Lukas. Antworten an Lukas auf **Deutsch**, kurz und ehrlich. **Alle Texte im Spiel auf Englisch.**

## Regeln, die nie gebrochen werden
- **Fahrgefühl nicht ändern.** Die Client-Steuerung (Hinge-Räder, direkte Gier-Lenkung, Grip-Impuls in `src/Client.lua`) gilt für ALLE Autos. Neue Fahrzeuge bekommen nur andere Modell-Attribute (MaxTempo, Antrieb, Bremse, Lenkwinkel, Grip, Lenkdirekt, Anpressdruck, Radius, Radstand).
- Vor jeder Auslieferung: `./tools/check.sh` muss „ALLES OK“ melden.
- Bei jeder Auslieferung `VERSION` +1 und `CHANGELOG.md` ergänzen (Skill `release`).

## Aufbau
- `karte/stadt_generator.lua` – Karte, läuft einmal in der Studio-Befehlszeile. Nur neu ausliefern, wenn sich die Karte ändert.
- `src/` – Spielcode. `tools/build.py` baut daraus `dist/fuehrerschein_installer.lua` (Befehlszeile) und `dist/DrivingSchool_v<N>.rbxmx` (Drag & Drop).
  - ReplicatedStorage/Fuehrerschein: `Verkehrsregeln`, `Verkehr`, Remotes `Aktion` (RF), `Oeffnen`, `Fahrstunde`, `Blinker`, `VerkehrDaten`.
  - Server-Script `FuehrerscheinServer` (`Server.lua`) mit Modulen Fragen, Auto, Fahrstunden, Strafen, Umwelt, Fahrzeugpflege, Missionen.
  - LocalScript `FuehrerscheinClient` (`Client.lua`). `v{VERSION}` im Code wird beim Build ersetzt.
- `tools/mock.luau` – Roblox-Nachbau zum Testen ohne Studio. `tests/*.luau` – Szenarien (laufen über `tools/runner.py`). Ein Test schlägt fehl, wenn eine `ERROR:`-Zeile erscheint.
- Neue Funktion → passenden Test in `tests/` ergänzen.
- `tools/mesh/` – Karosserie-Generatoren: `basis.py` (gemeinsam) + je Auto eine Formdatei (`suv.py`, `sport.py`). `python3 tools/mesh/<auto>.py` schreibt `dist/mesh/<Vorlage>.obj` und erzeugt `src/Karosserien.lua` neu (nie von Hand ändern). `Auto.bauenPrivat` nutzt die Karosserie, wenn das Modell im ServerStorage liegt; der Typ-Zweig braucht dafür `if rundVorlage then rundBauen() else <Block> end`. Vorschau: `python3 tools/mesh/render.py <obj> <info.json> <png> r,g,b`. Nur eigene Designs, keine Nachbauten echter Automodelle oder Marken.

## Daten
DataStore `Fuehrerschein_v1` (nie umbenennen, sonst verlieren Spieler alles). Neue Felder immer mit Standardwert ergänzen. OrderedDataStores `Rangliste_Level/Km/Perfekt`.

## Karte (Studs)
Stadt |x|,|z| ≤ 324 (50 km/h) · Autobahn z = -520 (130) · Siedlungen x 405–790 (30) · Fahrschule ~(550,40) · Depot (600,386) · Pizzeria (375,~60) · Autohaus (85,-376) · Servicestation x 336–412, z -96..-10 · Tankstelle West (-819,-160) · Parkhaus (156,-156) · Park/Bestenlisten (-156,156) · Kreisel (0,600) und (780,600).
Tempolimits zentral in `src/Verkehrsregeln.lua` (WOHNSTRASSEN muss zum Generator passen).

## Offene Punkte
- Etappe 2 Rest: Busfahrer-Job, Abschlepp-Job.
- Etappe 3: Spieler-Polizei, Gebrauchtwagenmarkt, echte Spieler als Fahrlehrer, Rettungsdienst/Feuerwehr, Schaltgetriebe, Hupe (Sound-ID von Lukas nötig).
- Noch nie in echtem Studio getestet – Fehlermeldungen von Lukas haben Vorrang.
