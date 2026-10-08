# Entscheidungen und Annahmen (Autopilot-Phase ab 8. Oktober 2026)

Der Nutzer hat die Umsetzung des gesamten Konzepts übergeben, mit Branches und Pull Requests wie bisher. Hier steht, was dabei **ohne Rückfrage entschieden** wurde, damit es geprüft und bei Bedarf geändert werden kann. Alle Zahlen sind Startwerte (siehe Kommentare in `src/shared/Config/`).

## Arbeitsweise

- Jeder Branch baut auf dem vorherigen auf (gestapelte Pull Requests), weil Claude nicht selbst mergen darf. Reihenfolge der PR-Nummern = Reihenfolge zum Mergen. Nach dem Merge des untersten PRs setzt GitHub den nächsten automatisch auf `main` um (Branch beim Mergen löschen lassen) oder der Basis-Branch wird manuell auf `main` gestellt.
- Tests zuerst für alles, was ohne Studio testbar ist. Was nur in Studio prüfbar ist, steht als Prüfpunkt in `docs/OFFEN.md`. Nichts davon wurde in Studio ausgeführt.
- Datenformat: jede Änderung hat eine Migration mit Test (`src/server/Migrations.luau`).

## Reihenfolge (Launch-Umfang zuerst)

1. Fund-IDs (Grundlage für Museum und Handel)
2. Onboarding: garantierter erster Fund
3. Museum
4. Offline-Bagger
5. Fähigkeiten und Schaufel-Reichweite
6. Quests und Login-Kette
7. Shop (Pässe, Produkte, Belege, PolicyService), Haustiere und Eier
8. Haus (Stufe 1 und 2), Dekoration
9. Gäste
10. Rebirth „Neue Bohrung“
11. Wöchentliche Events, Saison-Pass
12. Update-Umfang: Auktionshaus, Haus-Ausbau, Koop-Expedition, weitere Schichten

## Entscheidungen

| Thema | Entscheidung | Grund |
| --- | --- | --- |
| Fund-ID | Zahl, pro Profil eindeutig (`nextFindId`). Global eindeutig wird sie als `userId:findId` gebildet (Auktionshaus). | Reicht für Museum; Auktionshaus braucht eine globale ID, die sich daraus ableiten lässt. |
| Onboarding-Fund | Der 30. gegrabene Block (Lebenszeit-Zähler `stats.blocksDug`) ist ein garantierter seltener Fund, Mutation „golden“, einmalig pro Profil (`Config/Onboarding`). | Der Rucksack fasst 50 Blöcke, der Fund muss davor kommen; bei 0,6 s Abklingzeit sind 30 Blöcke etwa 18 Sekunden. Die Seltenheit bleibt zufällig, nur die Mutation ist fest. |
| Onboarding-Schritte | 7 Schritte (Graben, weiter graben, verkaufen, Upgrade, Museum, Bagger-Hinweis, fertig), vom Server per Ereignis weitergeschaltet, nie rückwärts. Der Client zeigt nur den Tipptext. Bestehende Profile überspringen das Onboarding. | Server entscheidet über den Fortschritt; kein Text-Tutorial, nur ein kurzer Tipp unten in der Mitte. |
| Pfeile im Onboarding | Noch nicht gebaut (nur Tipptext). | Pfeile und Highlights brauchen Studio-Prüfung; kommt mit dem UI-Feinschliff. |
