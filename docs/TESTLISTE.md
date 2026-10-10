# Testliste für Roblox Studio

Zum Abhaken von Hand. Die ausführlichen Beschreibungen stehen in `docs/OFFEN.md`; hier steht nur, was zu klicken und zu sehen ist. Wenn etwas nicht stimmt: Output-Zeilen kopieren (`[GlimmerDeep][...]`) und die Nummer des Punktes dazuschreiben.

## Vorbereitung

- [ ] `rojo serve` läuft aus dem Ordner mit dem neuesten `main` (nicht aus einem alten Branch), im Studio-Plugin „Connect“.
- [ ] Studio: Spiel ist veröffentlicht (File → Publish to Roblox) und API-Zugriff für DataStores ist an.
- [ ] Output-Fenster offen. Beim Start steht für jeden Dienst `started`, und kein `config is invalid` oder `is invalid`.
- [ ] Testprofil zum Zurücksetzen: Beim ersten Start mit neuem Profil läuft das Onboarding (Runde 1). Für Wiederholungen eine zweite Testfigur oder das Profil löschen.
- [ ] Emulator „Handy“ (Test-Tab) für die Mobil-Prüfungen bereithalten.

## Runde 1: Einzelspieler, ein Durchgang von neu bis Museum

Mit neuem Profil, in dieser Reihenfolge. Der Durchgang dauert etwa 20 bis 30 Minuten.

### Start und Onboarding

- [ ] Status im Log: erster Start `status=new`, danach `profile loaded`.
- [ ] Unten in der Mitte erscheint ein Tipp, er wechselt nach Graben, erstem Fund, Verkauf und Upgrade.
- [ ] Der Shop-Knopf und die Haustiere-Knöpfe fehlen am Anfang (keine Kaufangebote in den ersten Minuten).
- [ ] Der 30. gegrabene Block ist ein seltener Fund mit Mutation „Golden“.
- [ ] Ein bestehendes Profil zeigt keinen Tipp.

### Graben

- [ ] Taste E und der Graben-Knopf graben; Halten wiederholt im Takt der Abklingzeit.
- [ ] Anzeige unten links (auf dem Handy über dem Bewegungsstick): Tiefe, Rucksack, Münzen.
- [ ] Meldung „Rucksack voll“, wenn er voll ist; „Geh näher an deinen Schacht“, wenn zu weit weg.
- [ ] Nach Neustart ist die Tiefe noch da.

### Verkaufen und Upgrades

- [ ] Grüner Verkaufsstand nördlich vom Schacht. Einen Schritt auf die grüne Fläche: der Rucksack (und das Lager) wird **von selbst** verkauft, Meldung „Verkauft: +n Münzen“, kein Verkaufsknopf mehr. Mit leerem Rucksack passiert nichts (keine Meldung). Außerhalb des Stands wird nicht verkauft.
- [ ] Münzen steigen beim Verkauf, Münzen bleiben nach Neustart.
- [ ] „Upgrades“ öffnet und schließt das Panel; auf dem Handy passt es auf den Bildschirm (Hoch- und Querformat, scrollbar).
- [ ] Sieben Zeilen: Schaufel, Rucksack, Bagger und vier Fähigkeiten; ausgegraut bei zu wenig Münzen, „Maximal“ auf der letzten Stufe.
- [ ] Kauf zieht Münzen ab, Graben wird schneller, Rucksack-Kapazität steigt; Stufen bleiben nach Neustart.
- [ ] Fähigkeiten: Seilwinde macht die Figur schneller, Lampe/Erzspürer zeigt Text wie „Glück +5 %“.

### Museum

- [ ] Lila Schild „Museum“ östlich vom Schacht; Taste F oder Knopf „Ansehen“ in der Nähe öffnet das Panel (Handy: scrollbar, Knöpfe groß genug).
- [ ] Einen seltenen Fund aus dem Rucksack ausstellen und wieder entfernen; die Vitrine im Grundstück zeigt den Namen.
- [ ] Besucher-Einkommen abholen; Sets-Zeilen werden angezeigt.
- [ ] Nach einem vollständigen Set steigt der Münzbetrag beim Verkauf.
- [ ] Der Onboarding-Tipp springt nach dem ersten Ausstellen auf „Dein Bagger arbeitet weiter“.

### Offline-Bagger

- [ ] Zum schnellen Testen in `Config/Digger` `minSeconds` senken (nicht committen).
- [ ] Spiel verlassen, nach mehr als der Mindestzeit wieder betreten: Fenster „Während du weg warst“ mit Dauer, Blöcken, Erz und Funden.
- [ ] Im Panel unten links steht „+ Lager n“; Verkauf am grünen Punkt verkauft Rucksack und Lager zusammen.
- [ ] Funde aus dem Lager sind im Museum-Panel unter „Im Rucksack“ ausstellbar.
- [ ] Ein Absturz (Studio beenden ohne „Stop“) zahlt nichts aus (bewusst).

### Aufgaben und Login-Kette

- [ ] „Aufgaben“ öffnet das Panel (Handy, scrollbar): „Tägliche Belohnung“ Tag 1 von 7, Abholen klappt, danach „Abgeholt“.
- [ ] Drei Tagesaufgaben mit Fortschritt; Meldung „Aufgabe geschafft: …“; Abholen zahlt Münzen; Bonus „Alle geschafft“.
- [ ] Restzeit bis zu neuen Aufgaben wird angezeigt.

### Shop, Booster, Haustiere (nach dem Onboarding)

- [ ] Knopf „Shop“ erscheint erst nach dem Onboarding.
- [ ] Shop-Panel: vier Passes mit Name, Wirkung, Preis, „Angebot ansehen“ (nicht „Bald verfügbar“); Booster-Abschnitt mit Chancen in Prozent.
- [ ] Haustiere-Panel: Eier, Chancen (Summe 100 %), Garantie-Zeile, Sammlung.
- [ ] Texte klingen neutral, nichts Drängendes.

## Runde 2: Käufe, Sonderfälle, Mehrspieler

### Game Passes (Studio-Käufe kosten kein echtes Robux)

- [ ] **Nachtschicht:** Kauf, danach „Während du weg warst“ zählt bis zu 8 statt 4 Stunden.
- [ ] **Doppelte Münzen:** Erzverkauf bringt das Doppelte; seltene Funde sind nicht doppelt.
- [ ] **Schnellreise:** zwei Knöpfe „Zum Verkaufspunkt“ und „Zum Schacht“, 5 Sekunden Abklingzeit.
- [ ] **Rucksack Plus:** Kapazität +20 %.
- [ ] Nach erneutem Betreten sind die Pässe noch aktiv (Besitzprüfung im Hintergrund, Log `pass owned`).
- [ ] Zweiter Kauf eines schon besessenen Passes zeigt „Gekauft“ statt Angebot.

### Booster und Haustiere, Sonderfälle

- [ ] Booster mehrmals kaufen: Restzeit wächst, bei 2 Stunden Restzeit bietet der Shop nichts mehr an.
- [ ] Eingeschränkte Spieler: in `PaidRandomPolicy.isRestricted` testweise `true` erzwingen (nicht committen). Glücks-Booster und Ei-Preis verschwinden, „Glücks-Booster gratis“ und „Gratis-Ei abholen“ erscheinen, danach „Wieder möglich in …“.
- [ ] Haustier-Panel und Shop-Panel gleichzeitig öffnen: Überlappung auf dem Handy prüfen, ob es stört.
- [ ] Kaufdialog zeigt für jedes Angebot den richtigen Namen und Preis.

### Daten und Fehlerfälle

- [ ] Ladefehler: kein Test nötig, solange nur bekannt ist, dass bei Fehlern ein Kick mit Meldung erscheinen soll; wenn leicht möglich (zum Beispiel API-Zugriff kurz aus), Verhalten notieren.
- [ ] Altes Profil (vor den letzten Versionen) lädt als `migrated` und alles funktioniert weiter.
- [ ] Zwei Studio-Fenster mit demselben Konto: nur ein Spieler bekommt das Profil, der andere eine Meldung.

### Mehrspieler (mit zweiter Person oder lokalem Server mit 2 Spielern)

- [ ] Jeder Spieler bekommt ein eigenes Grundstück; Zuweisung und Freigabe beim Verlassen stimmen.
- [ ] Max Players = 8 in den Spiel-Einstellungen.
- [ ] Besucher bewundert das Museum: Meldung bei beiden, nur einmal je 6 Stunden, Bestenliste zeigt die Bewunderungen.
- [ ] Bonus-Wirkungen (Booster, Haustier) gelten nur für den Käufer.

## Runde 3: neue Systeme (Haus, Gäste, Rebirth, Event, Saison)

Reihenfolge wie in `docs/OFFEN.md` unter den gleichnamigen Punkten. Vorab ein Profil mit genug Münzen (zum Beispiel erst Münzen verdienen oder in `Config/Profile` `startCoins` testweise hoch setzen, nicht committen).

### Haus-Ausbau und Dekoration

- [ ] Orangefarbenes Schild „Haus“ (Taste G) öffnet das Panel (Handy: scrollbar, Knöpfe groß genug).
- [ ] Dekoration lässt sich vor dem Ausbau nicht kaufen („Erst das Haus ausbauen“).
- [ ] Ausbau auf Stufe 2 kostet 10.000 Münzen; danach 12 Vitrinen im Museum und 6 Dekoplätze.
- [ ] Deko kaufen, aufstellen, entfernen; aufgestellte Deko steht westlich vom Schacht und bleibt nach Neustart.

### Gäste (zweite Person nötig)

- [ ] Türkises Schild „Gäste“ (Taste H); ein Freund tritt bei, ein Fremder wird abgewiesen („Nur Freunde können mitgraben“). Zum Testen ohne Freundschaft `friendsOnly` in `Config/Guests` testweise auf `false`.
- [ ] Gast gräbt am Schacht des Gastgebers; Erz und Tiefe gehören dem Gast, der Gastgeber bekommt Münzen.
- [ ] Anzeige oben: „Gäste: Name“ beim Gastgeber, „Du gräbst bei Name mit“ beim Gast; erneutes Benutzen des Schilds beendet den Besuch.
- [ ] Vier Gäste gehen, ein fünfter wird abgewiesen („Das Grundstück ist voll“).

### Rebirth

- [ ] Rotes Schild „Neue Bohrung“ (Taste J); Knopf erst ab 300 m aktiv (zum Testen `requiredDepth` in `Config/Rebirth` testweise senken).
- [ ] Mit Rückfrage; danach Münzen 0, Tiefe 0, Werkzeuge auf Stufe 1, Erz weg; Museum, Haus, Haustiere und seltene Funde bleiben.
- [ ] Punkte 5 (dann 7, 9 …); Boni kaufen und prüfen, dass sie wirken und nach Neustart bleiben.

### Event und Saison

- [ ] Gelbes Schild „Saison“ (Taste K): Event mit Namen und Restzeit, Saison mit Stufe und Punkten.
- [ ] Beim Graben steigen die Saisonpunkte; Meldung „Saison-Stufe n erreicht“.
- [ ] Gratis-Belohnungen abholen (Münzen, Ei, Booster); Premium zeigt „Premium“ als gesperrt.
- [ ] Nach dem Kauf des „Entdecker-Pass“ (ID eintragen!) sind Premium-Belohnungen abholbar.
- [ ] Event-Wirkung: in `Config/Events` testweise nur das Event „Glühwoche“ in `rotation` lassen und viele seltene Funde graben: auffällig viele glühende.

### Optik (Runde 3b)

- [ ] Licht und Atmosphäre wirken stimmig (Nachmittagssonne, leichter Dunst), nichts ist überbelichtet.
- [ ] Grundstück: Gras oben, Erde an den Schachtwänden, Zaunpfosten ohne Hindernis, Lücke an der Südseite, Bäume und Felsen im Weg stehen nicht.
- [ ] Schachtrand mit Winde: man kommt zum Graben nah genug heran und kann in den Schacht springen.
- [ ] Verkaufsstand, Schilder, Vitrinen, Museumsboden und Dekoration sehen aus wie beschrieben; Beschriftungen sind gut lesbar.
- [ ] Handy-Emulator: gleichmäßige Framerate mit allen 8 Grundstücken, nichts ruckelt.
- [ ] Eigenes Modell testen (optional): eine `.rbxm` mit dem Namen `Sign_House` in `assets/models/` legen, `rojo serve` neu verbinden, im Output erscheint `using an uploaded model`.

### Stadt (Runde 3c)

- [ ] Die 8 Grundstücke sind durch Straßen verbunden (Asphalt mit gelber Mittellinie), an jeder Kreuzung steht eine Laterne.
- [ ] Rund um alle Straßen liegt ein Grasstreifen mit Bäumen; am Rand eine niedrige Steinmauer. Man kommt nicht darüber hinaus und fällt nicht ab (auch nicht mit Sprüngen und Schnellreise).
- [ ] Das eigene Grundstück ist größer (96 statt 64 Studs); Schacht, Verkaufsstand, Schilder, Vitrinen und Dekoration wirken im Verhältnis zur Figur groß genug, die Wege sind nicht zu lang.
- [ ] Texte in der Oberfläche und die Beschriftungen in der Welt sind klein genug, aber auf dem Handy noch lesbar.
- [ ] Mit zwei Spielern: der Besucher läuft über die Straße zum fremden Grundstück (Lücke im Zaun an der Südseite) und findet das Gäste-Schild.

## Danach

- [ ] Alle gefundenen Fehler als Liste mit Punkt-Nummer sammeln und weitergeben.
- [ ] Abgehakte Punkte in `docs/OFFEN.md` auf `[x]` setzen (oder mir sagen, welche).
- [ ] Zusätzlich offen aus der Technik: `luau-analyze` lokal ausführen (Typprüfung).


## Höhle (`Config/Cave.enabled = true`)

Nur in Studio prüfbar. Der Schalter steht seit dem Studio-Test auf `true`; bei groben Fehlern wieder auf `false` setzen, dann läuft der alte Schacht.

- [ ] Knopf „In die Höhle“ (oben links) bringt den Spieler in einen Gang nach unten; „Zur Burg“ bringt ihn zurück auf das Grundstück.
- [ ] Der Gang hat Boden, Decke und Wände (graues Gestein, Erz farbig); man fällt nirgends durch.
- [ ] Tippen oder Halten auf einen Block baut ihn ab; Erz landet im Rucksack, Anzeige unten links ändert sich; Münzen und Verkauf wie bisher.
- [ ] Mit höherer Spitzhackenstufe fallen mehrere Blöcke pro Hieb (Fläche wächst).
- [ ] Während man weitergeht, werden vorne Blöcke gebaut und hinten abgebaut (kein Ruckeln auf dem Handy, Teileanzahl im Log `cave window is over the part budget` darf nicht erscheinen).
- [ ] Truhe antippen: Meldung „Truhe geöffnet: …“, die Truhe verschwindet, ein zweites Antippen tut nichts.
- [ ] Nach Neustart des Spiels: abgebaute Blöcke bleiben abgebaut, nach 10 Minuten wachsen Erz und Kräuter an der Wand nach.
- [ ] Tod oder Zurücksetzen holt den Spieler auf das Grundstück.
- [ ] Zwei Spieler gleichzeitig: jeder hat seinen eigenen Gang, nichts überlappt.
- [ ] Mit eingeschaltetem Schalter tut der alte Graben-Knopf nichts (Log `cave_active`).
- [ ] Logs: `entered the cave`, `left the cave`, `chest opened`, keine `error`-Zeilen.
- [ ] Bekannte Lücke: Die Höhle ist dunkel (Licht fehlt noch).
