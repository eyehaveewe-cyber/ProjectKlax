class_name RogueLabWeather
extends RefCounted

# Simulation only. Renderers and NPC routines consume snapshot(), never shader state.
const NORMAL_KINDS := ["clear", "sunny", "partly_cloudy", "light_rain", "rain", "thunderstorm", "fog", "snow"]
const KINDS := NORMAL_KINDS + ["smoke", "ash", "smoke_ash", "ash_rain", "smoke_rain", "ash_smoke_rain"]
const LABELS := {"clear": "Clear", "sunny": "Sunny", "partly_cloudy": "Partly cloudy", "light_rain": "Light rain", "rain": "Heavy rain", "thunderstorm": "Thunderstorm", "fog": "Fog", "snow": "Snow", "smoke": "Drifting smoke", "ash": "Falling ash", "smoke_ash": "Smoke and ash", "ash_rain": "Ash and rain storm", "smoke_rain": "Smoke and rain", "ash_smoke_rain": "Ash, smoke and rain storm"}
const FRONT_BAG := ["clear", "sunny", "sunny", "partly_cloudy", "partly_cloudy", "light_rain", "light_rain", "rain", "rain", "thunderstorm", "fog", "snow"]
const MAX_MINUTES := 525600000

static func label(kind: String) -> String:
	return String(LABELS.get(kind, kind.capitalize()))
const MINUTES_PER_ACTION := 1
const FRONT_MINUTES := 120
const TRANSITION_MINUTES := 20
# Repeated entries are weights. Storms usually taper, but can clear directly.
const NEXT_FRONTS := {
	"thunderstorm": ["rain", "light_rain", "light_rain", "light_rain", "thunderstorm", "partly_cloudy", "sunny"],
	"rain": ["rain", "light_rain", "light_rain", "light_rain", "thunderstorm", "fog"],
	"light_rain": ["light_rain", "partly_cloudy", "partly_cloudy", "partly_cloudy", "rain", "fog", "sunny"],
	"partly_cloudy": ["partly_cloudy", "sunny", "sunny", "sunny", "clear", "light_rain"],
	"sunny": ["sunny", "sunny", "partly_cloudy", "partly_cloudy", "clear"],
	"clear": ["clear", "sunny", "partly_cloudy", "partly_cloudy", "fog", "snow"],
	"fog": ["fog", "clear", "partly_cloudy", "light_rain"],
	"snow": ["snow", "snow", "partly_cloudy", "clear", "fog"],
}
const ORC_FRONT_BAG := ["smoke", "smoke", "ash", "ash", "smoke_ash", "smoke_ash", "partly_cloudy", "clear", "ash_rain"]
const ORC_NEXT_FRONTS := {
	"clear": ["clear", "partly_cloudy", "smoke", "ash", "sunny"],
	"sunny": ["sunny", "clear", "partly_cloudy", "smoke"],
	"partly_cloudy": ["partly_cloudy", "clear", "smoke", "ash", "light_rain"],
	"smoke": ["smoke", "smoke", "smoke_ash", "ash", "clear", "smoke_rain"],
	"ash": ["ash", "ash", "smoke_ash", "smoke", "partly_cloudy", "ash_rain"],
	"smoke_ash": ["smoke_ash", "ash", "smoke", "ash_rain", "ash_smoke_rain"],
	"ash_rain": ["ash_rain", "light_rain", "ash", "smoke_ash", "ash_smoke_rain"],
	"smoke_rain": ["smoke_rain", "light_rain", "smoke", "ash_smoke_rain"],
	"ash_smoke_rain": ["ash_rain", "ash_rain", "smoke_rain", "smoke_ash", "light_rain", "clear"],
	"light_rain": ["light_rain", "ash", "smoke", "partly_cloudy", "clear", "sunny"],
}
var total_minutes: int = 16 * 60
var world_seed: int = 1
var override_kind: String = ""

func reset(seed_value: int) -> void:
	world_seed = posmod(seed_value, 2147483647)
	total_minutes = 16 * 60
	override_kind = ""

func advance(minutes: int) -> void:
	total_minutes = mini(MAX_MINUTES, total_minutes + maxi(0, minutes))

func minutes_until(hour: int) -> int:
	var delta := posmod(clampi(hour, 0, 23) * 60 - posmod(total_minutes, 1440), 1440)
	return 1440 if delta == 0 else delta

func weather_kind(profile: StringName = &"") -> String:
	if override_kind in KINDS:
		return override_kind
	return _front_kind(int(total_minutes / FRONT_MINUTES), profile)


func _front_roll(front: int) -> int:
	var mixed := posmod((world_seed + front * 104729) * 48271, 2147483647)
	mixed = posmod((mixed ^ (mixed >> 13)) * 48271, 2147483647)
	return mixed


func next_front(kind: String, roll: int, profile: StringName = &"") -> String:
	var fronts: Dictionary = ORC_NEXT_FRONTS if profile == &"orc" else NEXT_FRONTS
	var choices: Array = fronts.get(kind, fronts["clear"])
	return String(choices[posmod(roll, choices.size())])


func _front_kind(front: int, profile: StringName = &"") -> String:
	# Bounded deterministic two-day forecast windows avoid replaying millions
	# of historical fronts on old saves or large debug clock jumps.
	var first := int(front / 24) * 24
	var bag: Array = ORC_FRONT_BAG if profile == &"orc" else FRONT_BAG
	var kind: String = bag[posmod(_front_roll(first), bag.size())]
	for index: int in range(first + 1, front + 1):
		kind = next_front(kind, _front_roll(index), profile)
	return kind

func snapshot(profile: StringName = &"") -> Dictionary:
	var minute := posmod(total_minutes, 1440)
	var hour := float(minute) / 60.0
	var phase := "night"
	if hour >= 5.0 and hour < 8.0:
		phase = "dawn"
	elif hour >= 8.0 and hour < 17.0:
		phase = "day"
	elif hour >= 17.0 and hour < 20.0:
		phase = "dusk"
	var daylight := smoothstep(5.0, 8.0, hour) * (1.0 - smoothstep(17.0, 20.0, hour))
	var twilight := maxf(0.0, 1.0 - absf(hour - 6.5) / 1.5) + maxf(0.0, 1.0 - absf(hour - 18.5) / 1.5)
	var front := int(total_minutes / FRONT_MINUTES)
	var previous := weather_kind(profile) if not override_kind.is_empty() or front == 0 else _front_kind(front - 1, profile)
	var transition := 1.0 if not override_kind.is_empty() else smoothstep(0.0, float(TRANSITION_MINUTES), float(posmod(total_minutes, FRONT_MINUTES)))
	return {"day": int(total_minutes / 1440) + 1, "hour": hour,
		"clock": "%02d:%02d" % [int(minute / 60), minute % 60],
		"phase": phase, "daylight": daylight, "twilight": twilight,
		"kind": weather_kind(profile), "profile": String(profile), "previous_kind": previous, "transition": transition, "preview": not override_kind.is_empty(),
		"minutes_to_front": FRONT_MINUTES - posmod(total_minutes, FRONT_MINUTES)}

func to_dict() -> Dictionary:
	return {"version": 1, "total_minutes": total_minutes, "world_seed": world_seed, "override_kind": override_kind}

func load_from_dict(data: Dictionary) -> bool:
	if data.is_empty():
		return true
	for key: String in ["version", "total_minutes", "world_seed"]:
		var value: Variant = data.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floor(float(value)):
			return false
	if int(data.version) != 1 or int(data.total_minutes) < 0 or int(data.total_minutes) > 525600000:
		return false
	if int(data.world_seed) < 0 or int(data.world_seed) >= 2147483647:
		return false
	var kind: Variant = data.get("override_kind", "")
	if not kind is String or (kind != "" and kind not in KINDS):
		return false
	total_minutes = int(data.total_minutes)
	world_seed = int(data.world_seed)
	override_kind = kind
	return true

