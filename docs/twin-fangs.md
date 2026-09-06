# Twin Fangs: Heroic intermission

This standalone drill starts when Vexhul prepares Vile Flood in the center. Ithraz
casts Sanguine Storm from the edge. It includes the final blood pools, ending at
24 seconds. It does not simulate Submerge, the main phase, health, healing or
Eternal Venom stacks. Any hazard contact fails the clean dodge attempt; this is
an exercise rule, not a claim that one hit immediately wipes the actual raid.

## Spell data checked on 2026-09-06

| Value | Evidence |
| --- | --- |
| Flood: 4-second cast, 14-second frontal channel | [Vile Flood, 1294293](https://www.wowhead.com/spell=1294293/vile-flood?dd=15) |
| Storm: 18 seconds, 4-yard impacts | [Sanguine Storm, 1306872](https://www.wowhead.com/spell=1306872/sanguine-storm?dd=15) |
| Heroic Storm pools: 6 seconds | [Vexhul encounter journal](https://www.wowhead.com/npc=257361/vexhul) |
| Sweep direction indicated by orbiting effects; less than a full revolution | [Method Heroic strategy](https://www.method.gg/guides/the-venomous-abyss/the-twin-fangs-heroic) |

The published spell descriptions establish these durations. The drill aligns
the Storm with the beginning of Flood's preparation; that relative start still
needs a live recording check.

## Training parameters awaiting live calibration

- Open circular stone platform: 42-yard radius; not the actual raid WMO.
- Flood: 12-degree cone, 270-degree sweep; player collision margin 0.55 yards.
- Seeded initial facing, player position and rotation direction. The real
  encounter's allowed directions and selection rules still need confirmation.
- Four impacts every 1.5 seconds, with 1.5 seconds of warning. One impact in
  each volley baits the simulated player; the others use seeded positions.
- Six-second pools use the same 4-yard footprint as impacts. Pool radius is a
  training choice, separate from the documented impact radius.
- Boss model scale, beam attachment and visual size require in-game review.

Parameters live in `work/EncounterLab/TwinFangs.lua`. Gameplay and camera input
remain in the existing shared modules. The warning sector and rings are always
visible, including in Normal and while native effects load.

## Client assets

No model files are distributed with the addon. Native display IDs were checked
against the NPC pages' model-viewer metadata:

- [Vexhul](https://www.wowhead.com/npc=257361/vexhul): display 140993.
- [Ithraz](https://www.wowhead.com/npc=257368/ithraz): display 141309.

File IDs checked against the [WoW community listfile](https://github.com/wowdev/wow-listfile/releases/latest):

- 7948782: `spells/12fx_ulatekraid_thetwinfangs_vileflood_channel.m2`.
- 7752025: `spells/12fx_ulatekraid_thetwinfangs_taintedblood_areatrigger.m2`.
  This native blood effect represents gore visually; it is not presented as
  the verified Heroic Congealed Gore visual.

The model adapter uses the client actor template and documented actor methods,
checked against Blizzard UI source `upstream/live`, version 12.1.0.69587.

## Scoring and validation

Scores use the existing survival fraction and separate scenario-version boards.
Practice, pauses, revives, slowdown and retries are assisted. Interrupted runs
and arena exits stay out of ranked boards. Retry checkpoint returns to the start
of the intermission; mistake replay retains at most six seconds in memory.

Offline tests cover deterministic patterns, collision boundaries, phase timing,
movement parity, frame-rate variation, replay, persistence, preview/selection,
model-loading fallbacks, bounded renderer allocation and encounter switching.
They do not prove live rendering, camera feel or exact raid geometry.
