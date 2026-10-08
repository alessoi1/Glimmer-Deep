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
| Boni-Zentrale | `Modifiers` (rein) fasst Boni aus Museum, Fähigkeiten, Haustieren, Boostern und Pässen zusammen: Boni addieren sich, Pass-Faktoren multiplizieren. Der Pass „Doppelte Münzen“ wirkt als eigener Faktor nur auf Erzverkäufe. | Ein Ort für alle Multiplikatoren; Fairness-Regel „wirkt nicht auf Funde“ bleibt dadurch prüfbar. |
| Zeit | `Calendar` (rein): Tage, Wochen und Zeitfenster zählen ab der Unix-Epoche in UTC, nur aus Serverzeit. | Alle Server stimmen überein; Wochenwechsel ist Donnerstag 00:00 UTC. |
| Vitrinen | Ein Fund wird beim Ausstellen aus dem Rucksack in die Vitrine verschoben (nicht kopiert) und kann zurück in den Rucksack, wenn dort Platz ist. Ausgestellte Funde werden nicht mit verkauft. | Verhindert Doppelnutzung; „Funde im Museum ausstellen“ ist eine echte Entscheidung gegen den Verkauf. |
| Besucher-Einkommen | 10 % des Fundwerts pro Stunde und Vitrine, höchstens 4 Stunden angesammelt. Die Auszahlung passiert beim Abholen und vor jeder Änderung an den Vitrinen. Der Münz-Bonus (Sets) wirkt darauf, der Pass nicht. | Einfach, ohne Hintergrund-Timer; keine Zeit geht bei Änderungen verloren oder wird dem falschen Fund zugerechnet. |
| Sets | Pro Schicht ein Set: je ein Fund jeder Art der Schicht ausgestellt (Seltenheit egal). Jedes Set gibt +10 % Münzen und +5 % Glück (additiv). | Konzept nennt „zum Beispiel +10 % Einnahmen“; das Glück ist dazu erfunden. |
| Profil-Speicher Museum | Vitrinen als Liste `{ slot, find }` statt Tabelle mit Lücken. | DataStores speichern keine Arrays mit Lücken. |
| Haus-Stufe | `house.level` (1 bis 4) liegt schon im Profil; die Zahl der Vitrinen kommt aus `Config/Museum.slotsByHouseLevel` (4, 12, 30, 60). | Museum ist Teil des Hauses; der Ausbau kommt in einem späteren Branch. |
| Museum im Spiel | Schild mit ProximityPrompt (Taste F, weil E zum Graben gehört): Besitzer öffnet das Panel, Besucher bewundern. Vitrinen als Raster östlich vom Schacht, bis zu 60 Plätze (Test prüft, dass alles ohne Überlappung auf das Grundstück passt). Aktionen im Panel brauchen höchstens 24 Studs Abstand zum Schild. | Prompt ist serverseitig und mobil bedienbar; kein eigener Eingabecode nötig. |
| Bewundern | Nur wenn das Museum mindestens einen Fund zeigt; ein Besucher kann dasselbe Museum alle 6 Stunden einmal bewundern (nur im Serverspeicher, startet beim Neustart neu). Zählt für Gesamtzahl und Wochenzähler. | Verhindert Spam ohne eigenen Speicher; Konzept verlangt „ohne etwas zu verändern oder zu stehlen“. |
| Bestenliste | Nur Spieler auf dem aktuellen Server, nach Bewunderungen der Woche. Die serverübergreifende Liste braucht einen OrderedDataStore und damit einen eigenen Dienst; die Regel „kein DataStore im Spielcode“ spricht dafür, sie später im DataService zu bündeln. | Kleinster sicherer Schritt. |
| Boni wirken | `ModifierService` sammelt die Boni; `DigService` nutzt Glück, Tempo, Rucksackgröße, `SellService` den Münz-Bonus (nur auf Erz). | Sets haben sonst keinen Effekt. |
| Offline-Bagger | Jeder Spieler hat von Anfang an einen Bagger auf Stufe 1 (60 Blöcke pro Stunde); sechs Stufen bis 1920 Blöcke pro Stunde, Preise 500 bis 120.000 (Upgrade-Panel „Bagger“). Maximal 4 Stunden zählen (Pass später +4). Wer das Spiel nicht sauber verlässt (Absturz), bekommt keinen Ertrag. | Konzept nennt „Mehrere Stufen“ ohne Zahlen. Kein Ertrag bei Absturz ist die sichere Seite gegen Doppelauszahlung. |
| Offline-Ertrag | Blöcke wie beim Graben gewürfelt (gleiche Schicht, gleicher Glückswert), Chance auf seltene Funde halb so hoch. Ergebnis landet im **Lager** (Depot), das zusammen mit dem Rucksack verkauft wird; höchstens 3000 Teile, höchstens 20.000 Blöcke pro Rückkehr. Die Tiefe wächst offline nicht. | „Niedrigere Chance als beim aktiven Graben“ aus dem Konzept; Tiefe bleibt aktivem Spiel vorbehalten (Fortschritts-Clip-Motiv). |
| Fund-Lager im Museum | Funde im Lager lassen sich direkt im Museum ausstellen. | Sonst gingen seltene Offline-Funde zwangsläufig in den Verkauf. |
| Abwesenheitszeit | `digger.leftAt` wird beim geordneten Verlassen gesetzt (`DataService.onLeaving`) und beim Betreten verbraucht. Es gibt keinen Hintergrund-Timer. | Entspricht CLAUDE.md („Startzeit speichern, beim Betreten berechnen“). |
