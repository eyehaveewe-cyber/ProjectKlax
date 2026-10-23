# October playtest implementation

Project Klax 0.2 implements the Klax section of the supplied `Crunch_Time_Jam_Playtest_Notes_2026-10-22(1).docx`. The Foxlike and Project NVS sections concern separate games and were not applied to this repository. The source project remains editable in Godot 4.7.2 through the root `project.godot`.

| Playtest finding | Result in 0.2 |
| --- | --- |
| Sample handoff had no obvious object | A cyan, labeled deposit console stands beside the lander. Every deployed field station adds another. Press E beside it to transfer cargo, free the racks and save cultures. The ship lab explicitly lists deposited or extracted cultures. |
| Two species could be obtained too close to landing | The introductory organism remains near the lander. Every instance of the second species starts beyond 35 m, concentrated around the world's named habitat. The guidance names that destination and its distance. The habitat station supplies an additional recoverable research objective. |
| Bats and spiders did not feel alien | Twelve original procedural models replace all inherited wildlife. Their body plans include three-legged chambers, root wheels, mineral stilts, vertical sails, heat bells, segmented crescents, ceramic kilns, filtering mantles, salt wheels, living reefs, nutrient crowns and stacked memory plates. The inherited researcher remains. |
| Species needed different behavior | Striders align their normal movement with mineral axes; sails orbit their home resonator; mantles drift slowly over a wider area; bells and anchorbacks remain close to a host site; brine pilgrims alternate movement and rest; gardeners restore their nearby habitat. Ember carriers have a longer warning and faster charge. Existing calm, lure, stun, shy retreat and predator rules remain. |
| More reason to travel and more distinct places | Named remote habitat research, existing relay archives, service-tunnel caches and tether fissures give separate destinations. Glacial towers and a tidal listening gantry replace the shared orbital-ring landmark on the ice and sea worlds. Crossing placement reserves space around buildings and tunnel approaches. |
| More exploratory actions | C toggles a crouch with a smaller vertical profile through 0.9 m service passages. A low ceiling prevents standing. G starts an animated tether swing across a blocked fissure, with a working return swing. The rover stays on surface routes. |
| Discovery text interrupted roaming | Field messages use short action summaries and larger type. Full recovered transmissions and habitat observations are available in the journal. The lab explains collection, analysis and upgrade order. |
| Good rover feel and useful scan pressure | `scripts/klax_rover.gd` was not changed. Scanner duration, range, crew multiplier and upgrade formula were retained. |
| EXE did not replace editable source | A source-only ZIP includes scenes, scripts, assets, tests and provenance. CI imports and tests the actual project, then exports Windows, Web and source from the same commit. |

## What is saved

A sample initially occupies a rack in field cargo. E at a deposit console marks its species as sampled and available in the ship lab, awards its four provisional field research points, saves, and frees the rack. Several individuals of one species supply comparative field research but only one laboratory culture entry. A second press with empty racks gives no reward.

An emergency rescue loses cargo still in the racks and unextracted site or relay rewards. Observations, previously deposited cultures, their paid research and earlier progress survive. Depositing does not bank unrelated field rewards, unlock the ending, perform analysis or teleport the researcher. Returning to the lander and pressing X still secures carried cargo and site/relay data. Lab analysis and ship upgrades retain their original rules.

Version 0.1 saves keep the same filename and version. Missing habitat-survey data defaults to an empty list; loaded numeric IDs are normalized for progression. Web saves use the engine's asynchronous browser filesystem. The browser test permits that synchronization before reloading.

## Scope of the traversal pass

The passages and tether crossings are reusable prototypes on all six worlds. Standing and rover collision reject a low roof; only crouching permits entry. The fissure blocks walking and driving; its marked masts provide a safe swing in either direction, with a longer surface detour available. These are fixed-anchor crossings, not a free-aim grappling or climbing system. Crouch currently compresses the procedural researcher rather than using a bespoke crawl animation.

The notes described a compact rolling form and a multiplayer Metroidvania as possibilities. Neither is included in this pass. There are no extra planets, no ability-unlock tree and no multiplayer changes. This pass tests clearer field research and useful traversal inside the existing campaign.

## Verification

`tests/test_campaign.gd` passes 182 checks against the actual main scene. `tests/test_playtest.gd` passes 296 additional checks covering deposit rewards and capacity, rescue and reload safety, older saves, all six habitats, distinct anatomy, spawn collision, passage clearance, tether animation and return trips, field station consoles, and reachable interaction approaches to every site. Ecology, vehicle and assay suites also pass.

The route check flood-fills the actual standing collision field. It establishes reachable site approaches; it does not establish player enjoyment, navigation clarity for a new player, or performance on older hardware. 22 browser keyboard and mouse checks passed, covering deposit consoles, lab analysis, save reload, rover controls and crouch input. Browser results and rendered screenshots are recorded separately in `web-verification-v0.2.json` and `screenshots/`. Windows is exported but has not been executed on Windows.

Reproduce with Godot 4.7.2:

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/test_campaign.gd
godot --headless --path . --script res://tests/test_playtest.gd
godot --headless --path . --script res://tests/test_ecology.gd
godot --headless --path . --script res://tests/test_vehicles.gd
godot --headless --path . --script res://tests/test_assay.gd
python3 tools/package_release.py --godot godot
python3 tools/package_source.py
```

`tests/web_smoke.cjs` requires Playwright and Chromium. It drives ordinary keyboard and mouse input in the exported Web build. `CHROMIUM_EXECUTABLE` selects a browser executable; `CHROMIUM_SINGLE_PROCESS=1` supports environments that prohibit Unix sockets. QA telemetry supplies read-only state and collision geometry for navigation; it exposes no teleport or progression mutations.
