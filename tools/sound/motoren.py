"""
Eigene Motorsounds für alle Autos (komplett selbst erzeugt, keine Aufnahmen echter Autos).

Für jede Motor-"Stimme" entstehen:
  <Name>_Leerlauf.wav, <Name>_Niedrig.wav, <Name>_Hoch.wav  – nahtlose Schleifen bei fester Drehzahl
  <Name>_Start.wav                                           – Anlasser + Anspringen (einmalig)
Im Spiel werden die Schleifen je nach Drehzahl überblendet und schneller/langsamer abgespielt.

Aufruf:  python3 tools/sound/motoren.py            -> dist/sound/*.wav, dist/sound/vorschau/*.mp3, src/Motorklaenge.lua
Die Asset-IDs (nach dem Hochladen in Studio) stehen in tools/sound/ids.json und landen in src/Motorklaenge.lua.

Wie es klingt, entscheidet das Modell: Zündimpulse in der Reihenfolge des Motors (Zylinderzahl, Zündabstände,
Auspuffbank) -> Auspuff-Resonanzen (Filter) -> Ansauggeräusch, Diesel-Nageln, Turbo-Pfeifen -> leichte Sättigung.
Gefiltert wird "im Kreis" (3x hintereinander, nur die letzte Runde zählt): dadurch hat jede Schleife keine Naht.
"""
import json, math, os, subprocess, sys
import numpy as np
import scipy.signal as sg

SR = 44100
WURZEL = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
AUS = os.path.join(WURZEL, "dist", "sound")
VORSCHAU = os.path.join(AUS, "vorschau")
IDS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ids.json")


# ---------------------------------------------------------------------------------------------
# Filter (RBJ-Biquads)
# ---------------------------------------------------------------------------------------------
def _biquad(b, a):
    return np.array(b, float) / a[0], np.array(a, float) / a[0]


def spitze(f, db, q):
    A = 10 ** (db / 40); w = 2 * math.pi * f / SR; al = math.sin(w) / (2 * q); c = math.cos(w)
    return _biquad([1 + al * A, -2 * c, 1 - al * A], [1 + al / A, -2 * c, 1 - al / A])


def tiefpass(f, q=0.707):
    w = 2 * math.pi * f / SR; al = math.sin(w) / (2 * q); c = math.cos(w)
    return _biquad([(1 - c) / 2, 1 - c, (1 - c) / 2], [1 + al, -2 * c, 1 - al])


def hochpass(f, q=0.707):
    w = 2 * math.pi * f / SR; al = math.sin(w) / (2 * q); c = math.cos(w)
    return _biquad([(1 + c) / 2, -(1 + c), (1 + c) / 2], [1 + al, -2 * c, 1 - al])


def bandpass(f, q):
    w = 2 * math.pi * f / SR; al = math.sin(w) / (2 * q); c = math.cos(w)
    return _biquad([al, 0, -al], [1 + al, -2 * c, 1 - al])


def filtern(x, kette, periodisch=True):
    """periodisch=True: Filter im eingeschwungenen Zustand einer Endlosschleife (keine Naht)"""
    y = np.tile(x, 3) if periodisch else x.copy()
    for b, a in kette:
        y = sg.lfilter(b, a, y)
    return y[2 * len(x):] if periodisch else y


# ---------------------------------------------------------------------------------------------
# Motor-Stimmen. feuer = Zündfolge als (Kurbelwinkel in Grad innerhalb von 720°, Auspuffbank)
# ---------------------------------------------------------------------------------------------
def gleichmaessig(n, banken=(0,)):
    return [(i * 720 / n, banken[i % len(banken)]) for i in range(n)]


V8_CROSS = [(i * 90, b) for i, b in enumerate([0, 1, 0, 0, 1, 0, 1, 1])]  # ungleichmäßig je Bank -> Blubbern

STIMMEN = {
    # Fahrschulauto / Pizza-Auto: unauffälliger Vierzylinder
    "Fahrschule": dict(feuer=gleichmaessig(4), leerlauf=800, max=6200, gaenge=5, loops=(800, 2000, 4200),
                       puls=(0.5, 2.0, 0.35), auspuff=[(95, 6, 1.2), (310, 4, 1.5), (720, 2, 2.0), (1600, -3, 1.0)],
                       tp=(3000, 3400, 4600), rau=(1.3, 1.5, 1.8), ansaug=(0.06, 600, 2500), unruhe=(0.06, 0.04)),
    # Zipster: kleiner Dreizylinder mit Mini-Turbo, brummig
    "Zipster": dict(feuer=gleichmaessig(3), leerlauf=900, max=6300, gaenge=5, loops=(900, 2300, 4500),
                    puls=(0.45, 1.8, 0.3), auspuff=[(120, 5, 1.0), (420, 5, 2.0), (950, 3, 2.5), (2200, -2, 1.0)],
                    tp=(3600, 4000, 5200), rau=(1.4, 1.7, 2.2), ansaug=(0.08, 700, 3000), unruhe=(0.08, 0.05),
                    streuung=0.10, turbo=(7200, 0.002, 0.008, 0.012)),
    # Ranger X (SUV): tiefer, ruhiger V6
    "Ranger": dict(feuer=gleichmaessig(6, (0, 1)), leerlauf=700, max=5800, gaenge=6, loops=(700, 1900, 3900),
                   puls=(0.7, 2.8, 0.4), auspuff=[(75, 7, 1.0), (240, 4, 1.3), (520, 2, 2.0), (1300, -4, 1.0)],
                   tp=(2300, 2500, 3400), rau=(1.2, 1.3, 1.5), ansaug=(0.05, 500, 2000), unruhe=(0.05, 0.04),
                   bankversatz=0.4),
    # Executive (Limousine, Taxi): leiser, weicher V8 mit feinem Blubbern
    "Executive": dict(feuer=V8_CROSS, leerlauf=650, max=6000, gaenge=8, loops=(650, 1800, 3800),
                      puls=(0.8, 3.0, 0.45), auspuff=[(65, 6, 0.9), (180, 3, 1.2), (450, 1, 2.0), (900, -5, 1.0)],
                      tp=(1700, 1900, 2600), rau=(1.05, 1.15, 1.3), ansaug=(0.03, 400, 1600), unruhe=(0.05, 0.03),
                      bankversatz=0.8),
    # Velocity GT: kerniger Reihensechser, rau und hell
    "Velocity": dict(feuer=gleichmaessig(6, (0, 1)), leerlauf=850, max=7200, gaenge=6, loops=(850, 2300, 5000),
                     puls=(0.4, 1.6, 0.3), auspuff=[(110, 5, 1.2), (380, 4, 1.8), (1150, 5, 2.5), (2300, 3, 3.0)],
                     tp=(4500, 5000, 7000), rau=(1.5, 1.8, 2.4), ansaug=(0.10, 900, 4000), unruhe=(0.05, 0.04),
                     bankversatz=0.2),
    # Vanta GS: Biturbo-V6, scharf mit Turbo-Pfeifen
    "Vanta": dict(feuer=gleichmaessig(6, (0, 1)), leerlauf=800, max=6800, gaenge=7, loops=(800, 2200, 4700),
                  puls=(0.55, 2.2, 0.35), auspuff=[(90, 6, 1.1), (300, 5, 1.6), (850, 4, 2.2), (1900, 1, 2.5)],
                  tp=(3200, 3600, 5200), rau=(1.4, 1.6, 2.0), ansaug=(0.05, 600, 2500), unruhe=(0.05, 0.04),
                  bankversatz=0.3, turbo=(6200, 0.004, 0.015, 0.03)),
    # Vanta GS Night Edition: gleicher Motor, Sportauspuff – lauter, tiefer, rauer, unruhiger Leerlauf
    "VantaNight": dict(feuer=gleichmaessig(6, (0, 1)), leerlauf=820, max=7000, gaenge=7, loops=(820, 2300, 4900),
                       puls=(0.5, 2.0, 0.35), auspuff=[(85, 8, 1.0), (300, 5, 1.5), (850, 5, 2.2), (2100, 3, 2.5)],
                       tp=(3800, 4200, 6200), rau=(1.7, 2.0, 2.6), ansaug=(0.06, 600, 2800), unruhe=(0.10, 0.05),
                       bankversatz=0.35, turbo=(6400, 0.006, 0.02, 0.04)),
    # Striker TR: hochdrehender Sechszylinder-Boxer, metallisches Heulen
    "Striker": dict(feuer=gleichmaessig(6, (0, 1)), leerlauf=950, max=8800, gaenge=6, loops=(950, 2700, 6200),
                    puls=(0.35, 1.3, 0.25), auspuff=[(140, 4, 1.2), (480, 5, 2.0), (1500, 6, 3.0), (3000, 3, 3.0)],
                    tp=(5500, 6000, 8500), rau=(1.6, 1.9, 2.4), ansaug=(0.12, 1000, 5000), unruhe=(0.07, 0.04),
                    bankversatz=0.25),
    # Apex R1: roher Renn-V8 (flache Kurbelwelle), kreischend, unruhiger Leerlauf
    "Apex": dict(feuer=gleichmaessig(8, (0, 1)), leerlauf=1100, max=9500, gaenge=6, loops=(1100, 3000, 6800),
                 puls=(0.3, 1.2, 0.25), auspuff=[(160, 5, 1.0), (600, 6, 2.0), (1800, 6, 2.5), (3600, 3, 3.0)],
                 tp=(6000, 7000, 9500), rau=(1.6, 1.9, 2.3), ansaug=(0.08, 1200, 6000), unruhe=(0.14, 0.06),
                 jitter=0.15, bankversatz=0.15),
    # Nova SS: V12-Supersportler, weiches hohes Singen
    "Nova": dict(feuer=gleichmaessig(12, (0, 1)), leerlauf=950, max=8700, gaenge=7, loops=(950, 2700, 6000),
                 puls=(0.4, 1.5, 0.3), auspuff=[(130, 4, 1.0), (520, 5, 1.6), (1300, 6, 2.2), (2600, 5, 2.8)],
                 tp=(5500, 6500, 9000), rau=(1.5, 1.8, 2.2), ansaug=(0.11, 1000, 5000), unruhe=(0.04, 0.03),
                 bankversatz=0.2),
    # Lkw (Box/Heavy/Mega Truck): Reihensechs-Diesel mit Nageln und Turbo
    "Lkw": dict(feuer=gleichmaessig(6), leerlauf=600, max=2500, gaenge=8, loops=(600, 1200, 2000),
                puls=(1.0, 3.5, 0.5), auspuff=[(55, 6, 0.9), (160, 5, 1.2), (420, 3, 1.6), (1100, 1, 2.0)],
                tp=(2400, 2600, 3200), rau=(1.3, 1.5, 1.7), ansaug=(0.05, 500, 2000), unruhe=(0.06, 0.04),
                nageln=0.5, turbo=(4800, 0.01, 0.03, 0.05)),
    # Lieferwagen im NPC-Verkehr: Vierzylinder-Diesel
    "Transporter": dict(feuer=gleichmaessig(4), leerlauf=750, max=4500, gaenge=6, loops=(750, 1600, 3000),
                        puls=(0.8, 3.0, 0.45), auspuff=[(85, 5, 1.0), (260, 4, 1.4), (700, 2, 2.0)],
                        tp=(2600, 2800, 3600), rau=(1.2, 1.4, 1.6), ansaug=(0.05, 500, 2000), unruhe=(0.06, 0.04),
                        nageln=0.35, turbo=(5500, 0.008, 0.02, 0.03)),
}
LOOP_NAMEN = ("Leerlauf", "Niedrig", "Hoch")
LOOP_DAUER = (4.0, 3.0, 3.0)  # Sekunden


# ---------------------------------------------------------------------------------------------
# Bausteine
# ---------------------------------------------------------------------------------------------
def puls(x, tau1, tau2, beta):
    """Druckstoß im Auspuff: schneller Anstieg, Abklingen, danach Unterdruck (x in Samples, >= 0)"""
    t1 = tau1 * SR / 1000; t2 = tau2 * SR / 1000
    u = np.clip(x, 0, None)
    a = (u / t1) ** 2 * np.exp(2 * (1 - u / t1))
    b = (u / t2) ** 2 * np.exp(2 * (1 - u / t2))
    return a - beta * b


def impulse_setzen(puffer, zeiten, amps, form, n_lang, periodisch=True):
    N = len(puffer)
    idx = np.arange(-2, n_lang)
    for t, a in zip(zeiten, amps):
        i0 = int(math.floor(t))
        werte = form(idx + i0 - t) * a
        pos = idx + i0
        if periodisch:
            np.add.at(puffer, pos % N, werte)
        else:
            ok = (pos >= 0) & (pos < N)
            np.add.at(puffer, pos[ok], werte[ok])


def bank_ketten(v, art):
    """Filterketten je Auspuffbank. art 0..2 = Leerlauf/Niedrig/Hoch (Tiefpass öffnet mit der Last)"""
    ketten = []
    for bank in (0, 1):
        verstimmt = 1.0 if bank == 0 else 1.045
        k = [hochpass(32), hochpass(32)]
        for f, db, q in v["auspuff"]:
            k.append(spitze(f * verstimmt, db, q))
        k.append(tiefpass(v["tp"][art], 0.6))
        k.append(tiefpass(v["tp"][art] * 1.6, 0.7))
        ketten.append(k)
    return ketten


def periodische_frequenz(f, N):
    """Frequenz so runden, dass genau ganze Schwingungen in die Schleife passen (keine Naht)"""
    return max(1, round(f * N / SR)) * SR / N


def saettigen(x, staerke):
    x = x / (np.max(np.abs(x)) + 1e-9)
    return np.tanh(staerke * x) / math.tanh(staerke)


def normieren(x, rms_db=-17.0, spitze_max=0.89):
    rms = math.sqrt(float(np.mean(x ** 2))) + 1e-12
    x = x * (10 ** (rms_db / 20) / rms)
    sp = np.max(np.abs(x))
    if sp > spitze_max:
        x = x * (spitze_max / sp)
    return x


# ---------------------------------------------------------------------------------------------
# Schleife bei fester Drehzahl
# ---------------------------------------------------------------------------------------------
def schleife(name, v, art, rng):
    rpm_soll = v["loops"][art]
    N = int(round(LOOP_DAUER[art] * SR))
    zyklus = SR * 120.0 / rpm_soll                 # Samples pro Arbeitsspiel (720°)
    K = max(2, round(N / zyklus))
    zyklus = N / K                                 # ganze Arbeitsspiele in der Schleife
    rpm = 120.0 * SR / zyklus
    leer = art == 0
    amp_unruhe = v["unruhe"][0 if leer else 1]
    jitter = v.get("jitter", 0.08) * (1.6 if leer else 1.0) * SR / 1000
    n_zyl = len(v["feuer"])
    zyl_gain = 1 + rng.normal(0, v.get("streuung", 0.05), n_zyl)
    # langsame Drehzahlschwankung im Leerlauf (ganze Perioden in der Schleife)
    wobbel_f = periodische_frequenz(1.3, N) if leer else 0
    banken = [[], []]
    zeiten_alle = []
    for c in range(K):
        zyklus_amp = 1 + rng.normal(0, amp_unruhe * 0.6)
        for i, (winkel, bank) in enumerate(v["feuer"]):
            t = (c + winkel / 720.0) * zyklus
            if leer:
                t += 0.015 * zyklus * math.sin(2 * math.pi * wobbel_f * t / SR)
            t += rng.normal(0, jitter)
            a = zyl_gain[i] * zyklus_amp * (1 + rng.normal(0, amp_unruhe))
            last = (0.55, 1.0, 1.25)[art]
            banken[bank].append((t % N, a * last))
            zeiten_alle.append(t % N)
    tau1, tau2, beta = v["puls"]
    # Pulse werden mit steigender Drehzahl kürzer (Gas strömt schneller)
    kuerzer = (rpm / 2000) ** -0.15
    form = lambda x: puls(x, tau1 * kuerzer, tau2 * kuerzer, beta)
    n_lang = int(0.014 * SR)
    ketten = bank_ketten(v, art)
    summe = np.zeros(N)
    for bank in (0, 1):
        if not banken[bank]:
            continue
        roh = np.zeros(N)
        zt, za = zip(*banken[bank])
        impulse_setzen(roh, zt, za, form, n_lang)
        y = filtern(roh, ketten[bank])
        if bank == 1:
            y = np.roll(y, int(v.get("bankversatz", 0.3) * SR / 1000))
        summe += y
    rms = lambda x: math.sqrt(float(np.mean(x ** 2))) + 1e-12
    summe = summe / rms(summe)                      # alles relativ zum Motor-Grundklang (Effektivwert)

    # Ansauggeräusch: Rauschen, das bei jeder Zündung aufbrandet
    pegel, f1, f2 = v["ansaug"]
    rausch = rng.normal(0, 1, N)
    huelle = np.zeros(N)
    impulse_setzen(huelle, zeiten_alle, np.ones(len(zeiten_alle)), lambda x: np.exp(-np.clip(x, 0, None) / (0.004 * SR)) * (x >= 0), int(0.02 * SR))
    huelle = 0.4 + huelle / (np.max(huelle) + 1e-9)
    ansaug = filtern(rausch * huelle, [hochpass(f1), hochpass(f1), tiefpass(f2), tiefpass(f2)])
    summe += ansaug / rms(ansaug) * pegel * (0.7, 1.0, 1.4)[art]

    # Diesel-Nageln: kurzes, hartes Klopfen bei jeder Verbrennung
    if v.get("nageln"):
        klopf = np.zeros(N)
        knall = lambda x: np.sin(2 * math.pi * 3100 * x / SR) * np.exp(-np.clip(x, 0, None) / (0.0018 * SR)) * (x >= 0)
        impulse_setzen(klopf, zeiten_alle, 1 + rng.normal(0, 0.25, len(zeiten_alle)), knall, int(0.012 * SR))
        klopf = filtern(klopf + 0.3 * rausch * (huelle - 0.4), [hochpass(1500), tiefpass(6000)])
        summe += klopf / rms(klopf) * v["nageln"] * 0.7 * (1.0, 0.8, 0.6)[art]

    summe = saettigen(summe, v["rau"][art])
    summe = filtern(summe, [tiefpass(11000), hochpass(28)])

    # Turbo-Pfeifen (ganze Perioden in der Schleife)
    if v.get("turbo"):
        ft = v["turbo"][0] * (rpm / v["loops"][1]) ** 0.35
        ft = periodische_frequenz(ft, N)
        fm = periodische_frequenz(2.0, N)
        t = np.arange(N) / SR
        phase = 2 * math.pi * ft * t + 0.4 * np.sin(2 * math.pi * fm * t)
        # Pfeifen = schmales Rauschband + etwas reiner Ton (klingt nach Luft, nicht nach Piepser)
        band = filtern(rng.normal(0, 1, N), [bandpass(ft, 25), bandpass(ft, 25)])
        band = band / (np.max(np.abs(band)) + 1e-9)
        summe += (0.7 * band + 0.3 * np.sin(phase)) * v["turbo"][1 + art] * 4

    return normieren(summe), rpm


# ---------------------------------------------------------------------------------------------
# Anlassen: Anlasser, Anspringen, Hochdrehen, auf Leerlauf fallen
# ---------------------------------------------------------------------------------------------
def anlassen(name, v, rng):
    dauer = 2.3
    N = int(dauer * SR)
    t = np.arange(N) / SR
    t_kurbel = 0.62
    leer = v["leerlauf"]
    spitze_rpm = leer * 1.9
    rpm = np.where(t < t_kurbel, 230 + 25 * np.sin(2 * math.pi * 7 * t), 0.0)
    nach = t >= t_kurbel
    tt = t[nach] - t_kurbel
    hoch = 300 + (spitze_rpm - 300) * (1 - np.exp(-tt / 0.11))
    runter = leer + (spitze_rpm - leer) * np.exp(-np.clip(tt - 0.35, 0, None) / 0.38)
    rpm[nach] = np.where(tt < 0.35, hoch, runter)
    # Zündzeitpunkte aus dem Kurbelwinkel
    winkel = np.cumsum(rpm / 60 * 360 / SR)
    zuend = [w for w, _ in v["feuer"]]
    banken = [[], []]
    zeiten_alle = []
    for zyk in range(int(winkel[-1] // 720) + 1):
        for i, (w, bank) in enumerate(v["feuer"]):
            ziel = zyk * 720 + w
            k = np.searchsorted(winkel, ziel)
            if k <= 0 or k >= N:
                continue
            ts = k / SR
            if ts < t_kurbel:
                a = 0.12 + rng.normal(0, 0.02)          # nur Kompression, noch keine Zündung
            else:
                r = rpm[k]
                a = (0.7 + 0.8 * max(0.0, (r - leer) / (spitze_rpm - leer))) * (1 + rng.normal(0, 0.08))
                if ts - t_kurbel < 0.06 and rng.random() < 0.4:
                    a *= 0.3                            # die ersten Zündungen stottern
            banken[bank].append((k + rng.normal(0, 3), a))
            zeiten_alle.append(k)
    tau1, tau2, beta = v["puls"]
    form = lambda x: puls(x, tau1, tau2, beta)
    ketten = bank_ketten(v, 1)
    summe = np.zeros(N)
    for bank in (0, 1):
        if not banken[bank]:
            continue
        roh = np.zeros(N)
        zt, za = zip(*banken[bank])
        impulse_setzen(roh, zt, za, form, int(0.014 * SR), periodisch=False)
        summe += filtern(roh, ketten[bank], periodisch=False)
    summe /= np.max(np.abs(summe)) + 1e-9
    # Anlasser-Surren (Zahnrad-Heulen mit Kompressionsrhythmus)
    f0 = 150 + 25 * np.clip(t / t_kurbel, 0, 1)
    ph = np.cumsum(2 * math.pi * f0 / SR)
    surren = sum(np.sin(k * ph) / k for k in range(1, 8))
    surren *= (0.75 + 0.25 * np.sin(2 * math.pi * 7 * t)) * np.clip((t_kurbel + 0.05 - t) / 0.08, 0, 1) * np.clip(t / 0.03, 0, 1)
    surren = filtern(surren, [hochpass(250), tiefpass(3500)], periodisch=False)
    summe += 0.35 * surren / (np.max(np.abs(surren)) + 1e-9)
    summe = saettigen(summe, v["rau"][1])
    summe = filtern(summe, [tiefpass(11000), hochpass(28)], periodisch=False)
    summe *= np.clip((dauer - t) / 0.35, 0, 1)        # weich ausblenden, die Leerlauf-Schleife übernimmt
    return normieren(summe, rms_db=-19)


# ---------------------------------------------------------------------------------------------
# Vorschau: dieselbe Drehzahl-/Gang-Logik wie im Spiel (Motorsound.lua), offline gerendert
# ---------------------------------------------------------------------------------------------
def gang_hoechst(v_max, gang, gaenge):
    return v_max * 1.05 * (gang / gaenge) ** 0.7


def vorschau(name, v, loops, start, v_max):
    dt = 1 / 60
    dauer = 11.0
    schritte = int(dauer / dt)
    tempo, gang, rpm = 0.0, 1, float(v["leerlauf"])
    verlauf = []
    for s in range(schritte):
        zeit = s * dt
        # Ablauf: Start, Leerlauf, 2x Gasstoß im Stand, Vollgas, Rollen, Bremsen
        if zeit < 2.4:
            gas, stand = 0.0, True
        elif zeit < 3.4:
            gas = 1.0 if (2.5 < zeit < 2.75 or 3.0 < zeit < 3.2) else 0.0
            stand = True
        elif zeit < 8.6:
            gas, stand = 1.0, False
        elif zeit < 9.6:
            gas, stand = 0.25, False
        else:
            gas, stand = 0.0, False
        if not stand:
            beschl = gas * 14 * (1 - tempo / v_max) ** 0.6 * (1.15 if gang <= 2 else 1.0)
            if zeit >= 9.6:
                beschl = -30
            tempo = max(0.0, tempo + beschl * dt - 0.4 * dt)
        ziel, gang = drehzahl_ziel(v, tempo, gang, gas, v_max)
        rpm += (ziel - rpm) * min(1, dt * (9 if ziel > rpm else 6))
        verlauf.append((rpm, gas, zeit))
    # Rendern: Schleifen mit variabler Geschwindigkeit lesen und überblenden
    N = int(dauer * SR)
    schl = np.zeros(N)
    pos = [0.0, 0.0, 0.0]
    refs = [r for _, r in loops]
    for s, (r, gas, zeit) in enumerate(verlauf):
        if zeit < 1.6:
            continue
        a0, a1 = int(zeit * SR), min(N, int((zeit + dt) * SR))
        gew = gewichte(r, refs)
        lautst = (0.55 + 0.45 * gas) * (0.75 + 0.25 * min(1, r / v["max"]))
        for i, (daten, ref) in enumerate(loops):
            n = a1 - a0
            sp = r / ref
            idx = pos[i] + sp * np.arange(n)
            pos[i] = (pos[i] + sp * n) % len(daten)
            i0 = np.floor(idx).astype(int)
            fr = idx - i0
            werte = daten[i0 % len(daten)] * (1 - fr) + daten[(i0 + 1) % len(daten)] * fr
            schl[a0:a1] += werte * gew[i] * lautst
    # Anlassen am Anfang, die Schleifen blenden ab 1.6 s ein (wie im Spiel)
    schl *= np.clip((np.arange(N) / SR - 1.6) / 0.5, 0, 1)
    aus = schl.copy()
    aus[:len(start)] += start * 0.9
    return normieren(aus, rms_db=-16, spitze_max=0.95)


def drehzahl_ziel(v, tempo, gang, gas, v_max):
    leer, mx, n = v["leerlauf"], v["max"], v["gaenge"]
    if tempo < 0.5:
        return leer + gas * (mx * 0.62 - leer), 1
    # Gang wählen (mit Hysterese)
    hoch_bei = mx * (0.55 + 0.33 * gas)
    while gang < n and tempo / gang_hoechst(v_max, gang, n) * mx > hoch_bei:
        gang += 1
    while gang > 1 and tempo / gang_hoechst(v_max, gang, n) * mx < mx * 0.28:
        gang -= 1
    r = tempo / gang_hoechst(v_max, gang, n) * mx
    if gang == 1:
        r = max(r, leer + gas * leer * 1.2)            # Kupplung schleift beim Anfahren
    return max(leer, min(mx, r)), gang


def gewichte(r, refs):
    """Gleich-Leistungs-Überblendung zwischen den Schleifen (in Log-Drehzahl)"""
    g = [0.0, 0.0, 0.0]
    if r <= refs[0]:
        g[0] = 1
    elif r >= refs[2]:
        g[2] = 1
    else:
        i = 0 if r < refs[1] else 1
        t = math.log(r / refs[i]) / math.log(refs[i + 1] / refs[i])
        g[i] = math.cos(t * math.pi / 2)
        g[i + 1] = math.sin(t * math.pi / 2)
    return g


# ---------------------------------------------------------------------------------------------
def wav_schreiben(pfad, x):
    import wave
    d = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(pfad, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(d.tobytes())


VORSCHAU_TEMPO = {"Fahrschule": 130, "Zipster": 105, "Ranger": 120, "Executive": 145, "Velocity": 170, "Vanta": 180,
                  "VantaNight": 195, "Striker": 190, "Apex": 210, "Nova": 225, "Lkw": 70, "Transporter": 90}


def lua_daten(ergebnis, ids):
    z = ["-- Generated by tools/sound/motoren.py – do not edit by hand (asset IDs: tools/sound/ids.json).",
         "-- Engine voices: three seamless loops (idle / low / high rpm) and a start sound per voice.",
         "-- ref = rpm at which the loop was made (PlaybackSpeed = rpm / ref). id 0 = not uploaded yet.",
         "return {"]
    for name, info in ergebnis.items():
        v = STIMMEN[name]
        teile = []
        for i, ln in enumerate(LOOP_NAMEN):
            datei = f"DS_{name}_{ln}"
            teile.append(f'{{ id = {int(ids.get(datei, 0))}, ref = {info["refs"][i]:.1f} }}')
        sid = int(ids.get(f"DS_{name}_Start", 0))
        z.append(f'\t{name} = {{ leerlauf = {v["leerlauf"]}, max = {v["max"]}, gaenge = {v["gaenge"]}, start = {sid},')
        z.append(f'\t\tloops = {{ {", ".join(teile)} }} }},')
    z.append("}")
    return "\n".join(z) + "\n"


def main():
    nur = sys.argv[1:]
    os.makedirs(AUS, exist_ok=True); os.makedirs(VORSCHAU, exist_ok=True)
    ids = json.load(open(IDS)) if os.path.exists(IDS) else {}
    ergebnis = {}
    for name, v in STIMMEN.items():
        rng = np.random.default_rng(sum(map(ord, name)) * 7919)  # fest: gleiche Sounds bei jedem Lauf
        loops = []
        for art in range(3):
            x, rpm = schleife(name, v, art, rng)
            loops.append((x, rpm))
            wav_schreiben(os.path.join(AUS, f"DS_{name}_{LOOP_NAMEN[art]}.wav"), x)
        start = anlassen(name, v, rng)
        wav_schreiben(os.path.join(AUS, f"DS_{name}_Start.wav"), start)
        ergebnis[name] = {"refs": [r for _, r in loops]}
        if not nur or name in nur:
            vs = vorschau(name, v, loops, start, VORSCHAU_TEMPO[name])
            tmp = os.path.join(VORSCHAU, f"{name}.wav")
            wav_schreiben(tmp, vs)
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-b:a", "160k", os.path.join(VORSCHAU, f"{name}.mp3")], check=True)
            os.remove(tmp)
        print(f"{name:12s} Schleifen bei {', '.join(f'{r:.0f}' for _, r in loops)} U/min")
    with open(os.path.join(WURZEL, "src", "Motorklaenge.lua"), "w") as f:
        f.write(lua_daten(ergebnis, ids))


if __name__ == "__main__":
    main()
