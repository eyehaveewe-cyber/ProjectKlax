# Project Klax design

## The expedition

Project Klax follows a field researcher through the remains of six planetary colonies. The player studies the life that survived, recovers abandoned records and decides what the evidence justifies. Research provides progress. Combat tools create room to observe and escape.

The recurring decision is how far to continue before returning with the samples already carried. A rover shortens the journey but disrupts habitat and frightens animals. A pulse creates a safe collection window but increases disturbance. A lure is quieter and takes time. A field station extends the route at a substantial equipment-charge cost.

The mission deck is the campaign hub. It offers five initial worlds, three specialists, equipment upgrades, the specimen lab and a field journal. Recovering all five initial relays reveals The Quiet Heart. The final recommendation requires its relay, both final-world scans and at least six analyzed species. Preserve keeps the interplanetary archive connected; contain isolates it. Neither ending resolves the colonists' disappearance into a certainty the evidence does not support.

## Playable rules

| System | Current rule | Decision it creates |
| --- | --- | --- |
| Observation | Hold E near a targeted organism on foot; the base scan takes 3.2 seconds before bonuses | Maintain a safe observation window rather than rushing directly into collection range |
| Collection | A scanned, calm or stunned individual can be sampled within four meters | Use approach, lures or pulses to manage risk |
| Comparative samples | An individual can be sampled once per expedition; each extracted sample adds four research points | Extra cargo capacity supports longer comparative surveys |
| Analysis | Each species has one normal analysis reward and an optional assay bonus | Research variety matters; the puzzle does not block normal analysis |
| Return | Samples and recovered site rewards become permanent at extraction | Preserve a workable return route and watch oxygen |
| Rescue | Keep observations, earlier research and upgrades; lose current cargo and uncommitted site recovery | Failure costs expedition yield without erasing the campaign |
| Tactical survey | 12% simulation speed, three charged orders, refilled after twelve seconds in live time | Plan a brief scan, lure, sample or pulse sequence under pressure |
| Recovery | The lander and field stations refill health and oxygen; the lander repairs the rover | Extend a route by planning shelter rather than relying only on speed |

Three specialist modifiers favor faster scanning, safer encounters or better cache recovery. The scanner, oxygen system, suit, rover, lure and cargo racks each have three purchasable levels. Upgrade costs increase with the next level. No currency or time gate requires an external service.

## Spatial structure

Each planet is a compact survey area about 188 meters across. The landing circle is the fixed return point. Authored luminous route stakes, a tall relay structure and a distant silhouette provide bearings; ruins and caches give optional reasons to leave the main loop. Terrain and scatter are deterministic for the planet's seed.

The world layouts differ in relay direction, barriers, surface shape and points of interest. Moss introduces observation around nursery ruins. Glass uses mineral divisions and vibration-sensitive life. Ice pairs exposed travel with thermal organisms and a predator. Ash routes around industrial remains. Tidal ground uses broken channels and territorial life. The Heart combines the research verbs around the final sanctuary.

The maps are local surface regions. They are not planet-sized terrain, streamed continents or fully traversable building interiors. The same analytical ground-height function drives terrain construction and actor placement. Collision uses bounded obstacle queries suited to these small maps.

## Ecology and encounters

A 9×9 habitat grid advances every eight simulation seconds. Spore spread reads the old grid and applies proposals afterward, so a new cell cannot transmit across the entire map in the same update. Disturbance releases spores and reduces habitat quality. Quiet patches recover. Wildlife can choose a better nearby patch using the inherited habitat score. Field stations suppress spores locally.

Weather comes from Zen Elysium's deterministic front system. Its Klax interpretation changes environmental exposure and fog visibility. Creature behavior distinguishes passive grazing, shy avoidance, territorial defense and predatory pursuit. Hostile lunges record a target position during a visible windup; moving clear or interrupting the windup can prevent the hit.

This is a small coupled simulation. It has no breeding, food-chain population accounting, persistent migration between expeditions or off-screen planetary history. Habitat and animal state reset at launch. Those limits keep the initial campaign understandable and reproducible.

## Vehicle and presentation

The field rover uses ASCII Racer's lateral-grip, steering, drift and boost calculations with walking-scale tuning. Normal speed is capped around 16 m/s and boost around 25 m/s. Left and right module damage produces steering pull and reduced grip; a destroyed module disables boost. Braking remains a way to stop a damaged rover.

The carrier model comes from Project Barrel Roll and keeps its animated doors and segmented tail. Zendelves supplies articulated procedural creatures and the researcher body. Native Godot geometry, colored terrain, fog, restrained emissive materials and a clear instrument-style UI establish Klax's own setting. The field view stays three-dimensional.

The lab's 6×6 microscope assay is original work. Adjacent swaps create matches, cascades settle with a finite limit, and an analysis can finish without the optional bonus. Its provenance remains separate until Cat Jewler's source is identified.

## State ownership

`main.gd` owns campaign transitions, expedition actors and the observation/extraction rules. `catalog.gd` owns the authored planets, organisms, specialists and upgrades. `world.gd` builds geography and reports interaction/spawn records. `ecology.gd` owns habitat and weather state. `creature_models.gd`, `klax_rover.gd` and `research_carrier.gd` supply model and movement components. `hud.gd` emits commands and renders snapshots; `assay.gd` reports a result while the campaign awards research. `savegame.gd` validates and writes the campaign.

Persistent state includes observed/analyzed species, extracted samples, visited sites, recovered relays, upgrades and endings. Live expedition state includes cargo, positions, stations, animal timers, habitat and weather. This version saves only the former. Future mid-expedition saving must capture the latter explicitly rather than implying it is already supported.

## Development priority

Validate the first expedition and the complete ending path with real input before adding more systems. Then use playtest evidence to tune collection windows, environmental visibility, route length and upgrade value. Additional creatures and worlds should introduce a new observation problem or spatial decision. Larger maps and more species alone would not deepen the current research loop.
