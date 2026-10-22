extends SceneTree

const Assay = preload("res://scripts/assay.gd")
var failures: Array[String] = []
var awards: Array = []
var cancellations := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _run() -> void:
	var assay = Assay.new()
	root.add_child(assay)
	assay.finished.connect(func(id: int, bonus: int): awards.append([id, bonus]))
	assay.cancelled.connect(func(): cancellations += 1)
	for seed_value in range(40):
		assay.configure(3, "Test specimen", seed_value)
		_check(assay.board.size() == 36, "Board has 36 cells")
		_check(assay._matches().is_empty(), "Initial board has no matches at seed %d" % seed_value)
		_check(not assay.valid_swaps().is_empty(), "Initial board has a valid move at seed %d" % seed_value)
		var initial: Array = assay.board.duplicate()
		assay.configure(3, "Test specimen", seed_value)
		_check(assay.board == initial, "Seed is deterministic")
		_check(not assay.attempt_swap(5, 6), "Row-wrap swap rejected")
		_check(not assay.attempt_swap(-1, 0), "Out of bounds rejected")
		_check(assay.moves == 10 and assay.board == initial, "Rejected move preserves state")
		var legal_moves: Array = assay.valid_swaps()
		for index in range(35):
			if index % 6 < 5 and not legal_moves.has(Vector2i(index, index + 1)):
				_check(not assay.attempt_swap(index, index + 1), "Adjacent nonmatch rejected")
				_check(assay.moves == 10 and assay.board == initial, "Nonmatch is fully refunded")
				break
		var move: Vector2i = assay.valid_swaps()[0]
		_check(assay.attempt_swap(move.x, move.y), "Legal match accepted")
		_check(assay.moves == 9, "One move charged per accepted swap")
		_check(assay.matched >= 3, "Matched cells counted")
		_check(assay._matches().is_empty(), "Cascades leave a stable board")
		_check(assay._resolved or not assay.valid_swaps().is_empty(), "Nonterminal board remains playable")
	assay.configure(7, "Cancellation", 313)
	assay._request_cancel()
	assay._request_cancel()
	_check(cancellations == 1, "Cancel emits only once")
	assay.configure(7, "Standard analysis", 313)
	awards.clear()
	assay.analyze_now()
	assay.analyze_now()
	_check(awards == [[7, 0]], "Standard analysis emits exact species and zero bonus once")
	var tested_exhaustion := false
	for seed_value in range(40):
		assay.configure(4, "Last move", seed_value)
		awards.clear()
		assay.moves = 1
		var last_move: Vector2i = assay.valid_swaps()[0]
		assay.attempt_swap(last_move.x, last_move.y)
		if assay.matched < 9:
			_check(awards == [[4, 0]], "Running out of moves still gives standard analysis")
			tested_exhaustion = true
			break
	_check(tested_exhaustion, "Exhaustion fixture exercised")
	assay.configure(8, "Stable analysis", 921)
	awards.clear()
	while not assay._resolved:
		var move: Vector2i = assay.valid_swaps()[0]
		assay.attempt_swap(move.x, move.y)
	_check(awards == [[8, 12]], "Nine isolated cells award the stable assay bonus")
	var end_board: Array = assay.board.duplicate()
	_check(not assay.attempt_swap(0, 1) and assay.board == end_board, "Resolved assays reject further moves")
	assay.queue_free()
	if failures.is_empty():
		print("ASSAY PASS: 40 seeded boards, valid/invalid swaps, cascades, cancellation and exactly-once research awards")
		quit(0)
	else:
		for message in failures:
			push_error(message)
		quit(1)
