# Offene Punkte

Von Hand pflegen. Hier stehen Dinge, die bewusst verschoben wurden und nicht vergessen werden dürfen.

## Spielmechanik

- [ ] **Schaufel-Reichweite:** Laut Konzept bringt eine größere Schaufel nicht nur Grabtempo, sondern auch Reichweite. Bisher ist nur der Grab-Cooldown pro Stufe umgesetzt (`Config/Shovel.luau`). Umsetzen, sobald Loch und Grab-Eingabe stehen (Entscheidung nötig: Radius in Blöcken oder Studs, mehrere Blöcke pro Aktion?). Beschlossen am 7. Oktober 2026.
- [ ] **Eindeutige IDs für seltene Funde:** Nötig für Museum (Vitrinen) und Auktionshaus (Update 1). Gehört zur Entscheidung über das Datenformat der Funde im Profil.
- [ ] **Balancing:** `metersPerBlock = 0.02` und `digRange = 12` (Config/Dig) sind Startwerte. Alle Preise, Kapazitäten, Cooldowns, Erzwerte, Mutationswerte sind Startwerte (siehe Kommentare in `src/shared/Config/`). In Playtests prüfen.
- [ ] **Offline-Einkommen:** Profil braucht dafür Startzeit und Bagger-Stufe (eigene Migration mit Test, siehe `docs/KONZEPT.md`).

## Technik

- [ ] **Graben in Studio prüfen:** `DigAction` (Cooldown, Rucksack, Würfe, Tiefe) ist in Lune getestet. In Studio prüfen: Button und Taste E, Halten wiederholt im Takt des Cooldowns, Anzeige oben links, „Rucksack voll“, „Geh näher …“, Handy-Größe (Emulator im Test-Tab), Tiefe bleibt nach Neustart erhalten. Bewusst nicht gebaut: Verkauf, Upgrades, Schachtlänge nach Tiefe. Zeit: `os.clock()` wird für die Cooldown-Zeit genutzt (Sekundenbruchteile), nicht `os.time()`.
- [ ] **Plots: Mehrspieler prüfen:** In Studio mit einem Spieler geprüft (7. Oktober 2026): 8 Grundstücke sichtbar, Spawn auf Plot 1, Respawn funktioniert. Noch offen: Test mit 2+ Spielern (Zuweisung, Freigabe beim Verlassen) und Max Players = 8. Bewusst nicht gebaut: Schacht-Länge nach gespeicherter Tiefe (kommt mit Dig), Streaming, echte Modelle. Roblox kennt keinen Fallschaden; ein Sturz in den Schacht tötet nicht.
- [ ] **DataService: Rest prüfen:** Laden, Speichern und erneutes Laden funktionieren in Studio mit API-Zugriff (7. Oktober 2026: erster Start `status=new`, zweiter `status=loaded`). Noch offen: Verhalten bei Ladefehler (Kick mit Meldung) und die CI-Schritte `wally install` (ungeprüft, bis der erste Lauf grün ist).
- [ ] **Studio:** `rojo build` und die Rojo-Version laufen in der CI. Skripte in Roblox Studio sind noch nie ausgeführt worden; Anleitung und erwartete Startmeldungen in `docs/SETUP.md`.
- [ ] **Typprüfung:** Kein `luau-analyze` in der Entwicklungsumgebung gelaufen. Lokal prüfen (zum Beispiel mit luau-lsp), besonders die strukturellen Typen in `Backpack.luau` und `Selling.luau`.
- [x] **Selene:** Läuft in der CI mit der echten Roblox-Standardbibliothek.
- [x] **CI:** Workflow `.github/workflows/ci.yml` (StyLua, Selene, Lune-Tests, Rojo-Build auf Linux, Windows und macOS) ist aktiv, Branch-Schutz für `main` ist eingerichtet.

## Vor Launch und vor Update 1

- [ ] Roblox-Regeln erneut gegen die aktuelle Dokumentation prüfen (siehe `docs/KONZEPT.md`, Abschnitt Roblox-Regeln).
- [ ] Arbeitstitel auf Roblox und per Markenrecherche prüfen.
