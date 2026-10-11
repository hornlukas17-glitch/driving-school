# Driving School – Roblox

## Installieren / Update in Roblox Studio
1. **Vorher sichern:** File → Save to File As… (`DrivingSchool_vXX.rbxl`).
2. Nur bei neuer Karte: `karte/stadt_generator.lua` in die Befehlszeile (View → Command Bar) einfügen und Enter.
3. `dist/DrivingSchool_v<N>.rbxmx` ins Studio-Fenster ziehen, dann diese Zeile in die Befehlszeile:
```lua
local w=workspace:FindFirstChild("DrivingSchoolInstall",true) for _,o in {game.ReplicatedStorage:FindFirstChild("Fuehrerschein"),game.ServerScriptService:FindFirstChild("FuehrerscheinServer"),game.StarterPlayer.StarterPlayerScripts:FindFirstChild("FuehrerscheinClient")} do if o then o:Destroy() end end w.Fuehrerschein.Parent=game.ReplicatedStorage w.FuehrerscheinServer.Disabled=false w.FuehrerscheinServer.Parent=game.ServerScriptService w.FuehrerscheinClient.Parent=game.StarterPlayer.StarterPlayerScripts w:Destroy() print("Driving School installed")
```
4. Speichern (File → Save to Roblox).

## Runde Karosserien (optional)
SUV: In Studio **Home → Import 3D** → `dist/mesh/RangerX.obj` wählen → importieren. Das Modell heißt `RangerX` – ins **ServerStorage** ziehen. Fertig: alle SUVs (auch im Autohaus) bekommen die runde Karosserie.
Steht das Auto verkehrt herum, in `Auto.lua` `Auto.MESH_DREHUNG = 180` setzen.

## Für Entwicklung
`./tools/check.sh` – prüft Syntax, baut `dist/` und lässt alle Tests laufen.
