# Planetary survey areas

Each survey area spans a roughly 188-meter diameter. The cleared landing pad stays at the origin and the first organism stays 8 meters east and 10 meters north of it. Beyond this common opening, each planet has its own relay bearing, station positions, supply-cache positions and survey route. The expedition simulation owns creature behavior and rewards; the world reports actual positions and collision.

Luminous stakes mark the main route at intervals of approximately nine meters. The ground mesh contains a contrasting worn trail, and procedural scatter leaves its corridor clear. Three supply caches and three derelict stations sit along or beside the expedition route. The three station building templates repeat between worlds in this build, while their positions and surrounding travel constraints change. Wildlife beyond the first specimen rotates with the relay bearing and relocates when it would overlap an obstacle.

| Planet | Route configuration | Relay east/south meters | Physical navigation and appearance |
| --- | --- | --- | --- |
| Vesper Reach | Northern garden loop | 4, -57 | Two central rock beds divide outbound and return routes. Mossy soil, luminous fungi and a broken orbital ring. |
| Prism Grave | Eastern fracture crossings | 61, -31 | A north-south ridge has two separated passages. The main loop uses both. Gray-violet soil and tall glass monoliths. |
| Pale Archive | Western switchback | -61, -28 | Broken horizontal ridges divide the relay approach from the archive return. Frozen shards and a frost-colored orbital ring. |
| Cinder Choir | Southern caldera circuit | 15, 63 | A closed, unoccupied rock formation forces travel around its eastern or western flank. A depressed ash basin and furnace peaks. |
| Undertow Station | Southeastern seabed fork | 48, 46 | Divided channel banks separate the western archive return from the eastern relay approach. Undulating seabed and umbrella coral. |
| The Quiet Heart | Southwestern sanctuary loop | -47, 44 | Radial rock seams divide the outlying station sectors. Purple soil, glowing bulbs and a giant branching organism. |

Terrain height, flora distribution and faceted ground colors are deterministic for the supplied seed. Biome-specific ridges, depressions and rolling ground change the elevation profile. The mesh uses the same height function as character and rover positioning. The native collision query checks circular obstacles and the outer survey boundary. Station back walls, structural columns, supply crates, route barriers and large rocks block travel. Interiors and relay approaches stay open.

## Visual treatment and performance

The world uses Compatibility-compatible sky, ordinary fog, directional lights, rough materials and low-poly geometry. A browser screenshot revealed clipped pale objects in the first lighting pass. The revision lowers direct and ambient light, disables shiny specular response, and preserves value differences when tinting imported creature parts. Only eye details receive model emission. Broad terrain color patches and the worn trail distinguish ground regions.

Distant stars and nearby suspended motes use MultiMesh. Motes are static atmospheric detail in this build; they do not simulate weather. Procedural scatter was reduced from 165 candidate placements to 125 to offset the new physical route barriers and trail markers. The main integration pass measures browser presentation and performance.

## Source and animation

The creature geometry is generated from Zendelves' actual procedural actor constructors, with its walk, tail and wing motion ported to Godot. Species shapes and tints come from `catalog.gd`. This separates the species identity from the six underlying mesh families. `source-provenance/zendelves/README.md` records the exact source commit, blob and regeneration command.

## Verification

A Godot 4.7.2 headless check instantiated all six biome worlds, all twelve species and the researcher, then exercised movement and alert poses. Each world contained 15 specimens and 7 interaction points. After the layout revision, a flood-fill using the actual `is_blocked` query verified a walking route from the lander to within 4 meters of every point and specimen on all six actual campaign seeds, `91031 + planet_id * 7919`. Every specimen spawn was collision-free, the first specimen approach was clear, and the outer boundary rejected travel. This confirms layout connectivity and runtime construction, not visual presentation or the complete expedition loop.

The main integration pass separately verifies browser rendering and the complete expedition loop.
