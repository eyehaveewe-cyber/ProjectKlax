extends SceneTree
## Direct-method integration against the real scene. This does not claim mouse
## playtesting. It never reads or writes the player's normal campaign save.

const GameScene = preload("res://scenes/main.tscn")
const Save = preload("res://scripts/savegame.gd")
const TEST_SAVE := "user://klax_test_campaign_integration.json"
var failures: Array[String] = []
var checks := 0
var game: Node3D

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _near_species(id: int, distance: float = 3.0, occurrence: int = 0) -> Dictionary:
	var index := 0
	for creature: Dictionary in game.creatures:
		if int(creature.species) != id:
			continue
		if index != occurrence:
			index += 1
			continue
		# Choose a clear approach rather than assuming the +X side has no site console.
		for approach in range(16):
			var angle := float(approach)*TAU/16.0
			game.player.position = creature.node.position + Vector3(cos(angle),0,sin(angle))*distance
			game._update_target()
			if game.target.get("id","")==creature.id: break
		_check(not game.target.is_empty() and game.target.get("id", "") == creature.id, "Actual targeting selects specimen %s" % creature.id)
		creature.alert = false
		return creature
	_check(false, "Fixture species %d occurrence %d exists" % [id, occurrence])
	return {}

func _has_button(node: Node, needle: String) -> bool:
	if node.is_queued_for_deletion():
		return false
	if node is Button and needle in node.text:
		return true
	for child: Node in node.get_children():
		if _has_button(child, needle):
			return true
	return false

func _relay() -> void:
	for point: Dictionary in game.world.points:
		if point.kind == "relay":
			game.player.position = point.position
			game._update_target()
			_check(game.target.get("kind", "") == "relay", "Relay selected through actual world target lookup")
			game._interact()
			_check(game.relay_recovered, "Relay recovered by interaction")
			return
	_check(false, "World contains a relay")

func _extract() -> void:
	game.player.position = Vector3.ZERO
	game._request_extract()
	_check(game.mode == "HUB", "Lander extraction returns to hub")

func _analyze(id: int) -> void:
	_check(game._start_assay(id), "Recovered species %d opens actual assay" % id)
	if is_instance_valid(game.assay):
		game.assay.analyze_now()
	_check(bool(game._research(id).analyzed), "Assay signal records analysis %d" % id)
	var science := int(game.state.science)
	_check(not game._start_assay(id), "Analyzed species cannot award research twice")
	_check(int(game.state.science) == science, "Repeated assay attempt preserves science")

func _run() -> void:
	game = GameScene.instantiate()
	game.testing = true
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	_check(game.mode == "HUB" and int(game.state.science) == 0, "Testing scene starts with fresh hub state")
	game.state.science = 1000
	for level in range(1, 4):
		_check(game._upgrade("scanner"), "Scanner level %d can be purchased" % level)
	_check(int(game.state.science) == 820, "Scanner upgrades charge actual escalating costs 30 + 60 + 90")
	_check(game._level("scanner") == 3, "Scanner upgrade reaches declared cap")
	_check(not game._upgrade("scanner") and int(game.state.science) == 820, "Capped upgrade neither succeeds nor charges")
	game.state.science = 0
	_check(not game._upgrade("oxygen") and game._level("oxygen") == 0, "Unaffordable upgrade preserves level")
	_check(not game._upgrade("unknown"), "Unknown upgrade rejected")
	game._command("confirm_new")
	_check(game.state == Save.fresh(), "Confirmed new campaign resets progression")
	game.state.selected_planet = 5
	_check(not game.launch() and game.mode == "HUB", "Final world stays locked without five relays")
	game.state.selected_planet = 0
	_check(game.launch(), "First expedition launches")
	await process_frame
	_check(game.mode == "FIELD" and game.creatures.size() >= 2, "Real world and creature models instantiate")
	_check(game.health == 100.0 and game.energy == 100.0 and game.oxygen == 100.0, "Launch restores expedition resources")
	game.player.position = game.rover.position + Vector3(20, 0, 0)
	_check(not game._mount(), "Rover cannot be mounted remotely")
	game.player.position = game.rover.position + Vector3(2, 0, 0)
	_check(game._mount() and game.mounted and not game.player.visible, "Nearby rover mounts and hides researcher")
	game.rover.velocity = Vector3(4, 0, 0)
	_check(game._mount() and not game.mounted and game.player.visible, "Dismount restores researcher")
	_check(game.rover.velocity.is_zero_approx(), "Dismount stops rover momentum")
	game.rover.hull = 0.0
	game.energy = 34.0
	_check(not game._mount() and not game.mounted and game.energy == 34.0, "Disabled rover refuses unfunded emergency repair")
	game.energy = 35.0
	_check(game._mount() and game.rover.hull == 100.0 and game.energy == 0.0, "Emergency repair spends 35 charge and restores mountability")
	game._mount()
	game.health = 100.0
	game.hit_cooldown = 0.0
	game.state.selected_crew = 1
	game._hurt(15.0)
	_check(is_equal_approx(game.health, 88.0), "Ranger receives advertised 20 percent encounter protection")
	game.state.selected_crew = 0
	game.health = 100.0
	game.hit_cooldown = 0.0
	_near_species(0)
	game.tactical = true
	game.tactical_ap = 0
	game.energy = 100.0
	_check(not game._pulse() and game.energy == 100.0 and game.pulse_cooldown == 0.0, "Pulse rejects absent tactical order without cost")
	game.tactical_ap = 1
	game.energy = 24.0
	_check(not game._pulse() and game.tactical_ap == 1, "Pulse rejects insufficient energy without spending order")
	game.energy = 25.0
	_check(game._pulse() and game.energy == 0.0 and game.tactical_ap == 0, "Pulse spends one tactical order and 25 charge")
	_check(float(game.target.creature.stun) == 6.0 and not bool(game.target.creature.alert), "Pulse actually stuns nearby organism")
	game.energy = 100.0
	game.tactical_ap = 3
	_check(not game._pulse() and game.energy == 100.0 and game.tactical_ap == 3, "Pulse cooldown prevents repeated free effects and costs")
	game.tactical_ap = 0
	game.player.position = Vector3.ZERO
	game.tactical_recharge = 0.0
	for i in range(20):
		game._physics_process(0.1)
	_check(game.tactical_ap == 0, "Tactical slowdown cannot regenerate spent orders")
	game.tactical = false
	for i in range(121):
		game._physics_process(0.1)
	_check(game.tactical_ap == 3, "Twelve seconds of live simulation restores orders")
	game.player.position = Vector3(500, 0, 500)
	game._update_target()
	_check(game.target.is_empty() and not game._scan(5.0), "Scanner cannot acquire a remote creature")
	_near_species(0, 6.0)
	_check(not game._sample(), "Collection requires a prior scan")
	var starting_science := int(game.state.science)
	_check(game._scan(4.0), "Observation completes through normal scan path")
	_check(int(game.state.science) == starting_science + 5 and bool(game._research(0).scanned), "First observation records species and awards five science")
	_check(not game._scan(4.0) and int(game.state.science) == starting_science + 5, "Repeat observation has no duplicate award")
	_check(not game._sample(), "Collection rejects scanned organism beyond four meters")
	var specimen := _near_species(0)
	specimen.alert = true
	_check(not game._sample(), "Alert organism cannot be collected")
	specimen.alert = false
	game.tactical = true
	game.tactical_ap = 0
	game.energy = 100.0
	_check(not game._sample() and game.energy == 100.0, "Tactical collection requires an order without charging on refusal")
	game.tactical_ap = 1
	game.energy = 7.0
	_check(not game._sample() and game.tactical_ap == 1, "Insufficient collection energy preserves order")
	game.energy = 8.0
	_check(game._sample(), "Safe scanned organism enters field cargo")
	_check(game.tactical_ap == 0 and game.energy == 0.0, "Tactical collection spends one order and eight charge")
	_check(game.carried.size() == 1 and not bool(game._research(0).sampled), "Field cargo is provisional before extraction")
	_check(not game._sample(), "Same individual cannot be sampled twice in a sortie")
	game.tactical = false
	game.energy = 100.0
	_near_species(0, 3.0, 1)
	_check(game._sample() and game.carried.size() == 2, "Distinct individual provides a comparative sample")
	_near_species(0, 3.0, 2)
	_check(not game._sample() and game.carried.size() == 2, "Base cargo capacity rejects a third sample")
	game.player.position = Vector3(30, 0, 30)
	game._request_extract()
	_check(game.mode == "FIELD" and game.carried.size() == 2, "Extraction requires return to lander")
	_extract()
	await process_frame
	_check(game.state.samples == [0] and bool(game._research(0).sampled), "Extraction commits unique species once")
	_check(int(game.state.science) == 13, "Two comparative samples earn eight field science plus five observation science")
	_analyze(0)
	await process_frame
	_check(game._upgrade("cargo"), "Actual first analysis funds first cargo upgrade")
	_check(game._level("cargo") == 1, "Purchased cargo upgrade increases rack level")
	_check(game.launch(), "Second expedition launches")
	await process_frame
	for occurrence in range(3):
		_near_species(0, 3.0, occurrence)
		_check(game._sample(), "Upgraded rack accepts comparative sample %d" % occurrence)
	_near_species(0, 3.0, 3)
	_check(not game._sample() and game.carried.size() == 3, "Upgraded capacity is exactly three")
	_near_species(1)
	_check(game._scan(4.0), "Rescue fixture records a new observation")
	var before_rescue_science := int(game.state.science)
	var before_rescue_samples: Array = game.state.samples.duplicate()
	game._finish_expedition(false)
	await process_frame
	_check(game.carried.is_empty() and int(game.state.rescues) == 1, "Rescue discards field cargo and records rescue")
	_check(game.state.samples == before_rescue_samples and not bool(game._research(1).sampled), "Rescue preserves previous samples but adds no carried material")
	_check(bool(game._research(1).scanned) and int(game.state.science) == before_rescue_science, "Rescue retains observations without field-science award")
	await _campaign_progression()
	_save_checks()
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("CAMPAIGN PASS: %d checks against real main scene, six worlds, cargo/extraction/rescue, research/upgrades, tactical orders, rover and custom-path save recovery" % checks)
		quit(0)
	else:
		print("CAMPAIGN FAIL: %d of %d checks failed" % [failures.size(), checks])
		quit(1)

func _campaign_progression() -> void:
	# Fresh authored campaign fixture. Progression goes through actual targeting,
	# scanning, sample collection, relay interaction, extraction and assay signals.
	game._command("confirm_new")
	for planet_id in range(5):
		game.state.selected_planet = planet_id
		_check(game.launch(), "Planet %d launches" % planet_id)
		await process_frame
		for id in game.planet.species:
			_near_species(int(id))
			_check(game._scan(4.0), "Planet %d species %d scans" % [planet_id, int(id)])
			_check(game._sample(), "Planet %d species %d collected" % [planet_id, int(id)])
		_relay()
		_extract()
		await process_frame
		_check(planet_id in game.state.relays and planet_id in game.state.completed, "Extracted relay and complete observation persist for planet %d" % planet_id)
	_check(game.state.relays.size() == 5, "Five distinct relay archives recovered")
	game.state.selected_planet = 5
	_check(game.launch(), "Five relays unlock final world")
	await process_frame
	_relay()
	_extract()
	await process_frame
	_check(5 in game.state.relays and game.state.ending == "", "Heart archive persists without prematurely selecting an ending")
	_check(not _has_button(game.hud.overlay, "Preserve the living archive"), "Final recommendation remains blocked without analyzed species")
	for id in range(6):
		_analyze(id)
		await process_frame
	game._final_decision()
	_check(not _has_button(game.hud.overlay, "Preserve the living archive"), "Six analyses still require both Heart species to be observed")
	_check(game.launch(), "Final world can be revisited after premature archive recovery")
	await process_frame
	for id in game.planet.species:
		_near_species(int(id))
		_check(game._scan(4.0), "Heart species %d observed" % int(id))
	_extract()
	await process_frame
	game._final_decision()
	_check(_has_button(game.hud.overlay, "Preserve the living archive"), "Six analyses and Heart survey expose final recommendation")
	game._command("close")
	_check(_has_button(game.hud.content, "Council recommendation"), "Closing a pending ending leaves a Council entry on hub")
	_check(Save.save_campaign(game.state, TEST_SAVE), "Pending council decision can be saved")
	game.state = Save.load_campaign(TEST_SAVE)
	game._show_hub()
	_check(_has_button(game.hud.content, "Council recommendation"), "Reloaded pending ending remains reachable from hub")
	game._command("council")
	_check(_has_button(game.hud.overlay, "Preserve the living archive"), "Reloaded Council entry reopens available decision")
	game._command("ending", "preserve")
	_check(game.state.ending == "preserve", "Chosen ending persists in campaign state")
	game._command("close")
	_check(game.mode == "HUB", "Completed campaign permits continued research")

func _save_checks() -> void:
	for suffix in ["", ".backup", ".tmp"]:
		if FileAccess.file_exists(TEST_SAVE + suffix):
			DirAccess.remove_absolute(TEST_SAVE + suffix)
	var first: Dictionary = Save.fresh()
	first.science = 41
	first.research = {"0": {"scanned": true, "sampled": true, "analyzed": false}}
	first.samples = [0]
	first.relays = [0]
	first.completed = [0]
	_check(Save.save_campaign(first, TEST_SAVE), "Custom-path first save succeeds")
	var second: Dictionary = first.duplicate(true)
	second.science = 73
	second.upgrades = {"scanner": 1}
	_check(Save.save_campaign(second, TEST_SAVE), "Custom-path replacement save succeeds")
	_check(int(Save.load_campaign(TEST_SAVE).science) == 73, "Fresh read returns latest committed save")
	var loaded: Dictionary = Save.load_campaign(TEST_SAVE)
	_check(0 in loaded.relays and 0 in loaded.completed and 0 in loaded.samples, "JSON reload restores integer IDs for progression membership")
	var file := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	file.store_string("{broken-json")
	file.close()
	_check(int(Save.load_campaign(TEST_SAVE).science) == 41, "Corrupt primary restores previous valid backup")
	var malformed: Dictionary = second.duplicate(true)
	malformed.research = {"0": {}}
	_check(not Save.valid(malformed), "Malformed nested research is rejected at save boundary")
	file = FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(malformed))
	file.close()
	_check(int(Save.load_campaign(TEST_SAVE).science) == 41, "Malformed nested primary falls back to valid backup")
	_check(not Save.save_campaign(malformed, TEST_SAVE), "Rejected state cannot overwrite a save")
	var restored: Dictionary = Save.load_campaign(TEST_SAVE)
	_check(Save.save_campaign(restored, TEST_SAVE), "Recovered backup can be saved as active campaign")
	_check(int(Save.load_campaign(TEST_SAVE).science) == 41, "Repaired primary survives a new load")
	for suffix in ["", ".backup", ".tmp"]:
		if FileAccess.file_exists(TEST_SAVE + suffix):
			DirAccess.remove_absolute(TEST_SAVE + suffix)
