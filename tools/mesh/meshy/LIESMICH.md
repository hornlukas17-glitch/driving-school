# Meshy-Modell → Spielauto (Vanta GS)

Arbeitsordner beliebig (die großen Zwischendateien gehören nicht ins Repo). Reihenfolge:

1. `python3 laden.py <entpackter Meshy-Ordner>/` – liest OBJ + UV → `roh.npz`
2. `python3 farbe.py <Ordner>/` – Texturfarbe je Dreieck → `C.npy`
3. `python3 a_sicht.py` – Räder weg (Achsen fest eingetragen), Innenraum weg (Sichtbarkeit aus 65 Richtungen)
4. `python3 b_klassen.py` – Lack / Verkleidung / Glas / Scheinwerfer / Rücklicht / Blinker nach Farbe + Lage
5. `python3 c_bauen.py` – Fransen unten und Splitter weg, Beschriftung glätten, schwarze Zonen (Grill, Schweller, Diffusor), glätten (Taubin), Glas/Lichter/Zonen getrennt reduzieren (saubere Kanten, keine Risse), ins Spielmaß → `../vanta_teile.npz`
6. `python3 ../vanta.py` – Radhäuser, OBJ, `src/Karosserien.lua`

Braucht `pip install fast-simplification scipy pillow numpy`. Achsen, Gürtellinie und Maßstab stehen
oben in den Skripten und gelten nur für dieses Modell.
