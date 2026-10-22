class_name KlaxRover
extends Node3D
## Klax field rover. Driving is extracted and retuned from ASCII-Racer's
## GlyphRacer.step_drive. See source-provenance/VEHICLES.md for exact origins.
## Caller advances step_drive and resolves terrain height and world collisions.

const NORMAL_TOP_SPEED := 16.0
const BOOST_TOP_SPEED := 25.0
const DRIFT_THRESHOLDS: Array[float] = [0.12, 0.55, 1.3]
var velocity: Vector3 = Vector3.ZERO
var speed: float = 0.0
var heading: float = 0.0
var boost_energy: float = 100.0
var hull: float = 100.0
var left_module: float = 100.0
var right_module: float = 100.0
var boosting := false
var drifting := false
var drift_charge := 0.0
var drift_stage := 0
var _last_drift_stage := 0
var _boost_empty_latched := false
var _drift_held := false
var _drift_boost_time := 0.0
var _clock := 0.0
var _wheel_angle := 0.0
var _steer_visual := 0.0
var _impact_time := 0.0
var _body: Node3D
var _left_rack: Node3D
var _right_rack: Node3D
var _sensor: Node3D
var _wheels: Array[Node3D] = []
var _warning: MeshInstance3D
var _exhausts: Array[MeshInstance3D] = []
var _materials: Dictionary = {}

func _ready() -> void:
	_build_model()
	_update_visuals(0.0)

func step_drive(delta: float, throttle: float, steer: float, brake: bool, boost: bool) -> void:
	if delta <= 0.0:
		return
	var dt := minf(delta, 0.05)
	throttle = clampf(throttle, -1.0, 1.0)
	steer = clampf(steer, -1.0, 1.0)
	if hull <= 0.0:
		stop()
		return
	_drift_boost_time = maxf(0.0, _drift_boost_time - dt)
	if not boost:
		_boost_empty_latched = false
	elif boost_energy <= 0.2:
		_boost_empty_latched = true
	var modules_online := left_module > 0.0 and right_module > 0.0
	var manual_boost := boost and modules_online and not _boost_empty_latched and boost_energy > 0.2 and throttle > 0.0
	boosting = manual_boost or (_drift_boost_time > 0.0 and modules_online)
	if manual_boost:
		boost_energy = maxf(0.0, boost_energy - dt * 25.0)
	else:
		boost_energy = minf(100.0, boost_energy + dt * (12.0 if brake else 9.0))
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var previous_speed := flat.length()
	drifting = brake and previous_speed > 4.0 and absf(steer) > 0.08
	if drifting:
		drift_charge = minf(3.0, drift_charge + dt * clampf(absf(steer) * 1.4, 0.75, 1.0))
	elif brake:
		drift_charge = maxf(0.0, drift_charge - dt * 0.75)
	drift_stage = 0
	for threshold: float in DRIFT_THRESHOLDS:
		if drift_charge >= threshold:
			drift_stage += 1
	if _drift_held and not brake:
		_last_drift_stage = drift_stage
		if drift_stage > 0 and previous_speed > 4.0 and modules_online:
			_drift_boost_time = 0.22 + drift_stage * 0.24
			flat += Vector3(-sin(heading), 0.0, -cos(heading)) * (0.8 + drift_stage * 0.8)
			boost_energy = minf(100.0, boost_energy + drift_stage * 4.0)
			boosting = true
		drift_charge = 0.0
		drift_stage = 0
	_drift_held = brake
	var imbalance := (right_module - left_module) / 100.0
	var damaged := 1.0 - minf(left_module, right_module) / 100.0
	var turn_rate := lerpf(1.85, 1.38, clampf(previous_speed / BOOST_TOP_SPEED, 0.0, 1.0))
	if brake:
		turn_rate *= 1.38
	turn_rate *= 1.0 - damaged * 0.28
	# Asymmetric missing modules pull the physical heading, not just the model.
	# Braking damps the pull so a damaged rover can always be brought home.
	var pull := imbalance * clampf(previous_speed / 10.0, 0.0, 1.5) * (0.12 if brake else 0.62)
	heading = wrapf(heading - steer * turn_rate * dt + pull * dt, -PI, PI)
	rotation.y = heading
	var facing := Vector3(-sin(heading), 0.0, -cos(heading))
	var right := Vector3(cos(heading), 0.0, -sin(heading))
	var lateral_speed := flat.dot(right)
	var grip := (4.5 if brake else 8.5) * (1.0 - damaged * 0.45)
	flat -= right * lateral_speed * (1.0 - exp(-grip * dt))
	var acceleration := (13.0 if boosting else 9.0) + (_last_drift_stage * 2.0 if _drift_boost_time > 0.0 else 0.0)
	flat += facing * throttle * acceleration * dt
	# Deliberate Klax retuning: safe expedition stops instead of racing coast.
	var drag := 0.8 if is_zero_approx(throttle) else 0.12
	if brake:
		drag += 1.8 if absf(steer) < 0.08 else 0.45
	flat *= exp(-drag * dt)
	var top_speed := (BOOST_TOP_SPEED if boosting else NORMAL_TOP_SPEED) * (1.0 - damaged * 0.2)
	var ceiling := maxf(top_speed, move_toward(previous_speed, top_speed, dt * 12.0))
	if flat.length() > ceiling:
		flat = flat.normalized() * ceiling
	var forward_speed := flat.dot(facing)
	if forward_speed < -5.0:
		flat += facing * (-5.0 - forward_speed)
	velocity.x = flat.x
	velocity.z = flat.z
	position.x += flat.x * dt
	position.z += flat.z * dt
	speed = flat.length()
	_steer_visual = lerpf(_steer_visual, steer, 1.0 - exp(-dt * 9.0))
	_wheel_angle += forward_speed * dt / 0.42

func take_damage(amount: float, side: int = 0) -> void:
	if amount <= 0.0:
		return
	hull = maxf(0.0, hull - amount)
	if side < 0:
		left_module = maxf(0.0, left_module - amount * 2.5)
	elif side > 0:
		right_module = maxf(0.0, right_module - amount * 2.5)
	else:
		left_module = maxf(0.0, left_module - amount * 0.65)
		right_module = maxf(0.0, right_module - amount * 0.65)
	_impact_time = 0.55
	if hull <= 0.0:
		stop()

func repair() -> void:
	hull = 100.0
	left_module = 100.0
	right_module = 100.0
	boost_energy = 100.0
	_impact_time = 0.0
	stop()

func stop() -> void:
	velocity = Vector3.ZERO
	speed = 0.0
	boosting = false
	drifting = false
	drift_charge = 0.0
	drift_stage = 0
	_drift_held = false
	_drift_boost_time = 0.0
	_boost_empty_latched = false

func _process(delta: float) -> void:
	_clock += delta
	_impact_time = maxf(0.0, _impact_time - delta)
	_update_visuals(delta)

func _update_visuals(_delta: float) -> void:
	if not is_instance_valid(_body):
		return
	var imbalance := (right_module - left_module) / 100.0
	var motion := clampf(speed / NORMAL_TOP_SPEED, 0.0, 1.5)
	_body.position.y = sin(_clock * 12.0) * 0.025 * motion
	_body.rotation.z = -_steer_visual * motion * 0.09 + imbalance * (0.16 + sin(_clock * 8.0) * 0.09 * motion)
	_body.rotation.x = sin(_clock * 30.0) * _impact_time * 0.1
	_left_rack.visible = left_module > 0.0
	_right_rack.visible = right_module > 0.0
	_left_rack.rotation.z = (1.0 - left_module / 100.0) * 0.25
	_right_rack.rotation.z = -(1.0 - right_module / 100.0) * 0.25
	_warning.visible = hull < 40.0 or left_module <= 0.0 or right_module <= 0.0
	_warning.scale = Vector3.ONE * (0.7 + 0.3 * sin(_clock * 8.0))
	_sensor.rotation.y = sin(_clock * 0.7) * 0.5
	for wheel: Node3D in _wheels:
		wheel.rotation.x = _wheel_angle
	for flame: MeshInstance3D in _exhausts:
		flame.visible = boosting
		flame.scale.z = 0.8 + 0.3 * sin(_clock * 29.0)

func _material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var key := "%s/%.2f" % [color.to_html(), glow]
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.7
	mat.metallic = 0.25
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	_materials[key] = mat
	return mat

func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, color: Color, glow: float = 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.material_override = _material(color, glow)
	parent.add_child(node)
	return node

func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color, glow: float = 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent, mesh, at, color, glow)

func _cylinder(parent: Node3D, radius: float, height: float, at: Vector3, color: Color, glow: float = 0.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	return _mesh(parent, mesh, at, color, glow)

func _build_model() -> void:
	_body = Node3D.new()
	_body.name = "SuspensionBody"
	add_child(_body)
	var armor := Color("bccdc3")
	var dark := Color("192d34")
	var teal := Color("55f2cb")
	var amber := Color("ffc675")
	_box(_body, Vector3(1.65, 0.45, 3.2), Vector3(0, 0.68, 0), armor)
	_box(_body, Vector3(1.85, 0.2, 3.4), Vector3(0, 0.44, 0), dark)
	_box(_body, Vector3(1.35, 0.75, 1.35), Vector3(0, 1.2, -0.65), armor)
	_box(_body, Vector3(1.12, 0.43, 0.06), Vector3(0, 1.28, -1.35), Color("16444f"), 0.3)
	_box(_body, Vector3(0.08, 0.48, 0.08), Vector3(0, 1.28, -1.39), dark)
	_box(_body, Vector3(1.45, 0.11, 1.45), Vector3(0, 1.63, -0.65), dark)
	_box(_body, Vector3(1.8, 0.18, 0.14), Vector3(0, 0.75, -1.78), amber)
	_box(_body, Vector3(1.35, 0.15, 0.85), Vector3(0, 0.98, 0.85), dark)
	for side: int in [-1, 1]:
		_box(_body, Vector3(0.35, 0.16, 0.1), Vector3(side * 0.55, 1.0, -1.58), Color("e6ffef"), 1.8)
		_box(_body, Vector3(0.14, 0.14, 0.1), Vector3(side * 0.6, 0.78, 1.65), Color("ff665b"), 1.3)
		for z: float in [-1.1, 0.0, 1.1]:
			var wheel := Node3D.new()
			wheel.position = Vector3(side * 1.0, 0.44, z)
			add_child(wheel)
			_wheels.append(wheel)
			var tire := _cylinder(wheel, 0.43, 0.36, Vector3.ZERO, Color("111b22"))
			tire.rotation.z = PI / 2.0
			var hub := _cylinder(wheel, 0.23, 0.39, Vector3.ZERO, armor)
			hub.rotation.z = PI / 2.0
			_box(wheel, Vector3(0.41, 0.07, 0.38), Vector3.ZERO, amber)
			_box(_body, Vector3(0.27, 0.12, 0.6), Vector3(side * 0.78, 0.58, z), dark)
		var rack := Node3D.new()
		rack.position = Vector3(side * 0.92, 0.92, 0.1)
		_body.add_child(rack)
		if side < 0:
			_left_rack = rack
		else:
			_right_rack = rack
		_box(rack, Vector3(0.25, 0.5, 1.2), Vector3.ZERO, dark)
		_box(rack, Vector3(0.28, 0.08, 1.23), Vector3(0, 0.25, 0), teal, 0.6)
		# Extruded TextMesh adapted from ASCII-Racer GlyphFactory.glyph/mesh.
		var glyph := TextMesh.new()
		glyph.font = ThemeDB.fallback_font
		glyph.text = "#" if side < 0 else "&"
		glyph.font_size = 64
		glyph.pixel_size = 0.008
		glyph.depth = 0.06
		var tag := _mesh(rack, glyph, Vector3(side * 0.16, 0.0, 0.0), teal, 1.2)
		tag.rotation.y = side * PI / 2.0
		var flame := _box(_body, Vector3(0.25, 0.2, 0.6), Vector3(side * 0.55, 0.58, 1.95), teal, 1.5)
		_exhausts.append(flame)
	for i: int in 3:
		_cylinder(_body, 0.15, 0.44, Vector3((i - 1) * 0.38, 1.24, 0.95), Color("317977"))
		_cylinder(_body, 0.17, 0.08, Vector3((i - 1) * 0.38, 1.48, 0.95), teal, 0.7)
	_sensor = Node3D.new()
	_sensor.position = Vector3(0.55, 1.55, 0.25)
	_body.add_child(_sensor)
	_cylinder(_sensor, 0.035, 0.65, Vector3(0, 0.28, 0), armor)
	_box(_sensor, Vector3(0.45, 0.2, 0.18), Vector3(0, 0.65, 0), dark)
	_box(_sensor, Vector3(0.35, 0.1, 0.03), Vector3(0, 0.65, -0.11), teal, 0.8)
	_warning = _cylinder(_body, 0.12, 0.17, Vector3(-0.5, 1.77, -0.5), Color("ff574c"), 2.0)
