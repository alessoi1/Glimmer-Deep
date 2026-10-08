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

Maße in Studs. Wichtig sind die Grundfläche und die Höhe.

| Name des Models | Grundfläche | Höhe | Hauptteil | Hinweise |
| --- | --- | --- | --- | --- |
| `ShaftRim` | Rand 10,4 x 10,4, Öffnung 8 x 8 in der Mitte | Rand 0,6; Winde bis etwa 5 | beliebig | Die **Öffnung 8 x 8 muss frei bleiben**. Ursprung in der Mitte des Schachts. |
| `SellStand` | 6 x 6 (Dach darf 7 x 7 sein) | etwa 6 | `SellPoint` (die grüne Standfläche, 6 x 1 x 6) | Der Spieler steht auf `SellPoint`. |
| `Sign_Museum` | 3 breit | etwa 4 | `Board` | Schild mit Pfosten. Beschriftung hängt der Code an `Board`. |
| `Sign_House` | 3 breit | etwa 4 | `Board` | wie oben |
| `Sign_Guests` | 3 breit | etwa 4 | `Board` | wie oben |
| `Sign_Rebirth` | 3 breit | etwa 4 | `Board` | wie oben |
| `Sign_Season` | 3 breit | etwa 4 | `Board` | wie oben |
| `Vitrine` | 2 x 2 | 3 | `Vitrine` (das Glas) | leere Vitrine |
| `VitrineFilled` | 2 x 2 | 3 | `Vitrine` (das Glas) | Vitrine mit ausgestelltem Fund (leuchtender Edelstein oder ähnliches). Der Code setzt den Fundnamen als Text darüber. |
| `Decor_potted_plant` | 5 x 5 | bis 6,5 | beliebig | Topfpflanze |
| `Decor_lantern` | 5 x 5 | bis 6,5 | beliebig | Laterne (gern mit eigenem PointLight) |
| `Decor_rug` | 5 x 4 | flach (0,2) | beliebig | Teppich, CanCollide aus |
| `Decor_banner` | 5 x 5 | bis 6,5 | beliebig | Banner |
| `Decor_statue` | 5 x 5 | bis 6,5 | beliebig | Statue |
| `Decor_fountain` | 5 x 5 | bis 6,5 | beliebig | Brunnen |
| `Scenery` | gesamtes Grundstück 64 x 64, Ursprung in der Mitte | beliebig | beliebig | Bäume, Steine, Zaun. Die Mitte (Schacht, Pads, Schilder, Museum, Deko) muss frei bleiben. Siehe `src/shared/Config/Look.luau` für die bisherigen Plätze. |

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
