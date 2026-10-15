# MiniBars

Paladin-, Schurken- und Krieger-Buff- und Cooldown-Balken für WoW Forever Beta (Interface 16001). Buffs erscheinen erst bei weniger als drei Minuten Restlaufzeit, unabhängig von ihrer Gesamtdauer. Dies gilt auch für Talent-Procs und empfangene Buffs bei Schurken und Kriegern sowie geschätzte Paladin-Siegel. Permanente Auren werden ausgeblendet. Cooldowns erscheinen unabhängig von ihrer Restlaufzeit. Die Anzeige setzt ein lebendes, angreifbares Ziel voraus. Laufzeiten stammen aus den aktiven Buffs des Clients. Bekannte Paladin-Fähigkeiten werden über lokalisierte Zaubernamen erkannt, neue Fähigkeiten zusätzlich aus den Klassenabschnitten des Zauberbuchs. Schurken- und Krieger-Cooldowns werden für alle aktiven Fähigkeiten dieser Klassenabschnitte automatisch erfasst, unabhängig von Rang und Clientsprache.

Die Balken erscheinen rechts neben der Bildschirmmitte. Breite, goldene Farbe, Smooth-Textur und Rahmen entsprechen MiniExpBar. Die Textur liegt auch in MiniBars, sodass MiniExpBar nicht zwingend aktiviert sein muss. Die Balken sind von oben nach unten nach absteigender Restdauer sortiert. Der Buff mit der längsten Restdauer steht oben. Der Stapel wächst nach oben; die Position des untersten Balkens bleibt beim Hinzufügen und Entfernen fixiert. In den letzten drei Sekunden blinkt der Balken; ausgelaufene oder entfernte Buffs verschwinden.

- `/minibars unlock`: drei dauerhafte Testbalken anzeigen und den gesamten Stapel mit linker Maustaste verschieben. Echte Buffs sind bei einem angreifbaren Ziel sichtbar. Die drei Testbalken erscheinen auch ohne Ziel. Rechts unterhalb des Stapels erscheint ein kleiner Kreis: mit linker Maustaste gedrückt halten und ziehen, um Breite und Höhe unabhängig zwischen 50 % und 200 % der Standardgröße zu ändern: horizontal ziehen für die Breite, vertikal für die Höhe. Der Abstand bleibt bei 3 UI-Einheiten.
- `/minibars lock`: Position fixieren und Testbalken ausblenden.
- `/minibars reset`: Standardbreite (wie MiniExpBar), Standardhöhe (20 UI-Einheiten) und Standardposition (rechts neben der Bildschirmmitte) wiederherstellen. Der aktuelle Sperrstatus bleibt erhalten.

Position, Größe und Sperrstatus werden pro Charakter gespeichert. Nach der Installation den Client vollständig neu starten und MiniBars in der AddOn-Liste aktivieren.

Validierung: Lua-5.1-Tests mit simulierten WoW-APIs für Sortierung, Restzeit, Füllstand, Blinken, Entfernen, Testbalken, Sperre, Breite und Position. Ein Live-Test in der Beta steht aus.

## Changelog

### 1.3.1 — 2026-10-15

- Added Rogue and Warrior support: track temporary player buffs, talent procs, received buffs, and cooldowns of learned class abilities.
- Buff bars now appear only when less than three minutes remain, for all supported classes. Long buffs automatically appear as they approach expiration.
- Cooldowns remain visible regardless of their remaining duration; the global cooldown is excluded.
- Permanent buffs, including stances and Stealth, remain hidden.

### Initial release — 2026-10-14 (commit c72b9ba)

The first commit includes the features developed through version 1.1.1:

- Added Paladin buff and spell cooldown bars styled to match MiniExpBar, with a bundled texture so MiniExpBar is optional.
- Added movable preview bars, position locking, and a reset command. Position, size, and lock settings are saved per character.
- Added resizing with a drag handle, followed by independent width and height adjustment from 50% to 200% of the default size.
- Sorted bars by remaining time, with the longest timer at the top and a fixed bottom position as the stack grows upward.
- Shortened long buff names to keep timers readable while preserving accented characters.
- Showed active bars only while targeting a living enemy; preview bars remain available without a target.
- Improved timer continuity when the game temporarily restricts buff or cooldown information. Paladin seals can start estimated timers on cast and update when their actual duration becomes available.
- Turned buff bars orange when 30% or less of their duration remains and made bars blink during the final three seconds.
- Added light-blue Paladin cooldown bars, including Judgement, with automatic removal after expiration and updates when cooldowns reset.
- Initially limited Paladin buffs to a total duration of 60 seconds. Version 1.3.1 replaces this with the remaining-time rule above.
