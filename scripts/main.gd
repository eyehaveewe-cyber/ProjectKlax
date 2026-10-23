extends Node3D

const Catalog = preload("res://scripts/catalog.gd")
const Save = preload("res://scripts/savegame.gd")
const PlanetWorld = preload("res://scripts/world.gd")
const Models = preload("res://scripts/creature_models.gd")
const Rover = preload("res://scripts/klax_rover.gd")
const Carrier = preload("res://scripts/research_carrier.gd")
const Ecology = preload("res://scripts/ecology.gd")
const HUD = preload("res://scripts/hud.gd")
const Assay = preload("res://scripts/assay.gd")
const Sound = preload("res://scripts/audio.gd")

var state:Dictionary
var planets:Array = []
var species:Array = []
var upgrades:Array = []
var crew:Array = []
var mode:String = "HUB"
var previous_mode:String = "HUB"
var paused:bool = false
var tactical:bool = false
var tactical_ap:int = 3
var tactical_recharge:float = 0.0
var testing:bool = false
var qa_enabled:bool = false
var world:Node3D
var hub:Node3D
var camera:Camera3D
var player:Node3D
var rover:Node3D
var carrier:Node3D
var ecology:RefCounted
var hud:CanvasLayer
var sound:Node
var assay:Control
var planet:Dictionary
var creatures:Array[Dictionary] = []
var effects:Array[Dictionary] = []
var lures:Array[Dictionary] = []
var stations:Array[Dictionary] = []
var mounted:bool = false
var crouched:bool = false
var tether_trip:Dictionary = {}
var deposited:int = 0
var health:float = 100.0
var oxygen:float = 100.0
var energy:float = 100.0
var field_time:float = 0.0
var animation_time:float = 0.0
var ui_clock:float = 0.0
var pulse_cooldown:float = 0.0
var sample_cooldown:float = 0.0
var hit_cooldown:float = 0.0
var scan_progress:float = 0.0
var scan_id:String = ""
var carried:Array[int] = []
var collected:Array[String] = []
var relay_recovered:bool = false
var field_science:int = 0
var target:Dictionary = {}
var message:String = ""
var message_time:float = 0.0
var camera_distance:float = 21.0
var move_direction:Vector3 = Vector3.ZERO
var return_snapshot:Dictionary = {}

func _ready() -> void:
	planets = Catalog.planets()
	species = Catalog.species()
	upgrades = Catalog.upgrades()
	crew = Catalog.crew()
	state = Save.fresh() if testing else Save.load_campaign()
	qa_enabled = "--qa" in OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		qa_enabled = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('qa')"))
	camera = Camera3D.new()
	camera.fov = 53
	camera.far = 450
	add_child(camera)
	camera.current = true
	hud = HUD.new()
	add_child(hud)
	hud.command.connect(_command)
	if not testing:
		sound = Sound.new()
		add_child(sound)
		sound.muted = bool(state.get("muted",false))
	_build_hub()
	_show_hub()

func _save() -> void:
	if not testing and not Save.save_campaign(state):
		_notify("Save unavailable. Keep this session open; export support is listed in README.")

func _ping(frequency:float=600.0) -> void:
	if is_instance_valid(sound):
		sound.ping(frequency)

func _level(id:String) -> int:
	return int(state.upgrades.get(id,0))

func _research(id:int) -> Dictionary:
	var key:String = str(id)
	if not state.research.has(key):
		state.research[key] = {"scanned":false,"sampled":false,"analyzed":false}
	return state.research[key]

func _show_hub() -> void:
	mode = "HUB"
	paused = false
	tactical = false
	if is_instance_valid(hub):
		hub.visible = true
	hud.show_hub(state,planets,species,upgrades,crew)
	if is_instance_valid(sound):
		sound.intensity = 0.0

func _build_hub() -> void:
	if is_instance_valid(world):
		world.queue_free()
		world = null
	if is_instance_valid(hub):
		hub.queue_free()
	hub = Node3D.new()
	add_child(hub)
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("07121c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("698da8")
	env.ambient_light_energy = 0.75
	env_node.environment = env
	hub.add_child(env_node)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35,-40,0)
	light.light_color = Color("b4f0ee")
	light.light_energy = 1.5
	hub.add_child(light)
	var ship := Carrier.new()
	hub.add_child(ship)
	ship.position = Vector3(-4,1,0)
	ship.rotation_degrees.y = -32
	ship.set_open(true)
	ship.set_meta("hub_ship",true)
	var globe := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 12
	sphere.height = 24
	sphere.radial_segments = 40
	sphere.rings = 24
	globe.mesh = sphere
	globe.material_override = _material(Color("163e4d"),false)
	globe.position = Vector3(-19,-12,-32)
	hub.add_child(globe)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77919
	for i in 95:
		var star := MeshInstance3D.new()
		var dot := SphereMesh.new()
		dot.radius = rng.randf_range(0.025,0.075)
		dot.height = dot.radius*2
		dot.radial_segments = 4
		dot.rings = 2
		star.mesh = dot
		star.material_override = _material(Color(0.6,0.8,0.9),true)
		star.position = Vector3(rng.randf_range(-65,40),rng.randf_range(-15,35),rng.randf_range(-60,-25))
		hub.add_child(star)
	camera.position = Vector3(8,12,22)
	camera.look_at(Vector3(1,0,0))

func _material(color:Color,unshaded:bool=false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

func launch() -> bool:
	var id:int = int(state.selected_planet)
	if id == 5 and state.relays.size() < 5:
		return false
	if is_instance_valid(hub):
		hub.queue_free()
		hub = null
	if is_instance_valid(world):
		world.queue_free()
	planet = planets[id]
	world = PlanetWorld.new()
	add_child(world)
	world.build(planet,91031+id*7919)
	_start_expedition()
	return true

func _start_expedition() -> void:
	ecology = Ecology.new()
	ecology.setup(int(planet.id),91031+int(planet.id)*7919)
	player = Models.create_researcher()
	world.add_child(player)
	player.position = Vector3(0,0,6)
	rover = Rover.new()
	world.add_child(rover)
	rover.position = Vector3(5,0,6)
	carrier = Carrier.new()
	world.add_child(carrier)
	carrier.set_open(true)
	creatures.clear()
	for spawn:Dictionary in world.specimen_spawns:
		var model:Node3D = Models.create_creature(int(spawn.species))
		world.add_child(model)
		model.position = spawn.position
		var ring := _ring(model.position,1.9,Color("72ddcf"))
		ring.visible = false
		creatures.append({"id":str(spawn.id),"species":int(spawn.species),"node":model,"home":spawn.position,"sample_taken":false,
			"stun":0.0,"calm":0.0,"windup":0.0,"cooldown":0.0,"alert":false,"ring":ring,"phase":creatures.size()*1.72})
	mode = "FIELD"
	paused = false
	mounted = false
	crouched = false
	tether_trip.clear()
	deposited = 0
	tactical = false
	tactical_ap = 3
	tactical_recharge = 0.0
	health = 100.0
	oxygen = 100.0
	energy = 100.0
	field_time = 0.0
	pulse_cooldown = 0.0
	hit_cooldown = 0.0
	scan_progress = 0.0
	scan_id = ""
	carried.clear()
	collected.clear()
	lures.clear()
	stations.clear()
	effects.clear()
	relay_recovered = false
	field_science = 0
	target = {}
	state.expeditions = int(state.expeditions)+1
	_save()
	_notify("E: scan. F: sample. Deposit at a cyan console; X at the lander returns to the ship.",7.0)
	hud.show_field(_snapshot())
	camera.position = player.position + Vector3(0,camera_distance*0.78,camera_distance)
	camera.look_at(player.position)
	if is_instance_valid(sound):
		sound.intensity = 0.3

func _ring(pos:Vector3,radius:float,color:Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius-0.055
	torus.outer_radius = radius+0.055
	torus.rings = 24
	torus.ring_segments = 5
	mesh.mesh = torus
	mesh.material_override = _material(color,true)
	mesh.position = pos+Vector3(0,0.12,0)
	world.add_child(mesh)
	return mesh

func _notify(text:String,seconds:float=4.0) -> void:
	message = text
	message_time = seconds

func _process(delta:float) -> void:
	animation_time += delta
	if mode == "HUB" and is_instance_valid(hub):
		for node in hub.get_children():
			if node.has_meta("hub_ship"):
				node.rotation.y += delta*0.12
	if mode == "FIELD":
		var desired:Vector3 = player.position+Vector3(0,camera_distance*0.78,camera_distance)
		camera.position = camera.position.lerp(desired,1.0-exp(-delta*6.0))
		camera.look_at(player.position+Vector3(0,0.7,0))
	ui_clock += delta
	if ui_clock>0.1:
		ui_clock = 0.0
		if mode == "FIELD":
			hud.update_field(_snapshot())
		_publish_telemetry()

func _physics_process(delta:float) -> void:
	if mode != "FIELD" or paused:
		return
	var dt:float = delta*(0.12 if tactical else 1.0)
	field_time += dt
	message_time = maxf(0.0,message_time-dt)
	pulse_cooldown = maxf(0.0,pulse_cooldown-dt)
	sample_cooldown = maxf(0.0,sample_cooldown-dt)
	hit_cooldown = maxf(0.0,hit_cooldown-dt)
	if not tactical:
		tactical_recharge += dt
		if tactical_recharge>=12.0:
			tactical_ap = 3
			tactical_recharge = 0.0
	ecology.advance(dt)
	_update_movement(dt)
	_update_creatures(dt)
	_update_tools(dt)
	_update_effects(dt)
	_update_target()
	var at_base:bool = Vector2(player.position.x,player.position.z).length()<9.0
	var weather:Dictionary = ecology.weather_snapshot()
	for child in world.get_children():
		if child is WorldEnvironment:
			child.environment.fog_density = 0.0035+(1.0-float(weather.get("visibility",1.0)))*0.026
	var spores:float = ecology.spore_at(player.position)
	var shelter:bool = at_base
	for station:Dictionary in stations:
		if player.position.distance_to(station.position)<6.0:
			shelter = true
	if shelter:
		oxygen = minf(100.0,oxygen+dt*9.0)
		health = minf(100.0,health+dt*2.0)
		if at_base:
			rover.hull = minf(100.0,rover.hull+dt*8.0)
			rover.left_module = minf(100.0,rover.left_module+dt*7.0)
			rover.right_module = minf(100.0,rover.right_module+dt*7.0)
	else:
		var exposure:float = (0.22+spores*0.18+float(weather.get("hazard",0.0))*0.12)/(1.0+_level("oxygen")*0.35)
		if mounted:
			exposure *= 0.6
		oxygen = maxf(0.0,oxygen-dt*exposure)
		if spores>0.72 and not mounted:
			health -= dt*(spores-0.72)*2.0/(1.0+_level("suit")*0.4)
	if oxygen<=0.0:
		health -= dt*6.0
	if health<=0.0:
		_finish_expedition(false)
		return
	var scanning:bool = Input.is_physical_key_pressed(KEY_E) and not tactical and not mounted and not target.is_empty() and target.kind=="creature"
	if scanning:
		_scan(dt)
	else:
		energy = minf(100.0,energy+dt*6.0)
		if scan_progress>0.0:
			scan_progress = maxf(0.0,scan_progress-dt*0.1)
	if is_instance_valid(sound):
		sound.intensity = 0.8 if health<35.0 else (0.5 if mounted else 0.2)

func _update_movement(dt:float) -> void:
	if not tether_trip.is_empty():
		_advance_tether(dt)
		return
	var forward:float = float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))-float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
	var side:float = float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	var boost:bool = Input.is_physical_key_pressed(KEY_SHIFT)
	var previous:Vector3 = player.position
	if mounted:
		var old_rover:Vector3 = rover.position
		rover.step_drive(dt,forward,side,Input.is_physical_key_pressed(KEY_CTRL),boost)
		if world.is_blocked(rover.position,1.5):
			var impact:float = absf(rover.speed)
			rover.position = old_rover
			rover.velocity *= -0.2
			if impact>5.0 and hit_cooldown<=0.0:
				rover.take_damage(impact*0.9/(1.0+_level("rover")*0.35),-1 if side<0.0 else 1)
				hit_cooldown = 0.7
				_notify("Rover impact. Brake with Ctrl; damaged modules affect handling.")
		rover.position.y = world.ground_height(Vector2(rover.position.x,rover.position.z))
		player.position = rover.position
		if absf(rover.speed)>3.0:
			ecology.disturb(rover.position,dt*0.13)
		if rover.hull<=0.0:
			_mount()
			_notify("Rover disabled. Recover on foot, or repair at the lander.")
	else:
		move_direction = Vector3(side,0,-forward).normalized()
		var speed:float = 2.6 if crouched else (8.0 if boost else 5.2)
		var proposed:Vector3 = player.position+move_direction*speed*dt
		if not world.is_blocked(proposed,0.55,0.65 if crouched else 1.8):
			player.position = proposed
		else:
			var slide_x:Vector3 = player.position+Vector3(move_direction.x,0,0)*speed*dt
			var slide_z:Vector3 = player.position+Vector3(0,0,move_direction.z)*speed*dt
			if not world.is_blocked(slide_x,0.55,0.65 if crouched else 1.8):
				player.position = slide_x
			if not world.is_blocked(slide_z,0.55,0.65 if crouched else 1.8):
				player.position = slide_z
		player.position.y = world.ground_height(Vector2(player.position.x,player.position.z))
		if move_direction.length()>0.1:
			player.rotation.y = lerp_angle(player.rotation.y,atan2(move_direction.x,move_direction.z),minf(dt*12.0,1.0))
			if boost and not crouched:
				ecology.disturb(player.position,dt*0.025)
		Models.animate_researcher(player,field_time,player.position.distance_to(previous)>0.005)

func _update_creatures(dt:float) -> void:
	for c:Dictionary in creatures:
		var node:Node3D = c.node
		var info:Dictionary = species[int(c.species)]
		var distance:float = node.position.distance_to(player.position)
		c.stun = maxf(0.0,float(c.stun)-dt)
		c.calm = maxf(0.0,float(c.calm)-dt)
		c.cooldown = maxf(0.0,float(c.cooldown)-dt)
		var hostile:bool = info.temperament in ["territorial","predator"]
		var alert_range:float = 15.0 if info.temperament=="predator" else 8.0
		if crouched: alert_range *= 0.75
		if int(state.selected_crew)==1:
			alert_range *= 0.72
		c.alert = hostile and distance<alert_range and float(c.calm)<=0.0 and float(c.stun)<=0.0
		var direction:Vector3 = Vector3.ZERO
		var move_speed:float = 1.1
		if float(c.stun)<=0.0:
			var nearest_lure:Dictionary = {}
			for lure:Dictionary in lures:
				if node.position.distance_to(lure.position)<18.0+_level("lure")*3.0:
					nearest_lure = lure
			if not nearest_lure.is_empty():
				c.calm = 1.5
				c.alert = false
				var lure_delta:Vector3 = nearest_lure.position-node.position
				if lure_delta.length()>2.0:
					direction = lure_delta.normalized()
			elif bool(c.alert):
				if distance>3.0 and float(c.windup)<=0.0:
					direction = (player.position-node.position).normalized()
					move_speed = 3.5 if info.temperament=="predator" else 2.7
				elif float(c.cooldown)<=0.0 and float(c.windup)<=0.0:
					c.windup = 1.5 if int(c.species)==6 else 1.1
					c.attack_pos = player.position
					c.ring.visible = true
					c.ring.material_override = _material(Color("ff9e65"),true)
				if float(c.windup)>0.0:
					c.windup = maxf(0.0,float(c.windup)-dt)
					if float(c.windup)<=0.0:
						c.cooldown = 3.0
						if player.position.distance_to(c.get("attack_pos",node.position))<3.0 and distance<5.0:
							_hurt(15.0)
						_burst(node.position,Color("ff9e65"),3.0)
			elif (info.temperament=="shy" and distance<(15.0 if mounted else 5.0)) or (mounted and distance<9.0):
				direction = (node.position-player.position).normalized()
				move_speed = 4.0
			else:
				var home:Vector3 = c.home
				var wandering := home+Vector3(sin(field_time*0.13+float(c.phase))*4.5,0,cos(field_time*0.11+float(c.phase))*4.5)
				# Compare nearby habitats with Tilebean's disturbance/forage score.
				if ecology.habitat_at(node.position)<0.35:
					var best:float = ecology.habitat_at(wandering)
					for direction_index in 6:
						var angle:float = float(direction_index)*TAU/6.0
						var patch:Vector3 = node.position+Vector3(cos(angle),0,sin(angle))*7.0
						var score:float = ecology.habitat_at(patch)
						if score>best and not world.is_blocked(patch,0.8):
							best = score
							wandering = patch
				if node.position.distance_to(wandering)>1.1:
					direction = (wandering-node.position).normalized()
		else:
			c.windup = 0.0
			c.alert = false
		if not bool(c.alert) and float(c.stun)<=0.0 and float(c.calm)<=0.0:
			var home_delta: Vector3 = c.home-node.position
			match int(c.species):
				2: # Strides align with the mineral lattice, not free pursuit.
					if absf(direction.x)>absf(direction.z): direction.z = 0.0
					else: direction.x = 0.0
				3,7: # Sail circles a resonator; mantle drifts with the ash front.
					var angle: float = field_time*(0.28 if int(c.species)==3 else 0.1)+float(c.phase)
					var orbit: Vector3 = c.home+Vector3(sin(angle),0,cos(angle))*(5.5 if int(c.species)==3 else 8.0)
					direction = (orbit-node.position).normalized()
					move_speed = 1.7 if int(c.species)==3 else 0.8
				4,9: # Heat bells and filter reefs remain close to their host site.
					direction = home_delta.normalized() if home_delta.length()>1.3 else Vector3.ZERO
					move_speed = 0.45
				6: move_speed = 0.7 # Heavy ceramic carrier; louder warning, faster charge.
				8: # Brine pilgrim moves in pulses between osmotic rests.
					move_speed = 2.0 if fmod(field_time+float(c.phase),5.0)<2.5 else 0.0
				10:
					ecology.restore(node.position,dt*0.015)
					move_speed = 0.65
				11: move_speed = 0.8
		if bool(c.alert) and int(c.species)==6: move_speed = 3.7
		if bool(c.alert) and int(c.species)==9: direction = Vector3.ZERO
		direction.y = 0.0
		var candidate:Vector3 = node.position+direction*move_speed*dt
		if not world.is_blocked(candidate,0.7):
			node.position = candidate
		node.position.y = world.ground_height(Vector2(node.position.x,node.position.z))
		if direction.length()>0.1:
			node.rotation.y = lerp_angle(node.rotation.y,atan2(direction.x,direction.z),minf(dt*5.0,1.0))
		c.ring.position = node.position+Vector3(0,0.13,0)
		c.ring.visible = float(c.windup)>0.0 or float(c.stun)>0.0 or (not target.is_empty() and target.id==c.id)
		if float(c.windup)<=0.0:
			c.ring.material_override = _material(Color("a9b5ff") if float(c.stun)>0.0 else Color("70e8d2"),true)
		Models.animate_creature(node,field_time,direction.length()>0.1,bool(c.alert))

func _hurt(amount:float) -> void:
	if hit_cooldown>0.0:
		return
	hit_cooldown = 1.0
	amount *= float(crew[int(state.selected_crew)].get("damage_multiplier",1.0))
	amount /= 1.0+_level("suit")*0.35
	if mounted:
		rover.take_damage(amount/(1.0+_level("rover")*0.35),0)
	else:
		health = maxf(0.0,health-amount)
	_notify("Warning display became a lunge. Step out of the orange ring or use a pulse.")
	_ping(160.0)

func _update_target() -> void:
	target = {}
	var nearest:float = 14.0+_level("scanner")*2.5
	for c:Dictionary in creatures:
		var d:float = player.position.distance_to(c.node.position)
		if d<nearest:
			nearest = d
			target = {"kind":"creature","id":c.id,"species":c.species,"distance":d,"creature":c}
	for point:Dictionary in world.points:
		var d:float = player.position.distance_to(point.position)
		if d<4.5 and (point.kind in ["deposit","tether"] or not _point_visited(str(point.id))):
			if str(point.kind)=="relay" and relay_recovered:
				continue
			target = point.duplicate()
			target.distance = d
			break

func _point_visited(id:String) -> bool:
	return id in collected or id in state.visited.get(str(planet.id),[])

func _scan(dt:float,instant:bool=false) -> bool:
	if target.is_empty() or target.kind!="creature" or mounted or not tether_trip.is_empty():
		return false
	var record:Dictionary = _research(int(target.species))
	if bool(record.scanned):
		return false
	if energy<2.0:
		_notify("Scanner charge low. Release E to recharge.")
		return false
	if scan_id!=str(target.id):
		scan_id = str(target.id)
		scan_progress = 0.0
	var speed:float = (1.0+_level("scanner")*0.3)*float(crew[int(state.selected_crew)].get("scan_multiplier",1.0))
	if instant:
		if not _spend_order(18.0):
			return false
		scan_progress = 1.0
	else:
		scan_progress += dt*speed/3.2
		energy = maxf(0.0,energy-dt*5.0)
	if scan_progress>=1.0:
		record.scanned = true
		state.science = int(state.science)+5
		_notify("Observed: "+str(species[int(target.species)].name)+". F collects a sample within 4 meters.",6.0)
		_burst(target.creature.node.position,Color("73e5cb"),2.8)
		_ping(860.0)
		_save()
		return true
	return false

func _sample() -> bool:
	if mounted or not tether_trip.is_empty() or target.is_empty() or target.kind!="creature":
		return false
	var id:int = int(target.species)
	var record:Dictionary = _research(id)
	if not bool(record.scanned):
		_notify("Scan this organism first. Hold E within scanner range.")
		return false
	if bool(target.creature.get("sample_taken",false)):
		_notify("This individual has already been sampled. Leave it to recover.")
		return false
	if float(target.distance)>4.0:
		_notify("Approach within 4 meters to collect. Lures calm shy and territorial animals.")
		return false
	if carried.size()>=2+_level("cargo"):
		_notify("Racks full. Deposit at a cyan D console, or press B to build a field station.")
		return false
	if bool(target.creature.alert):
		_notify("Unsafe collection. Calm it with Q or stun it with Space.")
		return false
	if tactical and not _spend_order(8.0):
		return false
	carried.append(id)
	target.creature.sample_taken = true
	target.creature.calm = 6.0
	field_science += 4
	_notify("Sample in cargo. Deposit at a cyan D console to save it and free a rack.",5.0)
	_ping(1100.0)
	return true

func _interact() -> void:
	if target.is_empty():
		return
	if target.kind=="creature":
		if tactical:
			_scan(0.0,true)
		return
	if mounted:
		_notify("Dismount with R to work at the site.")
		return
	var kind:String = str(target.kind)
	if kind=="deposit":
		_deposit()
		return
	if kind=="tether":
		_tether()
		return
	var id:String = str(target.id)
	if _point_visited(id):
		return
	if tactical and not _spend_order(5.0):
		return
	collected.append(id)
	if kind=="relay":
		relay_recovered = true
		field_science += 15
		_notify("Relay archive recovered. Return to the lander to transmit it.",7.0)
	elif kind=="field_site":
		field_science += 12
		_notify(str(planet.site)+" surveyed. Habitat notes saved on extraction. J opens the journal.",6.0)
	elif kind=="cache":
		field_science += int(8.0*float(crew[int(state.selected_crew)].get("salvage_multiplier",1.0)))
		oxygen = minf(100.0,oxygen+30.0)
		energy = minf(100.0,energy+35.0)
		_notify("Field cache recovered: supplies restored and research materials packed.")
	else:
		field_science += 6
		_notify("Colony transmission recovered. Extract to keep it; read it in the journal.",5.0)
	_burst(target.position,Color("f2d18b"),3.5)
	_ping(740.0)

func _spend_order(cost:float) -> bool:
	if tactical and tactical_ap<=0:
		_notify("Orders spent. Resume live time with Tab; orders recharge after 12 seconds.")
		return false
	if energy<cost:
		_notify("Insufficient equipment charge. Wait for recharge.")
		return false
	energy -= cost
	if tactical:
		tactical_ap -= 1
	return true

func _pulse() -> bool:
	if pulse_cooldown>0.0 or not _spend_order(25.0):
		return false
	pulse_cooldown = 5.0
	for c:Dictionary in creatures:
		if player.position.distance_to(c.node.position)<9.0:
			c.stun = 6.0
			c.windup = 0.0
			c.alert = false
	ecology.disturb(player.position,0.45)
	_burst(player.position,Color("af9ff6"),9.0)
	_notify("Nonlethal pulse. Six seconds to collect or move away; nearby habitat was disturbed.")
	_ping(250.0)
	return true

func _lure() -> bool:
	if lures.size()>=3 or not _spend_order(15.0):
		return false
	var pos:Vector3 = player.position+Vector3(0,0,-4)
	pos.y = world.ground_height(Vector2(pos.x,pos.z))
	var ring := _ring(pos,2.4,Color("eacb88"))
	lures.append({"position":pos,"remaining":16.0+_level("lure")*7.0,"node":ring})
	_notify("Pheromone lure active. Wait for an animal to settle, then collect with F.")
	_ping(430.0)
	return true

func _deposit() -> bool:
	if mounted or not tether_trip.is_empty() or target.get("kind","")!="deposit" or float(target.get("distance",INF))>4.5:
		return false
	if carried.is_empty():
		_notify("No cargo to deposit. Saved cultures await analysis aboard the ship.")
		return false
	if tactical and not _spend_order(0.0):
		return false
	var count := carried.size()
	for id: int in carried:
		_research(id).sampled = true
		if not id in state.samples: state.samples.append(id)
	# Pay only this cargo's provisional sample reward, never relay/site rewards.
	var reward := count*4
	field_science -= reward
	state.science = int(state.science)+reward
	deposited += count
	carried.clear()
	_save()
	_notify("%d samples deposited and saved. Racks free. X at the lander, then open the lab." % count,6.0)
	_burst(target.position,Color("79e6db"),2.8)
	_ping(1100.0)
	return true

func _toggle_crouch() -> bool:
	if mounted or not tether_trip.is_empty(): return false
	if crouched and world.is_blocked(player.position,0.55,1.8):
		_notify("Low ceiling. Crawl out before standing.")
		return false
	crouched = not crouched
	player.scale.y = 0.35 if crouched else 1.0
	_notify("Crouched. Service passages are accessible. C stands up." if crouched else "Standing. Shift sprints.")
	return true

func _tether() -> bool:
	if mounted or not tether_trip.is_empty(): return false
	for crossing: Dictionary in world.crossings:
		for ends: Array in [[crossing.a,crossing.b],[crossing.b,crossing.a]]:
			if player.position.distance_to(ends[0])>4.5: continue
			if world.is_blocked(ends[1],0.55,1.8): continue
			crouched = false
			player.scale.y = 1.0
			var cable := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.035
			mesh.bottom_radius = 0.035
			mesh.height = 1.0
			mesh.radial_segments = 5
			cable.mesh = mesh
			cable.material_override = _material(Color("e8d3a4"),true)
			world.add_child(cable)
			tether_trip = {"start":player.position,"finish":ends[1],"pivot":crossing.pivot,"time":0.0,"cable":cable}
			scan_progress = 0.0
			_notify("Tether crossing. G swings back from the far bank.")
			return true
	_notify("Find a marked tether mast, then press G on foot.")
	return false

func _advance_tether(dt: float) -> void:
	tether_trip.time = minf(1.4,float(tether_trip.time)+dt)
	var t: float = float(tether_trip.time)/1.4
	player.position = Vector3(tether_trip.start).lerp(tether_trip.finish,smoothstep(0,1,t))
	player.position.y += sin(t*PI)*4.0
	var cable: Node3D = tether_trip.cable
	var end: Vector3 = player.position+Vector3(0,1.2,0)
	var delta: Vector3 = Vector3(tether_trip.pivot)-end
	cable.position = end+delta*0.5
	cable.quaternion = Quaternion(Vector3.UP,delta.normalized())
	cable.scale.y = delta.length()
	if t>=1.0:
		cable.queue_free()
		tether_trip.clear()
		player.position.y = world.ground_height(Vector2(player.position.x,player.position.z))

func _camp() -> bool:
	if not tether_trip.is_empty() or world.is_blocked(player.position,1.6):
		_notify("Find open ground before deploying a field station.")
		return false
	if stations.size()>=2:
		_notify("Two field stations already deployed on this expedition.")
		return false
	if not _spend_order(40.0):
		return false
	var pos:Vector3 = player.position
	var ring := _ring(pos,6.0,Color("91e3b6"))
	world.add_field_console(pos,"deposit-station-%d" % stations.size())
	stations.append({"position":pos,"node":ring})
	ecology.restore(pos,0.8)
	_notify("Station ready. Green circle restores oxygen. E at the cyan console deposits samples.",6.0)
	return true

func _mount() -> bool:
	if crouched or not tether_trip.is_empty():
		_notify("Stand outside the passage before boarding the rover.")
		return false
	if mounted:
		mounted = false
		rover.stop()
		player.visible = true
		var pos:Vector3 = rover.position+Vector3(3,0,0)
		if world.is_blocked(pos,0.55):
			pos = rover.position+Vector3(-3,0,0)
		player.position = pos
		player.position.y = world.ground_height(Vector2(pos.x,pos.z))
		_notify("On foot. E scans, F samples. Hold Shift to run.")
		return true
	if player.position.distance_to(rover.position)>6.0:
		_notify("Move within 6 meters of the rover. Its marker is blue on the map.")
		return false
	if rover.hull<=0.0:
		if energy>=35.0:
			energy -= 35.0
			rover.repair()
			_notify("Emergency rover repair used 35 equipment charge.")
		else:
			_notify("Disabled rover needs 35 charge for emergency repairs.")
			return false
	mounted = true
	player.visible = false
	player.position = rover.position
	scan_progress = 0.0
	_notify("W/S throttle · A/D steer · Shift boost · Ctrl brake/drift · R dismount",6.0)
	return true

func _update_tools(dt:float) -> void:
	for i in range(lures.size()-1,-1,-1):
		lures[i].remaining = float(lures[i].remaining)-dt
		lures[i].node.rotation.y += dt
		if float(lures[i].remaining)<=0.0:
			lures[i].node.queue_free()
			lures.remove_at(i)
	for station:Dictionary in stations:
		ecology.restore(station.position,dt*0.04)

func _burst(pos:Vector3,color:Color,radius:float) -> void:
	var ring := _ring(pos,1.0,color)
	effects.append({"node":ring,"time":0.0,"duration":0.7,"radius":radius})

func _update_effects(dt:float) -> void:
	for i in range(effects.size()-1,-1,-1):
		var fx:Dictionary = effects[i]
		fx.time = float(fx.time)+dt
		var size:float = lerpf(0.3,float(fx.radius),float(fx.time)/float(fx.duration))
		fx.node.scale = Vector3(size,1,size)
		if float(fx.time)>=float(fx.duration):
			fx.node.queue_free()
			effects.remove_at(i)

func _request_extract() -> void:
	if Vector2(player.position.x,player.position.z).length()>10.0:
		_notify("Return to the lander's white circle to extract. X works there too.",6.0)
		return
	_finish_expedition(true)

func _finish_expedition(success:bool) -> void:
	var id:int = int(planet.id)
	var recovered:int = carried.size()+deposited
	if success:
		for species_id:int in carried:
			_research(species_id).sampled = true
			if not species_id in state.samples:
				state.samples.append(species_id)
		state.science = int(state.science)+field_science
		if "field-site" in collected and not int(planet.id) in state.get("surveys",[]):
			state.surveys.append(int(planet.id))
		if relay_recovered and not id in state.relays:
			state.relays.append(id)
			state.logs.append(str(planet.log))
		if not state.visited.has(str(id)):
			state.visited[str(id)] = []
		for point_id:String in collected:
			if not point_id in state.visited[str(id)]:
				state.visited[str(id)].append(point_id)
		var all_scanned:bool = true
		for species_id in planet.species:
			all_scanned = all_scanned and bool(_research(int(species_id)).scanned)
		if all_scanned and id in state.relays and not id in state.completed:
			state.completed.append(id)
	else:
		state.rescues = int(state.rescues)+1
	carried.clear()
	_save()
	_build_hub()
	_show_hub()
	var summary:String = "%s\n\n%d samples saved, including %d deposited in the field.\n%d research from extracted sites and cargo.\n\nNext: open the laboratory and analyze your cultures. Spend research on the mission deck." % [str(planet.name),recovered,deposited,field_science]
	if not success:
		summary = "Your researcher was rescued. %d deposited samples are safe. Carried cargo and unextracted site data were lost.\n\nObservations, deposited cultures and previous research remain saved. Analyze cultures in the ship lab." % deposited
	hud.show_overlay("EXTRACTION COMPLETE" if success else "EMERGENCY RESCUE",summary,[{"text":"Open laboratory","action":"lab","payload":null},{"text":"Return to mission deck","action":"close","payload":null}])
	if success and id==5 and relay_recovered:
		_final_decision()

func _final_decision() -> void:
	if not 5 in state.relays:
		return
	if not bool(_research(10).scanned) or not bool(_research(11).scanned):
		hud.show_overlay("COMPLETE THE HEART SURVEY","Observe both organisms on The Quiet Heart before making your final recommendation. Your recovered relay is already safe aboard the carrier.",[{"text":"Mission deck","action":"close","payload":null}])
		return
	var analyzed:int = 0
	for record:Dictionary in state.research.values():
		if bool(record.get("analyzed",false)):
			analyzed += 1
	if analyzed<6:
		hud.show_overlay("THE QUIET HEART", "The relay confirms a living network across all six worlds. The research council needs six analyzed species before your final recommendation.\n\nYou have %d. Recovered samples are waiting in the laboratory." % analyzed,[{"text":"Open laboratory","action":"lab","payload":null},{"text":"Mission deck","action":"close","payload":null}])
		return
	hud.show_overlay("WHAT SHOULD KLAX PROTECT?","The network preserves a history we cannot yet read. The colonists' disappearance remains unexplained.\n\nPreserve: leave its interplanetary communication intact and establish a remote observation zone.\n\nContain: isolate the relays to prevent further spread, protecting settled space while fragmenting the living archive.",[{"text":"Preserve the living archive","action":"ending","payload":"preserve"},{"text":"Contain the network","action":"ending","payload":"contain"}])

func _upgrade(id:String) -> bool:
	for item:Dictionary in upgrades:
		if str(item.id)!=id:
			continue
		var level:int = _level(id)
		var cost:int = int(item.cost)*(level+1)
		if level>=int(item.max) or int(state.science)<cost:
			return false
		state.science = int(state.science)-cost
		state.upgrades[id] = level+1
		_save()
		_show_hub()
		_ping(920.0)
		return true
	return false

func _start_assay(id:int) -> bool:
	var record:Dictionary = _research(id)
	if not bool(record.sampled) or bool(record.analyzed):
		return false
	mode = "ASSAY"
	hud.clear_overlay()
	assay = Assay.new()
	hud.add_child(assay)
	assay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	assay.finished.connect(_analyzed)
	assay.cancelled.connect(func():
		assay.queue_free()
		mode = "LAB"
		hud.show_lab(state,species))
	assay.configure(id,str(species[id].name),9919+id*373)
	return true

func _analyzed(id:int,bonus:int) -> void:
	var record:Dictionary = _research(id)
	if bool(record.analyzed):
		return
	record.analyzed = true
	record.bonus = bonus
	state.science = int(state.science)+int(species[id].science)+bonus
	_save()
	if is_instance_valid(assay):
		assay.queue_free()
	mode = "LAB"
	hud.show_lab(state,species)
	_ping(1320.0)
	if 5 in state.relays and state.ending=="":
		_final_decision()

func _toggle_tactical() -> void:
	tactical = not tactical
	_notify("Tactical survey: three charged orders. E scan · Q lure · Space pulse. Tab resumes." if tactical else "Live survey resumed. Orders recover after 12 seconds.",5.0)

func _command(action:String,payload:Variant=null) -> void:
	match action:
		"select_planet":
			state.selected_planet = clampi(int(payload),0,5)
			_show_hub()
		"select_crew":
			state.selected_crew = clampi(int(payload),0,2)
			_show_hub()
		"launch":
			hud.clear_overlay()
			launch()
		"upgrade":
			_upgrade(str(payload))
		"council":
			_final_decision()
		"lab":
			hud.clear_overlay()
			mode = "LAB"
			hud.show_lab(state,species)
		"analyze":
			_start_assay(int(payload))
		"journal":
			previous_mode = mode
			mode = "JOURNAL"
			hud.show_journal(state,species)
		"close","resume":
			hud.clear_overlay()
			if is_instance_valid(world) and mode in ["JOURNAL","FIELD"]:
				mode = "FIELD"
				paused = false
				hud.show_field(_snapshot())
			else:
				_show_hub()
		"pulse":
			if mode=="FIELD" and not paused: _pulse()
		"lure":
			if mode=="FIELD" and not paused: _lure()
		"camp":
			if mode=="FIELD" and not paused: _camp()
		"crouch":
			if mode=="FIELD" and not paused: _toggle_crouch()
		"tether":
			if mode=="FIELD" and not paused: _tether()
		"deposit":
			if mode=="FIELD" and not paused: _deposit()
		"mount":
			if mode=="FIELD" and not paused: _mount()
		"extract":
			if mode=="FIELD" and not paused: _request_extract()
		"pause":
			_toggle_pause()
		"tactical":
			if mode=="FIELD" and not paused: _toggle_tactical()
		"abort":
			_finish_expedition(false)
		"help":
			paused = true
			hud.show_overlay("FIELD MANUAL","WASD / arrows move. Hold E to scan nearby organisms; tap E to recover a ruin, relay or cache. F collects a scanned species within 4 meters.\n\nR boards the rover nearby. W/S throttle, A/D steer, Shift boost, Ctrl brake and drift. R dismounts.\n\nSpace emits a nonlethal pulse. Q places a calming lure. B deploys one of two oxygen stations with sample consoles. E at a cyan D console saves cargo and frees racks.\n\nC crouches through low service passages. G swings between marked tether masts. The rover cannot enter either route. Tab slows time for three tactical orders. Mouse wheel adjusts the camera.\n\nReturn to the lander and press X to keep samples and relay data. Analyze samples aboard ship. Five relays reveal the final world. Six analyzed species let you make the final decision.\n\nEsc pauses. M toggles sound. F11 toggles fullscreen.",[{"text":"Continue","action":"resume","payload":null}])
		"ending":
			state.ending = str(payload)
			_save()
			hud.show_overlay("PROJECT KLAX / EXPEDITION COMPLETE","The living archive remains connected. Your team establishes an observation perimeter and transmits its evidence to the council. The next expedition will need to learn how to listen." if str(payload)=="preserve" else "The relays fall silent one by one. The colonies remain under quarantine. Your samples preserve fragments of a living history that no longer speaks across the stars.",[{"text":"Continue researching","action":"close","payload":null}])
		"new":
			hud.show_overlay("START A NEW CAMPAIGN?","This replaces your active campaign. The previous valid autosave remains as a backup file.",[{"text":"Keep current campaign","action":"close","payload":null},{"text":"Start fresh","action":"confirm_new","payload":null}])
		"confirm_new":
			state = Save.fresh()
			_save()
			hud.clear_overlay()
			_show_hub()

func _toggle_pause() -> void:
	if mode!="FIELD":
		_command("close")
		return
	paused = not paused
	if paused:
		hud.show_overlay("EXPEDITION PAUSED","Your suit, organisms, weather and cargo are paused.",[{"text":"Resume survey","action":"resume","payload":null},{"text":"Field manual","action":"help","payload":null},{"text":"Emergency return · lose field cargo","action":"abort","payload":null}])
	else:
		hud.clear_overlay()

func _unhandled_input(event:InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and mode=="FIELD":
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:
			camera_distance = maxf(15.0,camera_distance-2.0)
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = minf(42.0,camera_distance+2.0)
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key:int = event.physical_keycode
	if key==KEY_F11:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
	if key==KEY_M:
		state.muted = not bool(state.get("muted",false))
		if is_instance_valid(sound): sound.muted = state.muted
		_save()
	if key==KEY_ESCAPE:
		if mode=="ASSAY" and is_instance_valid(assay):
			assay.cancelled.emit()
			return
		_toggle_pause()
		return
	if mode=="HUB" and key==KEY_ENTER:
		launch()
		return
	if mode!="FIELD" or paused:
		return
	match key:
		KEY_E: _interact()
		KEY_F: _sample()
		KEY_R: _mount()
		KEY_C: _toggle_crouch()
		KEY_G: _tether()
		KEY_SPACE: _pulse()
		KEY_Q: _lure()
		KEY_B: _camp()
		KEY_TAB: _toggle_tactical()
		KEY_X: _request_extract()
		KEY_J: _command("journal")
		KEY_H: _command("help")

func _snapshot() -> Dictionary:
	if not is_instance_valid(player):
		return {}
	var target_name:String = "No life form in scanner range"
	var detail:String = "Explore the ruins. E recovers archives, caches and the relay."
	if not target.is_empty():
		if target.kind=="creature":
			var id:int = int(target.species)
			var info:Dictionary = species[id]
			var record:Dictionary = _research(id)
			target_name = "%s · %.1f m" % [str(info.name),float(target.distance)]
			if bool(record.scanned):
				detail = "Already sampled. Find another individual." if bool(target.creature.get("sample_taken",false)) else ("Alert: Q lure or Space pulse before F." if bool(target.creature.alert) else "F: collect within 4 m. Deposit at cyan D consoles.")
			else:
				detail = "Hold E to scan · "+str(info.temperament).capitalize()+". Keep clear of warning rings."
		else:
			target_name = str(target.get("title","Derelict archive"))
			detail = "E: deposit cargo and free racks. Analysis is aboard ship." if target.kind=="deposit" else ("G: swing across. Park the rover here." if target.kind=="tether" else "E: recover site data. Extract to keep it.")
	var markers:Array = [{"position":Vector2.ZERO,"color":Color.WHITE,"label":"L"},{"position":Vector2(rover.position.x,rover.position.z),"color":Color("8ab9ff"),"label":"R"}]
	for point:Dictionary in world.points:
		if point.kind in ["deposit","tether"] or not _point_visited(str(point.id)):
			var label: String = {"relay":"!","deposit":"D","field_site":"S","tether":"G"}.get(str(point.kind),"+")
			markers.append({"position":Vector2(point.position.x,point.position.z),"color":Color("79e6db") if point.kind=="deposit" else Color("f6d28a"),"label":label})
	for c:Dictionary in creatures:
		if player.position.distance_to(c.node.position)<25.0:
			markers.append({"position":Vector2(c.node.position.x,c.node.position.z),"color":Color("ff946f") if bool(c.alert) else Color("7ee5c0"),"label":""})
	var observed:int = 0
	for id in planet.species:
		if bool(_research(int(id)).scanned): observed+=1
	var objective:String = "Scanned %d/2 · Cargo %d/%d · %d deposited" % [observed,carried.size(),2+_level("cargo"),deposited]
	var destination: Dictionary = _destination()
	markers.append({"position":Vector2(destination.position.x,destination.position.z),"color":Color.WHITE,"label":">"})
	var weather:Dictionary = ecology.weather_snapshot()
	return {"planet":str(planet.name),"objective":objective,"health":health,"oxygen":oxygen,"energy":energy,
		"science":int(state.science),"cargo":carried.size(),"deposited":deposited,"navigation":destination.text,"crouched":crouched,"target":target_name,"target_detail":detail,
		"scan_progress":scan_progress if not target.is_empty() and str(target.id)==scan_id else 0.0,
		"message":message if message_time>0.0 else ecology.describe_at(player.position),"rover":mounted,"boost":float(rover.boost_energy),
		"rover_hull":float(rover.hull),"left_module":float(rover.left_module),"right_module":float(rover.right_module),
		"weather":str(weather.get("name","Calm")),"mode":"TACTICAL" if tactical else "SURVEY","tactical_ap":tactical_ap,
		"time":field_time,"player":Vector2(player.position.x,player.position.z),"markers":markers}

func _destination() -> Dictionary:
	var pos := Vector3.ZERO
	var title := "Lander [X]: return to ship, then analyze cultures"
	var first: int = int(planet.species[0])
	var second: int = int(planet.species[1])
	if not bool(_research(first).scanned):
		for c: Dictionary in creatures:
			if int(c.species)==first:
				pos = c.node.position
				title = "Local life signal: hold E to scan"
				break
	elif not bool(_research(second).scanned):
		pos = Vector3(world.habitat_center.x,0,world.habitat_center.y)
		title = str(planet.site)+" [S]: trace the second life signal"
	elif not _point_visited("field-site"):
		pos = Vector3(world.habitat_center.x,0,world.habitat_center.y)
		title = str(planet.site)+" [S]: recover habitat data"
	elif not relay_recovered and not int(planet.id) in state.relays:
		for point: Dictionary in world.points:
			if point.kind=="relay": pos = point.position
		title = "Relay [!]: recover the colony transmission"
	elif not carried.is_empty():
		var nearest := INF
		for point: Dictionary in world.points:
			if point.kind=="deposit" and player.position.distance_to(point.position)<nearest:
				nearest = player.position.distance_to(point.position)
				pos = point.position
		title = "Console [D]: deposit samples with E"
	var distance := Vector2(pos.x-player.position.x,pos.z-player.position.z).length()
	return {"position":pos,"text":"%s · %d m" % [title,roundi(distance)]}

func _publish_telemetry() -> void:
	if not qa_enabled or not OS.has_feature("web"):
		return
	var data:Dictionary = {"mode":mode,"paused":paused,"tactical":tactical,"science":int(state.science),"samples":state.samples,"relays":state.relays,"ending":state.ending}
	data.research = state.research
	data.buttons = _visible_buttons(hud)
	if is_instance_valid(player) and is_instance_valid(world):
		data.merge({"x":player.position.x,"z":player.position.z,"health":health,"oxygen":oxygen,"energy":energy,
			"mounted":mounted,"crouched":crouched,"tethering":not tether_trip.is_empty(),"deposited":deposited,"recovered_sites":collected,"navigation":_destination().text,"field_time":field_time,"cargo":carried.size(),"scan_progress":scan_progress,"target_id":str(target.get("id","")),
			"target_kind":str(target.get("kind","")),"research":state.research,"creatures":creatures.size(),"ecology_rounds":ecology.rounds})
		data.points = []
		for point: Dictionary in world.points:
			data.points.append({"kind":point.kind,"id":point.id,"x":point.position.x,"z":point.position.z})
		data.obstacles = []
		for obstacle: Dictionary in world.obstacles:
			var record := {"x":obstacle.position.x,"z":obstacle.position.z}
			if obstacle.has("half_size"):
				record.merge({"half_x":obstacle.half_size.x,"half_z":obstacle.half_size.y,"clearance":obstacle.get("clearance",-1)})
			else: record.radius = obstacle.radius
			data.obstacles.append(record)
		data.crawl = {"x":world.crawl_center.x,"z":world.crawl_center.y}
		var crossing: Dictionary = world.crossings[0]
		data.crossing = {"ax":crossing.a.x,"az":crossing.a.z,"bx":crossing.b.x,"bz":crossing.b.z}
		data.fauna = []
		for c: Dictionary in creatures:
			data.fauna.append({"species":c.species,"x":c.node.position.x,"z":c.node.position.z,"sampled":c.sample_taken})
		if not target.is_empty() and target.kind=="creature":
			data.merge({"target_x":target.creature.node.position.x,"target_z":target.creature.node.position.z,"target_distance":target.distance,"target_species":target.species})
	JavaScriptBridge.eval("window.__klaxQA = "+JSON.stringify(data)+";",true)

func _visible_buttons(node:Node) -> Array:
	var buttons:Array = []
	if node is Button and node.is_visible_in_tree():
		var rect:Rect2 = node.get_global_rect()
		buttons.append({"text":node.text,"x":rect.get_center().x,"y":rect.get_center().y,"disabled":node.disabled})
	for child in node.get_children():
		buttons.append_array(_visible_buttons(child))
	return buttons
