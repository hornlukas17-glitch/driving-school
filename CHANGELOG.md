# Changelog

## v28 – Aufklappmenü
- **Menü oben links:** Nur noch ein „☰ Menu“-Knopf; ein Klick klappt Shop, Rewards, Daily, My Cars, Record, Kamera und Settings aus. Nach der Auswahl klappt es wieder zu. Roter Punkt am Menü-Knopf, wenn Belohnungen warten.
- **Autohaus:** Statt der beschrifteten Fläche ein runder, transparenter grüner Kreis (wie die Tore in den Fahrstunden) mit leichter Lichtsäule – reinlaufen öffnet den Katalog.

## v27 – Autohaus & Grafik
- **Autohaus neu:** Nur noch 2 Plattformen im Showroom (exklusiver Vanta GS Night Edition + Top-Auto), mit Spot und Namensschild. Alle anderen Autos kauft man in der **grünen „BUY CARS“-Zone** vor der Rezeption – reinlaufen öffnet den Katalog.
- **Sophie (Sales):** neue Verkäuferin hinter der Rezeption, grauer Anzug mit Weste und blondem Zopf; Marco steht daneben.
- **Autolack:** Metallic-Look statt rosa-blasser Glanz (dunkle und kräftige Farben metallic, Weiß/helle Farben glänzend) – auch beim NPC-Verkehr.
- **Licht:** weniger Dunst, tiefere Schatten, etwas mehr Kontrast und Farbe.

## v26 – Fahrschule & Verkehr
- **Spawn vor der Tür:** Man startet draußen vor dem Eingang der Fahrschule, Blick zur Tür.
- **HUD kompakt:** Shop, Rewards, Daily, My Cars, Record, Kamera, Settings als eine Reihe kleiner Symbol-Knöpfe.
- **Anna:** Business-Anzug, Haare, freundliches Gesicht. Ihr Menü fragt zuerst **PKW oder LKW** und zählt dann alle Schritte als Checkliste auf (✅ erledigt, 👉 nächster Schritt).
- **Fußgänger & NPCs** tragen Kleidung, Frisuren und Gesichter (kostenlose Roblox-Katalog-Sachen); Polizei/Jobgeber behalten ihre Uniformfarben.
- **STOP-Schilder:** Schrift groß wie beim echten Schild; Pfosten sticht nicht mehr durchs Schild.
- **NPC-Autos fahren auf den Spuren:** Die Karte war in Studio um (8, -8) verschoben, deshalb fuhren die Autos durch die Siedlungsmauer. Karte zurück auf Originalposition, Gelände neu angepasst. Der Server warnt jetzt im Output, falls die Karte wieder verschoben wird.

## v25 – Karte repariert
- **Kein Rausfallen mehr:** Gras liegt jetzt knapp unter dem Asphalt (vorher 2 Studs darüber), Spalten im Gelände an Straßenrändern sind zu, unsichtbarer Kartenrand rundherum plus Sicherheitsboden.
- **Autos fahren auf den Reifen:** Die Karte war in Studio um 2,8 Studs angehoben – NPC-Verkehr fuhr dadurch *in* der Straße. Karte wieder auf Originalhöhe.
- Ausstellungsautos im Autohaus stehen auf dem Podest statt 0,5 Studs darin.
- Shop/Belohnungen: Lade-Absicherung jetzt auch in Studio.

## v24 – Belohnungen & Shop
- **Tägliche Belohnung:** 7-Tage-Kalender mit Serie (Tag 7 = große Truhe), öffnet sich beim Spielstart automatisch. Wer einen Tag auslässt, fängt wieder bei Tag 1 an.
- **Spielzeit-Geschenke:** nach 10/25/45/70/100 Minuten pro Tag (erstes nach 10 min – so lange muss jemand spielen, damit Roblox dir Creator Rewards zahlt).
- **Erfolge & Führerscheinklassen:** 12 Erfolge mit Stufen (Klasse B, C, CE, Taxischein, Lieferungen, km, perfekte Fahrten, Autosammlung, Level, Treue-Serie, mit Freunden, Villa). Zeigt immer die nächsten Stufen und Belohnungen.
- **Freunde:** +10 % Coins und XP, solange ein Freund auf dem Server ist; „Freunde einladen“-Knopf.
- **Shop (Robux):** Game Passes VIP (2x Coins, VIP-Schild, VIP-Chat-Tag, 2 Lacke), 2x XP, Paint Studio (6 exklusive Lacke), exklusives Auto „Vanta GS Night Edition“ (eigenes Podest vor dem Autohaus). Coin-Pakete, 2x-Coins-Boost (30 min), Starterpaket (nur einmal). Premium-Spieler +10 %.
- IDs der Passes/Produkte in `src/Shop.lua` eintragen (0 = noch nicht eingerichtet; in Studio dann kostenloser Testkauf).

## v23
- Vanta GS: untere Frontecken jetzt sauber schwarz (die zackigen Meshy-Lamellen dort sind weg). Neue `dist/mesh/VantaGS.obj` importieren.
- In Studio getestet (v22-Modell): Licht an/aus, Blinker blinken, Scheinwerfer leuchten nach vorn, Beschleunigung wie gehabt.

## v22
- Vanta GS: Rücklichtband und Frontleiste liegen jetzt direkt auf der Karosserie und laufen um die Ecken (vorher standen die Enden seitlich ab).
- Seitendetails: Türfugen (vier Türen), bündige Türgriffe, Chrom-Fensterleiste entlang der Gürtellinie. Neue `dist/mesh/VantaGS.obj` importieren.

## v21
- Vanta GS: Lichtleiste vorne und Rücklichtband hinten jetzt durchgehend und sauber (eigene Leuchtleisten entlang der Lichtlinie des Modells, Blinker an den Enden). Neue `dist/mesh/VantaGS.obj` importieren.
- Glattere Karosserie: stärker geglättet, mehr als doppelt so viele Dreiecke, eigene Normalen für weiche Schattierung, Sprenkel im Lack entfernt.
- Fix: Scheinwerfer der Vanta GS leuchten nach vorn (bei gedreht importierten Modellen zeigte das Licht nach hinten).

## v20
- Vanta GS: Frontecken sauber – die schwarze Frontzone läuft nicht mehr um die Ecke (keine blauen Zacken mehr), Lack/Schwarz-Grenzen glatter. Neue `dist/mesh/VantaGS.obj` importieren.
- In Studio geprüft: Fahrer sitzt komplett im Auto (Arm innerhalb der Tür, Kopf unter dem Dach).

## v19
- Vanta GS in echtem Studio getestet und nachgebessert (neue `dist/mesh/VantaGS.obj` importieren, altes Modell im ServerStorage ersetzen):
  - Karosserie stand verkehrt herum (Front hinten) – jetzt richtig gedreht.
  - Saubere Kanten: Fenster ohne Zacken, gerade schwarze Schweller, schwarzer Frontgrill und Diffusor, keine Fransen mehr unten.
  - Fahrer sitzt tiefer und weiter innen: Kopf nicht mehr durchs Dach, Arm nicht mehr durch die Tür.
- Fahrtest: 0–178 km/h in 4 s, bremst sauber, fährt stabil wie der Velocity GT.

## v18
- Neues Auto „Vanta GS“ (Sportlimousine aus Lukas' eigenem Meshy-Modell, 16.000 Coins, 180 km/h) mit eigenem Podest vor dem Autohaus. Runde Karosserie: `dist/mesh/VantaGS.obj` importieren, Modell `VantaGS` in den ServerStorage.
- Lichter funktionieren: LED-Leiste vorne als Scheinwerfer (mit Licht), durchgehendes Rücklichtband, Blinker an den Enden – aus den Lichtflächen des Modells ausgeschnitten.
- Modell aufbereitet: Meshy-Räder und Innenraum entfernt, Oberfläche geglättet, von 1,45 Mio. auf ~50.000 Dreiecke reduziert, Radhäuser ergänzt. Fahrgefühl wie alle Autos (nur eigene Werte).

## v17
- Neue runde Karosserie für die Limousine „Executive“ (eigenes Design): sportliche Oberklasse-Limousine mit flacher Front, vier Türen, Fensterleiste in Chrom, Diffusor und vier runden Endrohren. `dist/mesh/Executive.obj` importieren.
- Alle runden Autos realistischer: echter Karosserie-Querschnitt (unten eingezogen, Schulter, runde Oberkante) statt senkrechter Seiten.
- Scheinwerfer, Rückleuchten, Blinker, Grill und Lufteinlässe liegen jetzt als gebogene Flächen auf der Karosserie statt als aufgesetzte Blöcke. Endrohre sind rund.
- Dachhaut läuft an den Enden aus (keine Zacke mehr im Seitenfenster).

## v16
- Getönte Scheiben (dunkler, weniger durchsichtig): Kabinen wirken geschlossen statt hohl.
- Dachhaut beginnt erst hinter der Frontscheibe: keine zackige Kante mehr im vorderen Seitenfenster (neue OBJ-Dateien importieren).
- In echtem Studio geprüft: alle 7 Ausstellungsautos, Speichenfelgen, Fugen, Striker TR auf eigenem Podest.

## v15
- Neues Auto „Striker TR“ (Track-Coupé, eigenes Design, 22.000 Coins, 190 km/h) mit eigenem Podest vor dem Autohaus. Runde Karosserie: `dist/mesh/StrikerTR.obj` importieren, Modell `StrikerTR` in den ServerStorage.
- Alle Privatautos: Speichenfelgen, Bremsscheiben und farbige Bremssättel (nur Optik, Fahrgefühl unverändert), Kopfstützen, Mittelkonsole, leuchtender Tacho.
- SUV und Sportwagen: Tür- und Haubenfugen, Gitter in den Lufteinlässen, Scheinwerferrahmen.
- Fix: Fenstersäulen erschienen in Roblox als Deckel über der Heckscheibe (neue OBJ-Dateien importieren).

## v14
- Neuer runder Sportwagen-Look „Velocity GT“ (eigenes Design): flacher Keil mit Mittelmotor-Proportionen, breite Hüften, Seitenlufteinlässe, Abrisskante. `dist/mesh/VelocityGT.obj` importieren, Modell `VelocityGT` in den ServerStorage.
- Man sitzt im runden Sportwagen tiefer; Tuning-Heckflügel steht auf zwei Stützen über dem Motordeck.
- Intern: Karosserien kommen jetzt aus `src/Karosserien.lua` (automatisch erzeugt), neue Autos brauchen nur noch eine Formdatei.

## v13
- Neuer runder SUV-Look „Ranger X“ (eigenes Design): `dist/mesh/RangerX.obj` mit dem 3D-Importer importieren, Modell `RangerX` in den ServerStorage. Ohne Import bleibt der alte Block-SUV.
- Schmale LED-Scheinwerfer, Lichtband hinten, Dachreling, Dachspoiler, Chromleisten. Spoiler-Tuning sitzt beim runden SUV am Dach.

## v12
Etappe 2: Taxi-Job, Tanken/Schäden/Werkstatt/Tuning, Tagesmissionen, Bestenlisten, Parkhaus, Baustellen, Blitzer mit Punkten und Führerscheinentzug (Auto bleibt, Polizei sucht verstärkt), Tag/Nacht und Wetter.

## v11
Etappe 1: XP/Level, Autohaus, Admin-Geld, Polizei-Kontrollen, Villen, Pizza- und LKW-Jobs mit Stufen.
