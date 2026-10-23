extends RefCounted
## Original Klax wildlife lives in xeno_models.gd. The researcher mesh and
## biped animation below retain the Zendelves conversion and joint pivots.

const Catalog = preload("res://scripts/catalog.gd")
const Xeno = preload("res://scripts/xeno_models.gd")
static var _mesh_cache: Dictionary = {}

static func create_creature(species_index: int) -> Node3D:
	var index := posmod(species_index, 12)
	var species: Dictionary = Catalog.species()[index]
	var model := Xeno.create(index, species["color"])
	model.set_meta("model_kind", "xeno")
	model.set_meta("phase", float(index) * 0.63)
	return model

static func create_researcher() -> Node3D:
	var model := _create("researcher", Color("9bc5c3"), true)
	model.set_meta("model_kind", "researcher")
	model.set_meta("phase", 0.0)
	var pack := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.42, 0.5, 0.22)
	pack.mesh = box
	pack.position = Vector3(0, 1.16, -0.24)
	pack.material_override = _material(Color("e4d7b2"))
	model.add_child(pack)
	var helmet := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.245
	sphere.height = 0.42
	sphere.radial_segments = 12
	sphere.rings = 6
	helmet.mesh = sphere
	helmet.position = Vector3(0, 1.59, 0.055)
	helmet.material_override = _material(Color("153f4c"), 0.12)
	model.add_child(helmet)
	return model

static func _material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	return material

static func _load_meshes(model_name: String) -> Array:
	if _mesh_cache.has(model_name):
		return _mesh_cache[model_name]
	var text := FileAccess.get_file_as_string("res://assets/models/%s.json" % model_name)
	var decoded: Variant = JSON.parse_string(text)
	var result: Array = []
	if not decoded is Dictionary:
		push_error("Missing or invalid Zendelves model: " + model_name)
		return result
	for part: Dictionary in decoded.get("parts", []):
		var builder := SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		for triangle: Array in part["triangles"]:
			for vertex_index: Variant in triangle:
				var vertex: Array = part["vertices"][int(vertex_index)]
				builder.add_vertex(Vector3(float(vertex[0]), float(vertex[1]), float(vertex[2])))
		builder.generate_normals()
		var pivot: Array = part.get("pivot", [0, 0, 0])
		result.append({"mesh": builder.commit(), "name": str(part["name"]), "color": Color(str(part["color"])), "pivot": Vector3(float(pivot[0]), float(pivot[1]), float(pivot[2]))})
	_mesh_cache[model_name] = result
	return result

static func _create(model_name: String, tint: Color, researcher: bool) -> Node3D:
	var root := Node3D.new()
	root.name = model_name.capitalize().replace(" ", "")
	var anim_parts: Array[Node3D] = []
	for part: Dictionary in _load_meshes(model_name):
		var pivot := Node3D.new()
		pivot.position = part["pivot"]
		pivot.set_meta("joint", part["name"])
		pivot.set_meta("origin", part["pivot"])
		var mesh := MeshInstance3D.new()
		mesh.mesh = part["mesh"]
		var source_color: Color = part["color"]
		var is_eye := str(part["name"]) == "eyes" or str(part["name"]) == "head" and source_color.get_luminance() > 0.78
		var tinted_value := tint * clampf(source_color.get_luminance() * 1.5, 0.18, 1.0)
		tinted_value.a = 1.0
		var color := source_color.lerp(tinted_value, 0.52)
		if researcher:
			color = Color("e8e0c6") if source_color.get_luminance() > 0.25 else Color("315d62")
		mesh.material_override = _material(color, 0.18 if is_eye and not researcher else 0.0)
		pivot.add_child(mesh)
		root.add_child(pivot)
		anim_parts.append(pivot)
	root.set_meta("anim_parts", anim_parts)
	return root

static func animate_creature(node: Node3D, time: float, moving: bool, alert: bool) -> void:
	if node.has_meta("xeno_id"):
		Xeno.animate(node,time,moving,alert)
		return
	var phase: float = float(node.get_meta("phase", 0.0))
	var pace := sin(time * (12.0 if alert else 8.0) + phase) * (1.0 if moving else 0.0)
	var model_kind: String = node.get_meta("model_kind", "")
	for pivot: Node3D in node.get_meta("anim_parts", []):
		var joint: String = pivot.get_meta("joint", "")
		var origin: Vector3 = pivot.get_meta("origin", Vector3.ZERO)
		pivot.position = origin
		pivot.rotation = Vector3.ZERO
		if joint == "leftLeg": pivot.rotation.x = pace * 0.48
		if joint == "rightLeg": pivot.rotation.x = -pace * 0.48
		if model_kind in ["plant_hound", "slime_hound"] and origin.z < 0.0:
			pivot.rotation.x *= -1.0
		if joint == "leftArm": pivot.rotation.x = -pace * 0.3
		if joint == "rightArm": pivot.rotation.x = pace * 0.3
		if joint == "tail": pivot.rotation.y = sin(time * 4.0 + phase) * 0.2
		if joint == "leftWing": pivot.rotation.z = sin(time * 18.0 + phase) * 0.55
		if joint == "rightWing": pivot.rotation.z = -sin(time * 18.0 + phase) * 0.55
		if joint == "torso":
			pivot.position.y += sin(time * 2.4 + phase) * 0.025
			if alert: pivot.rotation.x = -0.08 + sin(time * 6.0) * 0.04
		if joint == "head":
			pivot.rotation.y = sin(time * 1.1 + phase) * (0.1 if moving else 0.2)

static func animate_researcher(node: Node3D, time: float, moving: bool) -> void:
	animate_creature(node, time, moving, false)
