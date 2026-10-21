-- v58 Rest: nur Versionsstrings im Client (v57 -> v58). Zonen/Party/Server/Shop sind schon per MCP drin.
-- Mehrfach ausführbar. In Studio im EDIT-Modus in die Befehlszeile.
local s = game.StarterPlayer.StarterPlayerScripts.FuehrerscheinClient
local src = s.Source
src = src:gsub("client v57 loaded", "client v58 loaded"):gsub("start screen v57 loading", "start screen v58 loading")
s.Source = src
print("v58: Client " .. #src .. " Zeichen (soll 193439)")
