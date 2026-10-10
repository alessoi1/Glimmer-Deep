# Spielkonzept: Glimmer Deep (Arbeitstitel)

Erstfassung 7. Oktober 2026 · überarbeitet am 10. Oktober 2026 (Burg, Höhle, Oberwelt mit PvP, Handelswelt) · @Developer

Glimmer Deep ist ein Roblox-Spiel, in dem jeder Spieler eine eigene Burg besitzt. In der Mitte der Burg beginnt eine Höhle: Man schlägt mit der Spitzhacke Block für Block Gestein ab, findet Erz, Kräuter, Truhen und seltene, mutierte Schätze und gräbt sich dabei durch immer neue Biome in die Tiefe. Aus den Erzen schmiedet man Rüstung und Waffen im Mittelalter-Stil, braut Tränke, stellt Funde im Museum der Burg aus und kämpft außerhalb der Burg in der Oberwelt gegen andere Spieler (PvP). In einer zweiten Welt, der Handelswelt, verkaufen Spieler Items an eigenen Ständen für Münzen. Das Spiel lässt sich in Stufen von einer Person mit Claude Code bauen.

## Was sich am 10. Oktober 2026 geändert hat

Entscheidungen des Entwicklers, die das Konzept vom 7. Oktober ersetzen:

| Bereich | Bisher | Neu |
| --- | --- | --- |
| Grundstück | Grundstück mit Schacht (Loch) | **Burg**, in der Mitte der Burg beginnt die **Höhle**. Kein fremder Spieler betritt die Burg. |
| Graben | Tippen, ein Block pro Aktion, Tiefe nur als Zahl | Man **baut Blöcke selbst ab**, die Höhle wird dadurch größer. Mit Upgrades fallen mehr Blöcke pro Hieb, später Auto-Graben. |
| Schichten | 3 Schichten zum Launch | **Mittelalterliche Biome** nach Tiefe |
| Erze | Fallen beim Graben an | **Erze und Kräuter wachsen an den Wänden** und wachsen nach. **Truhen** liegen versteckt in der Höhle. |
| Ausrüstung | keine | **Rüstung und Waffen** aus Erzen, bessere Erze geben mehr Leben und Schaden |
| Kampf | „Rein kooperativ, ohne Kämpfe“ | **PvP in der Oberwelt**, in Stufenzonen. Kein Item-Verlust, der Sieger bekommt Münzen. |
| Handel | Auktionshaus (Update 1) | **Handelswelt** mit Ständen (Update 1) |
| Besuch | Besucher bewundern das Museum | Burg ist privat. Nur Roblox-Freunde dürfen auf Einladung kommen. |
| Neu | – | **Tränke** aus Kräutern der Biome |

Bleibt: Offline-Helfer, Museum und Sets, Haustiere und Eier, Quests und Login-Kette, wöchentliche Events, Saison-Pass, Rebirth, Booster, Passes, Burg-Ausbau (früher Haus-Ausbau), Koop-Expedition als spätere Option. Die Entscheidungen dazu stehen am Ende unter „Entscheidungen vom 10. Oktober 2026“.

## Vision und Hype-Begründung

**Pitch in einem Satz:** Grab dich auf deinem eigenen Burggrund immer tiefer in die Erde, finde mutierte Schätze und seltene Erze, schmiede dir Rüstung und Schwert, zeig deine Sammlung im Museum, kämpfe in der Oberwelt und handle in der Handelswelt.

**Zielgruppe:** Roblox-Spieler ab etwa 9 Jahren mit Fokus auf Mobile, die kurze Sessions von 5 bis 15 Minuten mehrmals am Tag spielen, plus ältere Spieler, die Sammlungen vervollständigen, kämpfen und handeln wollen.

**Die Säulen:**

1. **Burg und Höhle:** privater Besitz mit sichtbarem Fortschritt (Höhle wird größer und tiefer, Biome wechseln).
2. **Sammeln und Museum:** seltene Funde mit Seltenheit und Mutation, ausgestellt in Vitrinen der Burg.
3. **Schmieden und Kämpfen:** bessere Erze, bessere Rüstung und Waffen, PvP in der Oberwelt.
4. **Handelswelt:** Spieler verkaufen und kaufen Items untereinander an eigenen Ständen.
5. **Burg und digitales Leben:** mit Münzen ausbauen und einrichten.

**Ergänzungen, damit es zum Hype passt:**

- **Offline-Einkommen:** Helfer graben auch dann weiter, wenn der Spieler weg ist.
- **Mutationen auf seltenen Funden:** Der Reveal ist der Clip-Moment, und Mutationen machen Funde im Handel unterschiedlich wertvoll.
- **Tägliche Quests und wöchentliche Events:** Sie sorgen für Rückkehr; der Empfehlungsalgorithmus misst seit April 2026 über 28 Tage.
- **Freunde:** Roblox-Freunde besuchen die Burg und graben mit. Das ist die günstigste soziale Ebene.
- **Handelswelt als Update 1** mit strengen Schutzregeln, Burg-Ausbau als Update 2 (Begründung im Abschnitt Roadmap).

**Warum das zum Hype passt** (Recherche vom 7. Oktober 2026, Zahlen von Drittanbieter-Trackern; zu Kampf und PvP wurde nicht recherchiert):

| Hype-Treiber | Beleg aus der Recherche | Umsetzung in Glimmer Deep |
| --- | --- | --- |
| Sammeln mit Seltenheit und Mutationen | Grow a Garden, Fish It!, Steal An Egg | Seltene Funde in der Höhle mit Seltenheit und Mutation |
| Offline-Einkommen | Sell Lemons (Peak 229K im Juli 2026) | Helfer arbeiten in der Höhle weiter |
| Twist beim Graben | Dig & Clean (Peak 118.4K bis 270K, Quellen widersprechen sich): reinigen und im Museum ausstellen | Museum, Handelswelt und Burg als Langzeitziel; Höhle, die durch das Graben wächst |
| Soziale Ebene und Wohnen | Roleplay-Evergreens wie Brookhaven RP (etwa 205K) und Adopt Me! (etwa 137K), Koop bei 99 Nights in the Forest | Freunde graben mit, Burg-Ausbau, Handelswelt als Treffpunkt |
| Wöchentliche Events | 99 Nights, Grow a Garden | Event-Mutationen, Zonen-Events in der Oberwelt |
| Rückkehr statt Launch-Spike | Neuer Empfehlungsalgorithmus mit 28-Tage-Fenster (DevForum, 15. Juni 2026) | Quests, Offline-Helfer, Truhen- und Erz-Nachwuchs, Stände mit Laufzeit |

**Bewusst nicht enthalten:** Brainrot-Memes und **Item-Diebstahl im PvP** (Beute-Stehlen). Solche Hits verlieren binnen 1 bis 3 Monaten den Großteil ihrer Spitze, und Roblox schränkte am 29. August 2026 sogenannte Brainrot-Scroll-Spiele ein. Das PvP ist ein sportlicher Kampf in Zonen nach Stärke: Wer verliert, verliert keine Items und kein Geld.

**Ehrliche Erwartung:** Reine Dig-Spiele haben eine niedrige Decke: Das beste Dig-Spiel 2026, Dig & Clean, liegt jetzt bei etwa 2.0K bis 2.5K Spielern. Die Wette dieses Konzepts ist, dass Besitz, Ausrüstung, Kampf und Handel länger binden. Dafür gibt es in der Recherche keinen direkten Beleg. Das Konzept ist größer geworden: Mining, Kampf und Markt sind drei Spielarten in einem. Für eine Person ist es nur in Stufen machbar (siehe Roadmap). Das Ziel bleibt ein stabiler Sockel an Rückkehrern, kein Viral-Spike.

## Weltaufbau

| Ort | Wer darf hinein | PvP | Zweck |
| --- | --- | --- | --- |
| **Burg** (mit Höhle in der Mitte) | nur der Besitzer, auf Einladung Roblox-Freunde | nein | Basis: Höhleneingang, Verkaufsstand, Schmiede, Alchemietisch, Museum, Portale |
| **Höhle** (in der Burgmitte) | wie die Burg | nein | graben, Erz und Kräuter, Truhen, Biome |
| **Oberwelt** | alle Spieler, über ein Portal aus der Burg | **ja**, in Stufenzonen | Kräuter und Material, Zonen-Events, Kopfgeld |
| **Handelswelt** (zweiter Place, ab Update 1) | alle Spieler, über ein Portal aus der Burg | nein | Stände, Käufer und Verkäufer |

Ablauf: Man startet in der Burg, geht in die Höhle, gräbt, kommt zurück, verkauft am Stand, schmiedet und stellt aus. Wer kämpfen will, geht durch das Portal in die Oberwelt, wer handeln will, durch das Portal in die Handelswelt. Beide Portale stehen in der Burg und sind darum sicher erreichbar.

## Core Loop und Spielmodi

Die Basis-Schleife läuft in der Höhle: Blöcke abbauen, Erz und Kräuter einsammeln, Rucksack füllen, zurück zur Burg, verkaufen, aufrüsten. Seltene Funde zweigen ab ins Museum und, ab Update 1, in die Handelswelt. Erze wandern zusätzlich in die Schmiede und werden zu Rüstung und Waffen. Mit der Ausrüstung wird die Höhle schneller und die Oberwelt machbarer. Die Münzen aus Verkauf, Handel und Kopfgeld fließen zurück in Werkzeuge, Ausbau und Ausrüstung. So hat der Spieler kurzfristig ein Upgrade vor Augen und langfristig eine Sammlung, eine Rüstung, einen Markt und eine Burg.

## Spielsysteme

Alle Zahlen sind Startwerte zum Balancen im Test, keine geprüften Werte.

**1. Burg.** Jeder Spieler bekommt beim Beitreten eine eigene Burg auf einem Grundstück. Kein anderer Spieler kann sie betreten; Roblox-Freunde dürfen nur auf Einladung kommen (siehe Abschnitt 13). In der Mitte der Burg liegt der Höhleneingang. In der Burg stehen außerdem der Verkaufsstand (verkauft automatisch beim Betreten), die Schmiede, der Alchemietisch, das Museum und die Portale in Oberwelt und Handelswelt.

**2. Höhle und Graben.** Die Höhle ist ein stetiges Gefälle nach unten, das mit der Zeit von deinen Hieben gebaut wird. Die Tiefe in Metern ist der sichtbare Fortschritt und ein Clip-Motiv.

- **Aufbau:** Die Höhle besteht aus Würfel-Blöcken (Startwert 4 Studs). Gestein verschwindet beim Abbau ohne Beute, Erze, Kräuter und Truhen geben Beute. Wer Erz erreichen will, muss das Gestein davor abbauen.
- **Platz zum Graben:** Der Spielbereich hat einen Radius von 6 Blöcken seitlich der Mittellinie (Breite 13) und eine Höhe von 6 Blöcken. Er ist nach den Seiten begrenzt: Die Grenze wächst mit der Spitzhacke bis auf 12 Blöcke (Breite 25). Geradeaus nach unten geht es, solange man gräbt.
- **Hieb:** Ein Hieb schlägt eine Fläche vor dem Spieler ab. Je besser die Spitzhacke, desto größer die Fläche (Startwerte: Stufe 1 und 2 ein Block, 3 und 4 zwei mal zwei, 5 und 6 drei mal drei, 7 und 8 vier mal vier, 9 und 10 fünf mal fünf) und desto kürzer die Abklingzeit.
- **Auto-Graben:** Eine kaufbare Funktion, die im Takt der Abklingzeit weiterschlägt, solange der Spieler vor der Wand steht und der Rucksack nicht voll ist. Erspielbar ab Spitzhacken-Stufe 3 für 5.000 Münzen, als Komfort auch als Game Pass ab Start (siehe Monetarisierung).
- **Rucksack:** Jedes Erz, Kraut und Fund belegt einen Platz. Ist der Rucksack voll, geht es zur Burg zurück, dort wird verkauft. Der Rucksack füllt sich anfangs in etwa 30 bis 45 Sekunden (Ziel zum Balancen, abhängig von der Erzdichte).
- **Speicherung:** Die Höhle wird als Seed plus komprimierte Liste der abgebauten Blöcke je Abschnitt gespeichert, mit Obergrenze für die Höhlengröße. Alles andere (Erze, Kräuter, Truhen) wird aus dem Seed berechnet.

**3. Erze, seltene Funde und Mutationen.** Erze und Kräuter sitzen an den Wänden. Etwa 30 % der Wandblöcke sind Erzadern oder Kräuter (Startwert; Ziel ist, dass sich der Rucksack in der genannten Zeit füllt). Etwa 1 von 50 Erzadern ist eine **Fundstelle** (schimmernd) mit einem seltenen Fund wie Fossil, Artefakt oder Edelstein, mit Seltenheit und möglicher Mutation. Der Reveal (Aufleuchten, Sound, Einblendung) ist bewusst ein Clip-Moment.

| Seltenheit | Startwert Chance | Mindestwert beim NPC (Münzen) |
| --- | --- | --- |
| Gewöhnlich | 60 % | 10 |
| Selten | 25 % | 50 |
| Episch | 10 % | 250 |
| Legendär | 4 % | 2,000 |
| Mythisch | 1 % | 20,000 |

Mutationen (zum Beispiel Glühend, Golden, Eisig, Schimmernd) haben eine Basischance von 5 % und multiplizieren den Wert mit 2 bis 10. Glückswerte von Fähigkeiten, Haustieren, Tränken und Boostern erhöhen die Chancen. Alle Chancen stehen im Spiel sichtbar in einem Infofenster. Der NPC-Mindestwert ist eine Untergrenze: Ein Fund lässt sich immer zu diesem Preis verkaufen, auch wenn der Markt leer ist.

**Nachwuchs:** Erze und Kräuter an den Wänden wachsen nach (Startwert: ein abgebauter Wandblock nach 10 Minuten). Der Nachwuchs wird beim Betreten und beim Näherkommen berechnet, es gibt keine Hintergrund-Timer.

**4. Truhen.** In der Höhle liegen versteckte Truhen (hinter Gestein, in Nischen). Sie erscheinen zufällig neu (Startwert: eine Truhe nach 6 Stunden, mit einer Obergrenze je Höhlenabschnitt). Inhalt: Waffen und Rüstungsteile (Stufe des Bioms oder eine höher), Tränke, Kräuter, seltene Funde, Münzen. Die Chancen stehen als Prozent im Infofenster. Truhen und Schlüssel gibt es nie gegen Robux. Ausrüstung aus Truhen hat dieselben Werte wie geschmiedete Ausrüstung der gleichen Stufe.

**5. Werkzeuge und Fähigkeiten.**

| Kategorie | Beispiele | Wirkung |
| --- | --- | --- |
| Spitzhacke | 10 Stufen von Holz bis Kristall; später weitere Werkzeuge (Hacke, Bohrer) | Fläche pro Hieb, Abklingzeit, Grenze des Spielbereichs |
| Rucksack | Mehrere Größen | Fassungsvermögen pro Gang |
| Fähigkeiten | Starke Arme, Erzspürer, Seilwinde, Lampe | Tempo, Anteil seltener Funde, Laufgeschwindigkeit, Glück |
| Helfer | Mehrere Stufen | Graben offline weiter |
| Auto-Graben | einmalige Freischaltung | Hieb im Takt |

Spitzhacken-Stufe 2 kostet etwa 100 Münzen, Stufe 10 etwa 1,000,000 Münzen; die Schritte sind 3-mal bis 3,3-mal teurer als die vorherige Stufe.

**6. Schmiede, Rüstung und Waffen.** In der Schmiede der Burg werden aus Erzen Barren und daraus Rüstung und Waffen im Mittelalter-Stil. Je besser das Erz, desto besser die Ausrüstung.

- **Plätze:** Waffe, Helm, Brustpanzer, Beinschutz, Stiefel.
- **Waffen zum Start:** Schwert (Nahkampf). Weitere (Axt, Bogen) später.
- **Stufen** (nach dem Erz): Kupfer, Eisen, Silber, Gold, Kristall zum Launch; Obsidian, Rubin, Saphir und Leuchtstahl mit den späteren Biomen.
- **Keine Haltbarkeit:** Ausrüstung geht nicht kaputt und kostet keine Reparatur.

| Stufe | Leben (komplette Rüstung) | Schaden pro Hieb (Schwert) |
| --- | --- | --- |
| Start (Stoff, Holz) | 100 | 10 |
| 1 Kupfer | 130 | 14 |
| 2 Eisen | 170 | 19 |
| 3 Silber | 220 | 26 |
| 4 Gold | 280 | 35 |
| 5 Kristall | 350 | 46 |

Die Zahlen sind Platzhalter (Wachstum etwa ×1,3 je Stufe). Rezepte, Barrenkosten und Münzpreise kommen in die Config.

**7. Tränke.** Am Alchemietisch der Burg braut man aus Kräutern der Biome verschiedene Tränke. Zum Start: Heiltrank (Leben), Stärketrank (Schaden), Tempotrank (Grab- und Lauftempo), Nachtsichttrank (Sicht in tiefen Biomen), Glückstrank (Fundchance und Mutationschance, wirkt wie ein Glückswert). Jedes Biom hat eigene Kräuter. Tränke wirken kurz (Startwert 5 Minuten), sind handelbar und gibt es nicht gegen Robux. Im PvP sind Tränke erlaubt, damit sich der Aufwand lohnt; ihre Wirkungsdauer und Stärke stehen in der Config.

**8. Oberwelt und Kampf.** Verlässt man die Burg durch das Portal, landet man in der Oberwelt. Hier ist PvP erlaubt.

- **Stufenzonen:** Die Oberwelt ist in Zonen nach Kampfstärke geteilt (zum Launch eine bis drei). Die Kampfstärke ergibt sich aus Leben und Schaden der Ausrüstung. Das Portal bietet die passende Zone an; wer deutlich über der Obergrenze einer Zone liegt, kommt nicht hinein (Schutz für Neulinge). Die genauen Grenzen stehen in der Config.
- **Neulingsschutz:** Das Portal ist erst nach dem Onboarding nutzbar und nur mit mindestens einem Rüstungsteil und einer Waffe. Vor dem ersten Betreten erscheint ein kurzer Hinweis, dass dort gekämpft wird. Nach dem Respawn gilt ein kurzer Spawnschutz.
- **Tod:** Kein Verlust von Items oder Münzen. Der Besiegte erscheint nach wenigen Sekunden wieder in der Burg.
- **Kopfgeld:** Wer einen Spieler besiegt, bekommt Münzen. Die Münzen schafft das System, sie werden dem Besiegten nicht abgezogen (Startwert Zone 1: 50 Münzen). Gegen Missbrauch (Zweitkonten, Absprachen): pro Besiegtem nur alle 10 Minuten eine Belohnung, Tageslimit, keine Belohnung bei Spawnschutz oder wenn der Besiegte weniger als halb so stark ist.
- **Warum in die Oberwelt:** Kopfgeld, besondere Kräuter und Material, Zonen-Events, später Bosse. Wer nicht kämpfen will, kommt in der Höhle trotzdem voran, aber ohne diese Extras.
- **Gegner (PvE):** Zum Launch keine. Gegner in tieferen Biomen und Bosse sind spätere Erweiterungen (siehe Koop-Expedition).
- **Technik:** Treffer, Schaden und Leben entscheidet der Server (siehe Technik).

**9. Offline-Helfer.** Helfer (Arbeitstitel „Zwerge“) graben in der Höhle weiter, bis zu 4 Stunden, mit dem Pass „Nachtschicht“ bis zu 8 Stunden. Beim nächsten Betreten zeigt „Während du weg warst“ Erz im Lager und gelegentlich einen seltenen Fund mit niedrigerer Chance als beim aktiven Graben. Die Höhle selbst wächst offline nicht. Haustiere aus Fossil-Eiern (offengelegte Quoten, Mindestgarantie) geben zusätzlich Boni auf Tempo, Glück oder Offline-Ertrag.

**10. Museum.** Seltene Funde stellt der Spieler in Vitrinen der Burg aus:

- Vollständige Sets pro Biom geben dauerhafte Boni auf Einnahmen und Glück.
- Besucher-NPCs bringen passiv Eintrittsgeld.
- Roblox-Freunde, die eingeladen sind, können das Museum besuchen und mit einem Daumen bewundern, ohne etwas zu verändern oder zu stehlen.
- Eine Wochenliste zeigt die am meisten bewunderten Museen (auf Freunde und den Server begrenzt, solange keine fremden Besucher kommen). Die Bestenliste nach Sammlungsvielfalt wertet Sets, nicht Ausgaben.

**11. Handelswelt (Update 1).** Über ein Portal aus der Burg erreicht man eine zweite Welt. Dort hat jeder Spieler einen eigenen Stand, in den er Items stellt und für Münzen verkauft.

- **Treuhand:** Beim Einstellen wird das Item aus dem Inventar genommen und beim Angebot gesperrt. Verkäufe laufen auch, wenn der Besitzer offline ist; die Münzen kommen beim nächsten Betreten oder beim Abholen an den Stand.
- **Preise:** Freie Preise innerhalb von Grenzen je Seltenheit (Untergrenze: NPC-Mindestwert). Anzeige der letzten Verkaufspreise je Item.
- **Gebühr:** 5 bis 10 % pro Verkauf (Startwert) als Münzsenke. Höchstens 10 Angebote pro Spieler (mit Pass 15).
- **Handelbar:** Erze, Funde, Kräuter, Tränke, und **Rüstung und Waffen, wenn sie erspielt oder gefunden sind** (geschmiedet oder aus Truhen). Nicht handelbar: alles, was mit Robux gekauft wurde, Game Passes, Developer Products, Eier-Haustiere und Ausrüstung aus Robux-Paketen.
- **Eindeutige IDs:** Jedes handelbare Item hat eine eindeutige ID; Abwicklung nur serverseitig, damit nichts dupliziert werden kann.
- **Sicherheit:** Kein PvP in der Handelswelt. Chat nur nach Roblox-Standard (Altersfilter), kein eigener Chat. Prüfprotokoll für verdächtige Käufe, Ratenlimits.
- **PolicyService:** Vor jeder Aktion prüft der Server, ob der Spieler Handel mit gekauften Items nutzen darf; falls nicht, ist die Handelswelt für ihn gesperrt.
- **Keine Chancenspiele** mit handelbaren Items (kein Einsatz, kein Münzwurf); Käufe sind deterministisch.
- **Suche:** Eine serverübergreifende Angebotsliste mit Suche, damit man nicht jeden Stand ablaufen muss. Die Stände sind die sichtbare Darstellung.

Der Handel zwischen Spielern ist auf Roblox möglich, aber an Bedingungen geknüpft. Die Prüfung vom 7. Oktober 2026 steht im Abschnitt „Roblox-Regeln“.

**12. Burg-Ausbau.** Mit Münzen baut der Spieler seine Burg in Stufen aus. Die Burg ist zugleich das Museum und der Ort zum Einrichten.

| Stufe | Name | Inhalt | Startpreis (Münzen) |
| --- | --- | --- | --- |
| 1 | Wachhaus | Museumsraum mit 4 Vitrinen, Höhleneingang, Schmiede, Alchemietisch | Start |
| 2 | Burghof | 12 Vitrinen, Platz für Dekoration | 10,000 |
| 3 | Festung | 30 Vitrinen, Gästeterrasse, mehr Deko-Slots | 250,000 |
| 4 | Königsburg | 60 Vitrinen, Sammler-Titel, eigener Schaufensterplatz | 5,000,000 |

Möbel und Deko lassen sich mit Münzen kaufen, kosmetische Pakete zusätzlich mit Robux. Zum Launch genügt Stufe 1 bis 2; der volle Ausbau kommt als Update 2.

**13. Freunde und gemeinsames Graben.** Roblox-Freunde des Besitzers dürfen die Burg betreten und in der Höhle mitgraben (bis zu 4 Gäste), aber nur in Biomen, die sie selbst schon freigeschaltet haben (größte eigene Tiefe). Jeder Gast behält sein eigenes Erz, der Gastgeber erhält einen kleinen Bonus. Fremde kommen nie in die Burg. Das ist ohne aufwendigen Koop-Modus eine soziale Ebene und ein Grund, Freunde einzuladen.

**14. Rebirth „Neue Bohrung“.** Nach Erreichen des tiefsten Bioms kann der Spieler eine neue Höhle beginnen. Münzen, Spitzhacke, Fähigkeiten, Tiefe und die Höhle werden zurückgesetzt. Burg, Museum, Haustiere, Eier, Ausrüstung und Tränke bleiben. Dafür gibt es Prestige-Punkte für dauerhafte Boni. So bleibt auch nach Wochen ein Ziel.

**15. Koop-Expedition „Deep Dive“ (optional, Update 3).** Der Koop-Modus bleibt im Konzept und kommt als späterer Modus: 1 bis 4 Spieler graben in einer 8 bis 10 Minuten langen Runde gemeinsam in Umweltgefahren (Gas, Einsturz, Flut), ein Aufzug entscheidet über die Beute. Hier können später auch Gegner (PvE) und Bosse ihren Platz finden. Gebaut wird er, sobald Burg, Höhle, Oberwelt und Shop stabil laufen.

## Biome und Progression

Die Höhle führt durch sechs Biome; zum Launch sind drei enthalten, die übrigen kommen als Updates und liefern den wöchentlichen Update-Rhythmus. Tiefen sind Startwerte (Tiefe = Weg entlang des Gefälles in Metern). Die Namen sind Vorschläge.

| Biom | Tiefe | Erze | Kräuter (Beispiele) | Seltene Funde | Zum Launch |
| --- | --- | --- | --- | --- | --- |
| 1 Kellergewölbe | 0 bis 50 m | Kohle, Kupfer | Moosfarn | Tonscherben, alte Münzen | ja |
| 2 Verlies | 50 bis 150 m | Eisen, Silber | Schattenpilz | Fossilien, Bernstein | ja |
| 3 Kristallgrotte | 150 bis 300 m | Gold, Kristalle | Glimmerblume | Edelsteine | ja |
| 4 Schmelzkammern | 300 bis 500 m | Obsidian, Rubin | Glutwurz | Feuersteine | Update |
| 5 Frostkluft | 500 bis 750 m | Eis-Erz, Saphir | Eisblüte | Eisfossilien | Update |
| 6 Leuchtende Tiefe | ab 750 m | Leuchterz | Leuchtmoos | Mythische Relikte | Update |

**Wirtschaft (Startwerte):**

- Ein Rucksack füllt sich anfangs in etwa 30 bis 45 Sekunden; der Weg zur Burg und zurück soll nie länger als etwa 10 Sekunden dauern.
- Ein Biom ist nach etwa 1 bis 3 Stunden Spielzeit durchgegraben.
- Ein vollständiges Biom-Set im Museum gibt zum Beispiel +10 % Einnahmen.
- Alles, was es gegen Robux gibt, lässt sich auch erspielen, nur langsamer (mit der Ausnahme „Ausrüstungspakete“, siehe Monetarisierung).

**Wirtschaftsregeln:** Münzen sind nicht verschenkbar. Handel läuft nur über die Handelswelt. Münzsenken sind die Handelsgebühr und die Ausbaukosten für Werkzeuge, Burg, Dekoration und Schmiede. Münzquellen sind Verkauf an den NPC, Handel und Kopfgeld. Direkte Münzpakete gegen Robux gibt es nicht, solange es eine Handelswelt gibt, weil sonst Robux gegen seltene Funde getauscht würden (siehe Monetarisierung).

## Onboarding: die ersten 10 Minuten

Die ersten 10 Minuten entscheiden über die Rückkehr am nächsten Tag; das Ziel ist ein Reveal in der ersten Minute und ein Grund, morgen wiederzukommen.

| Minute | Was passiert | Ziel |
| --- | --- | --- |
| 0 bis 1 | Spieler steht in seiner Burg, ein Pfeil zeigt auf den Höhleneingang in der Mitte; erster Hieb, erster Block | Sofort Spielgefühl, kein Text-Tutorial |
| 1 bis 2 | Garantierter erster seltener Fund mit Mutation (golden), großer Reveal mit Sound | Clip-Moment und Sammelreiz |
| 2 bis 4 | Rucksack füllt sich, zurück zur Burg, erster Verkauf am Stand | Schleife verstehen |
| 4 bis 6 | Erstes Upgrade (bessere Spitzhacke), die Höhle wird sichtbar größer und tiefer | Spürbarer Fortschritt |
| 6 bis 8 | Museumsraum öffnet, erster Fund kommt in die Vitrine | Sammelziel sehen |
| 8 bis 10 | Hinweis: „Deine Helfer arbeiten weiter, auch wenn du gehst“; erste tägliche Quests; Einladung an Freunde zum Mitgraben | Grund zur Rückkehr und zum Einladen |

**Regeln:** Keine Kaufangebote in den ersten 10 Minuten. Schmiede, Alchemietisch, Oberwelt-Portal und Handelswelt erscheinen erst, wenn der Spieler sie braucht (nach dem Onboarding, mehrere Funde bzw. erste Erze), und werden mit einer kurzen Erklärung eingeführt. Das Oberwelt-Portal braucht zusätzlich Ausrüstung und einen PvP-Hinweis. Kein erzwungener Chat, keine langen Texte; Anleitungen laufen über Pfeile, Highlights und kurze Sprechblasen. Das Menü ist auf dem Handy mit dem Daumen erreichbar.

## Retention und Live-Ops

Der Empfehlungsalgorithmus misst seit April 2026 Rückkehr, gemeinsames Spielen und Ausgaben über 28 Tage (Roblox DevForum, 15. Juni 2026). Das Spiel ist deshalb auf viele kurze Rückkehr-Anlässe gebaut statt auf lange Einzelsitzungen.

**Tägliche Schleife:**

- 3 tägliche Quests (zum Beispiel „Rucksack 3-mal füllen“, „1 Mutation finden“, „1 Vitrine füllen“, später „1 Trank brauen“).
- 7-Tage-Login-Kette; bei Ausfall wird sie nicht auf null gesetzt, sondern um einen Tag zurückgestuft.
- Rotierender Shop mit kosmetischen Burg-Dekos und Haustier-Eiern, alle 4 Stunden neu.
- Offline-Helfer arbeiten bis zu 4 Stunden weiter; beim Betreten wartet das Ergebnis.
- Nachwachsende Erze, Kräuter und Truhen holen zurück in die Höhle.
- Laufende Stände in der Handelswelt (ab Update 1) holen Verkäufer und Käufer zurück.

**Wöchentliche Schleife:** Jede Woche startet ein Event mit einer zeitlich begrenzten Mutation, einem Event-Fund-Set für das Museum, einem Zonen-Event in der Oberwelt und, ab Update 1, einem Event-Angebot an den Ständen mit begrenzten Funden. Alles ist ohne Kauf erspielbar.

**Saison (4 Wochen):** Ein „Entdecker-Pass“ mit Gratis-Track und Premium-Track (zusätzliche kosmetische Belohnungen und kleine Boni), neues Biom oder neue Funde als Saisonthema.

**Beispiel-Event-Kalender nach Launch:**

| Woche | Event | Neue Inhalte |
| --- | --- | --- |
| 1 | Eröffnung | Launch-Mutation „Golden“ garantiert beim ersten seltenen Fund |
| 2 | Glühwoche | Mutation „Glühend“ mit höherer Chance, Set „Leuchtsteine“ |
| 3 | Freunde-Woche | Doppelte Gastgeber-Münzen, wenn Freunde mitgraben |
| 4 | Saisonfinale | Neues Biom 4 (Schmelzkammern), Saison 2 startet |

Die Themen lassen sich an Jahreszeiten anpassen (zum Beispiel Halloween oder Winter). Wöchentliche Updates und Events sind laut Recherche ein gemeinsames Merkmal der erfolgreichen Spiele.

## Monetarisierung

Geld kommt über Game Passes (einmalig), Developer Products (wiederholbar), einen Saison-Pass und Premium Payouts. Die wichtigste Regel: Mit Robux darf man keine seltenen, handelbaren Funde und keine handelbare Ausrüstung direkt kaufen, sonst wird die Handelswelt zum Tauschmarkt Robux gegen Funde und Macht. Preise sind Startwerte für A/B-Tests; für Preise im Genre fand die Recherche keine verlässlichen Listen.

| Item | Typ | Preis (Robux) | Effekt | Fairness-Regel |
| --- | --- | --- | --- | --- |
| Nachtschicht | Game Pass | 299 | Offline-Helfer 8 statt 4 Stunden | Ohne Pass nur langsamer, nichts gesperrt |
| Doppelte Münzen | Game Pass | 399 | 2x Münzen beim Erzverkauf an den NPC | Wirkt nicht auf Funde, Handel und Kopfgeld |
| Schnellreise | Game Pass | 199 | Sofort zwischen Burg und Abbaustelle | Bequemlichkeit |
| Rucksack Plus | Game Pass | 249 | 20 % mehr Fassungsvermögen | Auch ohne Pass erspielbar |
| Auto-Graben ab Start | Game Pass | 249 (Startwert) | Auto-Graben ohne Freischaltung durch Münzen | Auto-Graben bleibt erspielbar |
| Standplätze | Game Pass | 199 | 15 statt 10 Angebote (ab Update 1) | Kein Einfluss auf Preise oder Chancen |
| Zweites Haustier | Game Pass | 199 | Zwei Helfertiere gleichzeitig | Ein Slot genügt zum Durchspielen |
| Burg-Deko-Paket | Game Pass | 149 | Zusätzliche Möbel- und Vitrinenstile | Rein kosmetisch |
| Rüstungs- und Waffen-Skins | Game Pass oder Developer Product | offen | Nur das Aussehen | Rein kosmetisch, keine Werte |
| Entdecker-Pass (Saison) | Game Pass pro Saison | 399 | Premium-Track mit Kosmetik und kleinen Boni | Gratis-Track bleibt voll nutzbar |
| Glücks-Booster (15 Minuten) | Developer Product | 39 | Höhere Mutationschance | Zählt als bezahltes Zufallsobjekt: Wirkung vor dem Kauf anzeigen, für eingeschränkte Spieler ausblenden und dort erspielbar machen |
| Tempo-Booster (30 Minuten) | Developer Product | 49 | 2x Grabtempo | Wirkt nur für den Käufer und nur beim Graben, nicht im PvP |
| Fossil-Ei | Developer Product | 99 | Zufälliges Haustier, nicht handelbar | Wahrscheinlichkeiten sichtbar, Mindestgarantie nach X Eiern, für eingeschränkte Spieler erspielbar statt kaufbar |
| Ausrüstungspaket | Developer Product oder Game Pass | offen | Ausrüstung bis zu einer mittleren Stufe | Siehe unten „Gesunder Rahmen“; Preise noch offen |

**Bewusst nicht im Shop:** Münzpakete gegen Robux, handelbare Funde gegen Robux, Tränke gegen Robux (Heil- und Stärketränke gäben im PvP einen Vorteil) und Truhen oder Schlüssel. Außerdem bietet Roblox keinen Handel von Game Passes oder Developer Products an (siehe Abschnitt „Roblox-Regeln zum Handel“).

**Ausrüstung gegen Robux, „in einem gesunden Rahmen“ (bestätigt am 10. Oktober 2026):**

1. Ausrüstung aus Robux-Paketen ist **kontogebunden und nicht handelbar**. Sonst würde die Handelswelt Robux in Macht verwandeln.
2. Sie reicht höchstens bis zu einer **mittleren Stufe** (Startwert: Silber) und hat dieselben Werte wie erspielbare Ausrüstung dieser Stufe, nie bessere.
3. Die Stufenzonen im PvP begrenzen den Vorsprung zusätzlich: Wer gekauft hat, kommt nicht weiter nach oben als jemand mit erspielter Ausrüstung gleicher Stärke.
4. Alles darüber ist nur erspielbar.
5. Kosmetik (Skins) ist unbegrenzt kaufbar und ändert keine Werte.

**Premium Payouts:** Spieler mit Roblox Premium bringen Auszahlungen nach Spielzeit; das Design setzt auf Rückkehr statt Kaufdruck. Zusätzlich gibt es einen kleinen kosmetischen Vorteil (Namensplakette im Museum). Zu Höhe und Verteilung der Premium Payouts lieferte die Recherche keine Daten.

**Umrechnung in echtes Geld:** Der Standard-DevEx-Satz beträgt laut Creator-Dokumentation $0.0038 pro Robux (seit 5. September 2025); für qualifizierende Ausgaben von altersgeprüften US-Spielern ab 18 gilt seit 8. Juni 2026 etwa $0.0054. Die Plattformgebühr und die aktuellen Bedingungen vor dem Start in der offiziellen Dokumentation prüfen; der Median der DevEx-Teilnehmer liegt laut Berichten bei etwa $1,500 pro Jahr.

**Fairness-Regeln:**

1. Keine Kaufangebote in den ersten 10 Minuten und keine Pop-ups mitten im Grabvorgang oder im Kampf.
2. Alle Zufallsobjekte (Eier, Booster) zeigen exakte Wahrscheinlichkeiten, und eingeschränkte Nutzer erhalten einen Alternativweg, wie es Roblox verlangt.
3. Die Handelswelt läuft nur mit Spielmünzen und ist für Spieler gesperrt, bei denen PolicyService den Handel gekaufter Items nicht erlaubt; Game Passes, Developer Products, Eier-Haustiere und Robux-Ausrüstung sind nicht handelbar.
4. Kein Pay-to-win in Bestenlisten und im PvP: Robux-Ausrüstung hat nie bessere Werte als erspielte und ist nicht handelbar; Tränke gibt es nicht gegen Robux; Tempo-Booster wirken nicht im Kampf.
5. Preis, Wirkung und Dauer stehen vor dem Kauf im Shop; Käufe brauchen eine bewusste Bestätigung. Kauftexte bleiben neutral („Angebot ansehen“, „Shop öffnen“) statt drängend („Jetzt kaufen, letzte Chance“), weil Roblox das bei jungen Spielern nicht will.

## Roblox-Regeln zum Handel (geprüft am 7. Oktober 2026)

Eine Handelswelt ist auf Roblox möglich, wenn der Handel pro Spieler per PolicyService geprüft wird und nichts handelbar ist, was direkt mit Robux gekauft wurde. Das Konzept bleibt deshalb bestehen und wurde um diese Bedingungen ergänzt. Das ist keine Rechtsberatung, und Roblox kann seine Regeln ändern. Die Prüfung stammt vom 7. Oktober 2026 und bezog sich auf Handel und Zufallsobjekte, **nicht auf PvP und Gewaltdarstellung**.

| Regel | Quelle | Folge für Glimmer Deep |
| --- | --- | --- |
| Handel mit gekauften Items ist per PolicyService einzuschränken. Wer nicht handeln darf, darf auch das Ergebnis eines bezahlten Zufallsobjekts oder andere bezahlte Items nicht handeln. | Community Standards, Creator Docs zu bezahlten Zufallsobjekten | Die Handelswelt wird pro Spieler per PolicyService (IsPaidItemTradingAllowed) geprüft; ist Handel nicht erlaubt, ist sie für diesen Spieler komplett gesperrt. |
| Bezahlte Zufallsobjekte (Eier, Kapseln, Luck-Boosts, Pity-Systeme, auch über mit Robux gekaufte Spielwährung) brauchen exakte Wahrscheinlichkeiten in Prozent, die sich auf 100 % summieren. Eingeschränkte Spieler (laut Ankündigung vom 26. Mai 2026 unter anderem Australien, Belgien, Niederlande, Vereinigtes Königreich, Brasilien) brauchen eine Alternative. Es darf kein Ergebnis geben, bei dem man nur verliert. Verstöße können zur Entfernung des Spiels und zur Kontosperre führen. | Creator Docs, DevForum-Ankündigung vom 26. Mai 2026 | Fossil-Ei und Glücks-Booster zeigen alle Chancen und Boost-Wirkungen, werden über ArePaidRandomItemsRestricted für betroffene Spieler ausgeblendet und sind dort erspielbar; jedes Ei gibt immer ein Haustier. Truhen und Tränke sind nie gegen Robux kaufbar. |
| Roblox bietet keinen Handel für Game Passes oder Developer Products. Wer sie gegen Spielgegenstände tauscht, umgeht das offizielle System (Moderationsrisiko laut Einschätzung des Thread-Autors). | DevForum, Antwort vom 10. Februar 2026 | Passes, Products, Robux-Ausrüstung und aus Robux-Eiern erhaltene Haustiere sind nicht handelbar und werden nicht gegen Funde getauscht oder „verschenkt“. |
| Glücksspiel ist verboten: Echtgeld, Robux oder Ingame-Items mit Wert dürfen nicht im Zusammenhang mit Glücksspiel getauscht werden. | Community Standards | Keine Chancenspiele mit handelbaren Items (kein Einsatz, kein Münzwurf); Gebote und Käufe sind deterministisch. |
| Handel mit Konten oder virtuellen Inhalten gegen Geld außerhalb der Plattform ist verboten. | Community Standards | Hinweis im Spiel; Preis-Ausreißer und Massenübertragungen werden protokolliert, Verdächtige gesperrt oder gemeldet. Handelbare Ausrüstung erhöht dieses Risiko. |
| Bei jungen Spielern keine drängenden Kauftexte wie „Jetzt kaufen“ oder „Letzte Chance“. | Roblox Help, Promoting Items to Younger Audiences (undatiert) | Shop- und Event-Texte bleiben neutral („Angebot ansehen“, „Shop öffnen“). |

**Nicht belegt:**

- Welche Länder beim Handel gesperrt sind, nennen die geöffneten Quellen nicht. Die Abfrage zur Laufzeit per PolicyService ist deshalb Pflicht.
- Die Bedeutung von IsPaidItemTradingAllowed stammt aus älteren Entwicklerforum-Beiträgen (2020 und 2022, von Community-Mitgliedern) und der Ankündigung vom 26. Mai 2026; die PolicyService-Seite der Creator Docs, die ich öffnen konnte, listete die Eigenschaft nicht.
- Für eine Handelswelt mit reinen Spielmünzen fand ich keine eigene Regel: Sie wird in den geöffneten Quellen weder verboten noch ausdrücklich erlaubt. Im Zweifel vor dem Bau im Entwicklerforum oder beim Roblox-Support nachfragen.
- **PvP und Gewaltdarstellung bei jungen Spielern:** nicht geprüft. Entscheidung des Entwicklers: normales Roblox-PvP ohne Blut. Vor dem Bau der Oberwelt und vor dem Launch die Community Standards und die Richtlinien zu Altersfreigaben und Inhaltsbeschreibungen lesen.

**Quellen (geöffnet am 7. Oktober 2026):**

- [Roblox Community Standards](https://about.roblox.com/community-standards)
- [Paid random items policy guidelines (Creator Docs)](https://create.roblox.com/docs/en-us/production/monetization/paid-random-items)
- [Clarifying Requirements for Paid Random Items (DevForum, 26. Mai 2026)](https://devforum.roblox.com/t/clarifying-requirements-for-paid-random-items/4654622)
- [Regarding Virtual Content Trading on Gamepasses (DevForum, Antwort vom 10. Februar 2026)](https://devforum.roblox.com/t/regarding-virtual-content-trading-on-gamepasses-for-in-game-content/4313006)
- [PolicyService Guidelines (DevForum, 2020)](https://devforum.roblox.com/t/policyservice-guidelines/773321)
- [Promoting Items to Younger Audiences (Roblox Help)](https://en.help.roblox.com/hc/en-us/articles/47965190783892-Promoting-Items-to-Younger-Audiences)

## Technik und Umsetzung mit Claude Code

Der Server hat die Autorität über Funde, Münzen, Mutationen, Käufe, Treffer, Schaden und Handel; der Client schickt nur Absichten. Die Umsetzung läuft mit Rojo, Git und Claude Code im Projektordner, Studio dient für Modelle, Terrain und UI-Layout. Studio hat seit April 2026 einen offiziellen eingebauten MCP-Server, der laut Creator-Dokumentation mit Claude Code nutzbar ist; Verfügbarkeit in deiner Studio-Version bitte in der aktuellen Dokumentation prüfen.

**Server-Dienste (Luau):**

| Dienst | Aufgabe |
| --- | --- |
| DataService | Spielerprofil mit ProfileStore laden und speichern (Münzen, Rucksack, Werkzeugstufen, Höhle, Ausrüstung, Tränke, Museum, Burg, Haustiere, Zeitstempel) |
| PlotService / CastleService | Burg zuweisen, Besuch nur für den Besitzer und eingeladene Freunde, Schmiede, Alchemietisch, Portale |
| CaveService | Höhle aus Seed und abgebauten Blöcken aufbauen, Erz- und Kräuter-Nachwuchs, Truhen, Biome, Abschnitte laden und entladen |
| DigService | Hieb (Fläche, Abklingzeit, Auto-Graben), Fundwurf (Seltenheit, Mutation), Rucksack füllen, Cooldowns und Tempo prüfen |
| OfflineService | Helfer-Ertrag aus Zeitstempeln berechnen, auf das Offline-Maximum begrenzen |
| CraftingService | Barren, Rüstung und Waffen herstellen, Rezepte prüfen |
| PotionService | Kräuter, Tränke brauen und Wirkung (Dauer auf Serverzeit) |
| CombatService | Treffer prüfen, Schaden und Leben, Zonen, Spawnschutz, Kopfgeld, Missbrauchsschutz |
| MuseumService | Vitrinen, Sets, Besucher-Einkommen, Bewunderungen |
| HouseService | Burg-Stufen, Möbel und Deko speichern und platzieren |
| TradeService (Handelswelt, ab Update 1) | Angebote serverübergreifend verwalten, Item sperren (Treuhand), Käufe und Gebühren abrechnen, PolicyService-Handelsprüfung |
| ShopService | Game Passes und Developer Products, ProcessReceipt, Idempotenz, PolicyService-Prüfung für Eier und Booster |
| QuestService | Tägliche Quests, Login-Kette, Event- und Saison-Fortschritt |

**Die Höhle speichern:** Die Höhle wird nicht als alle Blöcke gespeichert, sondern als Seed (Welt, Erze, Kräuter, Truhen sind daraus berechenbar) plus eine komprimierte Liste der vom Spieler abgebauten Blöcke je Abschnitt, mit Obergrenze für die Höhlengröße. Die sichtbare Form baut der Server daraus beim Betreten in Abschnitten wieder auf. Das hält Profile klein. Der Nachwuchs von Erzen und Truhen speichert nur den Zeitpunkt der letzten Ernte je Abschnitt und rechnet beim Laden nach.

**Höhle auf dem Handy:** Würfel-Blöcke (keine Terrain-Voxel), nur Abschnitte in Spielernähe geladen, Obergrenze für Teile pro Spieler, Blöcke im Abschnitt zu wenigen Meshes zusammengefasst, wo möglich. Der Server hält die Wahrheit, der Client bekommt Änderungen in Spielernähe. Fremde Höhlen werden nie geladen. Die Machbarkeit auf schwachen Handys muss früh in Studio gemessen werden.

**Offline-Einkommen:** Es laufen keine Timer im Hintergrund. Pro Helfer speichert der Server Startzeit und Stufe; beim Betreten rechnet er aus, wie viel fertig wurde, begrenzt auf das Offline-Maximum. Das ist exploit- und kostenarm.

**Kampf (PvP) technisch:**

- Treffer, Reichweite, Abklingzeit, Schaden und Leben entscheidet nur der Server. Der Client schickt „Ich schlage“ mit Blickrichtung, der Server prüft Position, Abstand und Takt.
- Werte kommen aus der Config und dem Profil, nie vom Client.
- PvP-Schaden ist serverseitig nur in der Oberwelt an. In Burg, Höhle und Handelswelt ist er aus.
- Schutz gegen Fliegen, Teleport und Geschwindigkeitscheats: Positions- und Geschwindigkeitsprüfung im Server, Ratenlimits, Logs für auffällige Spieler.
- Handy: Zielhilfe und große Angriffs-Taste. Latenz wird mit großzügigen Treffer-Fenstern aufgefangen.

**Handelswelt technisch (Update 1):**

- Zweiter Place im selben Spiel (TeleportService). Die Spiel-Server und die Handelswelt teilen sich Angebote über einen gemeinsamen Speicher.
- Beim Einstellen wird das Item aus dem Inventar entfernt und beim Angebot gesperrt (Treuhand); jedes Item hat eine eindeutige ID (`userId:id`).
- Gebote, Gebühren und Übergabe laufen in einer einzigen atomaren Aktualisierung des gemeinsamen Speichers, damit nichts doppelt verkauft oder dupliziert werden kann. Ob dafür DataStore mit UpdateAsync oder MemoryStore besser passt, ist vor Update 1 zu prüfen.
- Ratenlimits pro Spieler, Preisgrenzen je Seltenheit und ein Prüfprotokoll für verdächtige Käufe.
- Verkaufte Münzen werden beim nächsten Betreten oder Abholen gutgeschrieben.

**Exploit- und Betrugsschutz:**

- Alle Würfe (Seltenheit, Mutation, Truhen) und alle Preise nur serverseitig.
- Jeder RemoteEvent-Handler prüft Typ, Wertebereich und Cooldown.
- Käufe erst nach erfolgreichem Speichern bestätigen und doppelte Belege abfangen.
- Zeitwerte nur aus der Serverzeit.
- Kopfgeld: Missbrauchsschutz gegen Zweitkonten (Pro-Opfer-Sperre, Tageslimit, Stärke-Verhältnis).

**Mobile zuerst:** Viele Spieler nutzen das Handy, daher große Buttons, wenige Meldungen gleichzeitig, schlanke Modelle und Streaming für die Welt.

**CLAUDE.md-Kernregeln für das Projekt:** Luau strict mode; Spielwerte nur im Server; Käufe nur über MarketplaceService; neue Module immer mit Tests; vor jedem Commit StyLua, Selene und Tests ausführen.

**Arbeitsweise:** Pro Funktion erst eine kurze Spezifikation, dann Plan und Dateiliste von Claude Code, dann Tests zuerst für Würfe, Offline-Berechnung, Käufe, Kampfrechnung und später Handelsabrechnung, dann umsetzen, in Studio spielen und Fehler zurückgeben. Kleine Commits pro Funktion.

## Umbau des bestehenden Spiels

Der Launch-Umfang des Konzepts vom 7. Oktober ist schon gebaut (Profilversion 13): Grundstück mit Schacht, Graben, Verkauf, Upgrades, Museum, Offline-Bagger, Quests, Shop, Booster, Haustiere, Haus bis Stufe 2, Gäste, Rebirth, Events, Saison, Stadt mit 8 Grundstücken. Das neue Konzept ersetzt einen Teil davon. Ein Überblick (ausführliche Planung folgt pro Schritt):

| Bestehender Baustein | Schicksal im neuen Konzept |
| --- | --- |
| Fundwurf, Seltenheit, Mutationen (`DigRoll`), Fund-IDs | **bleibt**, wird pro Wand-Erzblock und Fundstelle gewürfelt |
| Rucksack, Verkauf am Stand (automatisch), Münzen, Upgrades | **bleibt**, Verkaufsstand steht in der Burg |
| Schaufel-Stufen, Abklingzeit | **wird Spitzhacke**, dazu Fläche pro Hieb und Spielbereich; „Reichweite“ in der alten Bedeutung (Abstand zum Schacht) entfällt |
| Schacht (Tiefe als Zahl) und Lochform | **wird ersetzt** durch die Höhle (Seed plus abgebaute Blöcke), Profil-Migration nötig |
| Schichten | **werden Biome** (Umbenennung, neue Funde, Kräuter) |
| Offline-Bagger | **bleibt**, wird zu Helfern (Arbeitstitel „Zwerge“) |
| Museum, Sets, Besucher-Einkommen | **bleibt**; Besuch nur durch Freunde, Bewundern/Wochenliste angepasst |
| Haus-Ausbau (Stufe 1 und 2), Dekoration | **bleibt**, wird Burg-Ausbau (Wachhaus, Burghof) |
| Gäste | **bleibt**, nur Roblox-Freunde (Burg ist sonst privat), nur bis zur eigenen größten Tiefe des Gastes |
| Stadt mit 8 Grundstücken, Straßen, Mauer | **bleibt** als Burgviertel mit Portalen; fremde Burgen sind nicht betretbar |
| Quests, Login-Kette, Events, Saison | **bleibt**, Inhalte um Truhen, Tränke, Oberwelt-Events ergänzen |
| Shop, Booster, Belege, Eier und Haustiere | **bleibt**, Pässe um Auto-Graben ergänzen |
| Rebirth „Neue Bohrung“ | **bleibt**, setzt zusätzlich die Höhle zurück |
| Auktionshaus (Update 1) | **entfällt**, ersetzt durch die Handelswelt |
| Neu zu bauen | Höhle, Erz-Nachwuchs, Truhen, Biome, Hieb-Fläche und Auto-Graben, Schmiede, Rüstung/Waffen, Tränke und Kräuter, Oberwelt mit Zonen und PvP, Kopfgeld, Handelswelt |

## Roadmap

Das alte Zeitgerüst (4 Phasen, 12 Wochen) gilt nicht mehr. Eine neue Schätzung gibt es erst nach dem ersten Umbau-Schritt. Eine Phase endet erst, wenn ihr Gate erfüllt ist. Die Reihenfolge ist bestätigt (Launch mit Oberwelt und PvP).

| Phase | Inhalt | Gate |
| --- | --- | --- |
| U1 Burg und Höhle | Höhle statt Schacht, Hieb-Fläche, Wandadern, Erz-Nachwuchs, Truhen, Biome, Profil-Migration, Handy-Messung | Höhle läuft in Studio auf einem Handy flüssig, Speichern und Laden stimmen |
| U2 Ausrüstung | Schmiede, Rüstung und Waffen, Kräuter und Tränke, Kampfwerte in der Config | Ausrüstung wirkt in Werten, alles per Test belegt |
| U3 Oberwelt | Portal, Stufenzonen, PvP, Kopfgeld, Spawnschutz, Missbrauchsschutz | Kampf serverseitig sauber, Test mit 10 bis 20 Spielern, Kennzahlen |
| Launch | geschlossener Test, danach öffentlicher Start | Kennzahlen siehe unten |
| Update 1 | Handelswelt | Regeln erneut geprüft, genügend aktive Spieler |
| Update 2 | Burg-Ausbau Stufe 3 und 4, Biome 4 bis 6, weitere Zonen | |
| Update 3 | Koop-Expedition, PvE-Gegner und Bosse | |

Die Handelswelt kommt bewusst erst als Update 1: Sie braucht die meiste Absicherung (Betrug, Duplikate, Preisbildung, Regelprüfung) und ergibt erst bei genügend aktiven Spielern Sinn, weil sonst kaum Angebote und Käufe entstehen. Der NPC-Mindestwert fängt diese Anfangszeit ab. Wird die Zeit knapp, entfällt zuerst die Oberwelt-Zonen-Vielfalt (eine Zone statt drei), nicht die Höhle.

## Kennzahlen, Risiken und Marketing

**Kennzahlen mit Zielwerten** (Zielwerte sind Annahmen; als Vergleich nennt der GameAnalytics-Bericht 2025 mediane Retention von 4.31 % bis 10.76 % am Tag 1, 0.41 % bis 1.82 % am Tag 7 und 0.13 % bis 0.50 % am Tag 30, je nach Sessionlänge):

| Kennzahl | Mindestziel (Annahme) | Ambitioniert (Annahme) |
| --- | --- | --- |
| D1-Retention | 12 % | 20 % |
| D7-Retention | 3 % | 6 % |
| Sessions pro Spieler und Tag | 1.5 | 3 |
| Anteil zahlender Spieler | 2 % | 4 % |
| Anteil mit Freundebesuch pro Tag | 15 % | 30 % |
| Anteil, der pro Woche die Oberwelt betritt | 20 % | 40 % |
| Anteil mit mindestens einem Verkauf in der Handelswelt pro Woche (ab Update 1) | 10 % | 25 % |

**Risiken:**

| Risiko | Gegenmaßnahme |
| --- | --- |
| Hype zerfällt schnell (Hits verlieren in 1 bis 3 Monaten den Großteil der Spitze) | Auf Sockel statt Spike bauen: Offline-Helfer, Rückkehr-Anlässe, wöchentliche Events, Besitz, Ausrüstung und Sammlung |
| Reine Dig-Spiele haben eine niedrige Decke (Dig & Clean jetzt bei etwa 2.0K bis 2.5K) | Eigener Hook: Burg, Mutationen, Museum, Ausrüstung, später Handelswelt; früh mit Testspielern prüfen, ob das bindet |
| **Zu großer Umfang** (Mining, Kampf, Markt in einem Spiel) | Stufenweiser Bau, eine Oberwelt-Zone zum Start, Handelswelt und Burg-Ausbau erst als Updates, keine PvE-Gegner zum Launch |
| **PvP: Belästigung und Frust bei jungen Spielern** | Stufenzonen, Neulingsschutz, Spawnschutz, kein Item-Verlust, Melden-Funktion, Portal erst nach Onboarding mit Hinweis |
| **PvP: Exploits** (Fliegen, Teleport, Reichweite) | Serverautorität für Treffer und Bewegung, Ratenlimits, Logs, früh mit Testspielern prüfen |
| **Kopfgeld-Farming** durch Zweitkonten | Pro-Opfer-Sperre, Tageslimit, Stärke-Verhältnis, Prüfprotokoll |
| **Höhle zu schwer fürs Handy** | Abschnitte nur in der Nähe laden, Obergrenze für Größe und Teile, früh messen |
| Handelswelt bleibt leer oder wird ausgenutzt | Start erst bei genug Spielern, NPC-Mindestwert als Untergrenze, Gebühren, Limits, atomare Abwicklung, Prüfprotokoll |
| Robux wird über Items in Spielwerte getauscht | Keine Münzpakete; Passes, Products, Eier-Haustiere und Robux-Ausrüstung nicht handelbar; Handel für nicht berechtigte Spieler gesperrt |
| Pay-to-win im PvP | Robux-Ausrüstung nie besser als erspielte, nur bis mittlere Stufe, nicht handelbar; Tränke nicht für Robux |
| Handelbare Ausrüstung fördert Handel gegen echtes Geld außerhalb der Plattform | Hinweis im Spiel, Ausreißer protokollieren, Verdächtige sperren oder melden |
| Neustart-Problem: Der Algorithmus misst 28 Tage | Frühe Tester und Freunde-Einladungen, geschlossener Test vor dem Launch |
| Exploits an Funden, Tiefe, Höhle und Käufen | Serverautorität, Tests, ProcessReceipt-Idempotenz |
| Regelverstöße (Zufallsobjekte, Handel, PvP, Chat, Kinderschutz) | PolicyService-Prüfung für Zufallsobjekte und Handel, Wahrscheinlichkeiten anzeigen, kein freier Chat zwischen Fremden, Regeln zu PvP vor dem Bau lesen, vor Launch und vor jedem Update erneut prüfen |
| Namens- oder Markenkonflikt | Arbeitstitel vor Launch auf Roblox und per Markenrecherche prüfen; ein passenderer Titel zum Mittelalter-Thema ist erwünscht (später) |

**Marketing und Clip-Momente:** Das Spiel ist auf teilbare Augenblicke gebaut: der Mutations-Reveal, die wachsende Höhle mit immer neuen Biomen, die Museumstour, der Rüstungs- und Waffenvergleich, Kämpfe in der Oberwelt und später spektakuläre Verkäufe in der Handelswelt. Ein Screenshot-Button im Museum und ein Reveal-Overlay erleichtern TikTok- und YouTube-Material. Kleine Creator können vorab Zugang zum geschlossenen Test erhalten. Roblox-Anzeigen sind nach dem Launch möglich, sobald Retention und Konversion gemessen sind; das Budget ist erst dann sinnvoll zu planen.

## Entscheidungen vom 10. Oktober 2026 (bestätigt)

Die offenen Punkte der ersten Fassung sind entschieden:

1. **Ausrüstung gegen Robux:** wie im Abschnitt Monetarisierung beschrieben (kontogebunden, nicht handelbar, höchstens mittlere Stufe, nie besser als erspielt). **Skins** (Aussehen von Waffen, Rüstung, Burg) können zusätzlich kommen.
2. **Kopfgeld:** wird umgesetzt, wie im Abschnitt Oberwelt beschrieben (Münzen vom System, Sperre pro Opfer, Tageslimit, Stärke-Verhältnis).
3. **Auto-Graben:** Freischaltung ab Spitzhacken-Stufe 3 für 5.000 Münzen; der Pass „Auto-Graben ab Start“ (249 Robux) schaltet es ohne Münzen frei. Auto-Graben schlägt im Takt der Abklingzeit, solange der Spieler vor der Wand steht und der Rucksack nicht voll ist, und bleibt im Spielbereich. Alle Werte sind Startwerte (Config).
4. **Freunde in der Höhle:** Eingeladene Roblox-Freunde dürfen in der Höhle des Gastgebers mitgraben, **aber nur in Biomen, die sie selbst schon freigeschaltet haben.** Ein Biom ist für einen Spieler freigeschaltet, wenn er es in seiner eigenen Höhle erreicht hat (größte erreichte Tiefe). Der Gast gelangt nur bis zu dieser Tiefe.
5. **Stadt:** Das heutige Stadtlayout mit 8 Grundstücken bleibt für den Start als Burgviertel. Fremde Burgen sind nicht betretbar.
6. **Rebirth:** Die Ausrüstung bleibt erhalten.
7. **Reihenfolge:** Der Launch enthält die Oberwelt mit PvP.
8. **Namen:** Biome, Helfer („Zwerge“), Zonen und Burgstufen bleiben wie vorgeschlagen. Der Spieltitel wird später geändert.
9. **Handelbare Ausrüstung:** Ausrüstung aus Truhen ist handelbar, solange sie erspielt oder gefunden wurde.
10. **PvP-Darstellung:** normales Roblox-PvP ohne Blut. Die Richtlinien zu Altersfreigabe und Gewaltdarstellung werden vor Launch trotzdem noch einmal gegen die aktuelle Dokumentation gelesen (nicht geprüft).

## Nächste Schritte

- [ ] Umbau U1 planen: Höhle statt Schacht (Datenformat, Profil-Migration, Handy-Messung) und eigene Dateiliste dazu
- [ ] Arbeitstitel festlegen und auf Roblox und per Markenrecherche prüfen
- [ ] Studio-Testphase des bestehenden Spiels abschließen (`docs/TESTLISTE.md`), damit der Umbau auf einem geprüften Stand beginnt
- [ ] Regeln zu PvP und Altersfreigabe lesen (vor dem Bau der Oberwelt)
- [ ] Vor Launch und vor Update 1 Handels- und Zufallsregeln erneut prüfen
