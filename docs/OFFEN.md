# Offene Punkte

Von Hand pflegen. Hier stehen Dinge, die bewusst verschoben wurden und nicht vergessen werden dürfen.

## Spielmechanik

- [ ] **Schaufel-Reichweite:** Laut Konzept bringt eine größere Schaufel nicht nur Grabtempo, sondern auch Reichweite. Bisher ist nur der Grab-Cooldown pro Stufe umgesetzt (`Config/Shovel.luau`). Umsetzen, sobald Loch und Grab-Eingabe stehen (Entscheidung nötig: Radius in Blöcken oder Studs, mehrere Blöcke pro Aktion?). Beschlossen am 7. Oktober 2026.
- [ ] **Eindeutige IDs für seltene Funde:** Nötig für Museum (Vitrinen) und Auktionshaus (Update 1). Gehört zur Entscheidung über das Datenformat der Funde im Profil.
- [ ] **Balancing:** Alle Preise, Kapazitäten, Cooldowns, Erzwerte, Mutationswerte sind Startwerte (siehe Kommentare in `src/shared/Config/`). In Playtests prüfen.
- [ ] **Offline-Einkommen:** Profil braucht dafür Startzeit und Bagger-Stufe (eigene Migration mit Test, siehe `docs/KONZEPT.md`).

## Technik

- [ ] **DataService mit ProfileStore:** Wartet darauf, dass `rokit install` und `wally install` lokal bestätigt sind. Paketname und Version in `wally.toml` sind ungeprüft. Danach `ServerPackages` in `default.project.json` eintragen.
- [ ] **Rojo und Studio:** `rojo build` und alle Skripte in Studio sind noch nie ausgeführt worden (nur Lune-Tests). Rojo-Version in `rokit.toml` ungeprüft.
- [ ] **Typprüfung:** Kein `luau-analyze` in der Entwicklungsumgebung gelaufen. Lokal prüfen (zum Beispiel mit luau-lsp), besonders die strukturellen Typen in `Backpack.luau` und `Selling.luau`.
- [ ] **Selene:** Roblox-Standardbibliothek konnte in der Cloud-Umgebung nicht erzeugt werden. Lokal `selene src tests` laufen lassen.
- [ ] **CI:** Es gibt noch keinen CI-Workflow (StyLua, Selene, Lune-Tests bei jedem Pull Request).

## Vor Launch und vor Update 1

- [ ] Roblox-Regeln erneut gegen die aktuelle Dokumentation prüfen (siehe `docs/KONZEPT.md`, Abschnitt Roblox-Regeln).
- [ ] Arbeitstitel auf Roblox und per Markenrecherche prüfen.
