# Übergabe an die lokale Arbeit (10. Oktober 2026)

Stand für eine neue Claude-Code-Sitzung, die lokal auf diesem Rechner arbeitet (nicht in der Cloud). Zuerst `CLAUDE.md` lesen, dann diese Datei, dann `docs/OFFEN.md`.

## Einrichtung lokal

Siehe `docs/SETUP.md` (Rokit, Wally, Rojo, Lune, StyLua, Selene). Kurz: `rokit install`, `wally install`, `mkdir build`, `lune run tests/run` (erwartet 739 bestandene Tests), `stylua --check src tests`, `selene src tests`, `rojo serve` und in Studio „Connect“.

Lokal gibt es im Gegensatz zur Cloud-Umgebung Rojo, Studio und das echte Selene. Bitte `luau-analyze` (Typprüfung) einmal laufen lassen, falls vorhanden: Die Roblox-Seite (`CaveService`, `CaveUI`) wurde nie typgeprüft.

## Arbeitsweise (bewährt)

- Pro Schritt ein Branch (`feature/…`, `fix/…`), kleine Commits, nur ausdrücklich genannte Dateien mit `git add <Pfad>` (nie `git add -A`: einmal landeten Python-Pakete im Repo).
- PR gegen `main` (Branch-Schutz, CI läuft auf Ubuntu, Windows und macOS), bei grüner CI per Squash mergen. Der Nutzer hat erlaubt, dass Claude PRs selbst erstellt und mergt, ohne jedes Mal nachzufragen.
- Reine Logik zuerst mit Tests (Lune), Roblox-Dienste dünn halten, Behauptungen über Studio nur nach einem Studio-Test.
- Antworten auf Deutsch, Code, Kommentare und Commits auf Englisch. Spielertexte in `src/shared/Strings.luau`.

## Stand des Spiels

Gemergt in `main` (Auszug, neueste zuerst): #43 waagerechte, geschlossene Höhle mit markierten Grenzwänden, #42 Höhle über der Zerstörungshöhe, #41 Höhle eingeschaltet, #40 `CaveSession`/`CaveService`/`CaveUI`, #39 Kampfrechnung, #38 Tränke und Truhen-Loot (Profil v16), #37 Ausrüstung (Profil v15), davor Höhlenmodell, Profil v14, `CaveAction`, `CaveView`.

Läuft im Spiel (im Studio-Test des Nutzers bestätigt, alle Punkte der Checkliste): Knopf „In die Höhle“, waagerechter geschlossener Gang, Abbauen per Antippen, Erz im Rucksack, Verkauf, Truhen, Speichern, Nachwuchs, Rückkehr nach dem Tod. `Config/Cave.enabled = true`.

Nur als reine Logik vorhanden, nicht im Spiel angeschlossen: Ausrüstung und Schmiede (`Equipment`), Tränke (`Potions`), Truhen-Loot ist angeschlossen (`CaveSession.openChest`), Kampf (`Combat`: Zonen, Treffer, Kopfgeld).

## Offener Fehler (zuerst beheben)

**Meldung des Nutzers:** „Die Höhle lädt manchmal nicht, ich falle raus und sterbe. Sollte nicht passieren.“ Im ersten Test (alte Version) erschien das Log `entered the cave`, dann `left the cave reason=respawned`.

Bisherige Maßnahmen: Ursprung der Höhlen auf y = 200 (zuvor -600, unter der Zerstörungshöhe -500), `Workspace.FallenPartsDestroyHeight` wird beim Start auf -5000 gesetzt (in `pcall`; falls Roblox das verbietet, steht „could not lower FallenPartsDestroyHeight“ im Log). Das reicht offenbar nicht.

Verdächtig, in dieser Reihenfolge prüfen (Ursache nicht reproduziert):

1. **Teleport vor dem Laden der Teile:** `CaveService.handleEnter` baut die Teile und setzt sofort danach `root.CFrame`. Die Teile erreichen den Client verzögert (bei Streaming oder Last); die Figur fällt durch den noch fehlenden Boden. Mögliche Lösung: die Figur beim Betreten verankern (`Anchored`) und erst freigeben, wenn der Client „Boden ist da“ meldet (oder nach kurzer Wartezeit mit Prüfung per `Workspace:Raycast` auf dem Server), außerdem einen Sicherheitsboden unter der Eingangshalle, der sofort da ist.
2. **Streaming:** Prüfen, ob `Workspace.StreamingEnabled` an ist. Die Höhle liegt weit weg (x ≈ 3000, y = 200, z ≈ 1500); der Client lädt Teile dort erst, wenn er in der Nähe ist. Der Teleport und die Teile müssen zusammenpassen (`Player.ReplicationFocus`, `Player:RequestStreamAroundAsync(position)` vor dem Teleport).
3. **Sichtfenster folgt der Bewegung nicht:** `updateView` läuft nur nach einem Hieb, einer Truhe und alle 30 s bei Nachwuchs. Bei einem langen Vorgrab-Gang (Spieler mit Tiefe aus dem alten Spiel, `preDugRow` > 24) fehlt der Boden, sobald man weitergeht. Lösung: Position der Figur serverseitig beobachten (zum Beispiel alle 0,5 s, nur bei Zeilenwechsel neu berechnen).
4. **Absturz-Absicherung:** Der Dienst sollte merken, wenn die Figur unter den Höhlenboden fällt (Position unter dem Ursprung minus Toleranz), und sie zum Eingang zurücksetzen, statt sie sterben zu lassen. Zusätzlich beim Betreten und Verlassen im Log den Grund und die Zeilen/Höhe ausgeben.
5. Beim Betreten aus einem laufenden Hieb-Halten oder kurz nach dem Respawn: Reihenfolge `CharacterAdded` → `leaveCave` prüfen (kann den Besuch beenden, während der Client noch „in der Höhle“ zeigt).

Zum Auffinden helfen Logs (`entered the cave`, `left the cave reason=…`, Warnungen) und ein Test mit gedrosseltem Netzwerk im Studio (Emulator, „Incoming Replication Lag“ in den Studio-Einstellungen).

## Weitere offene Punkte (aus dem Nutzerfeedback und der Planung)

- Licht in der Höhle fehlt (Fackeln, Nachtsicht-Trank).
- Burg und Portal als Modell; die Höhle wird bisher nur über den Knopf erreicht (Knopf links Mitte).
- Schmiede (`ForgeService` und Oberfläche), Alchemie, danach Oberwelt mit Portal und PvP (vorher die Roblox-Richtlinien zu PvP und Altersfreigabe lesen und `docs/KONZEPT.md`, Abschnitt Roblox-Regeln, beachten).
- Auto-Graben (ab Spitzhackenstufe 3 für 5.000 Münzen, Game Pass 249 Robux), Gäste in der Höhle (nur Freunde, nur in selbst freigeschalteten Biomen).
- Schichten zu Biomen umbenennen, `depth` und `layerSeeds` aus dem Profil entfernen (Migration), Strings für neue Dinge, Handy-Messung (Teilebudget `maxParts` 3000, Fensterberechnung 15 bis 30 ms).
- Offen aus früheren Zusagen: Schaufel-Reichweite wurde durch die Hieb-Fläche ersetzt, späterer Spieltitel, Roblox-PvP-Regeln lesen.
- Vollständige Liste: `docs/OFFEN.md`, Entscheidungen: `docs/ENTSCHEIDUNGEN.md`, Studio-Checkliste: `docs/TESTLISTE.md`.

## Wichtige Dateien für die Höhle

`src/shared/Cave.luau` (Modell), `CaveCodec.luau`, `CaveAction.luau` (Hieb), `CaveView.luau` (Welt-Geometrie, sichtbare Zellen), `CaveSession.luau` (Sitzung je Spieler), `ChestLoot.luau`, `src/shared/Config/Cave.luau` (alle Werte inkl. `enabled`, Welt, Farben), `src/server/CaveService.luau` (Teile, Remotes, Teleport), `src/client/CaveUI.luau` (Knöpfe, Zielen), Remotes in `src/shared/Remotes.luau` (`Cave*`).

## Startsatz für die neue Sitzung

> Lies `CLAUDE.md` und `docs/UEBERGABE.md`. Behebe zuerst den offenen Fehler „Höhle lädt manchmal nicht, Spieler fällt heraus und stirbt“ (Branch `fix/cave-load`), mit Test für die reine Logik, soweit möglich. Ich teste danach in Studio. Du darfst PRs selbst erstellen und mergen, wenn die CI grün ist.
