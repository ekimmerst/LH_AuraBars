# MiniBars

Paladin-, Schurken-, Krieger- und Hexer-Buff- und Cooldown-Balken für WoW Forever Beta (Interface 16001). Buffs erscheinen erst bei weniger als drei Minuten Restlaufzeit, unabhängig von ihrer Gesamtdauer. Dies gilt auch für Talent-Procs und empfangene Buffs bei Schurken, Kriegern und Hexern sowie geschätzte Paladin-Siegel. Permanente Auren werden ausgeblendet. Cooldowns erscheinen unabhängig von ihrer Restlaufzeit. Die Anzeige setzt ein lebendes, angreifbares Ziel voraus. Laufzeiten stammen aus den aktiven Buffs des Clients. Bekannte Paladin-Fähigkeiten werden über lokalisierte Zaubernamen erkannt, neue Fähigkeiten zusätzlich aus den Klassenabschnitten des Zauberbuchs. Bei allen vier unterstützten Klassen werden Cooldowns aktiver Fähigkeiten aus den Klassenabschnitten und dem allgemeinen Zauberbuchabschnitt automatisch erfasst, einschließlich Volksfähigkeiten und unabhängig von Rang und Clientsprache. Zeitlich begrenzte Buffs dieser Volksfähigkeiten werden ebenfalls angezeigt.

Die Spielergruppe erscheint rechts neben der Bildschirmmitte. Eine zweite Gruppe links neben der Bildschirmmitte zeigt zeitlich begrenzte Buffs und Debuffs des aktuellen Ziels, auch auf freundlichen Zielen und unabhängig vom Wirker. Auf Clients mit der nativen AuraContainer-API verwaltet der Client selbst Auren, Namen, Icons, Restzeit und Füllstand; MiniBars liest ihre geschützten Daten nicht aus. Permanente Auren bleiben ausgeblendet. Ziel-Buffs sind goldfarben, Ziel-Debuffs rot. Beim Zielwechsel aktualisiert der Client die Anzeige. Ohne native API bleibt die bisherige Abfrage als Fallback bestehen; diese kann bei geschützten Zielauren gesperrt sein.

Die Zuordnung richtet sich nach der betroffenen Einheit, nicht nach dem Wirker: Gruppe 1 zeigt ausschließlich Buffs und Debuffs auf `player` sowie die Cooldowns der eigenen Fähigkeiten. Auch empfangene Buffs werden beim Paladin berücksichtigt. Spieler-Debuffs sind rot und verwenden, sofern verfügbar, einen eigenen nativen AuraContainer oberhalb der Spieler-Buffs und Cooldowns; andernfalls werden sie über `HARMFUL` auf `player` gelesen. Native Spieler-Debuffs erscheinen für jede positive Gesamtdauer, ohne Dreiminutengrenze oder Blinken. Die bestehende Voraussetzung eines lebenden angreifbaren Ziels für die Spieleranzeige bleibt erhalten. Gruppe 2 bindet ausschließlich `target`. Eigene auf dem Target liegende Debuffs gehören daher in Gruppe 2. Echte Cooldowns fremder Einheiten sind über die verwendete Client-API nicht verfügbar und werden nicht geschätzt oder durch Spieler-Cooldowns ersetzt. Aura-Restzeiten sind keine Fähigkeits-Cooldowns.

Die native Zielanzeige zeigt alle zeitlich begrenzten Auren, auch über drei Minuten Restzeit. Die API bietet hier nur einen Filter nach Gesamtdauer, keinen nach Restzeit. Debuffs stehen im unteren, Buffs im oberen Block; innerhalb jedes Blocks stehen die längeren Restzeiten oben. Das bisherige Blinken unter drei Sekunden und die dynamische orange Warnfarbe entfallen für native Zielauren. Die Spielergruppe und die Testbalken behalten ihr bisheriges Verhalten.

Breite, Smooth-Textur und Rahmen entsprechen MiniExpBar. Die Schriftgröße bleibt für Namen und Zeitangaben bei 12 mit Kontur, genau wie in MiniExpBar, unabhängig von der Balkengröße. Die Textur liegt auch in MiniBars, sodass MiniExpBar nicht zwingend aktiviert sein muss. Beide Gruppen wachsen nach oben; die Position des untersten Balkens bleibt beim Hinzufügen und Entfernen fixiert. Die Spielergruppe sortiert nach absteigender Restdauer und blinkt in den letzten drei Sekunden. Ausgelaufene oder entfernte Auren verschwinden.

- `/minibars unlock`: je drei dauerhafte Testbalken für Spieler und Ziel anzeigen, auch ohne Ziel. Jede Gruppe mit linker Maustaste separat verschieben. Rechts unterhalb jeder Gruppe erscheint ein kleiner Kreis: mit linker Maustaste gedrückt halten und ziehen, um ihre Breite und Höhe unabhängig zwischen 50 % und 200 % der Standardgröße zu ändern: horizontal für die Breite, vertikal für die Höhe. Die Balken schließen vertikal direkt aneinander an, die Schriftgröße bleibt bei 12. Links neben jedem Balken steht das passende quadratische Icon mit 3 UI-Einheiten Abstand und derselben Höhe wie der Balken.
- `/minibars lock`: beide Gruppen fixieren und Testbalken ausblenden.
- `/minibars synch on`: Breite und Höhe beider Gruppen synchronisieren. Beim Einschalten übernimmt die Zielgruppe die aktuelle Größe der Spielergruppe. Danach werden Größenänderungen an jeder der beiden Gruppen sofort auf die andere übertragen; ihre Positionen bleiben unabhängig.
- `/minibars synch off`: Breite und Höhe wieder separat einstellen (Standard). Die Einstellung wird pro Charakter gespeichert.
- `/minibars reset`: Standardbreite (wie MiniExpBar), Standardhöhe (20 UI-Einheiten) und Standardpositionen beider Gruppen wiederherstellen. Der aktuelle Sperrstatus bleibt erhalten.

Position und Größe werden je Gruppe separat pro Charakter gespeichert; der Sperrstatus gilt für beide Gruppen. Nach der Installation den Client vollständig neu starten und MiniBars in der AddOn-Liste aktivieren.

Validierung: Lua-5.1-Tests mit simulierten WoW-APIs für Sortierung, Restzeit, Füllstand, Blinken, Entfernen, Testbalken, Sperre, Breite und Position. Ein Live-Test in der Beta steht aus.

## Changelog

### 1.5.3 — 2026-10-15

- Respect readable ready/GCD results after casts instead of starting cached cooldown estimates. An explicit zero base cooldown also prevents stale cached timers when live cooldown data is unavailable.
- Added regression coverage for Corruption and Immolate, stale saved durations, GCD-only results and real cooldown fallbacks. Warlock and unit ownership tests pass; the fix was also confirmed in the live beta client.

### 1.5.2 — 2026-10-15

- Hide the native target aura container immediately when no target exists. Restore and refresh it when a target is acquired, including friendly targets. Unlock previews remain usable without a target.
- Added regression coverage for clearing/reacquiring targets, polling while untargeted and locking/unlocking without a target.

### 1.5.1 — 2026-10-15

- Added player debuffs, using a native container bound only to `player` when available and a separate harmful-aura scan otherwise. Native debuffs stack above the player's existing bars and follow player size and preview visibility.
- Include all readable timed buffs on the player, including received Paladin buffs; caster identity does not determine group ownership.
- Verified that player cooldowns cannot enter the target group and target casts cannot start player cooldowns. Foreign unit cooldowns remain unavailable through the cooldown API.
- Added unit ownership and cooldown isolation tests; extended native tests to cover separate player/target unit bindings and independent sizing.

### 1.5.0 — 2026-10-15

- Reimplemented target rendering with Blizzard's native `AuraContainer` / `CustomAuraContainerTemplate`, following the integration approach inspected in [EllesmereUI AuraKit](https://github.com/EllesmereGaming/EllesmereUI/blob/main/EllesmereUI_AuraKit.lua). This is an independent implementation using Blizzard's public registration API, with no EllesmereUI dependency or bundled EllesmereUI code.
- Register `SetIcon`, `SetSpellName`, `SetDurationBar` and `SetDurationText` during frame initialization. The client owns aura assignment, removal, timers, filtering, sorting and layout, including while direct addon aura queries are denied.
- Native target groups preserve separate saved position/size, upward growth, red debuffs, gold buffs, fixed fonts and preview mode. Resize uses group layout settings and owned regions, avoiding restricted aura-button mutations.
- Native API limitations: all timed target auras are shown; expiration sorting is per buff/debuff block; native target bars do not use the former three-second blink or orange warning color. Legacy target rendering remains available on clients without the native module.
- Added native-backend tests for denied aura reads, restricted buttons, registration, resize, previews, reset and initialization failure diagnostics. Live beta validation remains pending.

### 1.4.4 — 2026-10-15

- Added `/minibars debug` to report target debuff API availability, errors, counts, readable fields and hidden fields in chat. Run while the target has a debuff to diagnose the live beta client; no hidden values are converted or compared.

### 1.4.3 — 2026-10-15

- Retry indexed and legacy queries when the batch aura API returns an empty list; a nil indexed response also permits legacy fallback. Harmful queries never fall back to UnitBuff.
- Show confirmed own Warlock Corruption, Curse of Agony, Immolate, Siphon Life and Curse of Doom with estimated timers when the client exposes the aura but omits its timer. Estimates start at first observation, use baseline durations (including early Corruption ranks), and yield to readable client timers. Reapplications with a new aura instance restart the estimate; refreshes without a new instance and talent-modified durations require readable timers for accuracy. Fully hidden auras remain unavailable.
- Added regression tests for missing Warlock timers, empty batch responses, nil indexed responses, countdown continuity, removal and real timer replacement.

### 1.4.2 — 2026-10-15

- Added `/minibars synch on|off` to synchronize group width and height while keeping positions independent; defaults to off and persists per character.
- Fall back to indexed and legacy aura queries when the batch API is unavailable. Target auras no longer require readable spell IDs when their names and timers are readable.
- Retain known target timers through incomplete/restricted scans without carrying them across target changes. Fully hidden newly applied auras still require readable client data.
- Added target aura regression coverage for Paladin, Rogue, Warrior, and Warlock, plus synchronization and reload tests.

### 1.4.1 — 2026-10-15

- Removed the 3-unit vertical gap between bars in both groups.
- Show aura and spell icons to the left of each bar with a 3-unit gap; square icons follow the independently adjustable bar height.

### 1.4.0 — 2026-10-15

- Added a separate target buff/debuff group with independently saved position, width, and height; unlock shows previews and resize handles for both groups.
- Target auras support modern and legacy APIs, include all casters and friendly targets, and clear on target changes.
- Keep all bar labels at MiniExpBar's original font size of 12 when resizing.

### 1.3.4 — 2026-10-15

- Start a Bloodfury buff timer on successful cast when combat restrictions hide aura data. Readable auras replace the estimate and confirm early removal; the fallback lasts 15 seconds unless an observed duration is available.

### 1.3.3 — 2026-10-15

- Include the General spellbook section when discovering cooldowns, enabling racial abilities such as Bloodfury.

### 1.3.2 — 2026-10-15

- Added Warlock support: automatically discover learned class abilities and track their cooldowns, temporary player buffs, talent procs, and received buffs.

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
