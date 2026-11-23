extends SceneTree
const SKIN_FX = preload("res://scripts/skin_fx.gd")
const GLASS = preload("res://shaders/frosted_glass.gdshader")
const DISPLAY_FONT = preload("res://assets/fonts/ChakraPetch-Bold.ttf")
const METRIC_FONT = preload("res://assets/fonts/DMMono-Regular.ttf")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	await process_frame
	if game.ui == null or game.ui.full == null or game.ui.ink == null:
		_fail("UI must instantiate frosted surfaces")
		return
	if game.name_entry.get_parent() != game.ui.root:
		_fail("Controls must be above glass in same CanvasLayer")
		return
	if game.ui.full.material == null or game.ui.full.material.shader != GLASS:
		_fail("Menu must use actual screen-blur shader")
		return
	if DISPLAY_FONT == null or METRIC_FONT == null:
		_fail("Licensed custom fonts should load")
		return
	if not game.ui.full.visible:
		_fail("Menu must have fullscreen glass")
		return
	game._on_shop_button()
	await process_frame
	if game.mode != "shop" or game.shop_buttons.size() != game.SKINS.size():
		_fail("Skin archive must show all phenotypes")
		return
	if not game.shop_buttons[0].visible:
		_fail("Skin archive controls must be visible")
		return
	game._return_from_overlay()
	game._on_secondary_button()
	await process_frame
	if game.mode != "settings" or not game.settings_theme_button.visible:
		_fail("Settings must be visible from home")
		return
	var previous_theme: bool = game.light_mode
	game._toggle_theme()
	if game.light_mode == previous_theme:
		_fail("Theme preference must switch")
		return
	game._return_from_overlay()
	game._start_game()
	await process_frame
	if game.ui.full.visible or not game.ui.top_bar.visible or not game.ui.bottom_bar.visible:
		_fail("Gameplay must show edge glass strips")
		return
	for id in ["mint","bubblegum","arctic","solar","rainbow","galaxy","gold"]:
		var c1: Color = SKIN_FX.phenotype_color(id,0.5)
		var c2: Color = SKIN_FX.phenotype_color(id,4.3)
		if c1.a < 0.9 or c2.a < 0.9:
			_fail("Opaque skin colors expected: "+id)
			return
	if SKIN_FX.phenotype_color("rainbow",0.1).is_equal_approx(SKIN_FX.phenotype_color("rainbow",6.0)):
		_fail("Prismatic color must animate")
		return
	if game.player.get("trail",null) == null:
		_fail("Movement trails must have state")
		return
	game.free()
	print("Amoeba Arena v0.6 UI and skin tests passed")
	quit(0)

func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
