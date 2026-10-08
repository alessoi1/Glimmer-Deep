# Eigene 3D-Modelle einbinden

Die Welt besteht aus Platzhaltern, die der Code aus einfachen Teilen baut (`src/shared/ModelSpecs.luau`). Für jedes Objekt kannst du ein eigenes Modell hochladen. Der Code nimmt es dann automatisch statt des Platzhalters, ohne dass eine Zeile geändert werden muss.

## So geht es

1. Das Modell in Roblox Studio (oder Blender mit Import als Mesh) bauen.
2. Alle Teile **Anchored**, die Teile in **einem Model** mit genau dem Namen aus der Tabelle unten.
3. Den **Ursprung (Pivot) des Models in die Mitte der Unterseite** legen. Dort steht es später auf dem Boden. In Studio: Model auswählen, *Pivot* im Modell-Tab auf „Mitte der Unterseite“ stellen.
4. Rechtsklick auf das Model, *Export Selection* oder *Save to File*, als `.rbxm` speichern.
5. Die Datei in den Ordner `assets/models/` des Projekts legen. Dateiname egal, **der Name des Models** zählt.
6. `rojo serve` neu verbinden. Beim Start steht im Output `using an uploaded model` mit dem Namen.

Nur eigene oder geprüfte Modelle verwenden, keine Toolbox-Modelle ohne Prüfung (siehe `CLAUDE.md`).

## Regeln für alle Modelle

- Das Modell darf **kein Skript** enthalten.
- Es soll **schlank** sein (Handy zuerst): wenige hundert Dreiecke pro Stück, kleine Texturen, nicht mehrere SurfaceAppearances je Teil.
- Das **PrimaryPart** setzen, oder einen Teil so nennen wie in der Spalte „Hauptteil“. An ihm hängen Beschriftung und Prompt. Fehlt beides, nimmt der Code irgendein Teil.
- Teile, die nicht im Weg stehen sollen (Dach, Deko), auf **CanCollide aus** stellen.
- Das Modell darf die **Grundfläche** unten nicht überschreiten, sonst überlappt es Nachbarobjekte (der Code prüft das nur bei den Platzhaltern).
- Hat ein Modell mehrere Größen oder Zustände, bekommt es mehrere Namen (zum Beispiel `Vitrine` und `VitrineFilled`).

## Liste der Modelle

Maße in Studs, für eine Figur von etwa 5 Studs Höhe. Wichtig sind die Grundfläche und die Höhe. Die Maße kommen aus `src/shared/Config/Plot.luau`; ändert sich dort etwas, ändert sich auch diese Tabelle.

| Name des Models | Grundfläche | Höhe | Hauptteil | Hinweise |
| --- | --- | --- | --- | --- |
| `ShaftRim` | Rand 15,6 x 15,6, Öffnung 12 x 12 in der Mitte | Rand 0,9; Winde bis etwa 7,5 | beliebig | Die **Öffnung 12 x 12 muss frei bleiben**. Ursprung in der Mitte des Schachts. |
| `SellStand` | 9 x 9 (Dach darf 10 x 10 sein) | etwa 9 | `SellPoint` (die grüne Standfläche, 9 x 1,5 x 9) | Der Spieler steht auf `SellPoint`; das Betreten verkauft automatisch. |
| `Sign_Museum` | 4,5 breit | etwa 6 | `Board` | Schild mit Pfosten. Beschriftung hängt der Code an `Board`. |
| `Sign_House` | 4,5 breit | etwa 6 | `Board` | wie oben |
| `Sign_Guests` | 4,5 breit | etwa 6 | `Board` | wie oben |
| `Sign_Rebirth` | 4,5 breit | etwa 6 | `Board` | wie oben |
| `Sign_Season` | 4,5 breit | etwa 6 | `Board` | wie oben |
| `Vitrine` | 3 x 3 | 4,5 | `Vitrine` (das Glas) | leere Vitrine |
| `VitrineFilled` | 3 x 3 | 4,5 | `Vitrine` (das Glas) | Vitrine mit ausgestelltem Fund (leuchtender Edelstein oder ähnliches). Der Code setzt den Fundnamen als Text darüber. |
| `Decor_potted_plant` | 7,5 x 7,5 | bis 9,75 | beliebig | Topfpflanze |
| `Decor_lantern` | 7,5 x 7,5 | bis 9,75 | beliebig | Laterne (gern mit eigenem PointLight) |
| `Decor_rug` | 7,5 x 6 | flach (0,3) | beliebig | Teppich, CanCollide aus |
| `Decor_banner` | 7,5 x 7,5 | bis 9,75 | beliebig | Banner |
| `Decor_statue` | 7,5 x 7,5 | bis 9,75 | beliebig | Statue |
| `Decor_fountain` | 7,5 x 7,5 | bis 9,75 | beliebig | Brunnen |
| `StreetLamp` | 1,5 x 1,5 | etwa 10 | `Pole` | Laterne an den 15 Kreuzungen der Straßen. Gern mit PointLight. |
| `Tree` | etwa 9 x 9 | etwa 14 | `Trunk` | Baum im Grasstreifen um die Stadt (etwa 40 Stück). |
| `Scenery` | gesamtes Grundstück 96 x 96, Ursprung in der Mitte | beliebig | beliebig | Bäume, Steine, Zaun. Die Mitte (Schacht, Pads, Schilder, Museum, Deko) muss frei bleiben. Siehe `src/shared/Config/Look.luau` für die bisherigen Plätze. |

Nicht ersetzbar: der Museumsboden (seine Größe hängt von der Hausstufe ab).

## Noch nicht im Code, aber sinnvoll als Modelle

Diese Dinge gibt es im Spiel noch nicht als 3D-Objekte. Wenn du Modelle dafür hast, binde ich sie in einem eigenen Schritt ein:

- **Haustiere:** zehn Figuren (`mole`, `glowworm`, `badger`, `bat`, `salamander`, `owl`, `lava_fox`, `crystal_moth`, `stone_dragon`, `star_beetle`), klein (etwa 1 bis 2 Studs), die dem Spieler folgen.
- **Funde:** ein Modell je Fund (`shard`, `shell`, `fossil`, `amber`, `gemstone`) für die Vitrine statt des einheitlichen Edelsteins.
- **Haus:** ein richtiges Gebäude für Stufe 1 und 2 um das Museum.
- **Erz:** kleine Brocken, die beim Graben herausfliegen.

## Wenn etwas nicht passt

- Steht das Modell schief oder schwebt es? Dann liegt der Ursprung nicht in der Mitte der Unterseite.
- Fehlt die Beschriftung? Dann hat das Modell keinen Teil, an dem sie hängen kann (PrimaryPart setzen).
- Kommt der Platzhalter statt deines Modells? Dann stimmt der Name nicht (Groß- und Kleinschreibung zählt) oder die Datei liegt nicht in `assets/models/`.
