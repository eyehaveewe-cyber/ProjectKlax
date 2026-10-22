class_name ResearchCarrier
extends Node3D
## Direct adaptation of Project-Barrel-Roll CarrierHull at 17bda73b7763c5033.
## Original broad head, thorax, launch doors and articulated tail are retained.
## Klax adds landing legs, medical markings, an antenna and a 10 m footprint.

var doors: Array[Node3D] = []
var tail: Array[Node3D] = []
var materials: Dictionary = {}
var _visual: Node3D
var _open := 0.0
var _target_open := 0.0
var _clock := 0.0
var _dish: Node3D

func _ready() -> void:
	_visual = Node3D.new()
	_visual.name = "DragonflyResearchHull"
	_visual.scale = Vector3.ONE * 0.18
	_visual.position.y = 1.25
	add_child(_visual)
	for item: Array in [["armor", Color("a5bdb5")], ["dark", Color("182c3d")], ["edge", Color("e1e5cc")], ["light", Color("63e7dc")], ["medical", Color("ff9e73")]]:
		var material := StandardMaterial3D.new()
		material.albedo_color = item[1]
		material.roughness = 0.65
		material.metallic = 0.25
		if item[0] == "light" or item[0] == "medical":
			material.emission_enabled = true
			material.emission = item[1]
			material.emission_energy_multiplier = 0.8
		materials[item[0]] = material
	box("Thorax", Vector3(8, 4.2, 12), Vector3(0, 0, -1), "armor")
	box("Spine", Vector3(3.2, 1.1, 13), Vector3(0, 2.35, -1), "edge")
	box("Belly", Vector3(6.2, 1.1, 10), Vector3(0, -2.2, -1), "dark")
	for side: int in [-1, 1]:
		var cheek := box("HeadLobe", Vector3(5.8, 3.8, 6.8), Vector3(side * 5.2, 0.2, -10.8), "armor")
		cheek.rotation.y = side * 0.12
		box("Eye", Vector3(3.4, 0.85, 0.25), Vector3(side * 5.2, 1.0, -14.3), "light")
		box("Brow", Vector3(4.2, 0.45, 1.0), Vector3(side * 5.2, 1.75, -14.0), "edge")
		box("DrivePod", Vector3(2.1, 2.7, 6.0), Vector3(side * 4.3, -0.3, 1), "dark")
		box("DriveGlow", Vector3(1.5, 1.7, 0.2), Vector3(side * 4.3, -0.3, 4.1), "light")
		var door := box("LaunchDoor", Vector3(2.0, 2.4, 0.35), Vector3(side * 1.05, -0.5, -13.4), "dark")
		doors.append(door)
		box("LaunchRail", Vector3(0.3, 0.25, 7.0), Vector3(side * 1.8, -1.8, -15), "light")
		for z: float in [-10.0, 3.0]:
			box("LandingStrut", Vector3(0.55, 4.2, 0.55), Vector3(side * 4.0, -4.0, z), "dark")
			box("LandingPad", Vector3(2.2, 0.3, 2.0), Vector3(side * 4.0, -6.1, z), "edge")
		box("MedicalCrossBar", Vector3(0.12, 0.5, 2.4), Vector3(side * 4.08, 0.5, -2), "medical")
		box("MedicalCrossStem", Vector3(0.12, 2.4, 0.5), Vector3(side * 4.08, 0.5, -2), "medical")
	box("CommandBridge", Vector3(4.4, 1.4, 3.0), Vector3(0, 3.0, -8.3), "dark")
	box("BridgeWindow", Vector3(3.5, 0.5, 0.2), Vector3(0, 3.15, -9.85), "light")
	for index: int in range(7):
		var segment := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = lerpf(2.6, 0.55, float(index + 1) / 7.0)
		mesh.bottom_radius = lerpf(2.6, 0.55, float(index) / 7.0)
		mesh.height = 4.0
		mesh.radial_segments = 6
		mesh.rings = 1
		segment.mesh = mesh
		segment.material_override = materials.armor if index % 2 == 0 else materials.dark
		segment.rotation.x = PI / 2.0
		segment.position = Vector3(0, 0, 7 + index * 4.3)
		_visual.add_child(segment)
		tail.append(segment)
		box("TailBand", Vector3(lerpf(3.5, 0.65, float(index) / 6.0), 0.25, 0.35), Vector3(0, lerpf(2.3, 0.6, float(index) / 6.0), 7 + index * 4.3), "edge")
	box("TailBeacon", Vector3(0.5, 0.5, 0.8), Vector3(0, 0, 37), "light")
	for index: int in range(4):
		box("DeckStripe", Vector3(6.0, 0.08, 0.28), Vector3(0, 2.15, -4.0 + index * 2.3), "light")
	box("BoardingRamp", Vector3(3.5, 0.3, 4.0), Vector3(0, -2.0, -15.8), "edge").rotation.x = -0.2
	box("AntennaMast", Vector3(0.25, 4.3, 0.25), Vector3(0, 4.0, 2.0), "edge")
	_dish = Node3D.new()
	_dish.position = Vector3(0, 6.3, 2)
	_visual.add_child(_dish)
	var array := MeshInstance3D.new()
	var array_mesh := BoxMesh.new()
	array_mesh.size = Vector3(3.2, 1.2, 0.15)
	array.mesh = array_mesh
	array.material_override = materials.dark
	_dish.add_child(array)
	var badge := Label3D.new()
	badge.text = "KLAX  //  FIELD MEDICINE"
	badge.font_size = 48
	badge.pixel_size = 0.014
	badge.position = Vector3(0, 4.5, -10.0)
	badge.modulate = Color("e7fff1")
	badge.outline_size = 6
	_visual.add_child(badge)
	pose(_open, _clock)

func box(label: String, size: Vector3, point: Vector3, material: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = materials[material]
	node.position = point
	_visual.add_child(node)
	return node

func set_open(value: bool) -> void:
	_target_open = 1.0 if value else 0.0

func _process(delta: float) -> void:
	_clock += delta
	_open = move_toward(_open, _target_open, delta * 1.4)
	pose(_open, _clock)

func pose(open_amount: float, time: float) -> void:
	for index: int in doors.size():
		var side := -1.0 if index == 0 else 1.0
		doors[index].position.x = side * (1.05 + 1.9 * clampf(open_amount, 0.0, 1.0))
	for index: int in tail.size():
		# Original Barrel Roll stable absolute-time cosmetic tail articulation.
		tail[index].rotation.z = sin(time * 0.8 - index * 0.35) * 0.012 * float(index + 1) / 7.0
	if is_instance_valid(_dish):
		_dish.rotation.y = time * 0.25
