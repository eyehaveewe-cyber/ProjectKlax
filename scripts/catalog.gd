extends RefCounted
## Original Project Klax field catalog. Research prerequisite structure follows
## Zen-Elysium's explicit progression nodes; organisms and narrative are new.

static func planets() -> Array[Dictionary]:
	return [
		{"id": 0, "name": "Vesper Reach", "biome": "moss", "color": Color("345d59"), "accent": Color("84f1be"), "species": [0, 1],
			"hazard": "Disturbance releases dormant spores.",
			"brief": "A nursery colony vanished beneath a living canopy. Begin with two life forms, then retrieve its silent relay.",
			"log": "NURSERY 04 / FINAL SHIFT: The grafts crossed the concrete last night. Nothing ate the gardeners. Their beds were made. Their radios were stacked in the greenhouse, all facing the same direction."},
		{"id": 1, "name": "Prism Grave", "biome": "glass", "color": Color("586481"), "accent": Color("d4a8ff"), "species": [2, 3],
			"hazard": "Crystalline ground magnifies motion and vibration.",
			"brief": "An observatory's mirrors have become reef. The animals respond to tremors from kilometers away.",
			"log": "OBSERVATORY / UNSENT: We thought the lattice was a fossil. It changed its angle to follow the signal. The signal was coming from the ocean world, and every receiver here was unplugged."},
		{"id": 2, "name": "Pale Archive", "biome": "ice", "color": Color("7a9ba9"), "accent": Color("b1efff"), "species": [4, 5],
			"hazard": "Cold fronts drain exposed life support.",
			"brief": "Buried laboratories still hold warm chambers. Their surviving organisms preserve something older than the colony.",
			"log": "CRYOLAB / DR. SEN: The frozen cells repeat the same chemical sequence as the moss. Different biochemistry, same timing. Do not thaw the entire archive. We are looking at a distributed memory."},
		{"id": 3, "name": "Cinder Choir", "biome": "ash", "color": Color("754a43"), "accent": Color("ffb176"), "species": [6, 7],
			"hazard": "Ash squalls increase exposure and shorten sightlines.",
			"brief": "An industrial colony tried to burn the network out. Something has learned to carry its messages through the furnaces.",
			"log": "FOUNDRY / EMERGENCY: The firebreak failed. Heat did not kill the colonies. It selected for a different carrier. The relays now synchronize even when the power grid is dark."},
		{"id": 4, "name": "Undertow Station", "biome": "tidal", "color": Color("386b7a"), "accent": Color("72e0ed"), "species": [8, 9],
			"hazard": "Salt surges and wet spore fronts move through low ground.",
			"brief": "The listening station stands above a drained seabed. Recover its relay to locate the source of the shared pulse.",
			"log": "LISTENING POST / LAST CONTACT: It is not a transmission aimed at us. It is coordination. Nursery, reef, archive, furnace, sea. We built our colonies on the organs of something that spans worlds."},
		{"id": 5, "name": "The Quiet Heart", "biome": "heart", "color": Color("59446e"), "accent": Color("f5a0dc"), "species": [10, 11],
			"hazard": "A synchronized spore tide binds the entire habitat.",
			"brief": "Five relays reveal an unregistered sanctuary. Complete its survey, then decide whether the network should remain open or be contained.",
			"log": "KLAX / FIRST INTERPRETATION: The abandoned colonies were not a conquest. Their machinery became scaffolding for a new ecology. No evidence tells us where the colonists went. Our final decision must preserve that uncertainty."}
	]

static func species() -> Array[Dictionary]:
	return [
		{"id": 0, "name": "Lantern grazer", "latin": "Luciventer ambulans", "model": 2, "temperament": "passive", "diet": "Fungal films on damp ruins", "clue": "A calm grazer. Scan on foot, then approach within four meters for a sample. Its luminous tissues may carry symbionts.", "adaptation": "Light-sensitive symbionts predict spore fronts before they arrive.", "color": Color("99e9a0"), "science": 18},
		{"id": 1, "name": "Root runner", "latin": "Radicipes fugax", "model": 0, "temperament": "shy", "diet": "Decaying roots and mineral grit", "clue": "It flees a close approach, especially a rover. A pheromone lure creates a safer collection window.", "adaptation": "Pressure-sensitive feet distinguish predators from rainfall.", "color": Color("e4b88d"), "science": 22},
		{"id": 2, "name": "Prism strider", "latin": "Vitropoda resonans", "model": 5, "temperament": "territorial", "diet": "Silica crust and embedded microbes", "clue": "Its orange warning ring marks an impending lunge. Step out, then use a lure or nonlethal pulse before sampling.", "adaptation": "Hollow limb chambers pass vibration into a continent-wide glass lattice.", "color": Color("c8a2f0"), "science": 25},
		{"id": 3, "name": "Mirror sail", "latin": "Velaria specularis", "model": 4, "temperament": "shy", "diet": "Charged aerosols above the reef", "clue": "This shy form withdraws from close contact. The laboratory suspects its reflective membranes help gather charged particles.", "adaptation": "Electrostatic lift lets a mineral-rich organism remain airborne.", "color": Color("89d5f2"), "science": 24},
		{"id": 4, "name": "Thermal bell", "latin": "Campanula thermophila", "model": 1, "temperament": "passive", "diet": "Waste heat and vent chemistry", "clue": "A passive vent organism. Its sheltered tissues may preserve cells through long winters; a recovered sample can test that interpretation.", "adaptation": "A reversible antifreeze gel stores living cells through long winters.", "color": Color("99ebee"), "science": 26},
		{"id": 5, "name": "Rime prowler", "latin": "Cryovenator lentus", "model": 3, "temperament": "predator", "diet": "Small vent grazers", "clue": "It pursues intruders and pauses before lunging. A lure diverts it; a pulse opens six seconds for collection.", "adaptation": "An insulating gel exposes heat-sensitive tissue during the attack windup.", "color": Color("d8e8f7"), "science": 32},
		{"id": 6, "name": "Ember carrier", "latin": "Ignifer errans", "model": 0, "temperament": "territorial", "diet": "Sulfur films and furnace residue", "clue": "Territorial behavior makes direct collection unsafe. Calm or stun it first. Its bright tissues may house heat-resistant spores.", "adaptation": "Ceramic plates keep a spore culture alive through brief furnace exposure.", "color": Color("ffad69"), "science": 29},
		{"id": 7, "name": "Ash mantler", "latin": "Cinerovelum migrans", "model": 4, "temperament": "passive", "diet": "Airborne ash microbes", "clue": "A passive drifting form. Its mantle may filter microbial cargo from the ash; watch your suit exposure while approaching.", "adaptation": "A filtering membrane separates toxic particles from viable microbial cargo.", "color": Color("e4a7b4"), "science": 27},
		{"id": 8, "name": "Brine pilgrim", "latin": "Salipoda recurrens", "model": 1, "temperament": "shy", "diet": "Salt-tolerant mats in drained channels", "clue": "Its shy response is stronger around a moving rover. Approach on foot with a lure to obtain a close sample.", "adaptation": "Salt pumps regulate internal chemistry through both dry and submerged phases.", "color": Color("8fe1d3"), "science": 28},
		{"id": 9, "name": "Anchorback", "latin": "Ancorata custodis", "model": 3, "temperament": "territorial", "diet": "Filter-feeding colonies within its mantle", "clue": "It warns before striking. Researchers suspect a symbiotic community inside its mantle, but proximity alone does not prove that relationship.", "adaptation": "A thick living mantle shelters several species whose waste feeds the host.", "color": Color("729fcd"), "science": 34},
		{"id": 10, "name": "Pulse gardener", "latin": "Hortulanus concordans", "model": 5, "temperament": "passive", "diet": "Exchanges nutrients with the surrounding network", "clue": "A passive form in the central habitat. Its anatomy suggests nutrient exchange with the network; repair behavior remains unconfirmed.", "adaptation": "Chemical pulses coordinate repair across organisms with unrelated anatomy.", "color": Color("e9b0e5"), "science": 40},
		{"id": 11, "name": "Witness grazer", "latin": "Memoriventer tacitus", "model": 2, "temperament": "shy", "diet": "Memory-bearing microbial sheets", "clue": "It retreats from close contact. Its luminous tissues resemble those from Vesper Reach; shared chemical memory remains a research interpretation.", "adaptation": "Symbiotic colonies retain and replay chemical histories through generations.", "color": Color("f5d695"), "science": 45}
	]

static func upgrades() -> Array[Dictionary]:
	return [
		{"id": "scanner", "name": "Coherent scanner", "cost": 30, "description": "Faster scans and a longer working range.", "max": 3},
		{"id": "oxygen", "name": "Closed-loop oxygen", "cost": 25, "description": "More time on the surface before returning to the lander.", "max": 3},
		{"id": "suit", "name": "Adaptive suit lining", "cost": 30, "description": "Better protection against bites, spores and extreme weather.", "max": 3},
		{"id": "rover", "name": "Rover reinforcement", "cost": 35, "description": "Stronger modules and more reliable travel across damaged ground.", "max": 3},
		{"id": "lure", "name": "Pheromone library", "cost": 25, "description": "Improves lure duration and creates safer observation windows.", "max": 3},
		{"id": "cargo", "name": "Sterile sample racks", "cost": 30, "description": "Carry more recovered biological material per expedition.", "max": 3}
	]

static func crew() -> Array[Dictionary]:
	return [
		{"id": "biologist", "name": "Dr. Mira Sen", "role": "Xenobiologist", "description": "Patient observation. Completes scans 25% faster.", "scan_multiplier": 1.25, "damage_multiplier": 1.0, "salvage_multiplier": 1.0},
		{"id": "ranger", "name": "Ivo Vale", "role": "Field ranger", "description": "Reads warning displays. Takes 20% less encounter damage.", "scan_multiplier": 1.0, "damage_multiplier": 0.8, "salvage_multiplier": 1.0},
		{"id": "engineer", "name": "Tamsin Osei", "role": "Expedition engineer", "description": "Recovers 50% more usable salvage from derelict equipment.", "scan_multiplier": 1.0, "damage_multiplier": 1.0, "salvage_multiplier": 1.5}
	]
