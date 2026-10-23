extends SceneTree
## Regression tests for the October playtest requests using actual game nodes.
const Scene = preload("res://scenes/main.tscn")
const Save = preload("res://scripts/savegame.gd")
const TEST_SAVE := "user://klax_playtest_deposit.json"
var game: Node3D
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, text: String) -> void:
	checks += 1
	if not value:
		failures.append(text)
		push_error(text)

func near_species(id: int, occurrence: int = 0) -> void:
	var index := 0
	for c: Dictionary in game.creatures:
		if int(c.species)!=id: continue
		if index!=occurrence:
			index+=1
			continue
		for i in range(16):
			var angle := float(i)*TAU/16.0
			game.player.position = c.node.position+Vector3(cos(angle),0,sin(angle))*2.8
			game._update_target()
			if game.target.get("id","")==c.id:
				c.alert = false
				return
	check(false,"Species has a usable targeting approach")

func near_console() -> void:
	for p: Dictionary in game.world.points:
		if p.kind=="deposit":
			game.player.position = p.position+Vector3(0,0,1.2)
			game._update_target()
			if game.target.get("kind","")=="deposit": return
	check(false,"Console has a usable targeting approach")

func _run() -> void:
	game = Scene.instantiate()
	game.testing = true
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	game.launch()
	await process_frame
	near_species(0)
	check(not game._scan(1.0),"Scan still requires sustained exposure, not instant observation")
	check(game._scan(3.0),"Original scan timing still completes")
	check(game._sample(),"First scanned individual can be collected")
	near_species(0,1)
	check(game._sample(),"Second individual fills base rack")
	check(game.carried.size()==2 and game.field_science==8,"Two samples carry exactly eight provisional research")
	game.player.position = Vector3(25,0,25)
	game._update_target()
	check(not game._deposit() and game.carried.size()==2,"Deposit cannot be invoked remotely")
	near_console()
	game.tactical = true
	game.tactical_ap = 0
	check(not game._deposit() and game.carried.size()==2,"Empty tactical orders cannot deposit")
	game.tactical = false
	check(game._deposit(),"Console deposits carried cultures")
	check(game.carried.is_empty() and game.deposited==2,"Deposit frees all sample racks")
	check(game.state.samples==[0] and game._research(0).sampled,"Comparative deposit stores unique lab species")
	check(game.state.science==13 and game.field_science==0,"Deposit pays sample reward once, separately from observations")
	check(not game._deposit() and game.state.science==13,"Empty deposit cannot duplicate research")
	near_species(0,2)
	check(game._sample(),"Freed rack accepts another individual on the same expedition")
	game._finish_expedition(false)
	await process_frame
	check(game._research(0).sampled and game.state.samples==[0],"Emergency rescue preserves deposited cultures")
	check(game.state.science==13 and game.carried.is_empty(),"Rescue loses unbanked cargo and preserves deposited rewards")
	check(Save.save_campaign(game.state,TEST_SAVE),"Deposited state saves at the actual save boundary")
	var restored: Dictionary = Save.load_campaign(TEST_SAVE)
	check(restored.samples==[0] and restored.research["0"].sampled,"Deposited cultures survive save reload")
	var legacy: Dictionary = restored.duplicate(true)
	legacy.erase("surveys")
	check(Save.valid(legacy),"Old version-one saves remain valid without habitat surveys")
	check(Save.save_campaign(legacy,TEST_SAVE),"Legacy save can still be saved")
	check(Save.load_campaign(TEST_SAVE).surveys.is_empty(),"Legacy saves receive an empty habitat survey list")
	for id in range(6):
		game.state.selected_planet = id
		game.state.relays = [0,1,2,3,4]
		check(game.launch(),"World %d launches" % id)
		await process_frame
		await _world_checks(id)
	for suffix in ["",".backup",".tmp"]:
		if FileAccess.file_exists(TEST_SAVE+suffix): DirAccess.remove_absolute(TEST_SAVE+suffix)
	game.queue_free()
	await process_frame
	print("PLAYTEST %s: %d checks, %d failures" % ["PASS" if failures.is_empty() else "FAIL",checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func _world_checks(id: int) -> void:
	var far_min := INF
	var geometry: Dictionary = {}
	for c: Dictionary in game.creatures:
		if int(c.species)==id*2+1: far_min = minf(far_min,Vector2(c.node.position.x,c.node.position.z).length())
		var organs: Array[String] = []
		for part: Node in c.node.get_children(): organs.append(str(part.name))
		geometry[int(c.species)] = str(organs)
	check(far_min>=35,"World %d second species requires travel beyond 35 m" % id)
	check(geometry[id*2]!=geometry[id*2+1],"World %d species have distinct original anatomy" % id)
	check(game.world.crossings.size()==1,"World %d contains a working tether pair" % id)
	var crossing: Dictionary = game.world.crossings[0]
	check(game.world.is_blocked((crossing.a+crossing.b)*0.5,0.55),"Fissure rejects walking and driving")
	game.player.position = crossing.a
	check(game._tether(),"World %d tether starts at marked mast" % id)
	check(not game._mount(),"Cannot board a rover during a swing")
	game._advance_tether(0.7)
	check(game.player.position.y>(crossing.a.y+crossing.b.y)*0.5+2.5,"Tether visibly swings above the fissure")
	game._advance_tether(0.7)
	check(game.tether_trip.is_empty() and game.player.position.distance_to(crossing.b)<0.1,"Tether lands on the opposite bank")
	check(game._tether(),"Tether supports the return journey")
	game._advance_tether(1.4)
	var center: Vector2 = game.world.crawl_center
	var tunnel := Vector3(center.x,0,center.y)
	check(game.world.is_blocked(tunnel,0.55,1.8),"Tunnel blocks a standing researcher")
	check(not game.world.is_blocked(tunnel,0.55,0.65),"Tunnel admits a crouched researcher")
	game.player.position = tunnel
	check(game._toggle_crouch() and game.crouched,"Crouch changes researcher posture")
	check(not game._toggle_crouch() and game.crouched,"Cannot stand through low tunnel roof")
	game.player.position = tunnel+Vector3(0,0,5)
	check(game._toggle_crouch() and not game.crouched,"Can stand outside tunnel")
	game.player.position = Vector3(20,0,5)
	for attempt in range(12):
		if not game.world.is_blocked(game.player.position,1.6): break
		game.player.position += Vector3(2,0,-2)
	game.energy = 100
	check(game._camp(),"Field station deploys")
	check(game.world.points.filter(func(p: Dictionary): return p.kind=="deposit").size()==2,"Deployed station adds a visible deposit interaction")
	# Flood fill the real standing collision field. Geometry rather than a
	# symbolic route graph proves approach access, but not human wayfinding.
	var reachable := _reachable()
	for c: Dictionary in game.creatures:
		check(not game.world.is_blocked(c.node.position,0.7),"World %d organism %s spawns outside blockers" % [id,c.id])
	for point: Dictionary in game.world.points:
		var accessible := false
		for dx in range(-2,3):
			for dz in range(-2,3):
				var cell := Vector2i(roundi(point.position.x/2.0)+dx,roundi(point.position.z/2.0)+dz)
				if reachable.has(cell) and Vector2(cell*2).distance_to(Vector2(point.position.x,point.position.z))<4.0:
					accessible = true
		check(accessible,"World %d site %s has a reachable interaction approach" % [id,point.id])
	# Short field UI, complete narrative stored in the journal.
	game.player.position = Vector3.ZERO
	game._update_target()
	var snapshot: Dictionary = game._snapshot()
	check(str(snapshot.target_detail).length()<110,"Target instructions remain a short readable action")
	check(str(snapshot.navigation).length()>10,"Field navigation states a destination and distance")

func _reachable() -> Dictionary:
	var queue: Array[Vector2i] = [Vector2i.ZERO]
	var visited := {Vector2i.ZERO:true}
	var head := 0
	while head<queue.size():
		var cell := queue[head]
		head+=1
		for delta: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next := cell+delta
			if visited.has(next): continue
			var pos := Vector3(next.x*2,0,next.y*2)
			if game.world.is_blocked(pos,0.65): continue
			visited[next] = true
			queue.append(next)
	return visited
