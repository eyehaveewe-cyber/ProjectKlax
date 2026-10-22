# Vehicle code provenance

ProjectKlax uses source from the user's existing games. The snapshots in `vehicles/` are unchanged originals saved with `.txt` extensions so Godot does not import their unrelated global classes. The source repositories were not modified.

| ProjectKlax implementation | Actual source | Inspected commit | Adaptation |
| --- | --- | --- | --- |
| `scripts/klax_rover.gd`, `step_drive` | [ASCII-Racer, scripts/glyph_racer.gd](https://github.com/eyehaveewe-cyber/ASCII-Racer/blob/39218c040b8923379a2fa11f369c05557aefcb5c/scripts/glyph_racer.gd) | `39218c040b8923379a2fa11f369c05557aefcb5c` | Extracted boost depletion, empty latch and recharge; steering rate; lateral velocity projection and exponential grip; drift thresholds and release; capped acceleration with gradual overspeed decay; reverse limit. Removed track, collision-pair and multiplayer/race dependencies. |
| `scripts/klax_rover.gd`, glyph flank modules | [ASCII-Racer, scripts/glyph_factory.gd](https://github.com/eyehaveewe-cyber/ASCII-Racer/blob/39218c040b8923379a2fa11f369c05557aefcb5c/scripts/glyph_factory.gd) | `39218c040b8923379a2fa11f369c05557aefcb5c` | Reused real TextMesh extrusion construction with Godot's fallback font. Klax uses two fixed glyphs and its own material cache, so the full font/mesh cache is unnecessary. |
| `scripts/research_carrier.gd` | [Project-Barrel-Roll, scripts/carrier_hull.gd](https://github.com/eyehaveewe-cyber/Project-Barrel-Roll/blob/17bda73b7763c5033cc19e945fd84b12019f0dc6/scripts/carrier_hull.gd) | `17bda73b7763c5033cc19e945fd84b12019f0dc6` | Retained broad head lobes, thorax, bridge, drive pods, launch rails, seven segmented tail meshes, door pose and stable tail animation. Added landing struts, medical markings, sensor array, ramp and field-medicine sign. |

## Klax changes

The rover is a new six-wheel field vehicle around the reused driving math. Top speeds are explicitly retuned to 16 m/s and 25 m/s boost. Acceleration, reverse speed, drift speed threshold and coasting/braking are reduced for walking-scale planetary expeditions. These changes affect Klax only and do not change ASCII Racer's handling.

Left and right module integrity control physical steering pull and lateral grip. Destroying either module disables boost; braking damps the pull and can bring the vehicle to a stop. Visual suspension tilts toward the missing module and wobbles in motion. Repair resets hull, modules and charge. The caller handles terrain height, collisions, boarding and HUD; this module moves only X/Z.

The research carrier has a 0.18 internal scale, approximately 10 m long. Root placement is at ground level; its own landing legs and hull are vertically offset. It has no collision body. `set_open(bool)` animates doors; `pose(open_amount, time)` remains available from the original model.

## Verification

`tests/test_vehicles.gd` exercises actual Godot nodes and driving over simulated time. It covers forward movement, normal/boost caps, left-module destruction, physical steering pull, braking to rest while damaged, repair, depletion latch/rearm and carrier door positions. It passed under Godot 4.7.2 headless. Rendering is verified separately by the complete game's capture workflow.
