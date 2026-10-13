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
In Studio **Home → Import 3D** → Datei aus `dist/mesh/` wählen → importieren → Modell ins **ServerStorage** ziehen (Name nicht ändern):
- `RangerX.obj` → SUV
- `VelocityGT.obj` → Sportwagen

Ohne Import bleibt das jeweilige Auto im Block-Look. Steht ein Auto verkehrt herum, in `Auto.lua` `Auto.MESH_DREHUNG = 180` setzen.

## Für Entwicklung
`./tools/check.sh` – prüft Syntax, baut `dist/` und lässt alle Tests laufen.

## Shop einrichten (Robux)
1. Spiel veröffentlichen (File → Publish to Roblox).
2. Creator Dashboard → dein Spiel → **Monetization → Passes**: VIP, 2x XP, Vanta GS Night Edition, Paint Studio anlegen (Bild + Preis).
3. **Monetization → Developer Products**: Starter Pack, 2x Coins – 30 min, 2,500 / 10,000 / 30,000 / 100,000 coins.
4. Die IDs in `src/Shop.lua` bei `id = 0` eintragen (oder Claude schicken). Preise im Spiel kommen automatisch von Roblox.
5. Optional: Roblox-Gruppe → ID in `src/Belohnungen.lua` (`GRUPPE_ID`), Badges → `badge = <ID>` bei den Erfolgen.
