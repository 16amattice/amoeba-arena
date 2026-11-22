extends SceneTree
## CI regression check of core mechanics.

func _initialize() -> void:
    call_deferred("_run_checks")

func _run_checks() -> void:
    var script := load("res://scripts/game.gd")
    if script == null:
        _fail("Could not load main game script")
        return
    var game = script.new()
    root.add_child(game)
    game._start_game()
    if game._cell_speed({"mass": 25.0}) <= game._cell_speed({"mass": 200.0}):
        _fail("Smaller cells must be faster")
        return
    if game._cell_radius({"mass": 25.0}) >= game._cell_radius({"mass": 200.0}):
        _fail("Larger cells must have larger bodies")
        return
    var large = game._make_cell(Vector2(800, 800), 240.0, Color.RED, "LARGE", false)
    var small = game._make_cell(Vector2(808, 800), 60.0, Color.GREEN, "SMALL", false)
    game.cells.clear()
    game.cells.append(large)
    game.cells.append(small)
    game.player = small
    game._resolve_bites(0.2)
    if small["mass"] >= 60.0 or large["mass"] <= 240.0:
        _fail("Overlapping bigger cell should bite a smaller one")
        return
    if not small["alive"]:
        _fail("Victim must survive a partial bite")
        return
    if small["marks"].size() == 0:
        _fail("Bites must create deformation marks")
        return
    print("Amoeba Arena smoke tests passed")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
