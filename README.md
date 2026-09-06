# EncounterLab

Practice raid mechanics inside World of Warcraft before your next pull.

EncounterLab is a standalone 3D training arena for **WoW Retail 12.1**. Open it with **`/el`**, choose an encounter, and start practicing. No raid group or other addon is required.

## Encounters

- **Rashok:** dodge lava waves and frontal attacks across three practice loops.
- **Sszorak:** practice Tempest tornado dodging, with different starting points and adjustable speed.
- **Entombed Sentinels (Mythic):** rehearse the Helical Toxins intermission with a simulated 20-player raid. Your number is randomly assigned each attempt. Only 1+3, 3+1 and 2+2 contacts clear; other active contacts wipe the raid. As a 1, use the dedicated **PING YOURSELF** button and jump after the reveal. The 2s meet in the center; simulated 3s take routes around it to find the 1s.

- **The Twin Fangs (Heroic):** practice the Vile Flood sweep together with Sanguine Storm impacts and lingering blood pools. Includes boss models, native Flood effects, repeatable seeds, local scores and mistake replay. Beam geometry and randomized patterns are training approximations.

## Features

- Native 3D models and effects, fullscreen or windowed arena.
- Familiar movement and mouse camera controls, using your WoW movement bindings and camera settings where supported. See **Controls** in the arena for the active bindings.
- Random attempts, repeatable seeds, daily seeds, practice speed and learning options.
- Local high scores, checkpoints and mistake replay where supported by the drill.
- English interface with a localization table ready for translations.

These are focused practice simulations, not complete boss encounters. Timings, room art and simulated raid behavior are approximations. All training happens in a private addon scene; this does not automate your live character or send real chat messages/pings. The arena closes when combat starts.

## Install

Download **EncounterLab-0.10.0.zip** from a release, extract the `EncounterLab` folder into `World of Warcraft/_retail_/Interface/AddOns/`, then restart WoW or reload the interface. Choose EncounterLab in the addon list and type `/el`.

Use the runtime ZIP for installation. The source ZIP and GitHub source download also include development tools.

## Build from source

Requirements: Lua 5.1 (`lua` and `luac` on PATH), Python 3.10+, and PowerShell. From the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File work/Build.ps1
```

The build runs the Lua syntax checks and offline regression suites, then writes the runtime ZIP, source ZIP and checksums to `outputs/`. Tests do not require WoW. They do not replace in-game visual or movement testing.

`work/EncounterLab/` contains the runtime source and original generated textures. `work/tests/` contains regression tests, including an anonymous mouse-displacement fixture. Texture generators require Pillow; generated runtime textures are already included. `work/Install.ps1` is an optional Windows upgrade helper requiring an explicit addon path and baseline manifest.


## Feedback and translations

Report issues at https://github.com/Mapkov2/EncounterLab/issues. Include the addon version, encounter, seed and steps to reproduce. Review logs before sharing them; full SavedVariables files are not needed for most reports.

Translation instructions are in `work/EncounterLab/Locales/README.md`.

## License and credits

Copyright 2026 Mapko. **All Rights Reserved**; see [LICENSE](LICENSE).

In-game assets remain part of the installed WoW client and belong to Blizzard Entertainment.
