# Offene Punkte

Von Hand pflegen. Hier stehen Dinge, die bewusst verschoben wurden und nicht vergessen werden dürfen.

## Spielmechanik

- [ ] **Schaufel-Reichweite:** Laut Konzept bringt eine größere Schaufel nicht nur Grabtempo, sondern auch Reichweite. Bisher ist nur der Grab-Cooldown pro Stufe umgesetzt (`Config/Shovel.luau`). Umsetzen, sobald Loch und Grab-Eingabe stehen (Entscheidung nötig: Radius in Blöcken oder Studs, mehrere Blöcke pro Aktion?). Beschlossen am 7. Oktober 2026.
- [ ] **Eindeutige IDs für seltene Funde:** Nötig für Museum (Vitrinen) und Auktionshaus (Update 1). Gehört zur Entscheidung über das Datenformat der Funde im Profil.
- [ ] **Balancing:** Alle Preise, Kapazitäten, Cooldowns, Erzwerte, Mutationswerte sind Startwerte (siehe Kommentare in `src/shared/Config/`). In Playtests prüfen.
- [ ] **Offline-Einkommen:** Profil braucht dafür Startzeit und Bagger-Stufe (eigene Migration mit Test, siehe `docs/KONZEPT.md`).

## Technik

- [ ] **DataService: Rest prüfen:** Laden, Speichern und erneutes Laden funktionieren in Studio mit API-Zugriff (7. Oktober 2026: erster Start `status=new`, zweiter `status=loaded`). Noch offen: Verhalten bei Ladefehler (Kick mit Meldung) und die CI-Schritte `wally install` (ungeprüft, bis der erste Lauf grün ist).
- [ ] **Studio:** `rojo build` und die Rojo-Version laufen in der CI. Skripte in Roblox Studio sind noch nie ausgeführt worden; Anleitung und erwartete Startmeldungen in `docs/SETUP.md`.
- [ ] **Typprüfung:** Kein `luau-analyze` in der Entwicklungsumgebung gelaufen. Lokal prüfen (zum Beispiel mit luau-lsp), besonders die strukturellen Typen in `Backpack.luau` und `Selling.luau`.
- [x] **Selene:** Läuft in der CI mit der echten Roblox-Standardbibliothek.
- [x] **CI:** Workflow `.github/workflows/ci.yml` (StyLua, Selene, Lune-Tests, Rojo-Build auf Linux, Windows und macOS) ist aktiv, Branch-Schutz für `main` ist eingerichtet.

## Vor Launch und vor Update 1

- [ ] Roblox-Regeln erneut gegen die aktuelle Dokumentation prüfen (siehe `docs/KONZEPT.md`, Abschnitt Roblox-Regeln).
- [ ] Arbeitstitel auf Roblox und per Markenrecherche prüfen.
