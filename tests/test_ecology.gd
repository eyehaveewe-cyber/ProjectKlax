extends SceneTree
## Native integration evidence for the source-derived habitat simulation.
## Run: godot --headless --path . --script res://tests/test_ecology.gd
const Ecology = preload("res://scripts/ecology.gd")
const Catalog = preload("res://scripts/catalog.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func run() -> void:
	var habitat = Ecology.new()
	habitat.setup(0, 123)
	check(habitat.tiles.size() == 81, "Planet grid must contain 81 cells")
	var baseline: float = habitat.spore_at(Vector3.ZERO)
	var rested: float = habitat.habitat_at(Vector3.ZERO)
	habitat.disturb(Vector3.ZERO, 1.0)
	var disturbed_spore: float = habitat.spore_at(Vector3.ZERO)
	check(disturbed_spore > baseline, "Disturbance must release spores")
	check(habitat.habitat_at(Vector3.ZERO) < rested, "Disturbance must lower habitat quality")
	habitat.advance(160.0)
	check(habitat.rounds == 20, "Time should resolve twenty eight-second ecology steps")
	check(habitat.spore_at(Vector3.ZERO) < disturbed_spore, "Quiet ground must clear released spores")
	check(habitat.habitat_at(Vector3.ZERO) > rested - 0.2, "Quiet habitat must recover after disturbance")

	# A station must actually filter spores; the former negative-disturbance
	# call was rejected, leaving restoration as a silent no-op.
	habitat.disturb(Vector3.ZERO, 1.0)
	var polluted: float = habitat.spore_at(Vector3.ZERO)
	var damaged: float = habitat.habitat_at(Vector3.ZERO)
	habitat.restore(Vector3.ZERO, 0.8)
	check(habitat.spore_at(Vector3.ZERO) < polluted, "Field station restoration must remove spores")
	check(habitat.habitat_at(Vector3.ZERO) > damaged, "Field station restoration must improve habitat")
	habitat.restore(Vector3.ZERO, 100.0)
	habitat.disturb(Vector3(1000, 0, -1000), 100.0)
	for tile: Dictionary in habitat.tiles:
		for key: String in ["spore", "fertility", "disturbance"]:
			check(float(tile[key]) >= 0.0 and float(tile[key]) <= 1.0, "%s must stay within zero and one" % key)

	# Same actions with different frame grouping must preserve the same future.
	for planet_id in range(6):
		var uninterrupted = Ecology.new()
		var chunked = Ecology.new()
		uninterrupted.setup(planet_id, 883)
		chunked.setup(planet_id, 883)
		uninterrupted.disturb(Vector3(30, 0, -20), 0.8)
		chunked.disturb(Vector3(30, 0, -20), 0.8)
		uninterrupted.advance(80.0)
		for _step in range(10):
			chunked.advance(8.0)
		check(uninterrupted.tiles == chunked.tiles, "Seeded ecology diverged on planet %d" % planet_id)
		check(uninterrupted.weather_snapshot() == chunked.weather_snapshot(), "Weather replay diverged on planet %d" % planet_id)
		var weather: Dictionary = uninterrupted.weather_snapshot()
		check(not str(weather.name).is_empty(), "Weather must have a display name")
		check(float(weather.visibility) > 0.0 and float(weather.visibility) <= 1.0, "Weather visibility is outside its contract")
		check(float(weather.hazard) >= 0.0, "Weather hazard cannot be negative")

	# A single infected source can expose neighbors, but a newly exposed cell
	# cannot trigger another generation during the same resolution.
	var observed_spread: bool = false
	for planet_seed in range(1, 21):
		var exposure = Ecology.new()
		exposure.setup(0, planet_seed)
		for tile: Dictionary in exposure.tiles:
			tile.spore = 0.0
			tile.fertility = 0.0
			tile.disturbance = 0.0
		exposure.tiles[40].spore = 1.0
		exposure.advance(8.0)
		for tile: Dictionary in exposure.tiles:
			var distance: int = absi(int(tile.x) - 4) + absi(int(tile.z) - 4)
			if distance == 1 and float(tile.spore) > 0.0:
				observed_spread = true
			if distance > 1:
				check(is_zero_approx(float(tile.spore)), "Exposure skipped the staged-spread boundary")
	check(observed_spread, "Seed fixtures never exercised a successful neighboring exposure")

	var planets: Array[Dictionary] = Catalog.planets()
	var species: Array[Dictionary] = Catalog.species()
	check(planets.size() == 6, "Campaign must supply six worlds")
	check(species.size() == 12, "Campaign must supply twelve species")
	var found: Dictionary = {}
	for planet: Dictionary in planets:
		check(planet.species.size() == 2, "Each world must have two catalog species")
		for species_id in planet.species:
			check(int(species_id) >= 0 and int(species_id) < species.size(), "Planet refers to an unknown species")
			check(not found.has(int(species_id)), "Species is assigned to more than one planet")
			found[int(species_id)] = true
	for specimen: Dictionary in species:
		check(int(specimen.model) >= 0 and int(specimen.model) <= 5, "Species refers to an unknown source model")
		check(int(specimen.science) > 0, "Analyzed species must yield research")
	check(Catalog.upgrades().size() == 6, "Campaign must supply six equipment upgrades")
	check(Catalog.crew().size() == 3, "Campaign must supply three expedition specialists")
	if failures.is_empty():
		print("ECOLOGY CHECK PASS: disturbance, field-station restoration, quiet recovery, bounds, staged exposure, six-planet deterministic replay, catalog links")
	quit(0 if failures.is_empty() else 1)
