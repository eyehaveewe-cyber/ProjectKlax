class_name TestRoomRng
extends RefCounted

const VERSION := "park_miller_test_v1"
const PRIME := 2147483647
const MULTIPLIER := 48271

var seed: int = 1
var _state: int = 1


func _init(seed_value: int = 1) -> void:
	reset(seed_value)


func reset(seed_value: int) -> void:
	seed = _normalize_seed(seed_value)
	_state = seed


func next_value() -> int:
	_state = int((_state * MULTIPLIER) % PRIME)
	return _state


func roll_basis_points() -> int:
	return next_value() % 10000


func roll_chance(chance: float) -> bool:
	return roll_basis_points() < int(round(clampf(chance, 0.0, 1.0) * 10000.0))


func sequence(count: int) -> Array[int]:
	var result: Array[int] = []
	for _index in range(maxi(count, 0)):
		result.append(next_value())
	return result


static func values_for_seed(seed_value: int, count: int) -> Array[int]:
	var generator := TestRoomRng.new(seed_value)
	return generator.sequence(count)


func _normalize_seed(value: int) -> int:
	var normalized: int = abs(value) % PRIME
	return maxi(normalized, 1)

