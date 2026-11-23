extends CanvasLayer
## Screen-space frosted HUD and full-bleed menus.
## "Lab instrument" visual system: Chakra Petch display + DM Mono metrics,
## asymmetric edge bars, hairline rules and actual screen-sampled blur.

const DISPLAY = preload("res://assets/fonts/ChakraPetch-Bold.ttf")
const BODY = preload("res://assets/fonts/ChakraPetch-Medium.ttf")
const MONO = preload("res://assets/fonts/DMMono-Regular.ttf")
const FROST = preload("res://shaders/frosted_glass.gdshader")
const SKIN_FX = preload("res://scripts/skin_fx.gd")

const INK = Color(0.025, 0.09, 0.13, 0.97)
const CYAN = Color(0.40, 0.96, 0.81)
const WHITE = Color(0.94, 0.98, 0.98)
const MUTED = Color(0.57, 0.75, 0.78)
const GOLD = Color(1.0, 0.83, 0.48)
const CORAL = Color(1.0, 0.48, 0.51)

class InkCanvas:
	extends Control
	var compositor
	func _draw() -> void:
		if compositor != null:
			compositor.paint(self)

var game
var root: Control
var full: ColorRect
var top_bar: ColorRect
var leaderboard_panel: ColorRect
var minimap_panel: ColorRect
var bottom_bar: ColorRect
var ink: InkCanvas
var last_size := Vector2.ZERO


func attach(host) -> void:
	game = host
	layer = 4
	root = Control.new()
	root.name = "FrostedHUDRoot"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	full = _surface("FullScreenBlur", Color(0.024, 0.085, 0.111, 0.83), 4.4)
	top_bar = _surface("GlassHeader", Color(0.035, 0.12, 0.16, 0.64), 3.3)
	leaderboard_panel = _surface("GlassScores", Color(0.028, 0.10, 0.14, 0.55), 3.0)
	minimap_panel = _surface("GlassRadar", Color(0.028, 0.10, 0.14, 0.60), 3.0)
	bottom_bar = _surface("GlassFooter", Color(0.03, 0.105, 0.13, 0.69), 3.3)
	ink = InkCanvas.new()
	ink.name = "InkAndLabels"
	ink.compositor = self
	ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(ink)
	_update_layout()
	set_process(true)


func _surface(title: String, tint: Color, blur: float) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = title
	rect.color = Color.WHITE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material_instance := ShaderMaterial.new()
	material_instance.shader = FROST
	material_instance.set_shader_parameter("glass_tint", tint)
	material_instance.set_shader_parameter("blur_lod", blur)
	rect.material = material_instance
	root.add_child(rect)
	return rect


func _process(_delta: float) -> void:
	_update_layout()
	if ink != null:
		ink.queue_redraw()


func _update_layout() -> void:
	if game == null or root == null:
		return
	var screen: Vector2 = get_viewport().get_visible_rect().size
	root.size = screen
	ink.size = screen
	var ingame: bool = game.mode == "playing"
	full.visible = not ingame
	top_bar.visible = ingame
	leaderboard_panel.visible = ingame
	minimap_panel.visible = ingame
	bottom_bar.visible = ingame
	full.position = Vector2.ZERO
	full.size = screen
	top_bar.position = Vector2.ZERO
	top_bar.size = Vector2(screen.x, 164)
	minimap_panel.position = Vector2(screen.x - 170, 181)
	minimap_panel.size = Vector2(148, 148)
	leaderboard_panel.position = Vector2(screen.x - 290, 343)
	leaderboard_panel.size = Vector2(268, 385)
	bottom_bar.position = Vector2(0, screen.y - 160)
	bottom_bar.size = Vector2(screen.x, 160)


func paint(c: Control) -> void:
	if game == null:
		return
	var s: Vector2 = c.size
	if game.mode == "playing":
		_game_hud(c, s)
	else:
		match game.mode:
			"menu":
				_home(c, s)
			"dead", "won":
				_result(c, s)
			"shop":
				_shop(c, s)
			"settings":
				_settings(c, s)


func _text(c: Control, value: String, position: Vector2, px: int, color: Color = WHITE, font: Font = BODY, width: float = -1.0, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	c.draw_string(font, position, value, align, width, px, color)


func _line(c: Control, a: Vector2, b: Vector2, opacity: float = 0.24, thick: float = 1.5) -> void:
	c.draw_line(a, b, Color(CYAN.r, CYAN.g, CYAN.b, opacity), thick, true)


func _tag(c: Control, value: String, x: float, y: float, color: Color = MUTED) -> void:
	_text(c, value, Vector2(x, y), 16, color, MONO)


func _mark(c: Control, pos: Vector2, radius: float, t: float) -> void:
	c.draw_arc(pos, radius, -0.95 + 0.12 * sin(t), PI * 1.3, 86, Color(CYAN.r, CYAN.g, CYAN.b, 0.60), 3.2, true)
	c.draw_arc(pos, radius * 0.74, 1.9 - t * 0.04, 4.75 - t * 0.04, 68, Color(GOLD.r, GOLD.g, GOLD.b, 0.48), 1.3, true)
	c.draw_circle(pos + Vector2.from_angle(t * 0.4) * radius * 0.60, radius * 0.09, Color(CYAN.r, CYAN.g, CYAN.b, 0.67))


func _home(c: Control, s: Vector2) -> void:
	var w := s.x
	var h := s.y
	_tag(c, "A / A   .   FIELD RECORD 001", 36, 62, CYAN)
	_tag(c, "SINGLE PLAYER // LOCAL", w - 266, 62)
	_line(c, Vector2(36, 81), Vector2(w - 36, 81), 0.43)
	_mark(c, Vector2(w - 159, 236), 104, game.clock)
	_text(c, "AMOEBA", Vector2(33, 233), 94, WHITE, DISPLAY, w - 60)
	_text(c, "ARENA", Vector2(37, 316), 98, CYAN, DISPLAY, w - 60)
	_tag(c, "SURVIVE.  CONSUME.  EVOLVE.", 39, 367, WHITE)
	_text(c, "Your specimen is ready for deployment.", Vector2(39, 412), 23, MUTED, BODY)
	_line(c, Vector2(36, 453), Vector2(w - 36, 453), 0.36)
	_stats(c, 38, 482, w)
	_line(c, Vector2(36, 556), Vector2(w - 36, 556), 0.38)
	_tag(c, "01 / SPECIMEN ID", 42, 643, CYAN)
	_tag(c, "EQUIPPED   " + str(game._skin_definition(game.equipped_skin)["name"]).to_upper(), 42, 757, GOLD)
	_tag(c, "02 / ENTER THE PETRI DISH", 42, 811, CYAN)
	_line(c, Vector2(36, h - 227), Vector2(w - 36, h - 227), 0.4)
	_tag(c, "PASSIVE EVOLUTION", 39, h - 194, CYAN)
	_text(c, _perks(), Vector2(39, h - 155), 20, WHITE, BODY, w - 80)
	_tag(c, "NO PURCHASES NEEDED  /  REWARDS ARE EARNED", 39, h - 101)
	_tag(c, "BUILD 006   •   GODOT 4.7", 39, h - 47, MUTED)


func _result(c: Control, s: Vector2) -> void:
	var w := s.x
	var h := s.y
	var won: bool = game.mode == "won"
	_tag(c, "SESSION ARCHIVED // " + str(game.username).to_upper(), 38, 67, CYAN)
	_line(c, Vector2(36, 87), Vector2(w - 36, 87), 0.43)
	_mark(c, Vector2(w - 155, 226), 111, game.clock)
	if won:
		_text(c, "CELL CROWN", Vector2(38, 195), 66, GOLD, DISPLAY, w - 70)
		_text(c, "SECURED", Vector2(40, 272), 86, WHITE, DISPLAY)
		_tag(c, "01 / YOU CONTROLLED THE ARENA", 42, 323, CYAN)
	else:
		_text(c, "SPECIMEN", Vector2(38, 196), 83, WHITE, DISPLAY)
		_text(c, "ABSORBED", Vector2(40, 275), 83, CORAL, DISPLAY)
		_tag(c, "01 / END OF THIS RUN — NOT THE END", 42, 324, CYAN)
	_line(c, Vector2(37, 360), Vector2(w - 37, 360), 0.38)
	_result_stats(c, w)
	_line(c, Vector2(37, 555), Vector2(w - 37, 555), 0.38)
	_tag(c, "RUN REWARDS", 43, 607, CYAN)
	_text(c, "+" + str(game.round_coins) + " COINS", Vector2(42, 662), 42, GOLD, DISPLAY)
	_text(c, "+" + str(game.round_xp) + " XP", Vector2(42, 714), 40, WHITE, DISPLAY)
	_tag(c, "02 / REDEPLOY OR EXPLORE YOUR COLLECTION", 42, 788)
	_line(c, Vector2(38, h - 203), Vector2(w - 38, h - 203), 0.31)
	_tag(c, "ACCOUNT // LVL " + str(game.level) + "   ·   BALANCE " + str(game.coins), 39, h - 173, CYAN)
	_text(c, _perks(), Vector2(39, h - 131), 20, WHITE, BODY, w - 78)
	_tag(c, "ALL PROGRESSION SAVED ON THIS DEVICE", 40, h - 52)


func _stats(c: Control, x: float, y: float, w: float) -> void:
	var third := (w - 76) / 3.0
	var values := [str(game.level).pad_zeros(2), str(game.coins), str(game.victories).pad_zeros(2)]
	var tags := ["LEVEL", "COINS", "CROWNS"]
	for i in range(3):
		var px := x + third * float(i)
		_tag(c, tags[i], px, y, MUTED)
		_text(c, values[i], Vector2(px, y + 49), 37, WHITE if i != 1 else GOLD, DISPLAY)
		if i > 0:
			_line(c, Vector2(px - 18, y - 8), Vector2(px - 18, y + 55), 0.22)


func _result_stats(c: Control, w: float) -> void:
	var third := (w - 80) / 3.0
	var data := [
		{"label":"SURVIVED","value":str(int(game.survival_time)) + "s"},
		{"label":"ELIMINATIONS","value":str(game.takedowns)},
		{"label":"BEST MASS","value":str(game.best_mass)}
	]
	for i in range(3):
		var x := 42 + float(i) * third
		_tag(c, str(data[i]["label"]), x, 413)
		_text(c, str(data[i]["value"]), Vector2(x, 487), 45, WHITE if i != 2 else GOLD, DISPLAY)
		if i > 0:
			_line(c, Vector2(x - 20, 396), Vector2(x - 20, 518), 0.22)


func _perks() -> String:
	return "MAGNET +" + str(int(game._pickup_bonus())) + "px    NUTRIENTS +" + str(int(game._food_bonus() * 100.0)) + "%    START +" + str(int(game._starting_mass_bonus()))


func _shop(c: Control, s: Vector2) -> void:
	var w := s.x
	_tag(c, "COLLECTION / 001", 40, 61, CYAN)
	_line(c, Vector2(39, 81), Vector2(w - 39, 81), 0.43)
	_text(c, "THE MUTATION", Vector2(38, 164), 59, WHITE, DISPLAY)
	_text(c, "ARCHIVE", Vector2(40, 230), 76, CYAN, DISPLAY)
	_tag(c, "YOUR BALANCE", 42, 279, MUTED)
	_text(c, str(game.coins) + "  ◉", Vector2(41, 327), 38, GOLD, DISPLAY)
	_tag(c, "SEVEN HAND-CRAFTED PHENOTYPES  /  VISUAL ONLY", 43, 364, CYAN)
	for i in range(game.SKINS.size()):
		var skin: Dictionary = game.SKINS[i]
		var id: String = skin["id"]
		var y := 409.0 + float(i) * 95.0
		_line(c, Vector2(39, y - 22), Vector2(w - 39, y - 22), 0.20)
		SKIN_FX.preview(c, id, Vector2(77, y + 20), 28, game.clock)
		var name := str(skin["name"])
		_text(c, name, Vector2(120, y + 15), 27, WHITE, DISPLAY, w - 342)
		_text(c, str(skin["detail"]), Vector2(121, y + 41), 16, MUTED, BODY, w - 345)
		if game.owned_skins.has(id):
			_tag(c, "OWNED", w - 143, y - 8, CYAN)
		else:
			_tag(c, "LOCKED", w - 143, y - 8)
	_tag(c, game.shop_message, 40, s.y - 175, GOLD)
	_tag(c, "SKINS ADD VFX, NOT A COMBAT ADVANTAGE", 40, s.y - 53)


func _settings(c: Control, s: Vector2) -> void:
	var w := s.x
	_tag(c, "CONTROL ROOM / 001", 40, 67, CYAN)
	_line(c, Vector2(38, 88), Vector2(w - 38, 88), 0.42)
	_text(c, "PREFERENCES", Vector2(38, 200), 73, WHITE, DISPLAY, w - 72)
	_tag(c, "AUDIO / HAPTICS / VISUALS", 43, 245, GOLD)
	_text(c, "Make the arena feel like yours.", Vector2(42, 320), 24, MUTED, BODY)
	for i in range(3):
		var y := 422.0 + float(i) * 116.0
		_line(c, Vector2(41, y), Vector2(w - 41, y), 0.20)
	_tag(c, "AUDIO", 44, 396, CYAN)
	_tag(c, "HAPTIC FEEDBACK", 44, 512, CYAN)
	_tag(c, "ARENA LIGHTING", 44, 628, CYAN)
	_line(c, Vector2(41, 774), Vector2(w - 41, 774), 0.3)
	_tag(c, "YOUR SETTINGS STAY ON THIS DEVICE", 42, 830)
	_text(c, "Sound is synthesized in-game.", Vector2(42, 888), 21, WHITE, BODY)
	_text(c, "Light theme changes arena contrast.", Vector2(42, 932), 21, WHITE, BODY)
	_text(c, "Haptics work on supported phones.", Vector2(42, 976), 21, WHITE, BODY)


func _game_hud(c: Control, s: Vector2) -> void:
	var w := s.x
	var h := s.y
	_tag(c, "SPECIMEN / " + str(game.username).to_upper(), 26, 37, CYAN)
	_tag(c, "LIVE   •   " + str(int(game.survival_time)) + "s", w - 206, 37, GOLD)
	_line(c, Vector2(25, 52), Vector2(w - 25, 52), 0.38)
	_tag(c, "MASS", 26, 88)
	_text(c, str(int(ceil(game.player["mass"]))), Vector2(25, 139), 54, WHITE, DISPLAY)
	_tag(c, "KOs  " + str(game.takedowns), 219, 92)
	_tag(c, "LVL  " + str(game.level), 218, 131, CYAN)
	_tag(c, "COINS", w - 210, 90)
	_text(c, str(game.coins), Vector2(w - 210, 133), 35, GOLD, DISPLAY)
	_line(c, Vector2(25, 157), Vector2(w - 25, 157), 0.35)
	var xp := clampf(float(game.experience) / float(game._experience_needed()), 0.0, 1.0)
	c.draw_rect(Rect2(0, 160, w, 3), Color(0.19, 0.38, 0.40))
	c.draw_rect(Rect2(0, 160, w * xp, 3), CYAN)
	_minimap(c, Vector2(w - 170, 181), Vector2(148, 148))
	_leaderboard(c, Vector2(w - 290, 343), Vector2(268, 385))
	_line(c, Vector2(26, h - 147), Vector2(w - 26, h - 147), 0.42)
	_tag(c, "CELL CROWN / CONTROL", 28, h - 120, CYAN)
	var rank_label := "TAKE THE LEAD TO START YOUR 24s HOLD"
	if game.crown_time > 0.0:
		rank_label = "DOMINATION  " + str(int(ceil(game.CROWN_HOLD_SECONDS - game.crown_time))) + "s TO VICTORY"
	_text(c, rank_label, Vector2(28, h - 83), 23, WHITE, DISPLAY, w - 55)
	c.draw_rect(Rect2(28, h - 64, w - 56, 5), Color(0.18, 0.33, 0.34, 0.68))
	c.draw_rect(Rect2(28, h - 64, (w - 56) * clampf(game.crown_time / game.CROWN_HOLD_SECONDS, 0.0, 1.0), 5), GOLD)
	_tag(c, "DRAG TO STEER  /  RELEASE TO CRUISE", 28, h - 27, MUTED)


func _minimap(c: Control, pos: Vector2, size: Vector2) -> void:
	_tag(c, "TERRITORY", pos.x + 11, pos.y + 23, CYAN)
	c.draw_rect(Rect2(pos + Vector2(14, 36), size - Vector2(28, 49)), Color(0.15, 0.30, 0.32, 0.20), false, 1.0)
	for cell in game.cells:
		if not cell["alive"]:
			continue
		var v: Vector2 = cell["pos"]
		var offset: Vector2 = v / game.ARENA * (size - Vector2(38, 60))
		c.draw_circle(pos + Vector2(19, 42) + offset, 4.8 if cell["human"] else 2.3, CYAN if cell["human"] else MUTED)


func _leaderboard(c: Control, pos: Vector2, size: Vector2) -> void:
	_tag(c, "LIVE INDEX   /   MASS", pos.x + 17, pos.y + 27, CYAN)
	_line(c, pos + Vector2(16, 38), pos + Vector2(size.x - 16, 38), 0.24)
	var ranked: Array = game.cells.duplicate()
	ranked.sort_custom(func(a: Dictionary,b: Dictionary)->bool: return a["mass"] > b["mass"])
	var show: Array = []
	var player_found := false
	for i in range(mini(6,ranked.size())):
		show.append({"cell":ranked[i],"rank":i+1})
		if ranked[i]["human"]:
			player_found = true
	if not player_found:
		for i in range(ranked.size()):
			if ranked[i]["human"]:
				show.append({"cell":ranked[i],"rank":i+1})
				break
	for i in range(show.size()):
		var cell: Dictionary = show[i]["cell"]
		var y := pos.y + 82 + i * 43
		if cell["human"]:
			c.draw_rect(Rect2(pos.x + 11, y - 25, size.x - 22, 37), Color(CYAN.r, CYAN.g, CYAN.b, 0.14))
		_tag(c, str(show[i]["rank"]).pad_zeros(2), pos.x + 20, y, GOLD if cell["human"] else MUTED)
		_text(c, str(cell["label"]).to_upper(), Vector2(pos.x+60,y), 19, WHITE if cell["human"] else MUTED, BODY, 112)
		_text(c, str(int(cell["mass"])), Vector2(pos.x + size.x-76,y), 18, CYAN if cell["human"] else WHITE, MONO)


