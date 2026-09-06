# Changelog

## 0.10.0

- Added The Twin Fangs Heroic intermission to the encounter selector: Vile Flood warnings and rotating beam, Sanguine Storm impacts, and lingering Congealed Gore.
- Added native Vexhul and Ithraz models, the client Vile Flood effect, and visible ground warnings that remain usable while models load.
- Added repeatable/random attempts, separate scores, mistake replay and an assisted retry of the intermission.
- Preserved the shared movement and camera input. No other addon is required.
- Documented spell timings and the beam, arena and impact-pattern parameters still awaiting live calibration.
- Offline mechanics, renderer and menu regression checks cover the new encounter; live-client visual acceptance remains pending.

## 0.9.2

- Fixed startup errors when MidnightSimpleUnitFrames is not installed: all menu fonts now use the WoW client standard font for the active language.
- Added standalone UI regression coverage that rejects external font paths.

## 0.9.1

- Simplified project documentation and removed obsolete comparison diagnostics.
- Training mechanics and camera controls are unchanged.

## 0.9.0 - First public release

- Three solo 3D drills: Rashok, Sszorak Tempest and Entombed Sentinels Mythic intermission.
- Fullscreen and windowed modes, WoW-style movement and mouse camera controls.
- Randomized attempts, repeatable and daily seeds, practice options and local high scores.
- Sentinels: random 1/2/3 assignment, strict contact matching, required self-ping plus jump for player 1s, and center-avoiding NPC 3 routes.
- English interface and translation support.
- Complete runtime source, offline regression suites and build tools.
- Compact runtime package with client-native 3D assets and original generated textures.
