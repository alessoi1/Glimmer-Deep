# Konzept: AI-Trading-Agent mit Claude (Schweiz, 500 CHF)

Oct 7, 2026 · @Developer

## Kurzfazit und Empfehlung

Mit 500 CHF ist ein Trading-Agent in erster Linie ein Lern- und Bauprojekt, kein Einkommen: Fixkosten und Gebühren verlangen schon vor dem ersten Gewinn rund 7–24 % Rendite pro Jahr.

- **Stil:** Swing- statt Daytrading. Regelbasierte Signale auf Tagesdaten, 1–3 Positionen, Cash-Konto ohne Hebel.
- **Markt:** US-ETFs und grosse US-Aktien. Krypto ist die Alternative, Forex und CFDs scheiden aus.
- **Broker:** Interactive Brokers (sicherste Wahl für die Schweiz, keine Mindesteinlage, ausgereifte API) oder Alpaca (einfachere API, aber Verfügbarkeit für die Schweiz vor der Anmeldung klären).
- **Stop-Loss:** als Bracket-Order beim Broker hinterlegt, nicht im Bot. So greift er auch, wenn der Agent abstürzt. Kurssprünge über Nacht kann ein Stop trotzdem nicht verhindern.
- **Rolle von Claude:** Claude Code baut und wartet den Code. Zur Laufzeit berät Claude höchstens (News-Filter, Plausibilitätsprüfung, Tagesbericht). Risikolimits stehen im Code, nicht im Prompt.

Zu deiner Frage, ob sich alles auf Claude auslagern lässt: Bauen, Testen und Betreuen ja. Das Entscheiden über echtes Geld nur eingeschränkt, denn für LLM-Agenten gibt es bisher keinen belegten Handelsvorteil (siehe Realitätscheck). Dazu kommen laufende API-Kosten pro Entscheidung.

## Realitätscheck

Die meisten Daytrader verlieren Geld, und für LLM-Handelsagenten gibt es bisher keinen belegten Vorteil. Die Studien sind teils alt und stammen aus anderen Märkten, die Richtung ist aber einheitlich.

**Daytrader (Menschen)**

| Studie | Ergebnis |
| --- | --- |
| [Jordan & Diltz, Financial Analysts Journal 2003](https://ideas.repec.org/a/taf/ufajxx/v59y2003i6p85-94.html) (US) | Etwa doppelt so viele Verlierer wie Gewinner, rund 20 % klar profitabel, mindestens 64 % verloren Geld. |
| [Garvey & Murphy 2005](https://www.cxoadvisory.com/?p=780) (1'386 US-Daytrader, 3 Monate in 2000) | Rund die Hälfte profitabel nach Kommissionen, aber kurzer Zeitraum und Nullsummenspiel zwischen geübten und ungeübten Tradern. |
| [Brasilien, Futures, 2020](https://finmasters.com/day-trading-statistics/) (Sekundärquelle) | Nur 1,1 % der Daytrader verdienten netto mehr als den Mindestlohn. |
| [Swissquote, Risikohinweis](https://www.swissquote.com/private/trade/platforms/forex-cfds/fix-api) | 68,73 % der Retail-Kunden verloren beim CFD-Handel in 12 Monaten Geld. |

**LLM-Agenten im Livehandel**

| Studie | Ergebnis |
| --- | --- |
| [DX Terminal Pro / DXAP, arXiv 2609.05663](https://arxiv.org/pdf/2609.05663) (Februar–August 2026, Tausende Agenten) | Kein gerichteter Vorteil. Die DXAP-Flotte verliert Geld und liegt hinter ihrem Retail-Benchmark. |
| [HKU Agentic Trader](https://hku.hk/press/news_detail_29241.html) (10 Agenten, Forex, 6 Wochen ab April 2026) | Mehr Risiko führte nicht zu besserer Performance. Ergebnisse weichen von Reasoning-Benchmarks ab. |
| [LiveTradeBench](https://econpapers.repec.org/paper/arxpapers/2511.03628.htm) (21 LLMs, 50 Tage) | Hohe Benchmark-Werte sagen nichts über den Handelserfolg. |
| [Fin-Analyst, CLEF 2026](https://arxiv.org/abs/2607.12233) | +13,51 % auf TSLA im Kurzzeitfenster, aber die Rangfolge kippte gegenüber dem Zwischenstand. Memoryless-Agenten wiederholten falsche Calls tagelang. Feste BTC-Regeln verloren im Seitwärtsmarkt. |

Konsequenz fürs Design: Entscheidungen über Ein- und Ausstieg kommen aus festen, testbaren Regeln. Claude darf Risiko nur reduzieren oder ablehnen, nie erhöhen.

## Rahmen Schweiz: Steuern und Regeln

Private Kursgewinne sind in der Schweiz steuerfrei, Verluste aber nicht abziehbar, und intensives Handeln kann dich steuerlich zum Gewerbetreibenden machen.

- **Kapitalgewinne:** Gewinne aus Wertschriften im Privatvermögen sind steuerfrei, Verluste können nicht abgezogen werden ([private.ch](https://www.private.ch/media/docs/private/2010/06/de/035_Wann-handelt-ein-Privatanleger.pdf), [cash.ch](https://www.cash.ch/news/politik/steuern-bei-kapitalgewinnen-auf-eine-faustregel-wurde-ich-mich-nicht-verlassen-461321)). Dividenden und Zinsen sind Einkommen, Depotwerte gehören ins Wertschriftenverzeichnis.
- **Gewerbsmässigkeit:** Häufigkeit der Geschäfte, kurze Haltedauer und Fremdfinanzierung sprechen dagegen, dass es Privatvermögen bleibt ([Bilanz](https://www.bilanz.ch/invest/maerkte-boerse/steuern-mit-dem-hobby-das-einkommen-aufpeppen/dzkgxsf)). Die Praxis stützt sich auf das ESTV-Kreisschreiben Nr. 36 ([Steuerpraxis TG](https://steuerpraxis.tg.ch/steuerpraxis/2026-01/stp-20-nr-2-gewerbsmassiger-handel-mit-wertschrift)). Gilt die Tätigkeit als gewerbsmässig, werden Gewinne als Einkommen versteuert und es fallen AHV-Beiträge an. Ein Bot mit kurzen Haltezeiten ist systematisch und häufig, ohne Hebel und mit 500 CHF bleibt das Volumen klein. Frag trotzdem dein Steueramt oder einen Steuerberater, bevor du hochskalierst.
- **Stempelabgabe:** Schweizer Broker führen bei ausländischen Wertschriften die Umsatzabgabe ab, 3,0 ‰ pro Geschäft, je zur Hälfte pro Vertragspartei ([ESTV](https://www.estv.admin.ch/de/umsatzabgabe-kurz-erklaert)). Das sind etwa 0,15 % pro Kauf oder Verkauf. Ausländische Broker wie Interactive Brokers erheben sie nicht ([Mustachian Post](https://www.mustachianpost.com/de/die-schweizer-stempelsteuer/)).
- **Krypto:** Gleiche Logik wie bei Wertschriften: private Kursgewinne steuerfrei, Bestand zum Jahresendkurs deklarieren, Staking-Erträge sind Einkommen ([Kanton Zug](https://zg.ch/de/steuern-finanzen/steuern/natuerliche-personen/steuererklaerung-ausfuellen/kryptowaehrungen)).
- **Pattern-Day-Trader-Regel:** Seit dem 4. Juni 2026 abgeschafft, der Mindestbestand von 25'000 USD entfällt ([FINRA-Rule-4210-Änderung bei E\*TRADE](https://us.etrade.com/knowledge/library/stocks/day-trading-basics)). Für dich ist sie damit kein Hindernis mehr.

Nicht geprüft: ob für Eigenhandel mit eigenem Geld in der Schweiz irgendeine Meldung oder Bewilligung nötig ist. Bei Privatpersonen ist das erfahrungsgemäss nicht der Fall, belegt habe ich es hier nicht.

## Märkte im Vergleich für 500 CHF

Für 500 CHF sind US-ETFs und grosse US-Aktien im Cash-Konto der einfachste Einstieg, Hebelprodukte fallen raus. Ein belastbarer Community-Konsens für «sicher und trotzdem rentabel» existiert nicht, die Ranking-Seiten der Broker sind meist Affiliate-Werbung.

| Markt | Eignung | Kosten (Beispiele) | Hauptrisiko |
| --- | --- | --- | --- |
| **US-ETFs und Large Caps** | Empfohlen: liquide, Tagesdaten reichen, Handelszeit 15:30–22:00 MEZ | IBKR fix 0,005 USD pro Aktie, min. 1 USD, max. 1 % ([IBKR](https://www.interactivebrokers.com.au/en/pricing/commissions-home.php)); Alpaca ohne Kommission ([TradersPost](https://docs.traderspost.io/docs/all-supported-connections/alpaca)) | Kurslücken über Nacht, Dollar-Wechselkurs |
| **Westeuropäische Aktien** | Möglich, aber teurer | IBKR ab 3 € pro Trade ([IBKR](https://www.interactivebrokers.com.au/es/index.php?f=6584)), bei 500 CHF etwa 0,6 % pro Order | Hohe Fixkosten pro Trade |
| **Krypto (Spot)** | Möglich: 24/7, aber der Bot muss dauernd laufen | Kraken Standard 0,25 % Maker / 0,40 % Taker, Pro ab 0,16 % / 0,26 % ([Capitalo](https://www.capitalo.at/anbieter/kraken/produkte/crypto)); API-Limit 20 Aufrufe pro Sekunde im Spot ([FXEmpire](https://www.fxempire.com/exchanges/kraken)) | Hohe Schwankung, regelbasierte Bots verlieren im Seitwärtsmarkt ([Fin-Analyst](https://arxiv.org/abs/2607.12233)) |
| **Forex und CFDs** | Nicht empfohlen | Hebel; Swissquote nennt 68,73 % verlierende Retail-Kunden; deren FIX-API verlangt 50'000 USD Mindestbestand ([Swissquote](https://www.swissquote.com/private/trade/platforms/forex-cfds/fix-api)) | Totalverlust, Nachschuss |
| **Futures und Optionen** | Nicht empfohlen (Einschätzung, nicht vertieft recherchiert) | Kontraktgrösse und Hebel passen nicht zu 500 CHF; bei Alpaca keine Bracket-Orders für Optionen und Krypto ([TradersPost](https://docs.traderspost.io/docs/all-supported-connections/alpaca)) | Hebel, Komplexität |

Nur eine Kleinigkeit zum Rechnen: Eine Order über 500 CHF kostet bei IBKR im Fixtarif mindestens 1 USD, also etwa 0,2 % pro Seite. Wer häufig ein- und aussteigt, zahlt schnell mehr in Gebühren, als eine Strategie netto abwirft.

## Broker und APIs

Interactive Brokers ist die sicherere Wahl für die Schweiz, Alpaca die einfachere für einen Bot, sofern Alpaca dich als Schweizer Kunden annimmt. Beide bieten Paper-Trading und Bracket-Orders für Aktien.

|  | [Interactive Brokers](https://interactivebrokers.ie/de/accounts/required-minimums.php) | [Alpaca](https://alpaca.markets/support/requirements-alpaca-brokerage-account) | [Kraken](https://support.kraken.com/ch/articles/201893638-how-trading-fees-work-on-kraken) (Krypto) |
| --- | --- | --- | --- |
| Verfügbarkeit Schweiz | Breit genutzt von Schweizer Anlegern ([Mustachian Post](https://www.mustachianpost.com/de/interactive-brokers-erfahrungen/)) | Offiziell nur «Support kontaktieren» ([Alpaca, Feb. 2026](https://alpaca.markets/support/countries-alpaca-is-available)); Schweizer Testseite nennt sie nutzbar, aber ohne FINMA-Aufsicht ([HelloSafe](https://hellosafe.ch/de/investieren/broker/alpaca)) | Eigene Schweizer Gebührenseite vorhanden |
| Mindesteinlage | 0 USD, keine Inaktivitätsgebühr | Offiziell keine für Einzelkonten; HelloSafe nennt 30'000 USD, das widerspricht Alpacas eigener Aussage ([Alpaca](https://alpaca.markets/support/is-there-an-account-minimum-for-live-brokerage-accounts-2)) | Nicht geprüft |
| Kosten pro Order | Fix 0,005 USD pro Aktie, min. 1 USD; gestaffelt ab 0,35 USD plus Börsen- und Clearinggebühren | Kommissionsfrei für US-Aktien und ETFs | 0,16–0,40 % je nach Tarif |
| Stempelabgabe CH | Entfällt (ausländischer Broker) | Entfällt (ausländischer Broker) | Entfällt |
| API | TWS API (Python: ib\_async), REST, FIX; Paper-Port 7497 bzw. 4002 | REST, WebSocket, Python-SDK; Authentifizierung per API-Key; MCP-Server vorhanden | REST/WebSocket, Sandbox laut FXEmpire |
| Betrieb ohne Aufsicht | Aufwendig: Gateway braucht Login, tägliche Neustarts, wöchentliche 2FA; offiziell kein Headless-Betrieb, Community-Lösungen wie IBC und Docker | Einfach: nur API-Key, keine Login-Sitzung | Einfach: API-Key |
| Aufsicht und Sicherung | US-Broker, nicht FINMA | FINRA und SIPC, nicht FINMA | Nicht geprüft |
| Offene Fragen | Brüche (fractional shares) und Stop-Orders per API testen | Brüche und Bracket-Orders gleichzeitig testen; Quellensteuer-Formular für Nicht-US-Kunden | Nur wenn du Krypto willst |

Ausgeschieden: Swissquote (FIX-API erst ab 50'000 USD, Stempelabgabe, höhere Gebühren) und alle CFD-Broker.

Quellen zum Betrieb von IBKR: [IBKR-Dokumentation zum Gateway](https://www.interactivebrokers.com/docs/tws-api/doc/architecture/the-trader-workstation/the-ib-gateway), [IBC auf GitHub](https://github.com/IbcAlpha/IBC/blob/master/userguide.md), [Docker-Image](https://github.com/gnzsnz/ib-gateway-docker).

## Strategie und Backtesting

Starte mit wenigen, einfachen Swing-Regeln auf Tagesdaten und miss sie immer gegen «ETF kaufen und halten» abzüglich aller Kosten. Keine der folgenden Ideen ist als profitabel belegt, es sind Hypothesen zum Testen (Auswahl aus allgemeinem Wissen, nicht aus den recherchierten Quellen).

1. **Trendfolge:** Einstieg, wenn ein liquider ETF über seinem 200-Tage-Durchschnitt oder einem Mehrwochen-Hoch schliesst, Ausstieg bei Trendbruch oder Stop.
2. **Kurzfristige Gegenbewegung im Aufwärtstrend:** Kauf nach einem scharfen Rücksetzer, solange der übergeordnete Trend intakt ist, Ausstieg nach wenigen Tagen.
3. **Relative Stärke:** Wöchentlich den stärksten von wenigen ETFs halten.

Grenzen bei 500 CHF: Mit Mindestgebühren pro Order sind höchstens wenige Trades pro Monat sinnvoll, und ein Stop über 1 % Risiko pro Trade bedeutet nur etwa 5 CHF. Teure ETF-Anteile erfordern Bruchstücke (fractional shares), deren Zusammenspiel mit Stop-Orders ist per API zu testen.

**Backtesting-Werkzeuge:** backtesting.py für den Einstieg, vectorbt für grössere Parameterläufe, Backtrader als Alternative. backtesting.py und vectorbt sind nicht für den Live-Handel gedacht, Backtrader lässt sich auch live anbinden ([Vergleich auf Medium](https://medium.com/@timemoneycode/mastering-python-backtesting-for-trading-strategies-1f7df773fdf5)).

**Typische Fallen** ([ABC Trading Group](https://www.abctradinggroup.com/backtesting-pitfalls/), [DEV Community](https://dev.to/kakembo_muhammed_53dbbc54/backtesting-trading-strategies-in-python-the-complete-guide-for-developers-fai)):

- Look-ahead-Bias: Signal und Ausführung am selben Kurs, Fix: Signal um einen Tag verschieben.
- Survivorship-Bias: nur Titel testen, die bis heute existieren.
- Overfitting: viele Parameter ausprobieren, bis einer zufällig glänzt. Wenige, begründbare Parameter und Walk-Forward-Test nutzen.
- Kosten und Ausführung: Mindestgebühr, Spread und Wechselkurs einrechnen, Order erst am Folgetag zum realistischen Kurs ausführen.

Das Open-Source-Paket [overfit-gauntlet](https://pypi.org/project/overfit-gauntlet/) prüft Backtest-Code auf Look-ahead und rechnet Walk-Forward- und Bootstrap-Tests. Claude kann beim Aufbau helfen, die Entscheidung «Strategie taugt oder nicht» sollte aber ein fester Test treffen, nicht ein Gefühl.

## Architektur und Rolle von Claude

Der Agent besteht aus fünf Schichten mit festen Regeln, Claude sitzt daneben als Berater und kann Trades nur ablehnen oder verkleinern.

&#91;embedded content: Architektur des Agenten · 5 Schichten, Claude als Berater\]

Lesart: Der Signal-Schritt reicht Kandidaten an Claude, der sie nur streichen oder kürzen darf. Die Risiko-Engine hat das letzte Wort, der Broker hält den Stop, und bei einer Limit-Verletzung schaltet der Kill-Switch alles ab.

**Regeln, die im Code stehen und nicht im Prompt:**

- Höchstens 1 % des Kontos (rund 5 CHF) Risiko pro Trade, 1–3 offene Positionen, nur Cash-Konto ohne Hebel.
- Jede Kauforder geht als Bracket-Order mit Stop-Loss beim Broker raus. Fehlt der Stop, wird nicht gekauft. Ein Stop garantiert keinen Kurs bei Kurslücken über Nacht.
- Tages- und Gesamtverlustlimit (Vorschlag: Abbruch bei 20 % des Einsatzes, höchstens 100 CHF), danach Kill-Switch und Alarm.
- Claude bekommt keine Schreibrechte auf Orders. Er liefert eine strukturierte Antwort (zulassen, kürzen, ablehnen), der Code setzt um.
- API-Schlüssel mit möglichst engen Rechten, nie im Code oder Prompt, Paper- und Live-Schlüssel getrennt.

**Technik:** Ein Python-Skript läuft per Scheduler täglich nach Börsenschluss, schreibt jede Entscheidung in eine SQLite-Datenbank und meldet Auffälliges per Chat. Claude Code schreibt und testet den Code, den Backtest und die Risikoprüfungen und überarbeitet sie nach jedem Review. Beim Bauen bekommt Claude Code nur die Paper-Schlüssel. Die Agent-SDK-Funktionen Berechtigungen und Hooks helfen, riskante Aktionen vor der Ausführung abzufangen ([Agent-SDK-Doku](https://code.claude.com/docs/en/agent-sdk/overview)).

## Laufende Kosten

Zuhause betrieben liegen die Fixkosten bei etwa 3–10 CHF pro Monat, das sind 7–24 % pro Jahr auf 500 CHF. Ein gemieteter Server (VPS) kommt obendrauf. Wer diese Hürde nicht schlägt, verliert netto, auch ohne einen einzigen Fehltrade.

| Posten | Annahme | Pro Monat |
| --- | --- | --- |
| Claude API, Sonnet 5.5 | 1 Lauf pro Handelstag (22 Tage), 30'000 Token Eingabe, 4'000 Ausgabe; 2 USD bzw. 10 USD pro Mio. Token ([Preisliste](https://platform.claude.com/docs/en/about-claude/pricing)) | ca. 2,20 USD |
| Claude API, Haiku 4.5 | gleiche Annahme; 1 USD bzw. 5 USD pro Mio. Token | ca. 1,10 USD |
| Web-Suche über die API | 10 Suchen pro Tag, 10 USD pro 1'000 Suchen | ca. 2,20 USD |
| Broker Interactive Brokers | 8 Orders (4 Round-Trips), gestaffelt ab 0,35 USD, fix ab 1 USD pro Order, plus Börsen- und Clearinggebühren | ca. 3–8 USD |
| Broker Alpaca | kommissionsfrei für US-Aktien | 0 USD |
| Marktdaten | Tagesdaten über die Broker-API (Einschätzung, Datenanbieter nicht verglichen) | 0 |
| Hosting | eigener PC oder Raspberry Pi / gemieteter VPS (Schätzung, nicht recherchiert) | 0 / ca. 5–10 CHF |

Spar-Hebel bei Claude: Prompt-Caching (Lesen kostet 10 % des Eingabepreises), Batch-API (50 % Rabatt, aber nicht in Echtzeit) und ein kleineres Modell für Routineprüfungen. Der Agent läuft über die Agent-SDK- oder Client-SDK-API mit eigenem API-Key und Abrechnung pro Token ([Agent-SDK-Doku](https://code.claude.com/docs/en/agent-sdk/overview)); setze in der Anthropic-Console ein Ausgabenlimit, damit eine Endlosschleife das Budget nicht sprengt (Funktion vorab prüfen).

Die Handelskosten hängen stark vom Broker ab: Bei einer 500-CHF-Position sind 1 USD Mindestgebühr etwa 0,2 % pro Seite, bei Alpaca entfallen sie. Die gestaffelte Tarifoption von IBKR ist für Orders zwischen 100 und 15'000 USD in der Regel günstiger als der Fixtarif ([Mustachian Post](https://www.mustachianpost.com/de/ibkr-gebuhren-festpreis-oder-gestaffelt/)).

## Roadmap mit Abbruchkriterien

Der Weg zum echten Geld führt über fünf Phasen mit vier Gates, und eine feste Abbruchregel: Stopp bei 20 % Verlust des Einsatzes, nie mehr als 100 CHF.

&#91;embedded content: Roadmap · 5 Phasen, 4 Gates, 1 Abbruchregel\]

Die Zeiten sind Vorschläge. Besteht eine Phase ihr Gate nicht, geht es nicht weiter: Strategie überarbeiten oder das Projekt beenden. Ein Abbruch im Backtest oder im Paper-Trading ist ein gutes Ergebnis, denn er kostet dich kein Geld.

## Offene Punkte, Entscheidungen und Quellen

Vor dem Bau brauche ich drei Entscheidungen von dir, und vier technische Fragen klären wir im Paper-Konto.

**Entscheidungen von dir**

1. Broker: Interactive Brokers (sicherer, aufwendigerer Betrieb) oder Alpaca (einfacher, Schweizer Zulassung offen)?
2. Betrieb: eigener Rechner oder Raspberry Pi, oder gemieteter Server?
3. Verlustbudget: Sollen wir die 500 CHF als Lernbudget behandeln und nach der Abbruchregel stoppen (20 % des Einsatzes, höchstens 100 CHF)?

**Technisch und steuerlich zu klären**

- Nimmt Alpaca Schweizer Kunden an, und mit welcher Mindesteinlage? Die Angaben widersprechen sich.
- Funktionieren Bruchstück-Aktien zusammen mit Stop- und Bracket-Orders per API (IBKR und Alpaca)?
- IBKR-Gateway: wie oft ist 2FA nötig, und läuft der Neustart zuverlässig?
- Einstufung als gewerbsmässiger Händler: beim Steueramt oder Steuerberater absichern.

**Nicht abgedeckt:** Vergleich von Marktdaten-Anbietern, Nachrichten- und Sentiment-Quellen, aufsichtsrechtliche Fragen zum Eigenhandel, Quellensteuer auf US-Dividenden. Die Broker-Vergleichsseiten im Netz enthalten Affiliate-Links, ich habe sie nur für Fakten wie Mindesteinlage und Gebühren herangezogen und, wo möglich, mit Herstellerseiten abgeglichen. Viele Quellen sind Suchtreffer und nicht vollständig gelesen.

**Hauptquellen (Stand 7. Oktober 2026)**

- [Alpaca: Länderliste](https://alpaca.markets/support/countries-alpaca-is-available), [Alpaca: Mindesteinlage](https://alpaca.markets/support/is-there-an-account-minimum-for-live-brokerage-accounts-2)
- [Interactive Brokers: Mindesteinlagen](https://interactivebrokers.ie/de/accounts/required-minimums.php), [IBKR-Gebührenmodelle](https://www.mustachianpost.com/de/ibkr-gebuhren-festpreis-oder-gestaffelt/)
- [ESTV: Umsatzabgabe](https://www.estv.admin.ch/de/umsatzabgabe-kurz-erklaert)
- [Claude API: Preise](https://platform.claude.com/docs/en/about-claude/pricing), [Claude Agent SDK](https://code.claude.com/docs/en/agent-sdk/overview)
- [FINRA-Regeländerung zur PDT-Regel (tastytrade)](https://tastytrade.com/learn/markets/industry/pattern-day-trading/)
- Studien: siehe Links im Abschnitt Realitätscheck
