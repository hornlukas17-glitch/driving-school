# Changelog

## v53 – Karte: Löcher weg, wärmere Optik
- Löcher an den Straßenrändern (man sah den Himmel unter der Karte) geschlossen: `Karte.Bankett` (Rasen-Grundplatte + Rasenstreifen unter Straßen), in Studio und im Generator.
- Licht ohne Blaustich (Umwelt.lua + Generator): wärmeres Umgebungslicht, weniger Himmelsspiegelung, weniger Sättigung.
- Fenster dunkles Glas statt knallblau; Häuser aus Putz in warmen Farben; Dächer mit Ziegeln/Schindeln; Stadtfassaden warm (Sand, Terrakotta, Ocker, Backstein) statt Pastellblau/Lila; Gehwege Pflaster; Autohaus-Glas ohne „Wasser“-Effekt.

## v52 – Keine Polizei mehr
- Polizeikontrollen, Polizei-Verfolgung und Streifenwagen im Verkehr sind abgeschaltet (`POLIZEI_AKTIV = false` in Server.lua, `Verkehr.POLIZEI = false`). Blitzer, Bußgelder und Punkte bleiben.
- Tagesmission „Polizeikontrolle“ entfernt; wer sie heute schon hatte, bekommt automatisch eine neue Liste.
- Test 06 prüft jetzt: keine Polizei, keine Kontrolle; Test 27 prüft die alte Mission.

## v51 – Auto bleibt bei vielen Fehlern, Minimap lädt wieder
- Normale Fahrstunden brechen bei 10 Fehlern nicht mehr ab: Man fährt die Route zu Ende, sie zählt dann nur nicht (+10 XP). Hinweis kommt einmal.
- Nach einer nicht bestandenen Fahrstunde/Prüfung verschwindet das Auto nicht mehr unter einem: Es bleibt, bis man aussteigt (dann 3 s) bzw. max. 45 s. Neuer Knopf „🔁 Try again“ startet dieselbe Lektion/Prüfung sofort neu.
- Minimap leer im veröffentlichten Spiel: Die Kartendaten wurden abgefragt, solange der Spielstand noch lud, und nie wieder. Jetzt wird bis zu 60 s nachgefragt; dasselbe für gespeicherte Einstellungen und die erste Fahrt.
- Test 28.

## v50 – Theorie ist optional
- Die Theorieprüfung ist keine Pflicht mehr: Für die Fahrprüfung braucht man nur noch alle Fahrstunden (prüft der Server). Die Theorie gibt weiterhin +80 XP als Bonus.
- Annas Checkliste zeigt nur noch „Fahrstunden → Fahrprüfung“, die Theorie steht klein als optional darunter. Willkommens- und Ergebnistexte angepasst.
- Neuer Test 27 (Prüfung ohne Theorie erlaubt, ohne alle Fahrstunden abgelehnt), Test 18/20 angepasst; der Mock-DataStore lässt sich jetzt vorbelegen.
- Gefunden (Studio): Die Motorsounds haben im neuen Spiel keine Zugriffsfreigabe → Lukas muss sie freigeben.

## v49 – Hupen mit Ton
- Die 5 Hupen-Sounds sind hochgeladen und eingetragen (`tools/sound/ids.json` → `src/Hupen.lua`). In Studio geprüft: alle 5 laden und spielen (Classic, Clown, Ente, Lufthorn, Fanfare).

## v48 – „Ride along“ nur auf dem Parkplatz
- Der „Ride along“-Hinweis an der Rückbank des Fahrstunden-Autos verschwindet, sobald das Auto den Fahrschul-Parkplatz verlassen hat (> 45 Studs vom Start), und der Fahrer selbst sieht ihn gar nicht mehr (nur Freunde). Test 25 erweitert.

## v47 – Neues Cockpit, mph, Pfeil zum Auto, Gameplay-Trailer
- **Pfeil zum Fahrschulauto:** Sobald dein Fahrstunden-Auto (oder der Lkw) wartet, hüpft ein grüner Pfeil „YOUR CAR · E“ über der Fahrertür, eine leuchtende Linie führt von dir zum Auto, und am Bildschirmrand zeigt ein Pfeil die Richtung, wenn das Auto hinter dir steht. Verschwindet beim Einsteigen.
- **Neues HUD unten rechts:** runder Tacho mit Lichterring (grün → gelb → orange, rot beim Rasen), roter Strich = Tempolimit, Tempolimit-Schild pulsiert beim Rasen, Status-Leiste darunter, runde Knöpfe. Alles skaliert auf kleinen Bildschirmen. Anweisungs-Box mit gelbem Akzent.
- **km/h ⇄ mph:** Tippen auf die Einheit im Tacho schaltet um (oder Einstellungen). Dann zeigen Tacho, Tempolimit-Schild, Warnungen, Blitzer-Texte, Anweisungen des Fahrlehrers, Autohaus und „My Cars“ alles in mph (Limits auf runde Werte: 30 → 20, 50 → 30, 100 → 60, 130 → 80).
- 15-Sekunden-Trailer aus echten Spielszenen (`tools/werbung/gameplay_trailer.py`, Bilder in `tools/werbung/gameplay/`). Test 26.

## v46 – Neuer Name: Crazy Driving School 🍌
- Startbildschirm und Begrüßung heißen jetzt „Crazy Driving School 🍌“, mit kleinem roten „BETA“-Schild (in Client.lua `SPIEL_PHASE = nil` setzen, wenn das Spiel fertig ist). Untertitel „Get your license. Survive the chaos.“
- Icon und Thumbnail mit dem neuen Namen, dazu ein fertiger 32-Sekunden-Trailer (`python3 tools/werbung/trailer.py` → `dist/werbung/trailer.mp4`, alles selbst gezeichnet und vertont).

## v45 – Mit Freunden: Mitfahren, Hupe, Party-Test, Worst Drivers
- **Freunde fahren mit:** „Ride along“ an der Beifahrertür eigener Autos und an der Rückbank der Fahrstunden-Autos (nicht in der Prüfung). Mitfahrer sehen die Chaos-Banner, bekommen die Ausweich-Münzen, können hupen und (mit Pass) Bananen werfen.
- **Hupe 📯** (H oder Knopf, für alle): jeder in der Nähe hört sie und sieht eine „HONK!“-Blase. Neuer Gamepass **„Funny Horn Pack“** (99 R$): Clown, Ente, Lufthorn, Fanfare – Auswahl in den Einstellungen. Alle Hupen selbst erzeugt (`tools/sound/hupen.py`).
- **🏁 Party-Test für bis zu 4 Spieler:** Knopf „Party“ im Menü, 25 s zum Beitreten, alle fahren dieselbe Prüfungsroute mit doppelt so viel Chaos. Zeit + 5 s pro Fehler, Preise 500/250/120/60 Münzen, Krone „👑 PARTY CHAMP“ für den Sieger, Erfolg „Party champion“.
- **💥 Worst-Drivers-Bestenliste** (4. Tafel im Park): Crash-Punkte für Treffer bei Events, Ausrutscher, Unfälle und angefahrene Fußgänger.
- Jeder Fahrlehrer hat jetzt 3 eigene Gags (nie zweimal hintereinander derselbe). Einstellung „Chaos in your own car: On/Off“. Icon + Thumbnail (`tools/werbung/bilder.py`) und Trailer-Plan (`tools/werbung/TRAILER.md`).

## v44 – Spielbereit: Chaos überall, Spaß-Shop, Fixes
- **Chaos auch im eigenen Auto** (nach dem Führerschein): etwa alle 1–1,5 min ein Event, ohne Fahrlehrer. Ausweichen gibt Münzen.
- **Neuer Gamepass „Banana Launcher“ 🍌** (149 R$): mit B oder dem 🍌-Knopf eine Bananenschale hinter das Auto werfen (alle 5 s, max. 5 liegen). Wer drüberfährt – auch Freunde – dreht sich. Der Werfer bekommt „GOTCHA!“.
- **Neue Spaß-Produkte für den ganzen Server**: „👽 Alien Invasion“ (49 R$, jedes fahrende Auto wird von einem UFO hochgezogen) und „🍌 Banana Rain“ (29 R$, Schalen regnen vor jedem Fahrer herunter). Eigene Rubrik „CHAOS FUN“ im Shop.
- **Wiederkommen:** 2 neue Tagesmissionen (Events ausweichen, auf einer Banane ausrutschen) und 5 Chaos-Erfolge (verschiedene Fahrlehrer, Event-Sammler, Ausweich-Meister, UFO-Flieger, Bananen-Scharfschütze). Neues Datenfeld `chaos` (Standard leer).
- **Fixes:** Server wartete beim Start 10 s auf die fehlende Servicestation (Shop/Missionen/Belohnungen waren so lange nicht da, Missionen warf einen Fehler) → kein Warten mehr, Missionen sicher beim Start. In Studio fehlte die Servicestation (Tanken, Werkstatt, Taxistand) und die Tankstelle West ganz → nachgebaut (`studio/service_bauen.lua`).

## v43 – Chaos nach Lukas' Test
- Banane: das Auto dreht sich jetzt immer mindestens 180° (dreht weiter, bis 200° erreicht sind, höchstens 2,5 s), danach 0,5 s bis der Grip zurück ist.
- UFO: Wer in den grünen Strahl fährt, wird mitsamt Auto hochgezogen (2,7 s hoch, langsam drehend) und wieder abgesetzt. Alien-Bonus sofort, keine Fehler während des Flugs.
- Riesenreifen rollt um seine Mitte (rutschte vorher halb unter die Straße).
- Events landen auf der Straße: bevorzugt am nächsten grünen Tor (rechte Spur), sonst geradeaus – aber nie auf Gehweg/Bordstein/Wiese (seitlich nachjustiert oder später neu versucht). Gilt auch für die Matschpfütze.
- Testmenü oben neben dem Menü-Knopf, beide Spalten per Klick auf die Überschrift ein-/ausklappbar.

## v42 – Chaos-Knöpfe im Testmenü
- Testmenü (nur Studio) hat jetzt Knöpfe für jedes Chaos-Event (Banane, Enten, Kühe, Hühner, Riesenreifen, Matsch, Clown, UFO, Zufall). In einer Fahrstunde erscheint das Event vor dem Auto.

## v41 – Enten und Banane in Studio nachgebessert
- Tiere (Enten, Kühe, Hühner, Einkaufswagen) laufen jetzt auf dem echten Boden mit (Bordstein/Gehweg) statt darin zu versinken, und verschwinden auf der anderen Straßenseite, statt in Häuser zu laufen.
- Banane: In den 4 s nach dem Ausrutscher gibt es gar keine Fehler mehr (vorher z. B. „You turned left without signalling“ durch den Dreher).

## v40 – Bananen in Studio getestet
- Bananenschale dreht das Auto jetzt richtig (vorher nur ~30°, die Reifen haben die Drehung gebremst): bei ~60 km/h etwa 130° Dreher mit Rutschen zur Seite, danach normal weiter.
- Unfälle mit anderen Autos in den 4 s nach der Banane zählen nicht als Fehler (nicht deine Schuld).
- Fix: Events wurden manchmal nicht gestartet, weil die Boden-Prüfung den eigenen Avatar statt der Straße traf.
- Testmenü-Befehl (nur Studio): `dev` → `{ befehl = "chaos", art = "banane" }` startet ein bestimmtes Event in der laufenden Fahrstunde.

## v39 – Mehr Chaos
- **Bananenschale lässt dich jetzt wirklich rutschen** (Lukas' Wunsch): kurze Drehung mit fast keinem Grip (1,6 s), danach fährt das Auto wieder ganz normal. Nur bei diesem Event – das normale Fahrgefühl bleibt gleich.
- 5 neue Events: 🐔 Hühner rennen im Zickzack über die Straße (Federwolke beim Treffer), 🛒 ein Einkaufswagen rollt quer über die Straße, 🛞 ein Riesenreifen rollt dir entgegen, 🟤 Matschpfütze (Matschflecken auf dem Bildschirm), 🤡 Clown mit „Blitzer“-Kamera (Blitzlicht + 10 Münzen „Photo of the year“).
- Sprechblasen der Fahrlehrer kleiner (180 × 50 statt 250 × 74, max. Schriftgröße 18) und näher am Kopf.

## v38 – In Studio getestet: Fahrschulauto breiter, Events früher sichtbar
- Neues Fahrschulauto im Spiel 15 % breiter: vorher ragten die Arme von Fahrer und Fahrlehrer durch Türen und Scheiben. Sitze, Räder und Kollision bleiben exakt gleich (nur die Optik wird gestreckt, kein neuer OBJ-Import nötig).
- Startbildschirm: Titel, Untertitel, PLAY und SETTINGS überlappten auf niedrigen Bildschirmen (Handy quer, kleines Studio-Fenster) – jetzt feste Abstände von der Bildschirmmitte aus.
- Chaos-Events erscheinen jetzt etwa 3 Sekunden vor dem Auto (je nach Tempo 60–150 Studs). Auf der Autobahn kam die Bananenschale vorher nur 1,5 s vor dem Aufprall.

## v37 – Chaos-Fahrschule (Teil 1: verrückte Fahrlehrer + Chaos-Events)
- **5 verrückte Fahrlehrer** statt Mike, pro Fahrstunde zufällig (nie zweimal hintereinander derselbe): Panic Pete, Sleepy Sam, Grandma Gerti, Coach Kevin, DJ Dina – mit eigener Kleidung und Sprechblase über dem Kopf (für alle sichtbar). Sie reagieren auf Start, Fehler, Unfälle, geschaffte Tore, das Ende und quatschen zwischendurch.
- **Chaos-Events** während der Fahrstunden (alle 30–45 s, nicht beim Einparken): Kuhherde über die Straße, Entenfamilie, Bananenschale, UFO mit Traktorstrahl, Fahrlehrer-Gags (Papiertüte, Pfannkuchen im Schlaf, Stricken, Protein-Shake, Radio auf 200 %). Großes Banner auf dem Bildschirm.
- Ausweichen = 15 Münzen, durch den UFO-Strahl fahren = 25 Münzen. Treffer: Kuh/Ente fliegt weg, Bildschirm wackelt kurz, Fahrlehrer schreit – zählt aber **nie** als Fehler.
- Fahrgefühl unverändert: alle Event-Objekte sind verankert, ohne Kollision, Treffer nur per Abstand (Test 23 prüft das).
- Texte ohne „Mike“.

## v36 – Neues Fahrschulauto
- **Neue Karosserie fürs Fahrschulauto** aus Lukas' Modell: kompakter Fünftürer in Weiß mit rot-blauen Streifen an den Seiten und auf der Haube, Dachschild „DRIVING SCHOOL“ (blaues Feld, weiße Schrift), eigene Scheinwerfer, Rücklichter, Blinker vorne/hinten/im Spiegel.
- Fahrverhalten, Räder, Sitze und Kollision sind exakt gleich wie vorher – nur die Optik wechselt (Test prüft das).
- Das Pizza-Auto bekommt dieselbe Form in seiner Farbe, ohne Fahrschul-Streifen.
- Aktiv, sobald das Modell „Fahrschulwagen“ (dist/mesh/Fahrschulwagen.obj) im ServerStorage liegt; sonst bleibt das alte Auto.

## v35 – Eigene Motorsounds aktiv
- Alle 48 eigenen Sound-Dateien sind hochgeladen und eingetragen: jedes Auto spielt jetzt seinen eigenen Motor (Leerlauf, niedrige und hohe Drehzahl überblendet) und seinen eigenen Anlass-Sound beim Einsteigen. Der Roblox-Platzhalter wird nur noch benutzt, falls eine Datei fehlt.

## v34 – Platzhalter-Sounds klar unterscheidbar
- Solange die eigenen Motorsounds noch nicht hochgeladen sind, klingt trotzdem jedes Auto anders: der Roblox-Platzhalter bekommt pro Motor eigene Tonhöhe, Bass/Höhen, Rauheit, Pulsieren (wenige Zylinder, Diesel) oder Chorus (V12). Vanta GS und Night Edition klingen jetzt tiefer und rauer als das Fahrschulauto.

## v33 – Motorsounds
- **Jedes Auto klingt anders:** eigene, selbst erzeugte Motorstimmen – Dreizylinder (Zipster), Vierzylinder (Fahrschulauto, Pizza), V6 (Ranger X), weicher V8 (Executive/Taxi), Reihensechser (Velocity GT), Biturbo-V6 (Vanta GS), Sportauspuff (Night Edition), Boxer (Striker TR), Renn-V8 (Apex R1), V12 (Nova SS), Diesel mit Turbo (LKW, Lieferwagen).
- **Drehzahl wie echt:** virtuelles Getriebe mit Gangwechseln, Gas im Stand dreht hoch, vom Gas gehen klingt dumpfer. Anlassen beim Einsteigen, Motor geht beim Aussteigen aus.
- **Andere Spieler und NPC-Verkehr** sind auch zu hören (die nächsten paar Autos, leiser). Im Fast-Modus weniger gleichzeitige Sounds.
- Bis die eigenen Sound-Dateien hochgeladen sind, läuft der kostenlose Roblox-Motorsound – pro Auto anders gestimmt.

## v32 – Kleine Korrekturen nach dem Studio-Test
- **Leistungsmodus:** Die FPS-Überwachung zählt nur noch, solange das Spielfenster aktiv ist. Vorher schaltete sich „⚡ Fast“ ein, sobald Studio oder das Spiel im Hintergrund lief (dort drosselt Roblox absichtlich die Bildrate).
- **Vanta GS Night Edition:** Die mittlere Diffusor-Finne saß vorne unter der Stoßstange statt hinten – jetzt sitzen alle fünf Finnen am Heck.

## v31 – Sofort fahren, Sterne, Auswertung, Handy-Pedale
- **Neuer Einstieg:** Neue Spieler sitzen nach PLAY direkt in der ersten Fahrstunde („Lesson 1: First Drive“, eine kurze Runde um den Block) – ohne Anmelden und ohne Theorie vorher. Die Theorie (Tafel + Prüfungsplatz) ist erst vor der praktischen Prüfung nötig. Jetzt 6 Fahrstunden.
- **Sterne pro Fahrstunde:** 0 Fehler = ★★★, bis 2 Fehler = ★★, sonst ★. Bei Anna „⭐ Improve a lesson“ zum Wiederholen; jeder neue Stern bringt Bonus-Coins. Das Ergebnisfenster zeigt die Sterne und den nächsten Schritt.
- **Anna:** Checkliste in der neuen Reihenfolge (Fahrstunden → Theorie → Prüfung) mit Sternezahl.
- **Auswertung:** Onboarding-Schritte für das Creator Dashboard (beigetreten, im ersten Auto, 1./3./alle Fahrstunden, Theorie, Führerschein, erstes Auto, erster Job) – zeigt, wo neue Spieler aufhören.
- **Handy/Tablet:** Gas-, Brems- und Lenkknöpfe beim Fahren (nur Eingabe, das Fahrverhalten ist unverändert).
- Die Tagesbelohnung springt bei ganz neuen Spielern nicht mehr über die erste Fahrt (roter Punkt im Menü bleibt).

## v30 – Flüssiger auf allen Geräten, Night-Edition-Heck, Menü-Symbol
- **Server schneller:** Der NPC-Verkehr liest Ampeln und Schilder nur noch einmal ein statt tausende Male pro Sekunde – der Server hat mehr Luft, alles ruckelt weniger.
- **Detailstufen + Streaming (Karte):** Weit entfernte Gebäude zeichnet Roblox als vereinfachte Form, Geräte laden nur noch ~640 Studs Umgebung voll.
- **Fast-Modus:** zusätzlich Fenster ohne teuren Glas-Effekt. Tacho/HUD, Uhr und Anzeigen aktualisieren sich seltener (unsichtbar, spart Zeit auf Handys).
- **Vanta GS Night Edition:** neues Heck – LED-Segmente im Leuchtband, Rauchglas-Rahmen, lila Nachtlinie, senkrechte Lichthaken, Rückstrahler, Diffusor und Endrohre. Der normale Vanta GS bleibt wie er ist.
- **Menü-Knopf:** gezeichnetes Symbol (drei Striche) statt Zeichen, wird beim Öffnen zum X; Knöpfe mit feinem Rand und Verlauf.

## v29 – Performance für Handy, Tablet und schwache PCs
- **Grafik-Schalter** in den Settings: „⚡ Fast“ / „Best“. Handys und Tablets starten automatisch in „Fast“; am PC schaltet es sich ein, wenn das Spiel 10 Sekunden unter 30 FPS läuft (nur solange man nicht selbst gewählt hat).
- „Fast“: keine Sonnenstrahlen/Tiefenunschärfe/Bloom, weniger Regen, Minimap seltener neu gezeichnet, ferne NPC-Autos seltener bewegt.
- **Für alle:** Straßenlaternen leuchten nur nachts und nur in der Nähe (vorher 332 Lichter rund um die Uhr). Ferne NPC-Autos werden seltener bewegt, die Minimap höchstens 30-mal pro Sekunde gezeichnet.
- **Kleine Bildschirme:** große Fenster (Autohaus, Werkstatt, Akte, My Cars, Settings) werden auf dem Handy automatisch verkleinert statt abgeschnitten.

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
