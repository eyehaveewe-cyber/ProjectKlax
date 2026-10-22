extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var rover = load("res://scripts/klax_rover.gd").new()
	root.add_child(rover)
	var carrier = load("res://scripts/research_carrier.gd").new()
	root.add_child(carrier)
	carrier.set_open(true)
	for i in 600:
		rover.step_drive(1.0 / 60.0, 1.0, 0.0, false, false)
	assert(rover.position.z < -100.0, "Forward travel failed")
	assert(rover.speed <= 16.001, "Normal speed cap failed")
	rover.take_damage(40.0, -1)
	assert(rover.left_module == 0.0, "Asymmetric damage failed")
	var before: float = rover.heading
	for i in 60:
		rover.step_drive(1.0 / 60.0, 0.0, 0.0, false, true)
	assert(not rover.boosting, "Broken module allowed boost")
	assert(rover.heading > before, "Missing left module did not pull left")
	for i in 600:
		rover.step_drive(1.0 / 60.0, 0.0, 0.0, true, false)
	assert(rover.speed < 0.05, "Damaged rover cannot stop")
	rover.repair()
	assert(rover.hull == 100.0 and rover.left_module == 100.0 and rover.right_module == 100.0)
	for i in 240:
		rover.step_drive(1.0 / 60.0, 1.0, 0.0, false, true)
	assert(rover.speed <= 25.001, "Boost speed cap failed")
	assert(rover.boost_energy < 1.0, "Boost did not consume energy")
	for i in 240:
		rover.step_drive(1.0 / 60.0, 1.0, 0.0, false, true)
	assert(not rover.boosting, "Exhausted held boost did not latch off")
	rover.step_drive(1.0 / 60.0, 1.0, 0.0, false, false)
	rover.step_drive(1.0 / 60.0, 1.0, 0.0, false, true)
	assert(rover.boosting, "Released boost did not rearm")
	carrier.pose(1.0, 2.0)
	assert(is_equal_approx(carrier.doors[0].position.x, -2.95))
	print("VEHICLE CHECK PASS: forward travel, caps, damage, recovery, repair, boost latch, carrier doors")
	quit()
