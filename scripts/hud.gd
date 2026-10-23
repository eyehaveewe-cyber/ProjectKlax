extends CanvasLayer
## Project Klax expedition interface. All game changes leave through command.
signal command(action: String, payload: Variant)

const INK := Color("09141e")
const PANEL := Color("101f2b")
const PALE := Color("e8f0ec")
const MUTED := Color("93a9b4")
const CYAN := Color("79e6db")
const ORANGE := Color("f6bc78")
const RED := Color("ed8782")

var root: Control
var content: Control
var overlay: Control
var fields: Dictionary = {}
var current_screen: String = ""

class SurveyMap extends Control:
	var player := Vector2.ZERO
	var markers: Array = []
	func _draw() -> void:
		var center: Vector2 = size * 0.5
		var radius: float = minf(size.x, size.y) * 0.44
		draw_circle(center, radius, Color(0.035, 0.09, 0.13, 0.96))
		for ring in [0.33, 0.66, 1.0]:
			draw_arc(center, radius * ring, 0, TAU, 64, Color(0.28, 0.53, 0.57, 0.35), 1.0, true)
		draw_line(center - Vector2(radius, 0), center + Vector2(radius, 0), Color(0.28, 0.53, 0.57, 0.3))
		draw_line(center - Vector2(0, radius), center + Vector2(0, radius), Color(0.28, 0.53, 0.57, 0.3))
		var font: Font = get_theme_default_font()
		for marker: Dictionary in markers:
			var p: Vector2 = marker.get("position", Vector2.ZERO)
			var projected: Vector2 = center + p.limit_length(95.0) / 100.0 * radius
			var color: Color = marker.get("color", Color("79e6db"))
			draw_circle(projected, 2.7, color)
			var marker_label: String = str(marker.get("label", ""))
			if not marker_label.is_empty():
				var label_position: Vector2 = projected + Vector2(5, -4)
				draw_string(font, label_position + Vector2.ONE, marker_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0, 0, 0, 0.9))
				draw_string(font, label_position, marker_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
		var lp: Vector2 = center
		draw_rect(Rect2(lp - Vector2(4, 4), Vector2(8, 8)), Color("f6bc78"), false, 1.5)
		var pp: Vector2 = center + player.limit_length(95.0) / 100.0 * radius
		draw_circle(pp, 5.5, Color(0.45, 1.0, 0.9, 0.18))
		draw_circle(pp, 2.8, Color("e8f0ec"))
		draw_string(font, Vector2(center.x - 4, 12), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("93a9b4"))
		draw_string(font, Vector2(-28, size.y - 2), "L ship  D deposit  S site  G tether", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("93a9b4"))

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_root()

func _style(bg: Color, border: Color, width: int = 1, radius: int = 6) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box

func _ensure_root() -> void:
	if is_instance_valid(root):
		return
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme := Theme.new()
	theme.default_font = load("res://assets/fonts/DejaVuSans.ttf")
	theme.default_font_size = 15
	theme.set_color("font_color", "Label", PALE)
	theme.set_color("font_color", "Button", PALE)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", CYAN)
	theme.set_color("font_disabled_color", "Button", Color("536775"))
	theme.set_stylebox("normal", "Button", _style(PANEL, Color("2e4654")))
	theme.set_stylebox("hover", "Button", _style(Color("18343f"), CYAN))
	theme.set_stylebox("pressed", "Button", _style(Color("21444c"), CYAN))
	theme.set_stylebox("focus", "Button", _style(Color(0, 0, 0, 0), ORANGE, 2))
	theme.set_stylebox("disabled", "Button", _style(Color("10202a"), Color("263743")))
	theme.set_stylebox("panel", "PanelContainer", _style(Color(0.04, 0.09, 0.13, 0.95), Color("2d4652")))
	theme.set_constant("separation", "VBoxContainer", 9)
	theme.set_constant("separation", "HBoxContainer", 10)
	theme.set_constant("h_separation", "GridContainer", 10)
	theme.set_constant("v_separation", "GridContainer", 10)
	root.theme = theme
	content = Control.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(content)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)

func _clear(screen: String) -> void:
	_ensure_root()
	for child: Node in content.get_children():
		child.queue_free()
	fields.clear()
	current_screen = screen
	clear_overlay()

func _label(text: String, font_size: int = 15, color: Color = PALE, wrap: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _button(text: String, action: String, payload: Variant = null, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 40
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(func() -> void: command.emit(action, payload))
	if primary:
		button.add_theme_stylebox_override("normal", _style(Color("7de2d6"), CYAN))
		button.add_theme_color_override("font_color", INK)
		button.add_theme_stylebox_override("hover", _style(Color("b1fff1"), Color.WHITE))
		button.add_theme_color_override("font_hover_color", INK)
		button.add_theme_stylebox_override("pressed", _style(Color("4ca89e"), CYAN))
	return button

func _panel(parent: Node, left: float, top: float, right: float, bottom: float, offsets: Vector4 = Vector4.ZERO) -> PanelContainer:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	panel.anchor_left = left
	panel.anchor_top = top
	panel.anchor_right = right
	panel.anchor_bottom = bottom
	panel.offset_left = offsets.x
	panel.offset_top = offsets.y
	panel.offset_right = offsets.z
	panel.offset_bottom = offsets.w
	return panel

func _column(parent: Node, separation: int = 9) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", separation)
	parent.add_child(column)
	return column

func _row(parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	parent.add_child(row)
	return row

func _spacer(parent: Node, height: float = 0) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(spacer)
	return spacer

func _line(parent: Node) -> void:
	var line := HSeparator.new()
	line.modulate = Color("395361")
	parent.add_child(line)

func _tag(text: String, color: Color = CYAN) -> Label:
	var label: Label = _label(text, 11, color)
	label.add_theme_constant_override("outline_size", 1)
	return label

func _entry(research: Dictionary, species_id: int) -> Dictionary:
	var value: Variant = research.get(str(species_id), research.get(species_id, {}))
	return value if value is Dictionary else {}

func show_hub(state: Dictionary, planets: Array, species: Array, upgrades: Array, crew: Array) -> void:
	_clear("hub")
	var title := VBoxContainer.new()
	content.add_child(title)
	title.position = Vector2(32, 28)
	title.add_theme_constant_override("separation", 3)
	title.add_child(_tag("XENOBIOLOGY / DEEP FIELD PROGRAM", CYAN))
	title.add_child(_label("PROJECT KLAX", 44))
	title.add_child(_label("Find what survived us.", 18, MUTED))
	var status := _label("RESEARCH VESSEL  ·  ORBITAL OPERATIONS", 11, MUTED)
	content.add_child(status)
	status.position = Vector2(34, 144)
	var utility_row := HBoxContainer.new()
	content.add_child(utility_row)
	utility_row.position = Vector2(32, 172)
	for item: Array in [["Field manual", "help"], ["New campaign", "new"]]:
		var utility: Button = _button(item[0], item[1])
		utility.custom_minimum_size.y = 30
		utility.add_theme_font_size_override("font_size", 12)
		utility_row.add_child(utility)
	var mission_panel: PanelContainer = _panel(content, 0.53, 0.0, 1.0, 1.0, Vector4(0, 26, -28, -197))
	var mission: VBoxContainer = _column(mission_panel, 8)
	var top: HBoxContainer = _row(mission)
	var report: Label = _tag("EXPEDITION BOARD")
	report.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(report)
	top.add_child(_label("%d RESEARCH" % int(state.get("science", 0)), 14, ORANGE))
	var relays: Array = state.get("relays", [])
	mission.add_child(_label("Signal network  %d / 5 relays recovered" % mini(relays.size(), 5), 13, MUTED))
	var selected: int = clampi(int(state.get("selected_planet", 0)), 0, maxi(planets.size() - 1, 0))
	var grid := GridContainer.new()
	grid.columns = 2
	mission.add_child(grid)
	for i in range(planets.size()):
		var planet: Dictionary = planets[i]
		var locked: bool = i == 5 and relays.size() < 5
		var recovered: bool = relays.has(i)
		var mark: String = "LOCKED" if locked else ("RELAY RECOVERED" if recovered else "SURVEY AVAILABLE")
		var card: Button = _button("%02d  %s\n%s" % [i + 1, str(planet.get("name", "Unknown")), mark], "select_planet", i)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(170, 58)
		card.add_theme_font_size_override("font_size", 13)
		card.disabled = locked
		card.tooltip_text = str(planet.get("brief", ""))
		if i == selected:
			card.add_theme_stylebox_override("normal", _style(Color("1c3942"), CYAN, 2))
		grid.add_child(card)
	_line(mission)
	if not planets.is_empty():
		var planet: Dictionary = planets[selected]
		mission.add_child(_label(str(planet.get("name", "")).to_upper(), 25))
		mission.add_child(_label(str(planet.get("brief", "")), 14, MUTED, true))
		mission.add_child(_tag("FIELD HAZARD / " + str(planet.get("hazard", "Unknown")).to_upper(), ORANGE))
	_spacer(mission)
	var launch: Button = _button("DEPLOY EXPEDITION   →", "launch", null, true)
	launch.custom_minimum_size.y = 47
	launch.disabled = selected == 5 and relays.size() < 5
	mission.add_child(launch)
	var tools: HBoxContainer = _row(mission)
	var waiting := 0
	for entry: Dictionary in state.get("research",{}).values():
		if bool(entry.get("sampled",false)) and not bool(entry.get("analyzed",false)): waiting+=1
	var lab: Button = _button("Specimen lab (%d ready)" % waiting, "lab")
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(lab)
	var journal: Button = _button("Field journal", "journal")
	journal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(journal)
	var ending: String = str(state.get("ending", ""))
	if relays.has(5) and ending.is_empty():
		var council: Button = _button("Council recommendation →", "council", null, true)
		council.custom_minimum_size.y = 38
		mission.add_child(council)
	elif not ending.is_empty():
		mission.add_child(_label("EXPEDITION COMPLETE  /  " + ending.to_upper(), 12, CYAN, true))
	var briefing: PanelContainer = _panel(content, 0, 1, 0.50, 1, Vector4(28, -358, -18, -197))
	var crew_box: VBoxContainer = _column(briefing, 7)
	crew_box.add_child(_tag("AWAY TEAM SPECIALIST", ORANGE))
	var crew_row: HBoxContainer = _row(crew_box)
	var chosen: int = int(state.get("selected_crew", 0))
	for i in range(crew.size()):
		var member: Dictionary = crew[i]
		var button: Button = _button(str(member.get("name", "Specialist")), "select_crew", i)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 13)
		if i == chosen:
			button.add_theme_stylebox_override("normal", _style(Color("29362e"), ORANGE))
		crew_row.add_child(button)
	if not crew.is_empty():
		var member: Dictionary = crew[clampi(chosen, 0, crew.size() - 1)]
		crew_box.add_child(_label(str(member.get("role", "")) + " · " + str(member.get("description", "")), 13, MUTED, true))
	var upgrade_panel: PanelContainer = _panel(content, 0, 1, 1, 1, Vector4(28, -180, -28, -24))
	var upgrade_box: VBoxContainer = _column(upgrade_panel, 7)
	var upgrade_heading: HBoxContainer = _row(upgrade_box)
	var ulabel: Label = _tag("SHIP FABRICATOR")
	ulabel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrade_heading.add_child(ulabel)
	upgrade_heading.add_child(_label("Recovered specimens fund the next expedition.", 12, MUTED))
	var upgrade_row: HBoxContainer = _row(upgrade_box)
	var owned: Dictionary = state.get("upgrades", {})
	for upgrade: Dictionary in upgrades:
		var id: String = str(upgrade.get("id", ""))
		var level: int = int(owned.get(id, 0))
		var cap: int = int(upgrade.get("max", 1))
		var cost: int = int(upgrade.get("cost", 20)) * (level + 1)
		var label: String = "%s\n%s" % [str(upgrade.get("name", id)), ("COMPLETE" if level >= cap else "%d RP · LEVEL %d/%d" % [cost, level, cap])]
		var buy: Button = _button(label, "upgrade", id)
		buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buy.custom_minimum_size.y = 70
		buy.add_theme_font_size_override("font_size", 12)
		buy.tooltip_text = str(upgrade.get("description", ""))
		buy.disabled = level >= cap or int(state.get("science", 0)) < cost
		upgrade_row.add_child(buy)
	if not ending.is_empty():
		status.text = "EXPEDITION COMPLETE  ·  " + ending.to_upper()

func _meter(parent: Node, label: String, color: Color) -> Dictionary:
	var row: HBoxContainer = _row(parent)
	row.add_theme_constant_override("separation", 8)
	var name_label: Label = _label(label, 13, MUTED)
	name_label.custom_minimum_size.x = 60
	row.add_child(name_label)
	var bar := ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(80, 7)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	bar.max_value = 100
	bar.add_theme_stylebox_override("background", _style(Color("263d48"), Color("263d48"), 0, 3))
	bar.add_theme_stylebox_override("fill", _style(color, color, 0, 3))
	row.add_child(bar)
	var value: Label = _label("100", 14, color)
	value.custom_minimum_size.x = 36
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	return {"bar": bar, "value": value}

func show_field(snapshot: Dictionary) -> void:
	_clear("field")
	var vitals_panel: PanelContainer = _panel(content, 0, 0, 0, 0, Vector4(22, 22, 326, 150))
	var vitals: VBoxContainer = _column(vitals_panel, 6)
	fields.planet = _label("", 16)
	vitals.add_child(fields.planet)
	fields.health = _meter(vitals, "INTEGRITY", RED)
	fields.oxygen = _meter(vitals, "OXYGEN", CYAN)
	fields.energy = _meter(vitals, "CHARGE", ORANGE)
	var objective_panel: PanelContainer = _panel(content, 0.5, 0, 0.5, 0, Vector4(-205, 22, 205, 116))
	var objective_box: VBoxContainer = _column(objective_panel, 4)
	fields.mode = _tag("SURVEY")
	objective_box.add_child(fields.mode)
	fields.objective = _label("", 16, PALE, true)
	objective_box.add_child(fields.objective)
	var supply_panel: PanelContainer = _panel(content, 1, 0, 1, 0, Vector4(-270, 22, -22, 116))
	var supply_box: VBoxContainer = _column(supply_panel, 4)
	fields.supply = _label("", 15, ORANGE)
	supply_box.add_child(fields.supply)
	fields.weather = _label("", 14, MUTED, true)
	supply_box.add_child(fields.weather)
	var target_panel: PanelContainer = _panel(content, 0.5, 1, 0.5, 1, Vector4(-300, -220, 300, -109))
	fields.target_panel = target_panel
	var target_box: VBoxContainer = _column(target_panel, 5)
	fields.target = _label("", 20, CYAN, true)
	target_box.add_child(fields.target)
	fields.target_detail = _label("", 17, MUTED, true)
	target_box.add_child(fields.target_detail)
	var scan := ProgressBar.new()
	scan.show_percentage = false
	scan.max_value = 1.0
	scan.custom_minimum_size.y = 6
	scan.add_theme_stylebox_override("background", _style(Color("1d3943"), Color("1d3943"), 0, 3))
	scan.add_theme_stylebox_override("fill", _style(CYAN, CYAN, 0, 3))
	target_box.add_child(scan)
	fields.scan = scan
	var nav_panel: PanelContainer = _panel(content,0.5,0,0.5,0,Vector4(-305,124,305,181))
	fields.navigation = _label("",17,ORANGE,true)
	nav_panel.add_child(fields.navigation)
	fields.message = _label("", 18, PALE, true)
	content.add_child(fields.message)
	fields.message.anchor_left = 0.25
	fields.message.anchor_right = 0.75
	fields.message.anchor_top = 0.25
	fields.message.anchor_bottom = 0.34
	fields.message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fields.message.add_theme_color_override("font_shadow_color", Color.BLACK)
	fields.message.add_theme_constant_override("shadow_offset_x", 1)
	fields.message.add_theme_constant_override("shadow_offset_y", 2)
	var map := SurveyMap.new()
	content.add_child(map)
	map.anchor_left = 1
	map.anchor_right = 1
	map.anchor_top = 1
	map.anchor_bottom = 1
	map.offset_left = -222
	map.offset_right = -20
	map.offset_top = -321
	map.offset_bottom = -115
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fields.map = map
	var controls: PanelContainer = _panel(content, 0, 1, 1, 1, Vector4(22, -92, -22, -19))
	var controls_box: VBoxContainer = _column(controls, 4)
	var buttons: HBoxContainer = _row(controls_box)
	for item: Array in [["Pulse [Space]", "pulse"], ["Lure [Q]", "lure"], ["Rover [R]", "mount"], ["Station [B]", "camp"], ["Tactical [Tab]", "tactical"], ["Journal", "journal"], ["Help", "help"], ["Ship [X]", "extract"]]:
		var button: Button = _button(item[0], item[1])
		button.add_theme_font_size_override("font_size", 12)
		button.custom_minimum_size.y = 30
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(button)
	controls_box.add_child(_label("E scan / deposit  ·  F sample  ·  C crouch  ·  G tether  ·  Shift sprint / boost  ·  X return at lander  ·  Esc pause", 14, MUTED))
	fields.rover = _label("", 12, ORANGE)
	content.add_child(fields.rover)
	fields.rover.position = Vector2(28, 161)
	update_field(snapshot)

func update_field(snapshot: Dictionary) -> void:
	if current_screen != "field":
		return
	fields.planet.text = str(snapshot.get("planet", "Unknown world"))
	fields.objective.text = str(snapshot.get("objective", "Survey the nearby lifeforms."))
	fields.mode.text = str(snapshot.get("mode", "SURVEY")) + ("  /  %d ORDERS" % int(snapshot.get("tactical_ap", 3)) if str(snapshot.get("mode", "SURVEY")) == "TACTICAL" else "  /  FIELD RESEARCH")
	for key: String in ["health", "oxygen", "energy"]:
		var value: float = float(snapshot.get(key, 100))
		fields[key].bar.value = value
		fields[key].value.text = str(ceili(value))
	fields.supply.text = "%d RP · %d CARGO" % [int(snapshot.get("science", 0)), int(snapshot.get("cargo", 0))]
	fields.navigation.text = str(snapshot.get("navigation",""))
	fields.weather.text = str(snapshot.get("weather", "Calm"))
	fields.target.text = str(snapshot.get("target", "No specimen selected"))
	fields.target_detail.text = str(snapshot.get("target_detail", "Approach a lifeform. Hold E to study it."))
	fields.scan.value = float(snapshot.get("scan_progress", 0))
	fields.message.text = str(snapshot.get("message", ""))
	fields.rover.text = "ROVER  /  BOOST %d%%  /  HULL %d%%\nLEFT %d%%   RIGHT %d%%" % [int(snapshot.get("boost", 100)), int(snapshot.get("rover_hull", 100)), int(snapshot.get("left_module", 100)), int(snapshot.get("right_module", 100))] if bool(snapshot.get("rover", false)) else ("CROUCHED  /  C TO STAND" if bool(snapshot.get("crouched",false)) else "ON FOOT  /  C CROUCH · G TETHER")
	fields.map.player = snapshot.get("player", Vector2.ZERO)
	fields.map.markers = snapshot.get("markers", [])
	fields.map.queue_redraw()

func _screen_panel(title: String, subtitle: String) -> VBoxContainer:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.018, 0.04, 0.06, 0.88)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(backdrop)
	var panel: PanelContainer = _panel(content, 0, 0, 1, 1, Vector4(40, 32, -40, -32))
	var box: VBoxContainer = _column(panel, 12)
	var header: HBoxContainer = _row(box)
	var titles: VBoxContainer = _column(header, 3)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(_tag("PROJECT KLAX / RESEARCH DIVISION"))
	titles.add_child(_label(title, 31))
	header.add_child(_button("← Back", "close"))
	box.add_child(_label(subtitle, 16, MUTED, true))
	_line(box)
	return box

func show_journal(state: Dictionary, species: Array) -> void:
	_clear("journal")
	var research: Dictionary = state.get("research", {})
	var known: int = 0
	var analyzed: int = 0
	for i in range(species.size()):
		var entry: Dictionary = _entry(research, int(species[i].get("id", i)))
		known += int(bool(entry.get("scanned", false)))
		analyzed += int(bool(entry.get("analyzed", false)))
	var box: VBoxContainer = _screen_panel("Field journal", "%d / %d species observed   ·   %d cultures analyzed   ·   Hold E near life to reveal a record." % [known, species.size(), analyzed])
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var journal_body: VBoxContainer = _column(scroll,14)
	journal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	journal_body.add_child(grid)
	for i in range(species.size()):
		var organism: Dictionary = species[i]
		var id: int = int(organism.get("id", i))
		var entry: Dictionary = _entry(research, id)
		var scanned: bool = bool(entry.get("scanned", false))
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.custom_minimum_size = Vector2(280, 216)
		grid.add_child(panel)
		var card: VBoxContainer = _column(panel, 6)
		var stage: String = "CULTURE ANALYZED" if bool(entry.get("analyzed", false)) else ("SAMPLE RECOVERED" if bool(entry.get("sampled", false)) else ("OBSERVED" if scanned else "UNIDENTIFIED"))
		card.add_child(_tag("%02d / %s" % [id + 1, stage], CYAN if scanned else MUTED))
		card.add_child(_label(str(organism.get("name", "Specimen")) if scanned else "Unknown lifeform", 20, PALE, true))
		card.add_child(_label(str(organism.get("latin", "")) if scanned else "No field observation recorded.", 12, MUTED, true))
		if scanned:
			card.add_child(_label(str(organism.get("temperament", "Unknown")).capitalize() + "  ·  " + str(organism.get("diet", "")), 12, ORANGE, true))
			card.add_child(_label(str(organism.get("clue", "")), 13, PALE, true))
			if bool(entry.get("analyzed", false)):
				card.add_child(_label("Adaptation: " + str(organism.get("adaptation", "")), 12, CYAN, true))
	journal_body.add_child(_label("Recovered transmissions",24,PALE))
	var logs: Array = state.get("logs",[])
	if logs.is_empty():
		journal_body.add_child(_label("Recover and extract a relay to preserve its transmission here. Field toasts remain brief.",17,MUTED,true))
	for log: Variant in logs:
		journal_body.add_child(_label(str(log),18,PALE,true))
	var surveys: Array = state.get("surveys",[])
	if not surveys.is_empty():
		journal_body.add_child(_label("Habitat surveys",24,PALE))
		var catalog = preload("res://scripts/catalog.gd")
		for id: Variant in surveys:
			var place: Dictionary = catalog.planets()[int(id)]
			journal_body.add_child(_label(str(place.site)+". "+str(place.hook),18,MUTED,true))
	box.add_child(_label("INHERITED SYSTEMS  /  Tilebean ecology · Zen Elysium weather · Zendelves researcher · ASCII Racer rover · Barrel Roll carrier", 11, MUTED, true))

func show_lab(state: Dictionary, species: Array) -> void:
	_clear("lab")
	var box: VBoxContainer = _screen_panel("Specimen lab", "1. Select a saved culture.  2. Analyze now, or play the optional assay.  3. Buy upgrades on the mission deck.")
	var stats: HBoxContainer = _row(box)
	stats.add_child(_label("%d RESEARCH POINTS" % int(state.get("science", 0)), 20, ORANGE))
	var note: Label = _label("Deposited or extracted cultures are saved here.", 15, MUTED)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stats.add_child(note)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list: VBoxContainer = _column(scroll, 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var research: Dictionary = state.get("research", {})
	var count: int = 0
	for i in range(species.size()):
		var organism: Dictionary = species[i]
		var id: int = int(organism.get("id", i))
		var entry: Dictionary = _entry(research, id)
		if not bool(entry.get("sampled", false)) and not state.get("samples", []).has(id):
			continue
		count += 1
		var panel := PanelContainer.new()
		list.add_child(panel)
		var row: HBoxContainer = _row(panel)
		var info: VBoxContainer = _column(row, 4)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(_tag("CULTURE %02d / %s" % [id + 1, "STABLE" if bool(entry.get("analyzed", false)) else "AWAITING ASSAY"]))
		info.add_child(_label(str(organism.get("name", "Specimen")), 22))
		info.add_child(_label(str(organism.get("clue", "")), 14, MUTED, true))
		var button: Button = _button("Analyzed" if bool(entry.get("analyzed", false)) else "Begin assay →", "analyze", id, not bool(entry.get("analyzed", false)))
		button.custom_minimum_size = Vector2(160, 48)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.disabled = bool(entry.get("analyzed", false))
		row.add_child(button)
	if count == 0:
		_spacer(list, 35)
		list.add_child(_label("The lab is waiting for its first specimen.", 25, PALE, true))
		list.add_child(_label("Deploy to a planet, approach a lifeform and hold E to observe it. Press F to collect. E at a cyan D console saves cargo. X at the lander returns to this lab.", 17, MUTED, true))
		_spacer(list)
	box.add_child(_label("FIELD PROTOCOL  /  Observe first. Keep a safe distance from predators. A calm subject yields a cleaner sample.", 12, CYAN, true))

func show_overlay(title: String, body: String, buttons: Array) -> void:
	_ensure_root()
	clear_overlay()
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.025, 0.04, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 580
	center.add_child(panel)
	var box: VBoxContainer = _column(panel, 15)
	box.add_child(_tag("PROJECT KLAX / EXPEDITION CONTROL"))
	box.add_child(_label(title, 30, PALE, true))
	var description: Label = _label(body, 18, PALE, true)
	description.custom_minimum_size.x = 580
	box.add_child(description)
	_line(box)
	for i in range(buttons.size()):
		var item: Dictionary = buttons[i]
		var button: Button = _button(str(item.get("text", "Continue")), str(item.get("action", "close")), item.get("payload", null), i == 0)
		box.add_child(button)

func clear_overlay() -> void:
	if is_instance_valid(overlay):
		for child: Node in overlay.get_children():
			child.queue_free()
