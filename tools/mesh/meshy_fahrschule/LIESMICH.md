# Meshy-Modell → neues Fahrschulauto ("Fahrschulwagen")

Lukas' Meshy-Modell `Meshy_AI_driving_school_car_3d_1014043433` (kompakter Fünftürer, eigenes Design, keine Logos).
Arbeitsordner beliebig (große Zwischendateien gehören nicht ins Repo), Skripte mit `python3 -I` aufrufen:

1. `python3 ../meshy/laden.py <entpackter Meshy-Ordner>/` – OBJ + UV → `roh.npz`
2. `python3 ../meshy/farbe.py <Ordner>/` – Texturfarbe je Dreieck → `C.npy`
3. `python3 a_sicht.py` – Räder weg (Achsen x = -0.561 vorne / 0.630 hinten, y = -0.273), Innenraum weg
4. `python3 b_klassen.py [vorschau.png]` – Dachschild raus (das Spiel baut ein eigenes mit Schrift),
   Lack / Verkleidung / Glas / Scheinwerfer / Rücklicht; Frontscheibe und Kühlergrill gerade geschnitten,
   Seitenscheiben aus der Geometrie (die Textur hat dort Zacken) → `L.npy`, `fest.npy`, `geschnitten.npz`
5. `python3 c_bauen.py` – ins Spielmaß (Achsabstand 9,6, Radmitte 1,3 = bisheriges Fahrschulauto),
   Lack und Verkleidung getrennt reduzieren (gerade Kanten), Knick-Normalen → `../fahrschule_teile.npz`
6. `python3 ../fahrschulwagen.py` – Radhäuser, rot-blaue Streifen, Blinker, Kennzeichen, Dachschild-Platz,
   `dist/mesh/Fahrschulwagen.obj` und `src/Karosserien.lua` (Eintrag `fahrschule`)

Im Modell ist vorne = -x. Die Streifen der Meshy-Textur werden Lack; saubere Streifen legt Schritt 6 auf die Karosserie.
