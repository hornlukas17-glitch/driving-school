-- Driving School v40 -> v41 (Rest): keine Fehler während des Bananen-Drehers. Nach dem Stoppen des Spiels in die Befehlszeile, Enter.
local s = game.ServerScriptService.FuehrerscheinServer
local alt = "local function warnung(p, st, text, punkte)\n\tst.fehler += punkte or 1"
local neu = "local function warnung(p, st, text, punkte)\n\tif Chaos.schonzeit(st) then\n\t\t-- spinning on a banana peel: turns, speed or bumps right now are not your fault\n\t\tst.drehSumme = 0\n\t\treturn\n\tend\n\tst.fehler += punkte or 1"
local src = s.Source
if string.find(src, "spinning on a banana peel", 1, true) then print("schon drin") return end
local a, b = string.find(src, alt, 1, true)
assert(a, "Stelle nicht gefunden")
s.Source = src:sub(1, a - 1) .. neu .. src:sub(b + 1)
local c = game.StarterPlayer.StarterPlayerScripts.FuehrerscheinClient
c.Source = c.Source:gsub("client v%d+ loaded", "client v41 loaded"):gsub("start screen v%d+ loading", "start screen v41 loading")
print("v41 eingespielt")
