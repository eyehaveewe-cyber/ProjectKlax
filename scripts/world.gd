extends Node3D
## Authored exploration routes over deterministic low-poly terrain.

var specimen_spawns: Array[Dictionary] = []
var points: Array[Dictionary] = []
var obstacles: Array[Dictionary] = []
var planet_data: Dictionary = {}
var world_seed := 0
var _rng := RandomNumberGenerator.new()
var _base := Color("355951")
var _accent := Color("a6e7be")
var _biome := "moss"
var _material_cache: Dictionary = {}
var _relay_position := Vector2(4, -57)
var _route_points: Array[Vector2] = []
var _ruin_positions: Array[Vector2] = []
var _cache_positions: Array[Vector2] = []
var _barriers: Array[Array] = []
const RADIUS := 94.0

func build(planet: Dictionary, seed_value: int) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	specimen_spawns.clear()
	points.clear()
	obstacles.clear()
	_material_cache.clear()
	planet_data = planet
	world_seed = seed_value
	_rng.seed = seed_value
	_base = planet.get("color", Color("355951"))
	_accent = planet.get("accent", Color("a6e7be"))
	_biome = str(planet.get("biome", "moss"))
	_layout()
	_environment()
	_terrain()
	_landing_marks()
	_route()
	_relay(Vector3(_relay_position.x, ground_height(_relay_position), _relay_position.y))
	_ruin(_ruin_positions[0], "archive", "Silent observation station")
	_ruin(_ruin_positions[1], "greenhouse", "Broken containment garden")
	_ruin(_ruin_positions[2], "habitat", "Abandoned habitat")
	_cache(_cache_positions[0], "cache-east", "Survey supply crate")
	_cache(_cache_positions[1], "cache-west", "Lost field equipment")
	_cache(_cache_positions[2], "cache-south", "Emergency reserve")
	_barrier_rocks()
	_scatter()
	_spawn_specimens(planet.get("species", [0, 1, 2]))
	_signature()

func _layout() -> void:
	_barriers = []
	match _biome:
		"glass":
			_relay_position = Vector2(61, -31)
			_ruin_positions = [Vector2(-29,-30),Vector2(43,-8),Vector2(35,37)]
			_cache_positions = [Vector2(9,-34),Vector2(62,16),Vector2(-20,30)]
			_route_points = [Vector2(0,0),Vector2(4,-12),Vector2(16,-10),Vector2(28,-12),Vector2(44,-24),_relay_position,Vector2(43,-47),Vector2(17,-44),Vector2(0,-32),Vector2(-16,-23),Vector2(-7,-8),Vector2.ZERO]
			_barriers = [[Vector2(17,-68),Vector2(17,-53)],[Vector2(17,-36),Vector2(17,-22)],[Vector2(17,4),Vector2(17,48)]]
		"ice":
			_relay_position = Vector2(-61,-28)
			_ruin_positions = [Vector2(-38,-51),Vector2(-31,-7),Vector2(29,27)]
			_cache_positions = [Vector2(-62,12),Vector2(22,-37),Vector2(-15,36)]
			_route_points = [Vector2.ZERO,Vector2(0,-14),Vector2(-13,-21),Vector2(-28,-23),Vector2(-43,-18),_relay_position,Vector2(-55,-43),Vector2(-38,-48),Vector2(-17,-41),Vector2(0,-29),Vector2(12,-17),Vector2.ZERO]
			_barriers = [[Vector2(-82,-35),Vector2(-63,-35)],[Vector2(-48,-35),Vector2(-25,-35)],[Vector2(-30,5),Vector2(8,5)]]
		"ash":
			_relay_position = Vector2(15,63)
			_ruin_positions = [Vector2(-33,39),Vector2(38,29),Vector2(-25,-27)]
			_cache_positions = [Vector2(-48,8),Vector2(51,54),Vector2(33,-20)]
			_route_points = [Vector2.ZERO,Vector2(-12,13),Vector2(-29,23),Vector2(-31,40),Vector2(-13,52),_relay_position,Vector2(33,48),Vector2(36,28),Vector2(24,12),Vector2.ZERO]
			_barriers = [[Vector2(-12,18),Vector2(14,18)],[Vector2(-12,18),Vector2(-12,38)],[Vector2(-12,38),Vector2(14,38)],[Vector2(14,38),Vector2(14,18)]]
		"tidal":
			_relay_position = Vector2(48,46)
			_ruin_positions = [Vector2(8,48),Vector2(54,-17),Vector2(-35,23)]
			_cache_positions = [Vector2(24,-25),Vector2(-22,53),Vector2(67,22)]
			_route_points = [Vector2.ZERO,Vector2(15,0),Vector2(29,9),Vector2(38,27),_relay_position,Vector2(34,53),Vector2(14,50),Vector2(8,33),Vector2(-6,18),Vector2.ZERO]
			_barriers = [[Vector2(22,-55),Vector2(22,-13)],[Vector2(22,22),Vector2(22,39)],[Vector2(-17,31),Vector2(-2,31)]]
		"heart":
			_relay_position = Vector2(-47,44)
			_ruin_positions = [Vector2(-57,-17),Vector2(17,-48),Vector2(39,30)]
			_cache_positions = [Vector2(-17,59),Vector2(44,-24),Vector2(-30,-39)]
			_route_points = [Vector2.ZERO,Vector2(-14,8),Vector2(-32,19),_relay_position,Vector2(-31,53),Vector2(-12,43),Vector2(4,26),Vector2(8,10),Vector2.ZERO]
			_barriers = [[Vector2(-15,-18),Vector2(-39,-40)],[Vector2(16,-12),Vector2(45,-12)],[Vector2(15,20),Vector2(26,43)]]
		_:
			_relay_position = Vector2(4,-57)
			_ruin_positions = [Vector2(-28,-28),Vector2(34,-39),Vector2(-20,35)]
			_cache_positions = [Vector2(23,-9),Vector2(-42,-53),Vector2(30,29)]
			_route_points = [Vector2.ZERO,Vector2(0,-9),Vector2(13,-20),Vector2(23,-37),Vector2(18,-47),_relay_position,Vector2(-12,-53),Vector2(-26,-43),Vector2(-27,-27),Vector2(-16,-15),Vector2(-7,-8),Vector2.ZERO]
			_barriers = [[Vector2(-8,-25),Vector2(8,-25)],[Vector2(-7,-38),Vector2(7,-38)]]

func _path_distance(pos: Vector2) -> float:
	var distance := INF
	for i in range(_route_points.size() - 1):
		var point := Geometry2D.get_closest_point_to_segment(pos, _route_points[i], _route_points[i + 1])
		distance = minf(distance, pos.distance_to(point))
	return distance

func _barrier_rocks() -> void:
	for span: Array in _barriers:
		var start: Vector2 = span[0]
		var finish: Vector2 = span[1]
		var steps := ceili(start.distance_to(finish) / 3.3)
		for i in range(steps + 1):
			var xz := start.lerp(finish, float(i) / maxf(1.0, float(steps)))
			if _reserved(xz): continue
			var pos := Vector3(xz.x, ground_height(xz), xz.y)
			var rock := _sphere(pos + Vector3(0, 1.5, 0), 2.0, _base.darkened(0.28), 5, 3)
			rock.scale = Vector3(1.1, _rng.randf_range(1.0, 1.6), 1.0)
			obstacles.append({"position":pos,"radius":1.95})

func ground_height(pos: Vector2) -> float:
	var dist := pos.length()
	var clearing := smoothstep(7.0, 20.0, dist)
	var seed_offset := float(posmod(world_seed, 217)) * 0.11
	var rolling := sin(pos.x * 0.054 + seed_offset) * 1.5 + cos(pos.y * 0.063 - seed_offset) * 1.25
	rolling += sin(pos.x * 0.105 + pos.y * 0.071) * 0.55
	match _biome:
		"glass": rolling += sin(pos.x * 0.105) * 1.4
		"ice": rolling += sin(pos.y * 0.072 - 0.5) * 2.0
		"ash": rolling -= exp(-pow(pos.distance_to(Vector2(1,28)) / 19.0, 2.0)) * 3.1
		"tidal": rolling += sin(pos.x * 0.08 + pos.y * 0.025) * 1.5
		"heart": rolling += sin(dist * 0.09) * 1.25
	return rolling * clearing

func is_blocked(pos: Vector3, radius: float = 0.6) -> bool:
	if Vector2(pos.x, pos.z).length() > RADIUS - radius:
		return true
	for obstacle: Dictionary in obstacles:
		var center: Vector3 = obstacle["position"]
		if Vector2(pos.x - center.x, pos.z - center.z).length() < radius + float(obstacle["radius"]):
			return true
	return false

func _material(color: Color, glow: float = 0.0, vertex: bool = false) -> StandardMaterial3D:
	var key := color.to_html() + "/" + str(glow) + "/" + str(vertex)
	if _material_cache.has(key): return _material_cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.vertex_color_use_as_albedo = vertex
	mat.vertex_color_is_srgb = vertex
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	_material_cache[key] = mat
	return mat

func _environment() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = _base.darkened(0.83)
	sky_mat.sky_horizon_color = _base.lightened(0.03)
	sky_mat.ground_bottom_color = _base.darkened(0.8)
	sky_mat.ground_horizon_color = _base.lightened(0.03)
	sky_mat.sky_curve = 0.22
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = _accent.lerp(Color.WHITE, 0.65)
	env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = _base.lightened(0.03)
	env.fog_light_energy = 0.45
	env.fog_density = 0.0028
	env_node.environment = env
	add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-36, -35, 0)
	sun.light_color = Color("e6d3b3") if _biome in ["ash", "glass"] else Color("c4e5eb")
	sun.light_energy = 0.7
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 140, 0)
	fill.light_color = _accent
	fill.light_energy = 0.13
	add_child(fill)
	# Distant eclipse companion is a world mesh, visible in Compatibility mode.
	var moon := _sphere(Vector3(135, 120, -210), 36, _base.lightened(0.25), 16, 8)
	moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var stars := MultiMesh.new()
	stars.transform_format = MultiMesh.TRANSFORM_3D
	stars.use_colors = true
	var star_mesh := SphereMesh.new()
	star_mesh.radius = 0.2
	star_mesh.height = 0.4
	star_mesh.radial_segments = 4
	star_mesh.rings = 2
	star_mesh.material = _material(Color("b9d7d6"), 1.4)
	stars.mesh = star_mesh
	stars.instance_count = 100
	for index in range(100):
		var direction := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0.15, 1), _rng.randf_range(-1, 1)).normalized()
		stars.set_instance_transform(index, Transform3D(Basis(), direction * 290.0))
		stars.set_instance_color(index, Color.WHITE)
	var star_field := MultiMeshInstance3D.new()
	star_field.multimesh = stars
	add_child(star_field)

func _terrain() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step_size := 3.0
	for x in range(-34, 34):
		for z in range(-34, 34):
			var p := Vector2(float(x) * step_size, float(z) * step_size)
			if p.length() > 102.0: continue
			var corners: Array[Vector2] = [p, p + Vector2(step_size, 0), p + Vector2(step_size, step_size), p + Vector2(0, step_size)]
			var patch := (sin(p.x * 0.09 + p.y * 0.04) + cos(p.y * 0.12)) * 0.11
			var tint := _base.lerp(Color("5b6656"),0.3).lightened(patch + _rng.randf_range(-0.035, 0.035))
			if _biome == "ice": tint = Color("809cae").lerp(_base, 0.32).lightened(patch * 0.7)
			if _biome == "glass": tint = Color("686579").lerp(_base, 0.45).lightened(patch)
			if _biome == "ash": tint = Color("3c373e").lerp(_base, 0.15).lightened(patch * 0.65)
			if _biome == "tidal": tint = Color("4a6468").lerp(_base,0.3).lightened(patch)
			if _biome == "heart": tint = Color("54415c").lerp(_base,0.4).lightened(patch)
			var path_distance := _path_distance(p + Vector2(1.5,1.5))
			if path_distance < 2.8:
				var path_color := Color("71654c") if _biome == "moss" else tint.darkened(0.3)
				tint = tint.lerp(path_color, (1.0 - path_distance / 2.8) * 0.85)
			for order: int in [0, 2, 1, 0, 3, 2]:
				var point := corners[order]
				surface.set_color(tint)
				surface.add_vertex(Vector3(point.x, ground_height(point), point.y))
	surface.generate_normals()
	var terrain := MeshInstance3D.new()
	terrain.name = "PlanetTerrain"
	terrain.mesh = surface.commit()
	terrain.material_override = _material(Color.WHITE, 0.0, true)
	add_child(terrain)
	# Raised jagged rim provides a visible end to the traversable survey area.
	for i in range(54):
		var angle := float(i) * TAU / 54.0
		var xz := Vector2(sin(angle), cos(angle)) * _rng.randf_range(96, 103)
		var rock := _cone(Vector3(xz.x, ground_height(xz) - 0.5, xz.y), _rng.randf_range(4, 8), _rng.randf_range(6, 17), _base.darkened(0.25), 5)
		rock.rotation.y = angle

func _landing_marks() -> void:
	var plate := _cylinder(Vector3(0, -0.12, 0), 6.2, 0.22, _base.darkened(0.32), 32)
	plate.name = "LandingPad"
	for i in range(16):
		var angle := float(i) * TAU / 16.0
		_box(Vector3(sin(angle) * 5.8, 0.04, cos(angle) * 5.8), Vector3(0.12, 0.08, 0.65), _accent, 0.5).rotation.y = angle
	for sign_value in [-1.0, 1.0]:
		_box(Vector3(sign_value * 4.7, 0.02, 0), Vector3(0.12, 0.03, 4.2), Color("e3d7ac"))

func _route() -> void:
	# Bright survey stakes make a readable outbound trail and return loop.
	for i in range(_route_points.size() - 1):
		var start := _route_points[i]
		var finish := _route_points[i + 1]
		var count := maxi(1, ceili(start.distance_to(finish) / 9.0))
		for j in range(count):
			var xz := start.lerp(finish, float(j) / float(count))
			if xz.length() < 8: continue
			var pos := Vector3(xz.x, ground_height(xz), xz.y)
			_cylinder(pos + Vector3(0, 0.5, 0), 0.11, 1.0, _base.darkened(0.45), 5)
			_sphere(pos + Vector3(0, 1.07, 0), 0.17, _accent, 6, 3, 0.3)

func _relay(pos: Vector3) -> void:
	points.append({"id": "relay", "kind": "relay", "position": pos, "title": "Planetary relay"})
	_cylinder(pos + Vector3(0, 0.18, 0), 4.8, 0.35, Color("45565c"), 8)
	for side in [-1.0, 1.0]:
		var p := pos + Vector3(side * 3.5, 3.2, 0)
		_box(p, Vector3(0.85, 6.4, 0.9), Color("647677"))
		_box(p + Vector3(0, 0, -0.48), Vector3(0.2, 5.5, 0.08), _accent, 0.4)
		obstacles.append({"position": pos + Vector3(side * 3.5, 0, 0), "radius": 0.7})
	_box(pos + Vector3(0, 6.25, 0), Vector3(7.8, 1.0, 1.05), Color("617274"))
	for i in range(3):
		_box(pos + Vector3(0, 6.95 + float(i) * 0.45, 0), Vector3(4.0 - float(i), 0.12, 0.5), _accent, 0.4)
	var orb := _sphere(pos + Vector3(0, 4.2, 0), 0.65, _accent, 12, 6, 0.8)
	orb.name = "RelayHeart"
	_box(pos + Vector3(0, 0.65, 1.8), Vector3(1.4, 1.3, 0.65), Color("2f444a"))
	_box(pos + Vector3(0, 1.3, 1.8), Vector3(1.1, 0.08, 0.48), _accent, 0.4)

func _ruin(xz: Vector2, ident: String, title: String) -> void:
	var pos := Vector3(xz.x, ground_height(xz), xz.y)
	points.append({"id": ident, "kind": "ruin", "position": pos, "title": title})
	var concrete := _base.lerp(Color("a1a59c"), 0.65)
	_box(pos + Vector3(0, 0.12, 0), Vector3(9, 0.25, 7), concrete.darkened(0.25))
	for corner: Vector2 in [Vector2(-4, -3), Vector2(4, -3), Vector2(-4, 3), Vector2(4, 3)]:
		var height := _rng.randf_range(3, 6.5)
		var pillar_pos := pos + Vector3(corner.x, height * 0.5, corner.y)
		_box(pillar_pos, Vector3(0.7, height, 0.8), concrete)
		obstacles.append({"position": Vector3(pillar_pos.x, pos.y, pillar_pos.z), "radius": 0.6})
	_box(pos + Vector3(0, 1.1, -3), Vector3(8.5, 2.2, 0.55), concrete.darkened(0.1))
	for offset in range(-4, 5):
		obstacles.append({"position": pos + Vector3(float(offset), 0, -3), "radius": 0.53})
	for offset in [-2.7, 0.0, 2.7]:
		_box(pos + Vector3(offset, 1.5, -2.69), Vector3(1.7, 0.12, 0.06), _accent, 0.3)
	var roof := _box(pos + Vector3(-2.3, 4.7, 0), Vector3(4.2, 0.45, 6.8), concrete)
	roof.rotation.z = 0.16
	if ident == "greenhouse":
		for i in range(6):
			var plant_pos := pos + Vector3(_rng.randf_range(-3.0, 3.0), 0, _rng.randf_range(-1.5, 2.3))
			_flora(plant_pos, 0.8 + float(i % 3) * 0.35)
	else:
		_box(pos + Vector3(2.8, 0.6, -1), Vector3(1.4, 1.2, 1), Color("344951"))
		_box(pos + Vector3(2.8, 1.24, -1), Vector3(1.25, 0.06, 0.8), _accent.darkened(0.1), 0.25)

func _cache(xz: Vector2, ident: String, title: String) -> void:
	var pos := Vector3(xz.x, ground_height(xz), xz.y)
	points.append({"id": ident, "kind": "cache", "position": pos, "title": title})
	_box(pos + Vector3(0, 0.45, 0), Vector3(1.15, 0.9, 0.8), Color("b39966"))
	_box(pos + Vector3(0, 0.94, 0), Vector3(1.25, 0.12, 0.9), Color("d2c397"))
	_box(pos + Vector3(0, 0.5, 0.42), Vector3(0.55, 0.12, 0.04), _accent, 0.5)
	_cylinder(pos + Vector3(0, 1.55, 0), 0.05, 1.0, _accent, 5, 0.2)
	obstacles.append({"position": pos, "radius": 0.68})

func _scatter() -> void:
	for i in range(125):
		var angle := _rng.randf_range(0, TAU)
		var distance := _rng.randf_range(12.0, 87.0)
		var xz := Vector2(sin(angle), cos(angle)) * distance
		if _reserved(xz): continue
		var pos := Vector3(xz.x, ground_height(xz), xz.y)
		if i % 4 == 0:
			var size := _rng.randf_range(0.7, 1.8)
			var stone := _sphere(pos + Vector3(0, size * 0.24, 0), size, _base.darkened(0.22), 5, 3)
			stone.scale = Vector3(1.0, 0.45, _rng.randf_range(0.65, 1.3))
			stone.rotation.y = _rng.randf_range(0, TAU)
			obstacles.append({"position": pos, "radius": size * 0.85})
		else:
			_flora(pos, _rng.randf_range(0.55, 1.65))
	# Small luminous motes use one draw call and remain independent of gameplay.
	var motes := MultiMesh.new()
	motes.transform_format = MultiMesh.TRANSFORM_3D
	var mote_mesh := SphereMesh.new()
	mote_mesh.radius = 0.055
	mote_mesh.height = 0.11
	mote_mesh.radial_segments = 4
	mote_mesh.rings = 2
	mote_mesh.material = _material(_accent, 0.8)
	motes.mesh = mote_mesh
	motes.instance_count = 110
	for i in range(110):
		var p := Vector2(_rng.randf_range(-65, 65), _rng.randf_range(-65, 65))
		motes.set_instance_transform(i, Transform3D(Basis(), Vector3(p.x, ground_height(p) + _rng.randf_range(0.6, 4.0), p.y)))
	var mote_node := MultiMeshInstance3D.new()
	mote_node.multimesh = motes
	add_child(mote_node)

func _reserved(xz: Vector2) -> bool:
	if xz.distance_to(Vector2(8, -10)) < 4.0: return true
	if _path_distance(xz) < 3.3: return true
	for point: Dictionary in points:
		var p: Vector3 = point["position"]
		if xz.distance_to(Vector2(p.x, p.z)) < 8.0: return true
	return false

func _flora(pos: Vector3, size: float) -> void:
	match _biome:
		"glass":
			for i in range(3):
				var crystal := _cone(pos + Vector3(float(i - 1) * 0.55 * size, 0, float(i % 2) * 0.35), 0.45 * size, (2.1 + float(i) * 0.6) * size, _accent.darkened(float(i) * 0.1), 5)
				crystal.rotation.z = float(i - 1) * 0.18
		"ice":
			_cone(pos, 0.9 * size, 2.2 * size, Color("a4c5d8"), 5)
			_cone(pos + Vector3(0.6, 0, 0), 0.45 * size, 1.2 * size, _accent, 5)
		"ash":
			var stone := _cylinder(pos + Vector3(0, size * 1.4, 0), 0.45 * size, size * 2.8, Color("38343e"), 6)
			stone.rotation.z = 0.12
			_box(pos + Vector3(0.1, size * 1.1, size * 0.46), Vector3(0.06, size * 1.8, 0.05), _accent, 0.4)
		"tidal":
			_cylinder(pos + Vector3(0, size * 0.7, 0), 0.12 * size, size * 1.4, _base.lightened(0.3), 5)
			var cap := _sphere(pos + Vector3(0, size * 1.5, 0), size * 1.0, _accent.darkened(0.22), 8, 4)
			cap.scale.y = 0.23
			for i in range(3):
				_cylinder(pos + Vector3(float(i - 1) * size * 0.4, size * 0.8, 0), size * 0.025, size * 1.4, _accent, 4, 0.2)
		"heart":
			var stem := _cylinder(pos + Vector3(0, size, 0), size * 0.25, size * 2.0, _base.lightened(0.14), 5)
			stem.rotation.z = 0.15
			for i in range(3):
				var bulb := _sphere(pos + Vector3(sin(float(i) * 2.1) * size * 0.45, (1.5 + float(i) * 0.35) * size, cos(float(i) * 2.1) * size * 0.4), size * 0.45, _accent, 8, 4, 0.18)
				bulb.scale.y = 1.3
		_:
			_cylinder(pos + Vector3(0, size * 0.65, 0), size * 0.14, size * 1.3, Color("637a6d"), 5)
			var crown := _sphere(pos + Vector3(0, size * 1.25, 0), size * 0.95, _accent.darkened(0.33), 8, 4)
			crown.scale.y = 0.38
			_sphere(pos + Vector3(0, size * 1.55, 0), size * 0.13, _accent, 6, 3, 0.5)

func _spawn_specimens(species: Array) -> void:
	if species.is_empty(): species = [0, 1, 2]
	var locations: Array[Vector2] = [Vector2(8, -10), Vector2(-11, -17), Vector2(19, -20), Vector2(31, -27), Vector2(-21, -35), Vector2(-34, -46), Vector2(12, -45), Vector2(20, -63), Vector2(-13, -64), Vector2(48, -8), Vector2(43, 18), Vector2(24, 42), Vector2(-13, 46), Vector2(-43, 22), Vector2(-54, -17)]
	var rotation_angle := atan2(_relay_position.x, -_relay_position.y)
	for i in range(1, locations.size()):
		locations[i] = locations[i].rotated(rotation_angle)
	for i in range(locations.size()):
		var xz := locations[i]
		var pos := Vector3(xz.x, ground_height(xz), xz.y)
		# Move wildlife out of already rendered rocks instead of removing collisions.
		var attempts := 0
		while is_blocked(pos, 1.0) and attempts < 20:
			attempts += 1
			xz = locations[i] + Vector2(sin(float(attempts) * 2.4), cos(float(attempts) * 2.4)) * (1.0 + float(attempts) * 0.4)
			pos = Vector3(xz.x, ground_height(xz), xz.y)
		specimen_spawns.append({"id": "specimen-%s-%s" % [planet_data.get("id", 0), i], "species": int(species[i % species.size()]), "position": pos})

func _signature() -> void:
	# Each world has a large silhouette behind the relay so bearings stay legible.
	var direction := _relay_position.normalized()
	var xz := direction * 79.0 + Vector2(-direction.y, direction.x) * -13.0
	var pos := Vector3(xz.x, ground_height(xz), xz.y)
	if _biome == "heart":
		_cylinder(pos + Vector3(0, 9, 0), 2.7, 18, _base.darkened(0.2), 7)
		for i in range(7):
			var angle := float(i) * TAU / 7.0
			var bulb := _sphere(pos + Vector3(sin(angle) * 6, 16 + float(i % 3), cos(angle) * 4), 4.2, _accent.darkened(0.24), 8, 4, 0.08)
			bulb.scale.y = 0.8
	elif _biome == "ash":
		for i in range(5):
			_cone(pos + Vector3(float(i - 2) * 5.0, 0, 0), 3.8, 18.0 + float(i % 3) * 6, _base.darkened(0.4), 5)
	elif _biome == "glass":
		for i in range(4):
			var shard := _cone(pos + Vector3(float(i - 2) * 5.0, 0, 0), 3.0, 17.0 + float(i % 2) * 9, _accent.darkened(0.3), 5)
			shard.rotation.z = float(i - 2) * 0.1
	else:
		# Broken orbital ring, part buried in the soil.
		var ring_color := _base.lerp(Color("b0b8ae"), 0.6)
		for i in range(13):
			var angle := -0.2 + float(i) / 12.0 * PI * 1.15
			var segment := _box(pos + Vector3(cos(angle) * 12, sin(angle) * 12 + 1, 0), Vector3(3.4, 1.35, 2.4), ring_color)
			segment.rotation.z = angle + PI * 0.5
			_box(segment.position + Vector3(0, 0, 1.25), Vector3(0.15, 0.55, 0.05), _accent, 0.3).rotation.z = angle
	# Outer landmark also has real blockage at its buried base.
	obstacles.append({"position": pos, "radius": 3.0})

func _box(pos: Vector3, size: Vector3, color: Color, glow: float = 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(mesh, pos, color, glow)

func _sphere(pos: Vector3, radius: float, color: Color, segments: int = 8, rings: int = 4, glow: float = 0.0) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = rings
	return _mesh(mesh, pos, color, glow)

func _cone(pos: Vector3, radius: float, height: float, color: Color, sides: int = 6) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.04
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	return _mesh(mesh, pos + Vector3(0, height * 0.5, 0), color)

func _cylinder(pos: Vector3, radius: float, height: float, color: Color, sides: int = 8, glow: float = 0.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	return _mesh(mesh, pos, color, glow)

func _mesh(mesh: Mesh, pos: Vector3, color: Color, glow: float = 0.0) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = _material(color, glow)
	add_child(instance)
	return instance
