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
| Schaufel-Reichweite | Reichweite heißt: wie weit der Spieler vom Schacht entfernt stehen darf (Studs auf `digRange`), 0 bis 5 je Schaufelstufe. Kein Mehrfach-Block pro Tipp. | Mehrere Blöcke pro Aktion würden die Rucksack- und Tempo-Balance (30 Sekunden bis voll) verändern. Der OFFEN-Punkt wollte eine Entscheidung. |
| Fähigkeiten | Vier Upgrade-Spuren mit 4 bis 5 Stufen: Starke Arme (+5 bis +20 % Tempo), Erzspürer (+10 bis +40 % Chance auf seltene Funde), Seilwinde (+10 bis +30 % Lauftempo), Lampe (+5 bis +20 % Glück). Der Bonus einer Stufe ersetzt den der vorigen. Preise 250 bis 60.000. | Konzept nennt Namen und Wirkung, keine Zahlen. Die „Lampe“ wirkt als Glück (Seltenheit und Mutation), nicht als Sicht. |
| Seilwinde | Statt „schnelleres Hochfahren“ (es gibt keinen Aufzug) macht sie die Figur schneller. | Wege zwischen Schacht, Verkaufspunkt und Museum sind die einzige Fahrtzeit. |
| Tagesaufgaben | Pool von 8 Aufgaben (Rucksack füllen, Mutation finden, Vitrine füllen, graben, verkaufen, seltene Funde, Upgrade, Besucher-Einnahmen), jeden Tag drei, deterministisch aus Tag und Spieler gewählt. Belohnung 150 bis 500 Münzen je Aufgabe, 500 Münzen Bonus für „alle drei“. Neue Aufgaben um Mitternacht UTC. | Konzept nennt drei Beispiele ohne Belohnungen. Feste Beträge, weil Münzwerte stark mit dem Fortschritt wachsen; eine Skalierung wäre ein späterer Schritt. |
| Login-Kette | Sieben Tage mit 100, 150, 200, 300, 400, 600, 1000 Münzen; nach Tag 7 beginnt die Kette wieder bei Tag 1; ein verpasster Tag setzt um einen Tag zurück (nie unter Tag 1). Die Belohnung wird bewusst abgeholt (kein Popup beim Betreten). | Entspricht „um einen Tag zurückgestuft“. Kein erzwungener Dialog, passend zur Regel „keine Pop-ups“. |
| Ereignisse | Graben, Verkauf, Upgrade und Museum melden an den `QuestService`; die Zeit kommt nur vom Server (`os.time`). | Server-Autorität. |
| Shop-Aufbau | Passes zuerst (dieser Branch), danach Developer Products mit Belegen und Zufallsobjekte. Pass-IDs stehen als 0 in der Config, bis sie im Dashboard angelegt sind; der Shop bietet sie dann nicht an. | IDs kann nur der Entwickler anlegen. Nichts darf ohne echte ID gekauft werden. |
| Shop erst nach dem Onboarding | Knopf „Shop“ und Kaufangebote gibt es erst ab Onboarding-Schritt 7; der Server lehnt Angebote davor ab. | Fairness-Regel 1: keine Kaufangebote in den ersten 10 Minuten. |
| Pass-Besitz | Roblox ist die Quelle; das Profil speichert nur das geprüfte Ergebnis (`passes`). Prüfung beim Betreten im Hintergrund und nach jedem Kauf. | Bonuse wirken ab dem Betreten, ohne das Laden zu blockieren; Rückerstattungen werden beim nächsten Betreten erkannt. |
| Schnellreise | Der Pass „Schnellaufzug“ heißt im Spiel „Schnellreise“ und springt zwischen Schacht und Verkaufspunkt (es gibt keinen Aufzug), Abklingzeit 5 Sekunden. | Konzept: „Sofort nach oben und zurück in die Tiefe“. |
| Booster | Glücks-Booster 15 Minuten (+25 % Glück, 39 Robux) und Tempo-Booster 30 Minuten (doppeltes Grabtempo, 49 Robux) als Developer Products. Kauf zählt Zeit dazu, die Restzeit steigt aber nie über 2 Stunden; ein Kauf, der darüber hinausginge, wird nicht angeboten. Die Zeit läuft auf Serverzeit (`expires` im Profil), ohne Hintergrund-Timer. Wirkung über `Modifiers` (Glück addiert sich mit Fähigkeiten und Sets). | Konzept nennt Preise und Dauer; +25 % ist ein Startwert. Das Deckel-Limit verhindert Vorratskäufe und Verlust von bezahlter Zeit. |
| Belege | `ProcessReceipt` gibt erst nach `DataService.saveNow` `PurchaseGranted` zurück. Das Profil merkt sich die letzten 100 Kaufnummern (`boosters.receipts`); eine bekannte Nummer gewährt nichts mehr, bestätigt aber nach erneutem Speichern. Unbekanntes Produkt oder fehlendes Profil: `NotProcessedYet` (Roblox fragt später erneut). | Idempotent und nach CLAUDE.md erst nach erfolgreichem Speichern bestätigt. |
| Glücks-Booster für eingeschränkte Spieler | Der Glücks-Booster ist ein bezahltes Zufallsobjekt. Das Angebot zeigt die Chancen je Seltenheit und die Mutationschance ohne und mit Booster (jeweils Summe 100 %). Ist `ArePaidRandomItemsRestricted` wahr oder unbekannt, wird er weder gezeigt noch angeboten; dann gibt es einmal pro 24 Stunden eine Gratis-Laufzeit. Der Server prüft das bei jedem Angebot. | Roblox-Regel für bezahlte Zufallsobjekte; „unbekannt“ zählt als eingeschränkt, damit nie versehentlich verkauft wird. |
| Boosters nicht handelbar | Booster sind Zeitwirkungen im Profil, keine Gegenstände, und können nicht verschenkt oder gehandelt werden. | Konzept: Developer Products sind nicht handelbar. |
