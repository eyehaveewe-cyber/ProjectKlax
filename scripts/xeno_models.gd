extends RefCounted
## Original Klax anatomy. No terrestrial animal meshes or external assets.
## Named organs supply both a silhouette and inexpensive procedural motion.

static func create(id: int, color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Xeno%02d" % id
	root.set_meta("xeno_id", id)
	var dark := color.darkened(0.6)
	var light := color.lightened(0.22)
	match id:
		0: # A translucent seed chamber carried by three arching limbs.
			_organ(root, "Chamber", Vector3(0,1.2,0), Vector3(0.72,0.95,0.72), color)
			_organ(root, "Lantern", Vector3(0,1.5,0), Vector3(0.38,0.6,0.38), light, true)
			_radial(root, 3, 1.0, 0.55, Vector3(0.14,0.75,0.14), dark, "Leg")
		1: # Five asymmetric roots around a horizontal feeding wheel.
			_ring(root, "FeedingWheel", Vector3(0,0.65,0), 0.7, color)
			_radial(root, 5, 0.85, 0.38, Vector3(0.1,0.45,0.32), dark, "Root")
			_organ(root, "Sensor", Vector3(0.3,1.1,0), Vector3(0.18,0.6,0.18), light, true)
		2: # Three tall mineral stilts with a suspended tetrahedral resonator.
			_radial(root, 3, 1.15, 0.9, Vector3(0.12,1.05,0.12), light, "Leg")
			_cone(root, "Resonator", Vector3(0,1.7,0), 0.8, 1.0, color, 3)
			_ring(root, "Receiver", Vector3(0,2.3,0), 0.6, light)
		3: # A vertical mineral sail surrounding a free-floating core, no wings.
			_organ(root, "Core", Vector3(0,1.65,0), Vector3(0.28,0.28,0.28), light, true)
			for i in range(3):
				var fin := _organ(root, "Sail%d" % i, Vector3((i-1)*0.75,1.9,0), Vector3(0.6,1.5,0.08), color)
				fin.rotation.z = (i-1)*0.4
		4: # A vent bell with a hanging braid of heat storage organs.
			_cone(root, "Bell", Vector3(0,1.6,0), 1.0, 0.7, color, 10)
			_radial(root, 6, 0.65, 0.6, Vector3(0.08,0.7,0.08), light, "Tendril")
			_organ(root, "HeatCore", Vector3(0,1.05,0), Vector3(0.4,0.6,0.4), light, true)
		5: # A low segmented crescent that opens heat-sensing vanes to hunt.
			for i in range(7):
				var a := (float(i)/6.0-0.5)*PI
				_organ(root, "Segment%d" % i, Vector3(sin(a),0.55,cos(a)*0.65), Vector3(0.38,0.4,0.45), color)
				_organ(root, "Vane%d" % i, Vector3(sin(a)*1.1,1.0,cos(a)*0.75), Vector3(0.06,0.65,0.25), light)
		6: # A walking ceramic kiln, with a hollow chimney and four paddles.
			_cone(root, "Kiln", Vector3(0,0.95,0), 0.85, 1.5, dark, 6)
			_ring(root, "Vent", Vector3(0,1.75,0), 0.42, light)
			_radial(root, 4, 0.95, 0.4, Vector3(0.3,0.18,0.5), color, "Paddle")
		7: # A broad hovering filter mantle with three trailing collectors.
			_organ(root, "Mantle", Vector3(0,1.5,0), Vector3(1.3,0.18,1.0), color)
			for i in range(3):
				_organ(root, "Filter%d" % i, Vector3((i-1)*0.65,0.8,0.6), Vector3(0.12,0.7,0.12), light)
		8: # Two nested salt wheels move around an upright osmotic bladder.
			for i in range(2):
				var wheel := _ring(root, "Wheel%d" % i, Vector3((i-0.5)*0.9,0.75,0), 0.65, color)
				wheel.rotation.z = PI/2.0
			_organ(root, "Bladder", Vector3(0,1.35,0), Vector3(0.32,0.8,0.32), light, true)
		9: # A mobile living reef, triangular base and tall filter fans.
			_cone(root, "Anchor", Vector3(0,0.5,0), 1.25, 0.9, dark, 3)
			for i in range(4):
				var fan := _organ(root, "Fan%d" % i, Vector3((i-1.5)*0.5,1.4,0), Vector3(0.13,1.0,0.75), color)
				fan.rotation.z = (i-1.5)*0.25
		10: # A floating crown with an open center and suspended nutrient pods.
			_ring(root, "Crown", Vector3(0,1.9,0), 1.0, color)
			_radial(root, 5, 0.9, 1.2, Vector3(0.2,0.6,0.2), light, "Pod")
			_organ(root, "Pulse", Vector3(0,1.8,0), Vector3(0.3,0.3,0.3), light, true)
		11: # Five stacked memory plates carried by a single expanding foot.
			_organ(root, "Foot", Vector3(0,0.3,0), Vector3(0.8,0.28,0.8), dark)
			for i in range(5):
				var plate := _ring(root, "Memory%d" % i, Vector3(0,0.7+i*0.35,0), 0.72-float(i)*0.07, color)
				plate.rotation.x = i*0.13
	return root

static func animate(root: Node3D, time: float, moving: bool, alert: bool) -> void:
	var id: int = root.get_meta("xeno_id",0)
	for part: Node3D in root.get_children():
		var origin: Vector3 = part.get_meta("origin",part.position)
		var phase := float(part.get_index())*1.8 + id
		part.position = origin
		if part.name.begins_with("Leg") or part.name.begins_with("Root") or part.name.begins_with("Paddle"):
			part.rotation.x = sin(time*8+phase)*0.4 if moving else 0.0
		elif part.name.begins_with("Wheel"):
			part.rotation.x = time*3 if moving else sin(time)*0.1
		elif part.name.begins_with("Vane") or part.name.begins_with("Fan"):
			part.rotation.x = -0.65 if alert else sin(time*1.5+phase)*0.12
		elif part.name.begins_with("Sail") or part.name.begins_with("Filter") or part.name.begins_with("Tendril"):
			part.rotation.x = sin(time*2+phase)*0.22
		elif part.name.begins_with("Memory") or part.name == "Crown":
			part.rotation.y = time*(0.4+id*0.03)+phase
		else:
			part.position.y += sin(time*2+phase)*0.07

static func _material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.65
	if glow:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.5
	return mat

static func _part(root: Node3D, name: String, pos: Vector3, mesh: Mesh, color: Color, glow: bool = false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = mesh
	node.position = pos
	node.set_meta("origin",pos)
	node.material_override = _material(color,glow)
	root.add_child(node)
	return node

static func _organ(root: Node3D, name: String, pos: Vector3, size: Vector3, color: Color, glow: bool = false) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	var node := _part(root,name,pos,mesh,color,glow)
	node.scale = size
	return node

static func _cone(root: Node3D, name: String, pos: Vector3, radius: float, height: float, color: Color, sides: int) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius*0.35
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	_part(root,name,pos,mesh,color)

static func _ring(root: Node3D, name: String, pos: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius*0.72
	mesh.outer_radius = radius
	mesh.rings = 12
	mesh.ring_segments = 5
	return _part(root,name,pos,mesh,color)

static func _radial(root: Node3D, count: int, radius: float, height: float, size: Vector3, color: Color, name: String) -> void:
	for i in range(count):
		var angle := float(i)*TAU/count
		var node := _organ(root,name+str(i),Vector3(sin(angle)*radius,height,cos(angle)*radius),size,color)
		node.rotation.y = angle
