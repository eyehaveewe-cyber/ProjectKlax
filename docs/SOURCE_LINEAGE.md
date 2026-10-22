# Source lineage

Project Klax adapts real code from five of the requested existing projects. The implementation and original source snapshots are retained together so future changes can be traced. The source repositories were not modified.

| Requested project | Source inspected | Runtime integration in Klax |
| --- | --- | --- |
| Bean Tiles Project / Tilebean | `simulation/condition_spread.gd`, `natural_world.gd`, `tile_development.gd` at `4228a34233579ce36104d25739cdcdce1ef7bfc5` | `scripts/ecology.gd` adapts staged neighboring spread, habitat value minus disturbance, and sustained quiet recovery. Province roles, settlements and cargo economies are not imported. |
| Zen Elysium | `world/test_room_rng.gd` and `world/weather/rogue_lab_weather.gd` at `3932b0ba03910c4dd67e1c01499f69423593b694` | Unchanged runtime copies under `source-provenance/ecology` provide deterministic random rolls, a weather clock, weighted fronts and snapshots. Klax maps these to planetary exposure and visibility. |
| Zendelves | `lib/xen/actor-models.ts` and `lib/xen/renderer.ts` at `357aa0f77b0c8080074745e3f56b2a7a78241d04` | Original model constructors generate the seven mesh JSON files under `assets/models`. `scripts/creature_models.gd` retains joint pivots and ports walk, tail and wing motion. Species colors, field identities and researcher additions are new. |
| ASCII Racer | `scripts/glyph_racer.gd` and `glyph_factory.gd` at `39218c040b8923379a2fa11f369c05557aefcb5c` | `scripts/klax_rover.gd` extracts exponential lateral grip, steering, drift release, boost depletion/recharge and overspeed decay. Its flank modules use the source's extruded TextMesh construction. Klax retunes speeds for a surface rover. |
| Project Barrel Roll | `scripts/carrier_hull.gd` at `17bda73b7763c5033cc19e945fd84b12019f0dc6` | `scripts/research_carrier.gd` retains the broad head, segmented tail, bridge, drive pods, rails and animated doors, adding expedition markings, sensors and landing equipment. |
| Cat Jewler | No identifiable source was found | No code is attributed to Cat Jewler. `scripts/assay.gd` is an original Klax microscope puzzle. |

## Exact records and regeneration

- [Ecology manifest](../source-provenance/ecology/manifest.json) records repository paths, commit IDs, blob hashes and whether each file is unchanged runtime code, an adaptation source or reference only. [Ecology notes](../source-provenance/ecology/README.md) explain the retained formulas.
- [Zendelves provenance](../source-provenance/zendelves/PROVENANCE.json) records model and renderer hashes. [Model notes](../source-provenance/zendelves/README.md) describe conversion, joint pivots and the mesh export command.
- [Vehicle notes](../source-provenance/VEHICLES.md) link the exact ASCII Racer and Barrel Roll files, document the handling changes and describe verification.
- [Cat Jewler search record](../source-provenance/cat/SEARCH_RESULT.md) states the inspected sources and the search limits. A repository URL, Site URL or source archive can resolve that missing contribution later.

The snapshots with `.gd.txt` extensions preserve original classes whose dependencies belong to other projects. They are not loaded as Godot scripts. Zen's two standalone `.gd` files are runtime dependencies and must remain in exported builds.

## New Klax work

The six worlds and their routes, xenobiology catalog, campaign narrative, observation/sample/extraction rules, specialist choices, research economy, tactical order system, UI, save format, synthesized sound and microscope assay were written for this game. They connect the reused pieces into one expedition loop.

Zen's progression file was inspected as a reference for explicit prerequisite and cost checks; it is not imported as the Klax upgrade system. Additional Zendelves aim, knockback, hazards and status files were inspected but are not included as whole runtime modules. Source research should not be mistaken for code reuse.

The twelve species use six inherited mesh families with Klax colors and identities. This is twelve gameplay catalog entries, not twelve wholly independent original model sets. The rover is a new six-wheel model around adapted driving math; changing Klax's handling does not alter ASCII Racer.

These records document authorship and reuse. They do not assign a new license to the source projects or claim that every source subsystem was ported.
