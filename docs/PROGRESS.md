# Project Klax progress

## Editable source delivery, 22 October 2026

Added an explicit `ProjectKlax-Godot-Source.zip` release download and README import instructions. The archive contains the tracked Godot project, scenes, scripts, assets, tests and provenance, without exported game binaries. The release workflow rebuilds and uploads it with a separate SHA-256 checksum. `project.godot` remains at the repository root for cloning or GitHub's source ZIP download.

## 0.1 initial campaign, 22 October 2026

The empty destination repository now contains a Godot 4.7.2 game with a mission deck, six planetary survey regions, twelve species, specimen analysis, equipment progression and two ending recommendations. The initial scope is one connected research campaign.

### Implemented

- Expedition loop: deploy, observe, sample, recover sites, return to the lander, analyze and upgrade. Failed expeditions preserve observations and earlier progress but lose their carried cargo and uncommitted site rewards.
- Six compact worlds with separate routes, barriers, landmarks, terrain and color palettes. Each has fifteen creatures, three ruins, three supply caches and one relay. Five recovered relays reveal the final planet.
- Passive, shy, territorial and predatory behavior, visible attack windups, nonlethal stun pulses, temporary lures, equipment charge, oxygen, health and two deployable recovery stations per expedition.
- A bounded habitat grid with delayed neighboring spore spread, disturbance, quiet recovery and habitat scoring that affects wildlife movement. Zen's seeded weather drives exposure and visibility.
- A six-wheel rover adapted from ASCII Racer's handling. Drift, boost, charge depletion and asymmetric module damage affect travel. The research carrier retains Barrel Roll's animated hull and doors.
- Zendelves creature geometry and articulated gait, converted into native Godot meshes with a researcher, twelve species identities and six underlying creature families.
- Three specialist choices and six upgrade lines, each with three levels. Sample capacity matters because distinct individuals provide comparative material as well as species unlocks.
- Tactical survey at 12% speed with three orders, a radar, field journal, pause menu, field manual, sound toggle and fullscreen control.
- An original 6×6 microscope match-three assay. Normal analysis is available without earning the optional puzzle bonus. Cat Jewler source was not found.
- Campaign saves with validation, a previous valid backup and numeric-ID normalization after JSON reload. No mid-field save is claimed.
- A final council decision after the sixth relay, both final-world observations and six analyzed species. Either ending permits continued research.

### Verification recorded so far

`docs/campaign-verification.txt` records **182 passing checks** against the actual main scene. Coverage includes six-world campaign construction, cargo and extraction, emergency rescue, research and upgrades, tactical orders, rover behavior and save recovery through a test-specific path.

Focused Godot suites exercise ecology, vehicles and the assay. The HUD's mission deck, field view, journal, lab and overlays were instantiated headlessly at 1280×800; their measured containers fit that viewport. World connectivity checks use the same collision query as gameplay. Such checks establish construction and reachability, not visual quality or human playability.

The actual Web export passed **17 browser checks** with no recorded browser or engine errors. Ordinary keyboard and mouse input covered launch, walking, scanning, live collection, tactical mode, pause, journal navigation, extraction, opening and cancelling an assay, normal analysis, reload persistence, boarding, boosted driving and dismounting. [The result file](web-verification.json) retains the checks and observed state. Screenshots in `docs/screenshots` come from this run. This is an automated browser smoke test, not a human playthrough of every world.

Windows and Web packages are present in `releases`, with [SHA-256 checksums](../releases/SHA256SUMS.txt). The Windows executable was exported and packaged but was not run on Windows in this environment. The tested Web build used headless Chromium with software WebGL, so these checks do not establish hardware performance or compatibility with every browser.

### Current limits

The campaign persists research, equipment and extracted site state. Planet terrain, wildlife and ecology reset for each launch. The player cannot resume a sortie after closing the game. There is one local campaign, no controller/mobile interface and no multiplayer. The environment uses low-poly procedural assets; it has no full interior traversal, fluid tides, flight stage, voice acting or generated music soundtrack. Ambient sound is synthesized locally.

This build does not reproduce every system from the source games. Tilebean's province economy, Zen's complete RPG/class systems, ASCII Racer's tracks and multiplayer, and Barrel Roll's squad/ship combat remain outside Klax. The microscope assay is original code pending identification of Cat Jewler's source.

### Next useful work

Prioritize real playtest observations: first-expedition comprehension, dangerous-specimen collection, vehicle control on each route, and whether the finale asks for a satisfying amount of field research. Then expand the ecology's visible consequences and the planets' encounter differences. A persistent mid-expedition save or additional planet content should follow a deliberate scope decision, not be implied by this first version.
