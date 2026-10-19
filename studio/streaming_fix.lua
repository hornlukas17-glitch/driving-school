-- v54: Karte laedt im veroeffentlichten Spiel nicht -> Streaming nach Roblox-Empfehlung, keine vereinfachten Detailstufen.
-- In Studio (Edit-Modus) in die Befehlszeile oder per MCP. Mehrfach ausfuehrbar, Strg+Z macht es rueckgaengig.
local CHS = game:GetService("ChangeHistoryService")
CHS:SetWaypoint("Vor Streaming-Fix")
local bericht = {}
for eig, wert in {
	StreamingEnabled = true,
	StreamingTargetRadius = 1024,
	StreamingMinRadius = 64,
	StreamingIntegrityMode = Enum.StreamingIntegrityMode.PauseOutsideLoadedArea,
	StreamOutBehavior = Enum.StreamOutBehavior.Opportunistic,
} do
	local ok = pcall(function() workspace[eig] = wert end)
	table.insert(bericht, eig .. (ok and " gesetzt" or " NICHT setzbar -> bitte im Eigenschaften-Fenster von Workspace setzen: " .. tostring(wert)))
end
local vorher, n = {}, 0
for _, m in workspace:GetDescendants() do
	if m:IsA("Model") then
		local k = tostring(m.LevelOfDetail)
		vorher[k] = (vorher[k] or 0) + 1
		if m.LevelOfDetail ~= Enum.ModelLevelOfDetail.Disabled then
			m.LevelOfDetail = Enum.ModelLevelOfDetail.Disabled
			n += 1
		end
	end
end
local s = {}
for k, v in vorher do table.insert(s, k .. "=" .. v) end
table.insert(bericht, "Detailstufen vorher: " .. table.concat(s, ", ") .. " -> " .. n .. " auf Disabled")
CHS:SetWaypoint("Streaming-Fix")
return table.concat(bericht, "\n")
