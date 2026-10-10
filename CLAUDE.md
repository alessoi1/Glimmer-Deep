# Glimmer Deep (Arbeitstitel)

Roblox-Spiel in Luau: Spieler besitzen eine private Burg mit einer Höhle in der Mitte, bauen Blöcke ab, finden Erz, Kräuter, Truhen und seltene Funde, stellen Funde im Museum aus, schmieden Rüstung und Waffen und kämpfen in der Oberwelt (PvP in Stufenzonen). Später: Handelswelt (Update 1), Burg-Ausbau (Update 2), Koop-Expedition (Update 3).
Das ausführliche Konzept steht in `docs/KONZEPT.md`. Bei Widersprüchen zwischen diesem File und dem Konzept: nachfragen, nicht raten.

## Zusammenarbeit

- Antworte auf Deutsch. Code, Kommentare, Variablennamen und Commit-Messages sind Englisch. Texte, die Spieler sehen, stehen in `src/shared/Strings.luau` (Deutsch).
- Arbeite in kleinen Schritten: erst kurzer Plan mit Dateiliste, dann Umsetzung. Eine Funktion pro Branch.
- Schreibe Tests zuerst für Fundwurf, Offline-Berechnung, Preise, Käufe, Kampfrechnung (später Handelsabrechnung).
- Frage nach, bevor du Preise, Wahrscheinlichkeiten, Datenformate oder Monetarisierung änderst.
- Sage offen, wenn etwas nur in Roblox Studio getestet werden kann. Behaupte nie, etwas laufe, wenn du es nicht ausgeführt hast.

## Plattform: Mac und Windows

Das Projekt wird auf Mac und Windows bearbeitet. Deshalb:
- Nur plattformneutrale Befehle und Skripte. Keine bash-only-Skripte; Hilfsskripte bevorzugt in Luau (Lune) oder Python.
- Relative Pfade mit `/`. Keine absoluten Pfade im Repo.
- Zeilenenden sind LF (`.gitattributes`: `* text=auto eol=lf`). Ändere das nicht.
- Dateinamen konsequent in der gleichen Schreibweise (macOS ist standardmäßig nicht case-sensitive, CI und Linux schon).
- Keine Datei darf von der Plattform abhängen (kein `.DS_Store`, kein `Thumbs.db` im Repo).

## Befehle

```
rokit install                    # Werkzeuge aus rokit.toml installieren
wally install                    # Pakete installieren (Ordner Packages/ ist nicht im Git)
rojo serve                       # Live-Sync nach Studio (im Rojo-Plugin "Connect")
mkdir build                      # einmalig (Rojo legt den Ordner nicht an, er ist nicht im Git)
rojo build -o build/GlimmerDeep.rbxl
stylua src tests                 # formatieren (Prüfung: stylua --check src tests)
selene src tests                 # Lint
lune run tests/run               # Tests (anpassen, sobald das Test-Setup steht)
```

Vor jedem Commit: `stylua --check`, `selene`, Tests. Schlägt etwas fehl, erst beheben.

## Projektstruktur

- `src/server` wird zu ServerScriptService (Dienste: Data, Castle, Cave, Dig, Offline, Crafting, Combat, Museum, Shop, Quest; später Potion, Trade).
- `src/client` wird zu StarterPlayerScripts (UI, Eingabe, Effekte, keine Spielwerte).
- `src/shared` wird zu ReplicatedStorage (Config, Typen, Strings, reine Hilfsfunktionen).
- `tests/` Tests, `assets/models/` exportierte `.rbxm`, `docs/` Konzept und Entscheidungen.
- Rojo-Dateien: `Name.server.luau`, `Name.client.luau`, ModuleScripts als `Name.luau`, Ordner mit `init.luau`.
- Bearbeite Skripte nur im Repo, nie direkt in Studio (sonst überschreibt Rojo sie). Fasse die `.rbxl`-Datei nicht an.

## Luau-Regeln

- Jede Datei beginnt mit `--!strict`. Typen für Funktionen und Daten angeben.
- Keine globalen Variablen. Keine veralteten Funktionen: `task.wait`, `task.spawn`, `task.delay` statt `wait`, `spawn`, `delay`.
- Alle Spielwerte (Preise, Chancen, Multiplikatoren, Limits) liegen in `src/shared/Config/`. Keine magischen Zahlen im Code.
- Dienste sind Module mit klarer Schnittstelle. Kleine Funktionen, früh zurückkehren, Fehler abfangen und loggen (siehe Abschnitt Logging), nicht verschlucken.
- Reine Logik (Würfe, Berechnungen) so schreiben, dass sie ohne Studio testbar ist (keine Roblox-Dienste direkt darin).

## Logging und Debugging

Alles wird mit Logs versehen, damit Fehler leicht nachvollziehbar sind.
- Geloggt wird nur über `src/shared/Log.luau` (`local log = Log.new("Dienstname")`). Kein loses `print` oder `warn` im Spielcode.
- Level: `debug` (hochfrequent, standardmäßig aus), `info` (normale Ereignisse), `warn` (abgelehnte Eingaben, unerwartete aber behandelte Fälle), `error` (Fehler, die eine Aktion abbrechen).
- Jeder Dienst loggt Start, Spieler laden/speichern, Käufe und Belege, Münz- und Tiefenänderungen durch Systeme, seltene Funde (ab Episch) und jeden abgefangenen Fehler.
- Jeder Remote-Handler loggt abgelehnte Aufrufe (Remote, Spieler, Grund) auf `warn`.
- Kontext als Tabelle mitgeben (`log.warn("save failed", { userId = id, attempt = n })`), nicht in den Text bauen. Spieler nur über `UserId` identifizieren.
- Reine Logik (zum Beispiel `DigRoll`) loggt nicht selbst; der aufrufende Dienst loggt das Ergebnis und Fehler.
- Keine Schlüssel, Tokens oder persönliche Daten in Logs. Hochfrequente Ereignisse (zum Beispiel jeder gegrabene Block) nur auf `debug`.
- Jeder `pcall` loggt den Fehler mit Kontext, bevor er behandelt wird.

## Server-Autorität und Sicherheit (harte Regeln)

- Der Server entscheidet über Funde, Münzen, Mutationen, Käufe, Treffer, Schaden, Leben und Handel. Der Client sendet nur Absichten (zum Beispiel eine Upgrade-ID), nie Preise oder Mengen.
- Jeder RemoteEvent/RemoteFunction-Handler prüft Typ, Wertebereich, Berechtigung und Cooldown. Ratenlimit pro Spieler.
- Würfe laufen nur im Server. Zeitwerte nur aus der Serverzeit (`os.time()` im Server, kein Clientwert).
- Vertraue nie Daten aus `RemoteEvent`-Argumenten, Attributen oder Instanzen, die der Client verändern kann.
- Kampf: Treffer (Position, Abstand, Takt), Schaden und Leben nur im Server, Werte aus Config und Profil. PvP-Schaden ist nur in der Oberwelt an; in Burg, Höhle und Handelswelt ist er serverseitig aus.
- Keine Skripte oder Modelle aus der Roblox-Toolbox übernehmen. Eigene oder geprüfte Assets nur.
- Keine Schlüssel, Tokens oder Open-Cloud-Keys im Repo oder in Chat-Ausgaben.

## Spielerdaten

- Laden und Speichern nur über DataService (ProfileStore). Kein direkter DataStore-Zugriff im Spielcode.
- Das Profil hat eine `version`-Nummer. Jede Änderung am Format bekommt eine Migration und einen Test.
- Die Höhle wird als Seed plus komprimierte Liste der abgebauten Blöcke je Abschnitt gespeichert (mit Obergrenze für die Höhlengröße), nie als alle Blöcke. Erze, Kräuter und Truhen werden aus dem Seed berechnet, der Nachwuchs beim Laden aus Zeitstempeln.
- Jedes handelbare Item (Fund, Ausrüstung) hat eine eindeutige ID.
- Offline-Einkommen: Startzeit und Stufe speichern, beim Betreten berechnen, auf das Offline-Maximum begrenzen. Keine Hintergrund-Timer.

## Käufe, Zufall und Roblox-Regeln

- Käufe nur über `MarketplaceService`. `ProcessReceipt` bestätigt erst nach erfolgreichem Speichern und ist idempotent (doppelte Belege abfangen).
- Eier und Glücks-Booster sind bezahlte Zufallsobjekte: alle Chancen als Prozent anzeigen (Summe 100 %), für eingeschränkte Spieler per `PolicyService` (`ArePaidRandomItemsRestricted`) ausblenden und dort erspielbar machen. Jedes Ei gibt immer etwas.
- Handel (Handelswelt, ab Update 1) nur nach `PolicyService`-Prüfung (`IsPaidItemTradingAllowed`); sonst für den Spieler gesperrt. Handelbar sind nur erspielte Dinge (Erze, Funde, Kräuter, Tränke, geschmiedete oder gefundene Ausrüstung). Nichts, was mit Robux gekauft wurde: Game Passes, Developer Products, Eier-Haustiere und Ausrüstung aus Robux-Paketen nie.
- Ausrüstung gegen Robux ist kontogebunden und nicht handelbar, reicht höchstens bis zur mittleren Stufe (Config) und ist nie besser als erspielte Ausrüstung der gleichen Stufe. Skins sind frei kaufbar und ändern keine Werte. Tränke gibt es nicht gegen Robux, Tempo-Booster wirken nicht im PvP.
- Nur Spielmünzen, nie Robux in der Handelswelt. Keine Münzpakete gegen Robux. Keine Chancenspiele mit handelbaren Items. Truhen und Tränke gibt es nie gegen Robux.
- Kauftexte neutral („Angebot ansehen“), nie drängend („Letzte Chance“).
- Die Regeln ändern sich. Vor Launch und vor Update 1 gegen die aktuelle Roblox-Dokumentation prüfen (siehe `docs/KONZEPT.md`, Abschnitt Roblox-Regeln).

## Mobile zuerst

Große Buttons, wenige Meldungen gleichzeitig, schlanke Modelle, Streaming für die Welt. UI immer auf Handy-Größe prüfen.

## Git

- Branches: `feature/kurzer-name`, `fix/kurzer-name`. Kein direkter Push auf `main`, kein Force-Push.
- Commit-Messages Englisch, kurz im Imperativ („Add dig service roll tests“). Kleine, einzelne Commits.
- Nicht ins Repo: `Packages/`, `build/`, `.env`, Schlüssel, lokale Studio-Dateien.
- Lösche oder verschiebe keine Dateien außerhalb des Projektordners. Keine neuen Abhängigkeiten ohne Rückfrage.

## Fertig heißt

Code formatiert, Lint sauber, Tests grün, Regeln oben eingehalten, kurze Notiz, was geändert wurde und was nur in Studio zu prüfen ist.

## Aktueller Stand

(Von Hand pflegen.) Gebaut ist der Umfang des alten Konzepts (Grundstück mit Schacht, Graben, Verkauf, Upgrades, Museum, Bagger, Quests, Shop, Booster, Haustiere, Haus bis Stufe 2, Gäste, Rebirth, Events, Saison, Stadt). Das Konzept wurde am 10. Oktober 2026 auf Burg, Höhle, Ausrüstung, Oberwelt-PvP und Handelswelt umgestellt und bestätigt (`docs/KONZEPT.md`, Abschnitte „Umbau des bestehenden Spiels“ und „Entscheidungen“). Der Launch enthält die Oberwelt mit PvP (ohne Blut). Nächster Schritt: Umbau U1 (Höhle statt Schacht). Noch nicht umgebaut: Höhle, Schmiede, Tränke, Oberwelt, Handelswelt. Vor dem Bau der Oberwelt die Roblox-Richtlinien zu PvP lesen. Später: Handelswelt (Update 1), Burg-Stufen 3 und 4 (Update 2), Koop-Expedition (Update 3).
