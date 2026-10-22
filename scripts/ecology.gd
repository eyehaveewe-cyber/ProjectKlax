extends RefCounted
## Planet habitat simulation. Staged exposure and recovery are adapted from
## Tilebean; seeded RNG and deterministic weather are reused from Zen-Elysium.
const SeededRng = preload("res://source-provenance/ecology/zen_test_room_rng.gd")
const Weather = preload("res://source-provenance/ecology/zen_weather.gd")
const GRID_SIZE: int = 9
const CELL_SIZE: float = 20.0
const HALF_EXTENT: float = 90.0
const STEP_SECONDS: float = 8.0

var tiles: Array[Dictionary] = []
var planet_id: int = 0
var seed_value: int = 1
var rounds: int = 0
var last_events: Array[String] = []
var _elapsed: float = 0.0
var _rng = SeededRng.new()
var _weather = Weather.new()

func setup(new_planet_id: int, new_seed_value: int) -> void:
	planet_id = clampi(new_planet_id, 0, 5)
	seed_value = new_seed_value
	rounds = 0
	_elapsed = 0.0
	last_events.clear()
	tiles.clear()
	_rng.reset(seed_value + planet_id * 7919)
	_weather.reset(seed_value + planet_id * 104729)
	_weather.total_minutes = 600 + planet_id * 37
	for z in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var fertility: float = 0.35 + float(_rng.roll_basis_points()) / 18000.0
			var spore: float = 0.0
			if _rng.roll_chance(0.18 + float(planet_id) * 0.025):
				spore = 0.28 + float(_rng.roll_basis_points()) / 22000.0
			if abs(x - 4) <= 1 and abs(z - 4) <= 1:
				spore *= 0.16
			tiles.append({"x": x, "z": z, "spore": spore,
				"fertility": clampf(fertility, 0.0, 1.0), "disturbance": 0.0,
				"recovery": 0, "blooms": 0})

func advance(delta: float) -> void:
	if delta <= 0.0 or tiles.is_empty():
		return
	_elapsed += delta
	while _elapsed >= STEP_SECONDS:
		_elapsed -= STEP_SECONDS
		_step()

func disturb(pos: Vector3, amount: float) -> void:
	if tiles.is_empty() or amount <= 0.0:
		return
	var index: int = _index_at(pos)
	var tile: Dictionary = tiles[index]
	tile.disturbance = clampf(float(tile.disturbance) + amount, 0.0, 1.0)
	# Tires and footsteps break dormant spore crust. The resulting exposure is
	# immediate, while neighboring infection waits for the next ecology step.
	tile.spore = clampf(float(tile.spore) + amount * 0.22, 0.0, 1.0)
	tile.fertility = maxf(0.0, float(tile.fertility) - amount * 0.08)
	tile.recovery = 0

func spore_at(pos: Vector3) -> float:
	if tiles.is_empty():
		return 0.0
	return float(tiles[_index_at(pos)].spore)

func restore(pos: Vector3, amount: float) -> void:
	if tiles.is_empty() or amount <= 0.0:
		return
	var tile: Dictionary = tiles[_index_at(pos)]
	# A field station filters active spores and settles disturbed ground.
	# Its small nutrient return supplements the normal quiet-recovery cycle.
	tile.disturbance = maxf(0.0, float(tile.disturbance) - amount)
	tile.spore = maxf(0.0, float(tile.spore) - amount * 0.45)
	tile.fertility = minf(1.0, float(tile.fertility) + amount * 0.08)

func habitat_at(pos: Vector3) -> float:
	if tiles.is_empty():
		return 0.0
	var tile: Dictionary = tiles[_index_at(pos)]
	# Tilebean habitat_score subtracts disturbance and depleted forage from
	# habitat value. A creature can use this to prefer quiet, rested ground.
	return float(tile.fertility) - float(tile.disturbance) * 0.65 - float(tile.spore) * 0.25

func describe_at(pos: Vector3) -> String:
	if tiles.is_empty():
		return "Habitat survey pending."
	var tile: Dictionary = tiles[_index_at(pos)]
	if float(tile.spore) >= 0.65:
		return "Dense airborne bloom. Suit exposure is rising; move to clearer ground."
	if float(tile.disturbance) >= 0.5:
		return "Disturbed crust. Rover tracks release spores and drive shy life away."
	if float(tile.fertility) < 0.25:
		return "Depleted habitat. Leave this patch quiet to let its food web recover."
	if int(tile.recovery) >= 3:
		return "Recovering habitat. Undisturbed ground is rebuilding its living cover."
	if float(tile.spore) >= 0.25:
		return "Active spores. A quiet approach limits further release."
	return "Rested habitat. Low disturbance gives the clearest behavioral observations."

func weather_snapshot() -> Dictionary:
	var profile: StringName = &"orc" if planet_id == 3 else &""
	var snapshot: Dictionary = _weather.snapshot(profile)
	var kind: String = str(snapshot.kind)
	var names: Dictionary = {
		"clear": "Clear atmosphere", "sunny": "Hard sunlight", "partly_cloudy": "High cloud",
		"light_rain": "Fine precipitation", "rain": "Heavy precipitation", "thunderstorm": "Electrical front",
		"fog": "Ground haze", "snow": "Crystal fall", "smoke": "Drifting ash plume", "ash": "Ash fall",
		"smoke_ash": "Ash curtain", "ash_rain": "Caustic rain", "smoke_rain": "Black rain",
		"ash_smoke_rain": "Ash squall"}
	var visibility: float = 1.0
	var hazard: float = 0.0
	if kind in ["fog", "smoke", "smoke_ash"]:
		visibility = 0.48
	elif kind in ["rain", "snow", "ash", "smoke_rain"]:
		visibility = 0.70
	elif kind in ["thunderstorm", "ash_rain", "ash_smoke_rain"]:
		visibility = 0.55
		hazard = 0.32
	if planet_id == 2:
		hazard += 0.12
		if kind in ["rain", "light_rain", "snow"]:
			names[kind] = "Needle-ice drift"
	elif planet_id == 3:
		hazard += 0.14
	elif planet_id == 4 and kind in ["rain", "thunderstorm"]:
		names[kind] = "Saltwater surge"
		hazard += 0.10
	elif planet_id == 5:
		visibility = minf(visibility, 0.78)
		names[kind] = "Synchronous spore tide"
		hazard += 0.10
	return {"name": str(names.get(kind, kind.capitalize())), "visibility": visibility,
		"hazard": hazard, "kind": kind, "clock": str(snapshot.clock), "phase": str(snapshot.phase)}

func _step() -> void:
	rounds += 1
	_weather.advance(12)
	last_events.clear()
	# Adapted from ConditionSpread.proposals: exposures read only this snapshot,
	# and all newly infected targets are applied after every source is evaluated.
	var original: Array[Dictionary] = tiles.duplicate(true)
	var pending: Dictionary = {}
	var weather: Dictionary = weather_snapshot()
	var wet: bool = str(weather.kind) in ["light_rain", "rain", "snow"]
	for index in range(original.size()):
		var source: Dictionary = original[index]
		if float(source.spore) < 0.48:
			continue
		for target_index in _neighbors(index):
			var target: Dictionary = original[target_index]
			if float(target.spore) >= 0.28:
				continue
			var severity: int = clampi(int(float(source.spore) * 4.0), 1, 3)
			var mitigation: float = (float(source.fertility) + float(target.fertility)) * 7.0
			if wet:
				mitigation += 14.0
			var chance: float = clampf(12.0 + float(severity) * 8.0 - mitigation + float(source.disturbance) * 20.0, 0.0, 70.0)
			if _rng.roll_chance(chance / 100.0):
				pending[target_index] = maxf(float(pending.get(target_index, 0.0)), 0.32)
	for index in range(tiles.size()):
		var tile: Dictionary = tiles[index]
		var before: Dictionary = original[index]
		var disturbed: bool = float(before.disturbance) >= 0.16
		tile.disturbance = maxf(0.0, float(before.disturbance) - 0.11)
		# The sustained-condition counter follows Tilebean's tile development and
		# natural succession. A newly quiet cell must remain quiet before regrowth.
		tile.recovery = 0 if disturbed else int(before.recovery) + 1
		var growth: float = 0.018 if int(tile.recovery) >= 3 else 0.0
		tile.fertility = clampf(float(before.fertility) + growth - float(before.spore) * 0.012, 0.0, 1.0)
		var spores: float = float(before.spore) + float(before.disturbance) * 0.045
		if not disturbed:
			spores -= 0.017 + float(tile.fertility) * 0.012
		if wet:
			spores -= 0.025
		if pending.has(index):
			spores = maxf(spores, float(pending[index]))
			tile.blooms = int(tile.blooms) + 1
		tile.spore = clampf(spores, 0.0, 1.0)
	if not pending.is_empty():
		last_events.append("Spore front reached %d neighboring habitat patches." % pending.size())
	if rounds % 4 == 0:
		last_events.append("Habitat cycle %d. Quiet ground recovers; disturbed crust sheds spores." % rounds)

func _index_at(pos: Vector3) -> int:
	var x: int = clampi(int(floor((pos.x + HALF_EXTENT) / CELL_SIZE)), 0, GRID_SIZE - 1)
	var z: int = clampi(int(floor((pos.z + HALF_EXTENT) / CELL_SIZE)), 0, GRID_SIZE - 1)
	return z * GRID_SIZE + x

func _neighbors(index: int) -> Array[int]:
	var result: Array[int] = []
	var x: int = index % GRID_SIZE
	var z: int = int(index / GRID_SIZE)
	if x > 0:
		result.append(index - 1)
	if x < GRID_SIZE - 1:
		result.append(index + 1)
	if z > 0:
		result.append(index - GRID_SIZE)
	if z < GRID_SIZE - 1:
		result.append(index + GRID_SIZE)
	return result
