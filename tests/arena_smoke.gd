extends SceneTree
## Headless smoke tests: tissue subtraction, wall projection, momentum, economics.

func _initialize() -> void:
	_run_checks()

func _run_checks() -> void:
	var script := load("res://scripts/game.gd")
	if script == null:
		_fail("Game script missing")
		return
	var game = script.new()
	game._start_game()
	if game._cell_speed({"mass": 400.0}) <= game._cell_speed({"mass": 600.0}) * 1.25:
		_fail("Speed advantage must be substantial at 400 vs 600 mass")
		return

	game.touch_index = 3
	game.touch_origin = Vector2(50, 50)
	game.touch_position = Vector2(150, 50)
	var before: Vector2 = game._move_input()
	game._release_touch(3)
	if game.touch_index != -1 or game._move_input().distance_to(before) > 0.001:
		_fail("Cruise direction and speed must persist after touch release")
		return
	game._move_cells(0.1)
	if game.player["pos"].x <= 1800.0:
		_fail("Player should coast forward after lifting touch")
		return

	var wall = game._make_cell(Vector2(8, 8), 400.0, Color.BLUE, "CORNER", false)
	var pieces = game.CellGeometry.world_shapes(wall, game.ARENA)
	for polygon in pieces:
		for vertex in polygon:
			if vertex.x < 0.0 or vertex.y < 0.0 or vertex.x > game.ARENA.x or vertex.y > game.ARENA.y:
				_fail("Tissue must conform to corners and never leave arena")
				return

	var eater = game._make_cell(Vector2(870, 800), 260.0, Color.RED, "BIG", false)
	var victim = game._make_cell(Vector2(800, 800), 100.0, Color.GREEN, "PREY", false)
	var original_mass: float = victim["mass"]
	var original_area: float = game.CellGeometry.visible_area(victim, game.ARENA)
	var part: Dictionary = game.CellGeometry.consume(eater, victim, game.ARENA)
	if part["mass"] <= 0.0 or victim["mass"] >= original_mass or not victim["alive"]:
		_fail("Partial overlap must remove actual tissue without killing victim")
		return
	if game.CellGeometry.visible_area(victim, game.ARENA) >= original_area:
		_fail("Physical remaining shape must lose actual visible area")
		return
	eater["pos"] = victim["pos"]
	var finish: Dictionary = game.CellGeometry.consume(eater, victim, game.ARENA)
	if not finish["dead"] or victim["alive"] or victim["mass"] > 0.0:
		_fail("Full overlap must consume every part and eliminate prey")
		return

	game._award(400, 15)
	if game.level <= 1 or game.coins < 15 or game.round_xp < 400:
		_fail("Persistent coins and XP must be awarded with level-ups")
		return
	if game._sanitize_username("  Blob King  ") != "Blob King":
		_fail("Usernames must be trimmed")
		return
	print("Amoeba Arena v0.3 tests passed")
	quit(0)

func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
