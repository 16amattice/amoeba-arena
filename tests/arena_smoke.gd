extends SceneTree
const CellGeometry = preload("res://scripts/cell_geometry.gd")
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
	var pieces = CellGeometry.world_shapes(wall, game.ARENA)
	var touches_x := false
	var touches_y := false
	for polygon in pieces:
		for vertex in polygon:
			touches_x = touches_x or vertex.x < 0.01
			touches_y = touches_y or vertex.y < 0.01
	if not touches_x or not touches_y:
		_fail("Corner body must actually touch both walls")
		return
	for polygon in pieces:
		for vertex in polygon:
			if vertex.x < 0.0 or vertex.y < 0.0 or vertex.x > game.ARENA.x or vertex.y > game.ARENA.y:
				_fail("Tissue must conform to corners and never leave arena")
				return

	var eater = game._make_cell(Vector2(870, 800), 260.0, Color.RED, "BIG", false)
	var victim = game._make_cell(Vector2(800, 800), 100.0, Color.GREEN, "PREY", false)
	var original_mass: float = victim["mass"]
	var original_area: float = CellGeometry.visible_area(victim, game.ARENA)
	var part: Dictionary = CellGeometry.consume(eater, victim, game.ARENA)
	if part["mass"] <= 0.0 or victim["mass"] >= original_mass or not victim["alive"]:
		_fail("Partial overlap must remove actual tissue without killing victim")
		return
	if CellGeometry.visible_area(victim, game.ARENA) >= original_area:
		_fail("Physical remaining shape must lose actual visible area")
		return
	for remaining in CellGeometry.world_shapes(victim, game.ARENA):
		for covered in CellGeometry.world_shapes(eater, game.ARENA):
			for overlap in Geometry2D.intersect_polygons(remaining, covered):
				if CellGeometry.polygon_area(overlap) > 1.0:
					_fail("Already-eaten area must not still be part of the victim")
					return
	eater["pos"] = victim["pos"]
	var finish: Dictionary = CellGeometry.consume(eater, victim, game.ARENA)
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
	game._save_profile()
	var saved := ConfigFile.new()
	if saved.load("user://amoeba_progress.cfg") != OK or int(saved.get_value("progress", "coins", -1)) != game.coins:
		_fail("Wallet must persist to device storage")
		return
	game._start_game()
	game.cells.clear()
	game.cells.append(game.player)
	CellGeometry.grow(game.player, 300.0)
	game._check_victory(game.CROWN_HOLD_SECONDS)
	if game.mode != "won" or game.victories <= 0:
		_fail("Hold-the-lead win condition must award a crown")
		return
	game.free()
	print("Amoeba Arena v0.3 tests passed")
	quit(0)

func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
