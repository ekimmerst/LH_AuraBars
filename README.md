# MiniBars

Paladin-Buff- und Cooldown-Balken für WoW Forever Beta (Interface 16001). Zeigt Paladin-Buffs mit höchstens 60 Sekunden Gesamtdauer auf deinem Spieler nur mit einem lebenden, angreifbaren Ziel; permanente Auren werden ausgeblendet. Laufzeiten stammen aus den aktiven Buffs des Clients. Bekannte Paladin-Fähigkeiten werden über lokalisierte Zaubernamen erkannt, neue Fähigkeiten zusätzlich aus den Klassenabschnitten des Paladin-Zauberbuchs.

Die Balken erscheinen rechts neben der Bildschirmmitte. Breite, goldene Farbe, Smooth-Textur und Rahmen entsprechen MiniExpBar. Die Textur liegt auch in MiniBars, sodass MiniExpBar nicht zwingend aktiviert sein muss. Die Balken sind von oben nach unten nach absteigender Restdauer sortiert. Der Buff mit der längsten Restdauer steht oben. Der Stapel wächst nach oben; die Position des untersten Balkens bleibt beim Hinzufügen und Entfernen fixiert. In den letzten drei Sekunden blinkt der Balken; ausgelaufene oder entfernte Buffs verschwinden.

- `/minibars unlock`: drei dauerhafte Testbalken anzeigen und den gesamten Stapel mit linker Maustaste verschieben. Echte Buffs sind bei einem angreifbaren Ziel sichtbar. Die drei Testbalken erscheinen auch ohne Ziel. Rechts unterhalb des Stapels erscheint ein kleiner Kreis: mit linker Maustaste gedrückt halten und ziehen, um Breite und Höhe unabhängig zwischen 50 % und 200 % der Standardgröße zu ändern: horizontal ziehen für die Breite, vertikal für die Höhe. Der Abstand bleibt bei 3 UI-Einheiten.
- `/minibars lock`: Position fixieren und Testbalken ausblenden.
- `/minibars reset`: Standardbreite (wie MiniExpBar), Standardhöhe (20 UI-Einheiten) und Standardposition (rechts neben der Bildschirmmitte) wiederherstellen. Der aktuelle Sperrstatus bleibt erhalten.

Position, Größe und Sperrstatus werden pro Charakter gespeichert. Nach der Installation den Client vollständig neu starten und MiniBars in der AddOn-Liste aktivieren.

Validierung: Lua-5.1-Tests mit simulierten WoW-APIs für Sortierung, Restzeit, Füllstand, Blinken, Entfernen, Testbalken, Sperre, Breite und Position. Ein Live-Test in der Beta steht aus.

Version 1.0.1: Buff-Abfragen sind gegen temporär gesperrte Aura-Daten abgesichert. Die Listen-API wird bevorzugt; geheime Werte werden vor jeder Auswertung übersprungen. Bei gesperrtem Zugriff laufen zuletzt bekannte Timer bis zu ihrem bekannten Ablauf weiter. Neue Buffs oder vorzeitiges Entfernen können während der Sperre nicht zuverlässig erkannt werden. Automatische erneute Abfrage nach spätestens 0,5 Sekunden und nach Kampfende. Regressionstests decken Zugriffssperren, geheime Felder, Ablauf und Wiederherstellung ab.

Version 1.0.2: Proportionale Größenänderung über den Kreis im Unlock-Modus; feste Balkenabstände. Lua-Regressionstests prüfen Größenfaktor, Grenzen, Kreisposition, Loslassen außerhalb des Kreises und Sperren während des Ziehens.

Version 1.0.3: Breite und Höhe sind unabhängig einstellbar und werden getrennt gespeichert. Die bisher gespeicherte proportionale Größe wird für beide Dimensionen übernommen. Lua-Tests für unabhängige Achsen, feste Abstände und bestehende Buff-Funktionen bestanden.

Version 1.0.4: Absteigende Sortierung nach Restdauer und nach oben wachsender Stapel mit festem unterstem Balken. Lua-Tests prüfen neue Buffs, Ablauf, feste Basisposition und unveränderte Balkenabstände.

Version 1.0.6: Buff-Namen enden spätestens in der Balkenmitte. Längere Namen werden anhand der tatsächlichen Textbreite gekürzt und mit `...` abgeschlossen. Umlaute und andere UTF-8-Zeichen bleiben vollständig; nach Größenänderungen wird die Kürzung neu berechnet. Lua-Tests für Textbreite, kurze Namen, UTF-8 und Größenänderungen bestanden.

Version 1.0.7: Echte Buff-Balken werden nur bei einem lebenden, angreifbaren Ziel angezeigt. Timer laufen während der ausgeblendeten Anzeige weiter. Testbalken und Ziehkreis bleiben im Unlock-Modus verfügbar. Lua-Tests für Zielwechsel, freundliche/tote Ziele, geheime Zielwerte und unveränderte Restlaufzeit bestanden.

Version 1.0.8: Eigene Siegel starten über UNIT_SPELLCAST_SUCCEEDED einen Timer, auch wenn die Aura-Abfrage im Kampf gesperrt ist. Erneutes Wirken aktualisiert den Timer; ein anderes Siegel ersetzt das bisherige. Die Laufzeit wird aus lesbaren Siegel-Buffs gelernt und gespeichert; ohne Messwert werden zunächst 30 Sekunden angenommen. Sobald die Aura wieder lesbar ist, werden Laufzeit und Entfernung mit dem tatsächlichen Buff abgeglichen. Ein partieller geheimer Snapshot löscht bekannte Buffs nicht mehr. Vorzeitiges Entfernen oder geänderte Laufzeiten sind während gesperrter Aura-Daten nur eingeschränkt erkennbar. Regressionstests für gesperrte Aura-Abfragen, erneutes Wirken, Siegelwechsel, gelernte Laufzeiten, Ablauf und Abgleich bestanden; Live-Beta-Test steht aus.

Version 1.0.9: Bei höchstens 30 % verbleibender Gesamtdauer wird die Füllung orange. Über 30 % ist sie goldfarben; erneutes Wirken stellt die Farbe entsprechend zurück. Das Blinken in den letzten drei Sekunden bleibt erhalten. Lua-Tests für den Grenzwert und erneutes Wirken bestanden.

Version 1.1.0: Laufende Cooldowns gelernter Paladin-Zauber (z. B. Judgement) erscheinen als eigene Balken mit hellblauer Füllung und hellblau getöntem Hintergrund. Der globale Cooldown wird ausgefiltert. Buffs und Cooldowns werden gemeinsam nach absteigender Restdauer sortiert und wachsen nach oben; die unterste Position bleibt fixiert. Cooldowns bleiben hellblau und blinken während der letzten drei Sekunden, anschließend verschwinden sie. Wie Buffs erscheinen sie nur bei einem lebenden, angreifbaren Ziel. Einer der drei Testbalken zeigt die Cooldown-Farbe.

Cooldown-Daten werden bei Änderungen und alle 0,5 Sekunden aktualisiert. Bei gesperrten Daten verwendet ein eigener erfolgreicher Zauber eine zuvor gelesene Cooldown-Dauer oder die Basisdauer des Clients als Schätzung. Lesbare Daten korrigieren den Timer und erkennen vorzeitige Resets. Talent-/Ausrüstungsänderungen oder Resets sind während einer Datensperre nur eingeschränkt erkennbar. Lua-Tests für Judgement, GCD-Filter, Farbe, Blinken, Ablauf, Combat-Fallback, gleichzeitige Buff-/Cooldown-Balken, Sortierung, Zielwechsel und modernes Zauberbuch bestanden. Live-Beta-Test steht aus.

Version 1.1.1: Nur Buffs mit einer Gesamtdauer von höchstens 60 Sekunden werden angezeigt, einschließlich geschätzter Siegel-Timer. Längere Buffs bleiben auch dann ausgeblendet, wenn ihre Restdauer unter eine Minute sinkt. Cooldown-Balken sind von dieser Grenze ausgenommen. Tests für den Grenzwert, lange Buffs nahe Ablauf, Siegel-Abgleich und lange Cooldowns bestanden.
