# Ecology sources

Project Klax uses code from the user's existing projects. These originals were fetched from the recorded commits before adaptation.

| Project and source path | Commit | Project Klax use |
| --- | --- | --- |
| Zen-Elysium, `world/test_room_rng.gd` | `3932b0ba03910c4dd67e1c01499f69423593b694` | `zen_test_room_rng.gd` is an unchanged runtime copy. `scripts/ecology.gd` uses it to generate deterministic cells and exposure rolls. |
| Zen-Elysium, `world/weather/rogue_lab_weather.gd` | `3932b0ba03910c4dd67e1c01499f69423593b694` | `zen_weather.gd` is an unchanged runtime copy. Ecology calls its clock, weighted fronts and snapshot. Klax maps these to planet-specific names, visibility and exposure. |
| Tilebean, `simulation/condition_spread.gd` | `4228a34233579ce36104d25739cdcdce1ef7bfc5` | Adapted snapshot-and-proposal loop in `ecology._step`. Chance keeps the source's base + severity - source/target mitigation form, with new Klax parameters. Newly exposed cells cannot spread until the next step. |
| Tilebean, `simulation/natural_world.gd` | `4228a34233579ce36104d25739cdcdce1ef7bfc5` | Adapted habitat value minus disturbance/depletion in `habitat_at`; quiet habitat recovery and sustained succession counters in `_step`. The original province class is retained as text, not loaded into Klax. |
| Tilebean, `simulation/tile_development.gd` | `4228a34233579ce36104d25739cdcdce1ef7bfc5` | Adapted sustained-condition progress/reset mechanism for habitat recovery. No province or settlement economy is imported. |
| Zen-Elysium, `world/skills/rogue_lab_progression.gd` | `3932b0ba03910c4dd67e1c01499f69423593b694` | Inspected explicit research-node pattern. The Klax catalog is original data. Its upgrade economy is implemented separately; this file is retained as reference. |

Source blob hashes are recorded in the adjacent manifest. Original ecology classes with province dependencies use `.gd.txt` so Godot will not register unresolved classes. Organism names, descriptions, worlds and campaign narrative in `scripts/catalog.gd` were written for Project Klax. They are not imported fantasy content.

Ecology is a bounded 9 x 9 grid covering x/z -90 through 90. Every eight seconds it stages spread, reduces disturbance and recovers ground that stayed quiet. Tires/footsteps release dormant spores immediately. Call `spore_at` for suit exposure, `habitat_at` for wildlife preferences, and `weather_snapshot` for sight and environmental risk. The grid is simulation state; rendering does not advance it.
