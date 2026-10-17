# MiniAuraBars

Buff and spell cooldown bars for Paladins, Rogues, Warriors, Warlocks, Priests and Hunters in WoW Forever Beta (Interface 16001). Buffs appear when at most three minutes remain, regardless of their total duration. This includes talent procs, received buffs and estimated Paladin seals. Permanent auras are hidden. Cooldowns appear regardless of remaining time. The player display requires a living, attackable target. Buff durations come from the client's active auras. Localized spell names cover known Paladin abilities and their ranks; class spellbook sections provide additional abilities. Active ability cooldowns are discovered from class and General spellbook sections for all six supported classes, including racial abilities, regardless of rank or client language. Timed racial buffs are also shown.

The player group appears to the right of the screen center. A second group on the left shows timed buffs and debuffs on the current target, including friendly targets and auras from any caster. When the native AuraContainer API is available, the client manages debuffs, names, icons, remaining time and bar fill; buffs use readable aura queries to enforce the remaining-time threshold. Permanent auras remain hidden. Target buffs are gold and target debuffs are red. The client updates the display when targets change. Older aura queries remain available as a fallback where the native API is unavailable; protected target auras may block these queries.

Groups follow the affected unit: group 1 shows buffs and debuffs on `player` and the player's own ability cooldowns, including buffs received from other players. Player debuffs are red and use a separate native AuraContainer above buffs and cooldowns when available; otherwise they use `HARMFUL` queries on `player`. Native player debuffs appear for any positive total duration, without the three-minute threshold or blinking. The player display still requires a living, attackable target. Group 2 binds only to `target`, including the player's debuffs on that target. Other units' actual cooldowns are unavailable through the client API and are not estimated or replaced with player cooldowns. Aura timers represent remaining aura duration.

Player and target buffs use readable aura timers and appear only at 180 seconds remaining or less, regardless of total duration. Buffs with protected, unreadable timers cannot be newly displayed. Native containers remain responsible for debuffs; native debuffs retain their full-duration display.

Width, Smooth texture and borders match MiniExpBar. Names and timers use an outlined 12-point font regardless of bar size. The texture is bundled with MiniAuraBars, so MiniExpBar does not need to be enabled. Both groups grow upward, keeping the bottom bar fixed as bars appear and disappear. Player bars sort by descending remaining duration and blink during the final three seconds. Expired or removed auras disappear.

- `/miniaurabars unlock`: show three persistent preview bars per group, even without a target. Player and Target headers appear 8 UI units above their groups while unlocked and disappear when locked. Left-drag each group to move it independently. Left-drag the small circle below the right side of each group to resize width horizontally and height vertically, independently between 50% and 200% of the default size. Bars touch vertically and retain the 12-point font. Each bar has a square icon on its left, matching its height with a gap of 3 UI units.
- `/miniaurabars lock`: lock both groups and hide preview bars.
- `/miniaurabars synch on`: synchronize group width and height. The target group initially adopts the player group's size; subsequent resizing of either group updates both. Positions remain independent.
- `/miniaurabars synch off`: resize groups independently (default). Saved per character.
- `/miniaurabars reset`: restore default width (matching MiniExpBar), height (20 UI units) and positions for both groups. The lock state is preserved.
- `/miniaurabars debug`: print target aura API diagnostics in chat.

Position and size are saved separately for each group and character; both groups share the lock state. After installation, fully restart the client and enable MiniAuraBars in the AddOn list. Settings use the per-character `MiniAuraBarsDB` saved variable.

Validation: Lua 5.1 tests with simulated WoW APIs cover sorting, remaining time, bar fill, blinking, removal, preview bars, locking, width and position. The three-minute buff threshold was confirmed working in the live beta client on 2026-10-17.

All supported classes use the same remaining-time filter for player buffs. Native player and target debuffs remain supported, including protected auras. Cooldowns retain their existing display.

## Changelog

### 1.5.9 - 2026-10-17

- Show player and target buffs only when their remaining duration is 180 seconds or less, including exactly 180 seconds, for all six supported classes. Long buffs enter the display automatically as their timers cross the threshold; permanent buffs remain hidden.
- Use readable buff timers instead of native helpful-aura containers, whose filters only support total duration. Newly encountered buffs with protected, unreadable timers cannot be displayed reliably. Native player and target debuffs retain their existing behavior, and cooldowns remain independent of the buff threshold.
- Place native target debuffs above the target buff rows to prevent overlap.
- Updated boundary and native-mode regression coverage. All simulated Lua 5.1 regression tests pass; the user confirmed the behavior working in the live beta client.

### 1.5.8 - 2026-10-16

- Rogue player buffs now use the native aura container when available, including protected timed buffs and talent procs. Player debuffs, automatic discovery of learned abilities/ranks/talents/beta spells and target auras remain supported; legacy aura queries remain the fallback. Permanent Stealth remains hidden.
- Expanded Rogue cooldown and incoming debuff tests and native coverage with all direct aura reads denied. Native Rogue buffs follow the full-duration native display rules described above. Live beta validation is pending.

### 1.5.7 - 2026-10-16

- Added Hunter spellbook discovery for learned abilities, ranks, talents, racial abilities and beta spells. Hunter player buffs and debuffs use native aura containers when available, with the existing legacy fallback. Target buffs and debuffs remain class-independent.
- Added Hunter legacy/modern spellbook, cooldown, buff, proc, debuff and native protected-aura regression coverage. All simulated Lua 5.1 regression tests pass. Permanent aspects remain hidden. Pet-unit auras and pet ability cooldowns are outside the existing player/target groups. Live beta validation is pending.

### 1.5.6 - 2026-10-16

- Route Priest player buffs through the native player AuraContainer alongside debuffs, avoiding direct reads of protected Renew/aura fields. Refresh the player container on player aura events and retain its explicit player binding.
- Avoid duplicate legacy buff bars; preserve cooldowns, enemy-target visibility and the fallback for clients without native aura support.
- Added self-cast Renew application/refresh/removal tests and native Priest coverage with all aura queries denied. Simulated checks pass; live beta confirmation is pending.

### 1.5.5 - 2026-10-16

- Added Priest support to automatic class and General spellbook discovery, including learned ranks, talents, racial abilities and beta spells. Timed buffs, procs and player/target debuffs use the existing class-independent aura handling and visibility rules.
- Added Priest regression coverage for legacy/modern spellbooks, cooldowns, GCD exclusion, buffs, procs, player debuffs and target aura fallbacks. Simulated Lua 5.1 checks pass; live beta validation is pending.

### 1.5.4 — 2026-10-16

- Reassert each native container's explicit player/target binding during rendering and after visibility changes; refresh player debuffs when shown again.
- Explicitly refresh native target auras on every target change, including switches between two visible targets.
- Added regression scenarios for a changed unit binding during show, locking previews, and refreshing an already visible target. The reported cross-group display was clarified as swapped groups by the user.
- Added Player and Target headers above unlocked groups; confirmed working in the live client.
- Moved Python test scripts into `_tests` with script-relative paths.

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

- Added `/miniaurabars debug` to report target debuff API availability, errors, counts, readable fields and hidden fields in chat. Run while the target has a debuff to diagnose the live beta client; no hidden values are converted or compared.

### 1.4.3 — 2026-10-15

- Retry indexed and legacy queries when the batch aura API returns an empty list; a nil indexed response also permits legacy fallback. Harmful queries never fall back to UnitBuff.
- Show confirmed own Warlock Corruption, Curse of Agony, Immolate, Siphon Life and Curse of Doom with estimated timers when the client exposes the aura but omits its timer. Estimates start at first observation, use baseline durations (including early Corruption ranks), and yield to readable client timers. Reapplications with a new aura instance restart the estimate; refreshes without a new instance and talent-modified durations require readable timers for accuracy. Fully hidden auras remain unavailable.
- Added regression tests for missing Warlock timers, empty batch responses, nil indexed responses, countdown continuity, removal and real timer replacement.

### 1.4.2 — 2026-10-15

- Added `/miniaurabars synch on|off` to synchronize group width and height while keeping positions independent; defaults to off and persists per character.
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
