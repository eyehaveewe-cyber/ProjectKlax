extends Control
## Original Project Klax specimen assay. No Cat Jewler source was available.
## The caller owns sample consumption and research awards.

signal finished(species_id: int, bonus: int)
signal cancelled

const WIDTH := 6
const CELL_COUNT := WIDTH * WIDTH
const GOAL := 9
const MOVE_LIMIT := 10
const SYMBOLS := ["●", "◆", "+", "■"]
const NAMES := ["Cell", "Spore", "Protein", "Mineral"]
const COLORS := [Color("77e0c6"), Color("e9b977"), Color("a7b9ff"), Color("e99abd")]

var board: Array = []
var moves: int = MOVE_LIMIT
var matched: int = 0
var species_id: int = 0
var species_name: String = "Unknown specimen"
var selected: int = -1
var _rng := RandomNumberGenerator.new()
var _resolved := false
var _built := false
var _buttons: Array[Button] = []
var _heading: Label
var _stats: Label
var _status: Label
var _progress: ProgressBar
var _analyze: Button
var _cancel: Button
var _message := "Select a cell, then an adjacent cell to swap them."

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	if board.is_empty():
		configure(species_id, species_name, 8123)

func configure(id: int, specimen_name: String, seed_value: int) -> void:
	species_id = id
	species_name = specimen_name
	_rng.seed = seed_value
	moves = MOVE_LIMIT
	matched = 0
	selected = -1
	_resolved = false
	_message = "Select a cell, then an adjacent cell to swap them."
	_generate_board()
	if not _built:
		_build_ui()
	_refresh()

func select_cell(index: int) -> void:
	if _resolved or index < 0 or index >= CELL_COUNT:
		return
	if selected == index:
		selected = -1
	elif selected < 0:
		selected = index
	elif _adjacent(selected, index):
		var previous := selected
		selected = -1
		attempt_swap(previous, index)
	else:
		selected = index
	_refresh()

func attempt_swap(a: int, b: int) -> bool:
	if _resolved or moves <= 0 or board.size() != CELL_COUNT or not _adjacent(a, b):
		return false
	_swap(a, b)
	var cells := _matches()
	if cells.is_empty():
		_swap(a, b)
		_message = "No match. Your move was returned. Try three of the same shape in a row."
		_refresh()
		return false
	moves -= 1
	var resolved_count := 0
	var cascades := 0
	while not cells.is_empty() and cascades < 32:
		resolved_count += cells.size()
		for index in cells:
			board[index] = -1
		_collapse()
		cascades += 1
		cells = _matches()
	# Exceptionally long random cascades cannot block the UI or leave old matches.
	if not cells.is_empty():
		_generate_board()
	matched += resolved_count
	selected = -1
	_message = "%d cells isolated%s. The specimen remains safe." % [resolved_count, " across %d cascades" % cascades if cascades > 1 else ""]
	_refresh()
	if matched >= GOAL:
		_complete(12)
	elif moves == 0:
		_complete(0)
	elif valid_swaps().is_empty():
		_generate_board()
		_message += " No combinations remained, so the slide was refreshed at no cost."
		_refresh()
	return true

## Pure board check used by the UI's deadlock recovery and headless tests.
func valid_swaps() -> Array:
	var result: Array = []
	if board.size() != CELL_COUNT:
		return result
	for a in range(CELL_COUNT):
		for b in [a + 1, a + WIDTH]:
			if not _adjacent(a, b):
				continue
			_swap(a, b)
			if not _matches().is_empty():
				result.append(Vector2i(a, b))
			_swap(a, b)
	return result

func analyze_now() -> void:
	if not _resolved:
		_complete(0)

func _adjacent(a: int, b: int) -> bool:
	if a < 0 or b < 0 or a >= CELL_COUNT or b >= CELL_COUNT or a == b:
		return false
	return absi(a % WIDTH - b % WIDTH) + absi(a / WIDTH - b / WIDTH) == 1

func _swap(a: int, b: int) -> void:
	var value: int = board[a]
	board[a] = board[b]
	board[b] = value

func _matches() -> Array:
	var found: Dictionary = {}
	for y in range(WIDTH):
		for x in range(WIDTH):
			var index := y * WIDTH + x
			var value: int = board[index]
			if value < 0:
				continue
			if x <= WIDTH - 3 and board[index + 1] == value and board[index + 2] == value:
				found[index] = true
				found[index + 1] = true
				found[index + 2] = true
			if y <= WIDTH - 3 and board[index + WIDTH] == value and board[index + WIDTH * 2] == value:
				found[index] = true
				found[index + WIDTH] = true
				found[index + WIDTH * 2] = true
	return found.keys()

func _collapse() -> void:
	for x in range(WIDTH):
		var write_y := WIDTH - 1
		for y in range(WIDTH - 1, -1, -1):
			var value: int = board[y * WIDTH + x]
			if value >= 0:
				board[write_y * WIDTH + x] = value
				write_y -= 1
		while write_y >= 0:
			board[write_y * WIDTH + x] = _rng.randi_range(0, 3)
			write_y -= 1

func _generate_board() -> void:
	for generation in range(200):
		board.clear()
		for index in range(CELL_COUNT):
			var choices: Array = [0, 1, 2, 3]
			if index % WIDTH >= 2 and board[index - 1] == board[index - 2]:
				choices.erase(board[index - 1])
			if index >= WIDTH * 2 and board[index - WIDTH] == board[index - WIDTH * 2]:
				choices.erase(board[index - WIDTH])
			board.append(choices[_rng.randi_range(0, choices.size() - 1)])
		if not valid_swaps().is_empty():
			return
	# A deterministic, match-free fallback with a known legal swap at 1 <-> 7.
	board = [0, 1, 0, 2, 3, 1, 2, 0, 3, 1, 2, 0, 1, 2, 0, 3, 1, 2, 3, 0, 1, 2, 0, 3, 2, 3, 2, 0, 3, 1, 0, 1, 3, 1, 2, 0]

func _complete(bonus: int) -> void:
	if _resolved:
		return
	_resolved = true
	_message = "Stable assay: +12 research." if bonus > 0 else "Standard analysis complete. The recovered sample is preserved."
	_refresh()
	finished.emit(species_id, bonus)

func _request_cancel() -> void:
	if _resolved:
		return
	_resolved = true
	cancelled.emit()

func _build_ui() -> void:
	var assay_theme := Theme.new()
	assay_theme.default_font = load("res://assets/fonts/DejaVuSans.ttf")
	theme = assay_theme
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.045, 0.95)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(780, 720)
	panel.add_theme_stylebox_override("panel", _style(Color("0d1b2a"), Color("31566a"), 1, 18))
	center.add_child(panel)
	var margins := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margins)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margins.add_child(column)
	var eyebrow := _label("KLAX / MICROSCOPY LAB", 13, Color("77e0c6"))
	column.add_child(eyebrow)
	_heading = _label("Specimen assay", 26, Color("edf5ff"))
	column.add_child(_heading)
	var instructions := _label("Swap adjacent cells to align 3 or more matching shapes. Isolate 9 cells in 10 valid moves for +12 research. Cascades count.", 16, Color("bccbd8"))
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(instructions)
	_stats = _label("", 17, Color("edf5ff"))
	column.add_child(_stats)
	_progress = ProgressBar.new()
	_progress.max_value = GOAL
	_progress.show_percentage = false
	_progress.custom_minimum_size.y = 8
	_progress.add_theme_stylebox_override("background", _style(Color("172e40"), Color.TRANSPARENT, 0, 4))
	_progress.add_theme_stylebox_override("fill", _style(Color("77e0c6"), Color.TRANSPARENT, 0, 4))
	column.add_child(_progress)
	var grid_center := CenterContainer.new()
	grid_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(grid_center)
	var grid := GridContainer.new()
	grid.columns = WIDTH
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid_center.add_child(grid)
	for index in range(CELL_COUNT):
		var button := Button.new()
		button.custom_minimum_size = Vector2(78, 62)
		button.add_theme_font_size_override("font_size", 17)
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(select_cell.bind(index))
		grid.add_child(button)
		_buttons.append(button)
	_status = _label("", 14, Color("a8bdcc"))
	_status.custom_minimum_size.y = 42
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	column.add_child(actions)
	_analyze = _action_button("Analyze now · standard yield", Color("163c39"), Color("77e0c6"))
	_analyze.pressed.connect(analyze_now)
	actions.add_child(_analyze)
	_cancel = _action_button("Return to lab", Color("1c2b3c"), Color("9aafc4"))
	_cancel.pressed.connect(_request_cancel)
	actions.add_child(_cancel)
	var reassurance := _label("No sample can be lost here. Invalid swaps cost nothing. You can take standard analysis at any time.", 12, Color("849bad"))
	reassurance.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(reassurance)

func _refresh() -> void:
	if not _built or not is_instance_valid(_heading):
		return
	_heading.text = species_name + " / specimen assay"
	_stats.text = "ISOLATED  %d / %d     •     MOVES LEFT  %d" % [matched, GOAL, moves]
	_progress.value = mini(matched, GOAL)
	_status.text = _message
	for index in range(_buttons.size()):
		var button := _buttons[index]
		if index >= board.size():
			continue
		var kind: int = board[index]
		var color: Color = COLORS[kind]
		button.text = "%s\n%s" % [SYMBOLS[kind], NAMES[kind]]
		button.tooltip_text = "%s, row %d column %d. Select an adjacent cell to swap." % [NAMES[kind], index / WIDTH + 1, index % WIDTH + 1]
		button.add_theme_color_override("font_color", color)
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_color_override("font_pressed_color", Color.WHITE)
		button.add_theme_stylebox_override("normal", _style(Color("1d3745") if index == selected else Color("132737"), Color.WHITE if index == selected else color.darkened(0.66), 2 if index == selected else 1, 8))
		button.add_theme_stylebox_override("hover", _style(Color("264454"), color, 2, 8))
		button.add_theme_stylebox_override("pressed", _style(Color("355766"), Color.WHITE, 2, 8))
		button.disabled = _resolved
	_analyze.disabled = _resolved
	_cancel.disabled = _resolved

func _label(value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _action_button(value: String, background: Color, border: Color) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 44
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_stylebox_override("normal", _style(background, border, 1, 8))
	button.add_theme_stylebox_override("hover", _style(background.lightened(0.12), border, 2, 8))
	button.add_theme_stylebox_override("pressed", _style(background.lightened(0.2), Color.WHITE, 2, 8))
	return button

func _style(background: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style
