# Lokale Einrichtung (Mac und Windows)

Diese Anleitung richtet das Projekt lokal ein, verbindet es mit Roblox Studio und prüft die Startmeldungen. Alle Befehle laufen im Terminal (Mac: Terminal, Windows: PowerShell) im Projektordner.

## 1. Cloud oder lokal arbeiten?

Du kannst Claude Code lokal statt in der Cloud nutzen. Das Projekt ist dafür ausgelegt (Mac und Windows, plattformneutrale Befehle).

- **Vorteil lokal:** Roblox Studio, Rojo und Wally laufen auf deinem Rechner. Nur lokal lässt sich testen, ob die Skripte in Studio laufen; in der Cloud ist das nicht möglich. Kein Netzwerk-Sandbox, keine Host-Freigaben nötig.
- **Kosten:** Die Cloud-Umgebung entfällt. Die Nutzung des Modells hängt an deinem Claude-Plan und seinen Limits; verbindliche Preise kann ich hier nicht nennen. Schau in deinem Konto unter Plan und Nutzung nach.
- **Was lokal fehlt:** Die GitHub-Werkzeuge der Cloud-Sitzung (Pull Requests anlegen, CI-Ereignisse beobachten). Lokal geht das über die GitHub-CLI (`gh`), siehe Abschnitt 6.

Claude Code installieren: https://code.claude.com/docs/en/quickstart (dort stehen die aktuellen Befehle für Mac und Windows).

## 2. Voraussetzungen

- **Git:** Mac: `git --version` im Terminal (bietet bei Bedarf die Installation der Entwicklerwerkzeuge an). Windows: Git for Windows von https://git-scm.com installieren.
- **Roblox Studio:** von https://create.roblox.com herunterladen und einmal mit deinem Konto anmelden.
- **Claude Code** (siehe oben).

## 3. Projekt holen und Werkzeuge installieren

```
git clone https://github.com/alessoi1/Glimmer-Deep.git
cd Glimmer-Deep
```

**Rokit** verwaltet die Werkzeuge des Projekts (Rojo, Lune, StyLua, Selene, Wally). Installation laut offizieller Anleitung: https://github.com/rojo-rbx/rokit (Release für dein System herunterladen, dann `rokit self-install` ausführen und das Terminal neu öffnen). Danach im Projektordner:

```
rokit install
```

Rokit fragt, ob du den Werkzeugen vertraust. Mit Ja bestätigen. Dann:

```
wally install
```

`wally install` lädt ProfileStore in den Ordner `ServerPackages/` (nicht im Git). Beim Start kann Wally nach einem Login fragen; für öffentliche Pakete ist keiner nötig.

## 4. Prüfen, dass alles läuft

```
stylua --check src tests
selene generate-roblox-std
selene src tests
lune run tests/run
mkdir build
rojo build -o build/GlimmerDeep.rbxl
```

Erwartet:

- StyLua und Selene ohne Fehler.
- Lune meldet am Ende `93 passed, 0 failed` (die Zahl steigt mit neuen Tests).
- `rojo build` legt `build/GlimmerDeep.rbxl` an. Den Ordner `build` mit `mkdir build` nur einmal anlegen; die Datei nicht ins Git legen und nicht von Hand bearbeiten.

Das sind dieselben Prüfungen wie in der CI (`.github/workflows/ci.yml`).

## 5. Mit Roblox Studio verbinden

1. **Rojo-Plugin installieren:** Im Projektordner `rojo plugin install` ausführen. Danach Studio neu starten, falls es offen war. (Das Plugin passt zur Rojo-Version aus `rokit.toml`. Eine andere Plugin-Version aus der Toolbox kann Fehler verursachen.)
2. **Leeres Place anlegen:** In Studio ein neues Place (Baseplate) erstellen. Das Place speicherst du außerhalb des Projektordners oder gar nicht; Skripte kommen nur über Rojo, nie von Hand in Studio.
3. **Rojo starten:** Im Projektordner:
   ```
   rojo serve
   ```
   Das Terminal zeigt eine Adresse (normalerweise `localhost:34872`). Das Fenster offen lassen.
4. **Verbinden:** In Studio im Reiter Plugins auf Rojo klicken und im Rojo-Fenster auf **Connect**. Die Frage nach HTTP-Zugriff für das Plugin bestätigen. Studio zeigt jetzt unter `ReplicatedStorage/Shared`, `ServerScriptService/Server` und `StarterPlayer/StarterPlayerScripts/Client` die Skripte aus dem Repo.
5. **Output öffnen:** Reiter View, dann **Output**.
6. **Starten:** Play (F5) oder Run (F8) drücken.

### Erwartete Startmeldungen im Output

```
[GlimmerDeep][Main] dig config is valid
[GlimmerDeep][Main] ore prices is valid
[GlimmerDeep][Main] backpack levels is valid
[GlimmerDeep][Main] shovel levels is valid
[GlimmerDeep][Main] upgrade tracks is valid
[GlimmerDeep][Main] new profile is valid
[GlimmerDeep][Data] started profileVersion=1 store=PlayerProfiles_v1
[GlimmerDeep][Data] loading profile userId=...
[GlimmerDeep][Data] profile loaded status=new userId=... version=1
[GlimmerDeep][Plot] plot assigned userId=... plot=1 free=7
[GlimmerDeep][Dig] started metersPerBlock=0.02 digRange=12
```

**Graben testen:** Auf dem Grundstück an den Schacht gehen (maximal 12 Studs entfernt). Dann den Button „Graben“ unten rechts antippen oder halten, am PC geht auch die Taste **E**. Oben links stehen Tiefe, Schicht und Rucksack, darunter erscheint der letzte Fund. Pro Block wächst die Tiefe um 0,02 m, nach 50 Blöcken kommt „Rucksack voll“ (Verkauf gibt es noch nicht). Zu weit weg zeigt „Geh näher an deinen Schacht“. Seltene Funde ab Episch stehen als `rare find` im Output; abgelehnte Aufrufe als `dig rejected` (höchstens alle 5 Sekunden pro Grund).

**Plots ansehen:** Die 8 Platzhalter-Grundstücke liegen weit weg von der Baseplate (Config `Plot.origin`, Start bei X = 3000, die Template-Baseplate ist 2048 Studs breit). Dein Charakter erscheint auf Plot 1 neben dem Schacht. Im Workspace liegt der Ordner `Plots`.

**Max Players:** Es gibt nur 8 Grundstücke. Unter Game Settings, Players, **Max Players** auf 8 stellen, sonst wird der 9. Spieler mit einer Meldung gekickt (das ist gewollt, aber der Server sollte gar nicht erst so viele annehmen).

In Studio ohne Zugriff auf API-Dienste nutzt ProfileStore automatisch einen Zwischenspeicher: Alles funktioniert, aber der Spielstand überlebt das Beenden von Play nicht. Zum echten Speichern im Studio unter Game Settings, Security, **Enable Studio Access to API Services** aktivieren (das Place muss dafür veröffentlicht sein).

Eine Zeile mit `... is invalid reason=...` (rot oder gelb) bedeutet einen Fehler in der Config oder im Profilformat; bitte die ganze Zeile an Claude schicken.

### Wenn etwas nicht klappt

| Symptom | Ursache und Lösung |
| --- | --- |
| `Infinite yield possible on 'ReplicatedStorage:WaitForChild("Shared")'` | Rojo ist nicht verbunden. `rojo serve` läuft nicht oder Connect wurde nicht gedrückt. |
| Rojo meldet eine Versionsabweichung zwischen Plugin und CLI | `rojo plugin install` erneut ausführen und Studio neu starten. |
| Plugin kann nicht verbinden | Läuft `rojo serve`? In Studio unter Game Settings, Security, **Allow HTTP Requests** aktivieren, falls verlangt. Firewall-Frage bestätigen. |
| Keine Meldungen im Output | Play oder Run drücken; Server-Skripte laufen nur dann. Im Output-Fenster den Filter auf Alle stellen. |
| `selene` meldet, dass die Standardbibliothek fehlt | `selene generate-roblox-std` ausführen. |

## 6. Mit Claude Code lokal arbeiten

```
cd Glimmer-Deep
claude
```

Claude Code liest `CLAUDE.md` automatisch. Die Arbeitsweise bleibt gleich: kleiner Plan mit Dateiliste, Tests zuerst, vor jedem Commit `stylua --check`, `selene`, Tests, ein Branch pro Funktion (`feature/kurzer-name`), kein Push auf `main`.

Für Pull Requests lokal die GitHub-CLI installieren (https://cli.github.com) und einmal `gh auth login` ausführen. Danach kann Claude Code PRs anlegen und den CI-Stand lesen.

## 7. Was danach als Nächstes ansteht

Siehe `docs/OFFEN.md`.
