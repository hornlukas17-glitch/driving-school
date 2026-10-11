---
name: release
description: Neue Version des Driving-School-Spiels testen, bauen und an Lukas ausliefern. Nutzen, wenn eine Änderung fertig ist und Lukas sie in Studio einspielen soll.
---
1. `./tools/check.sh` ausführen. Bei Fehlern: reparieren, nicht ausliefern.
2. `VERSION` um 1 erhöhen, `./tools/check.sh` erneut (baut `dist/` mit neuer Nummer).
3. `CHANGELOG.md` oben ergänzen: 2–4 Zeilen, was neu ist (Deutsch, aus Spielersicht).
4. Wenn ein neuer Test sinnvoll ist (neue Funktion), in `tests/` ergänzen.
5. Commit „vN: <Kurzbeschreibung>“ und, falls ein Remote existiert, pushen.
6. Lukas schicken: `dist/DrivingSchool_vN.rbxmx` (+ `karte/stadt_generator.lua` nur wenn die Karte geändert wurde).
7. Antwort auf Deutsch, kurz: was neu ist, ob die Karte neu muss, Erinnerung „vorher als .rbxl sichern“, die Installationsschritte aus README.md, und was er zuerst testen soll.
