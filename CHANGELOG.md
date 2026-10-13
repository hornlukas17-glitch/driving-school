# Changelog

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
