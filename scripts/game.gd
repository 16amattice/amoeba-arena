extends Node2D
const CellGeometry = preload("res://scripts/cell_geometry.gd")
## Amoeba Arena — a self-contained arcade prototype.
## No external services are required. Every amoeba is drawn procedurally.

const ARENA = Vector2(3600.0, 3600.0)
const FOOD_COUNT = 730
const BOT_COUNT = 19
const GRID_SPACING = 150
const BITE_MARK_SECONDS = 2.5
const CELL_VERTICES = 64
const PICKUP_RADIUS = 14.0
const CROWN_HOLD_SECONDS = 24.0
const LEVEL_BASE_XP = 75
const LEVEL_STEP_XP = 35
const SKINS = [
	{"id":"mint","name":"Mint Jelly","cost":0,"color":Color(0.26,0.94,0.78),"detail":"Classic living cell"},
	{"id":"bubblegum","name":"Bubblegum","cost":75,"color":Color(1.0,0.46,0.71),"detail":"Candy freckles"},
	{"id":"arctic","name":"Arctic Glow","cost":140,"color":Color(0.30,0.77,1.0),"detail":"Icy microbubbles"},
	{"id":"solar","name":"Solar Flare","cost":215,"color":Color(1.0,0.60,0.24),"detail":"Golden sparks"},
	{"id":"rainbow","name":"Rainbow Flux","cost":365,"color":Color(1.0,0.35,0.65),"detail":"Shifting colors"},
	{"id":"galaxy","name":"Galactic","cost":490,"color":Color(0.47,0.30,0.80),"detail":"Starlight speckles"},
	{"id":"gold","name":"Golden Crown","cost":650,"color":Color(0.96,0.78,0.28),"detail":"Royal shimmer"}
]
const CELL_COLORS = [
	Color(0.98, 0.43, 0.56), Color(0.65, 0.55, 1.0),
	Color(0.36, 0.74, 1.0), Color(1.0, 0.70, 0.35),
	Color(0.50, 0.87, 0.47), Color(1.0, 0.46, 0.82),
	Color(0.36, 0.83, 0.83), Color(0.96, 0.83, 0.36)
]
const FOOD_COLORS = [
	Color(0.40, 1.0, 0.75), Color(0.48, 0.80, 1.0),
	Color(1.0, 0.75, 0.47), Color(1.0, 0.58, 0.75),
	Color(0.80, 0.68, 1.0)
]
const BOT_NAMES = [
	"MITO", "NOVA", "SPORE", "ZIGGY", "PLASM", "BLOOP", "KELP",
	"GLIM", "NIB", "CILIA", "MOCHI", "PIP", "WISP", "MOSS",
	"ECHO", "LUMA", "FIZZ", "BUD", "NUCLEO", "WOBBLE", "PICO"
]

var mode := "menu"  # menu, playing, dead
var cells: Array[Dictionary] = []
var food: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var player: Dictionary = {}
var clock := 0.0
var camera_position := ARENA * 0.5
var camera_zoom := 1.0
var touch_index := -1
var touch_origin := Vector2.ZERO
var touch_position := Vector2.ZERO
var mouse_position := Vector2.ZERO
var mouse_aim := false
var best_mass := 0
var survival_time := 0.0
var takedowns := 0
var damage_flash := 0.0
var cruise_direction := Vector2.ZERO
var cruise_power := 0.0
var coins := 0
var level := 1
var experience := 0
var best_survival := 0
var victories := 0
var round_coins := 0
var round_xp := 0
var crown_time := 0.0
var survival_tick := 0.0
var pellet_tick := 0
var bite_progress := 0.0
var save_tick := 0.0
var username := "YOU"
var owned_skins: Array[String] = ["mint"]
var equipped_skin := "mint"
var sound_enabled := true
var vibration_enabled := true
var light_mode := false
var shop_return_mode := "menu"
var shop_message := ""
var sound_player: AudioStreamPlayer
var last_sound_time := -10.0
var name_entry: LineEdit
var start_button: Button
var shop_button: Button
var secondary_button: Button
var back_button: Button
var settings_sound_button: Button
var settings_vibration_button: Button
var settings_theme_button: Button
var shop_buttons: Array[Button] = []
var hud_panel_style: StyleBoxFlat


func _ready() -> void:
	randomize()
	_load_record()
	_load_profile()
	_load_username()
	_reset_arena()
	_setup_menu_controls()
	sound_player = AudioStreamPlayer.new()
	sound_player.name = "ProceduralSFX"
	add_child(sound_player)
	set_process(true)


func _reset_arena() -> void:
	cells.clear()
	food.clear()
	particles.clear()
	clock = 0.0
	survival_time = 0.0
	takedowns = 0
	damage_flash = 0.0
	touch_index = -1
	mouse_aim = false
	cruise_direction = Vector2.ZERO
	cruise_power = 0.0
	crown_time = 0.0
	survival_tick = 0.0
	pellet_tick = 0
	bite_progress = 0.0
	round_coins = 0
	round_xp = 0
	player = _make_cell(ARENA * 0.5, 100.0 + _starting_mass_bonus(), _equipped_color(), username, true)
	cells.append(player)
	for n in range(BOT_COUNT):
		_spawn_bot(n)
	for n in range(FOOD_COUNT):
		food.append(_make_food())
	camera_position = player["pos"]
	camera_zoom = 1.0


func _make_cell(position: Vector2, mass: float, color: Color, label: String, human: bool) -> Dictionary:
	var seed := randf_range(0.0, TAU)
	return {
		"pos": position,
		"vel": Vector2.ZERO,
		"mass": mass,
		"shapes": CellGeometry.initial_shapes(mass, seed),
		"needs_reform": false,
		"reform_delay": 0.0,
		"color": color,
		"label": label,
		"human": human,
		"alive": true,
		"phase": seed,
		"direction": randf_range(0.0, TAU),
		"aim": position,
		"think": randf_range(0.05, 0.55),
		"impact": 0.0,
		"food_count": 0
	}

func _spawn_bot(number: int) -> void:
	var placement := Vector2(randf_range(100.0, ARENA.x - 100.0), randf_range(100.0, ARENA.y - 100.0))
	if placement.distance_to(player["pos"]) < 390.0:
		placement = player["pos"] + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(420.0, 660.0)
		placement = placement.clamp(Vector2(80.0, 80.0), ARENA - Vector2(80.0, 80.0))
	var mass := randf_range(40.0, 210.0)
	if number % 6 == 0:
		mass = randf_range(240.0, 470.0)
	var bot := _make_cell(placement, mass, CELL_COLORS[number % CELL_COLORS.size()], BOT_NAMES[number % BOT_NAMES.size()], false)
	cells.append(bot)


func _skin_definition(id: String) -> Dictionary:
	for skin in SKINS:
		if skin["id"] == id:
			return skin
	return SKINS[0]


func _equipped_color() -> Color:
	return _skin_definition(equipped_skin)["color"]


func _skin_render_color(id: String) -> Color:
	if id == "rainbow":
		return Color.from_hsv(fposmod(clock * 0.035, 1.0), 0.48, 0.95)
	if id == "galaxy":
		return Color.from_hsv(0.75 + 0.012 * sin(clock * 0.7), 0.52, 0.68)
	if id == "gold":
		return Color(0.98, 0.76 + 0.035 * sin(clock * 1.4), 0.32)
	return _skin_definition(id)["color"]


func _pickup_bonus() -> float:
	return minf(32.0, float(maxi(0, level - 1)) * 2.0)


func _food_bonus() -> float:
	return minf(0.24, float(maxi(0, level - 1)) * 0.02)


func _starting_mass_bonus() -> float:
	return minf(35.0, float((maxi(0, level - 1)) / 3) * 5.0)


func _on_shop_button() -> void:
	shop_return_mode = mode
	shop_message = "Choose a look. Owned skins can be equipped for free."
	mode = "shop"
	_layout_menu_controls()


func _on_secondary_button() -> void:
	mode = "settings" if mode == "menu" else "menu"
	_layout_menu_controls()


func _return_from_overlay() -> void:
	mode = shop_return_mode if mode == "shop" else "menu"
	_layout_menu_controls()


func _on_skin_pressed(index: int) -> void:
	var skin: Dictionary = SKINS[index]
	var id: String = skin["id"]
	var price: int = skin["cost"]
	if not owned_skins.has(id):
		if coins < price:
			shop_message = "Need " + str(price - coins) + " more coins for " + str(skin["name"]) + "."
			_play_sfx("deny")
			return
		coins -= price
		owned_skins.append(id)
		shop_message = "Unlocked " + str(skin["name"]) + "!"
		_play_sfx("buy")
		_vibrate(45)
	else:
		shop_message = "Equipped " + str(skin["name"]) + "."
	equipped_skin = id
	if not player.is_empty():
		player["color"] = _equipped_color()
	_save_profile()
	_layout_menu_controls()


func _toggle_sound() -> void:
	sound_enabled = not sound_enabled
	_save_profile()
	if sound_enabled:
		_play_sfx("buy")
	_layout_menu_controls()


func _toggle_vibration() -> void:
	vibration_enabled = not vibration_enabled
	_save_profile()
	if vibration_enabled:
		_vibrate(35)
	_layout_menu_controls()


func _toggle_theme() -> void:
	light_mode = not light_mode
	_save_profile()
	_layout_menu_controls()


func _vibrate(milliseconds: int) -> void:
	if vibration_enabled and OS.has_feature("mobile"):
		Input.vibrate_handheld(milliseconds)


func _play_sfx(kind: String) -> void:
	if not sound_enabled or sound_player == null or clock - last_sound_time < 0.10:
		return
	last_sound_time = clock
	var frequency := 680.0
	var duration := 0.095
	var volume := 0.21
	match kind:
		"bite":
			frequency = 250.0
			duration = 0.075
			volume = 0.14
		"level":
			frequency = 930.0
			duration = 0.19
		"win":
			frequency = 1080.0
			duration = 0.28
		"lose", "deny":
			frequency = 185.0
			duration = 0.20
		"buy":
			frequency = 830.0
			duration = 0.15
	var hz := 22050
	var samples := int(float(hz) * duration)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / float(hz)
		var envelope := pow(maxf(0.0, 1.0 - t / duration), 2.0)
		var note := sin(TAU * frequency * t) + 0.18 * sin(TAU * frequency * 2.02 * t)
		var sample := int(clampf(note * envelope * volume, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, sample)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = hz
	wav.stereo = false
	wav.data = data
	sound_player.stream = wav
	sound_player.play()


func _make_food() -> Dictionary:
	return {
		"pos": Vector2(randf_range(25.0, ARENA.x - 25.0), randf_range(25.0, ARENA.y - 25.0)),
		"mass": randf_range(2.0, 4.5),
		"radius": randf_range(3.5, 5.8),
		"color": FOOD_COLORS.pick_random(),
		"phase": randf_range(0.0, TAU)
	}


func _start_game() -> void:
	if name_entry != null:
		username = _sanitize_username(name_entry.text)
	_save_username()
	_reset_arena()
	mode = "playing"
	if name_entry != null:
		name_entry.visible = false
		name_entry.release_focus()
	if start_button != null:
		start_button.visible = false
	_layout_menu_controls()
	DisplayServer.virtual_keyboard_hide()


func _sanitize_username(value: String) -> String:
	var clean := value.strip_edges()
	var valid := ""
	for i in range(clean.length()):
		var code := clean.unicode_at(i)
		if code >= 32 and code != 127:
			valid += clean.substr(i, 1)
	valid = valid.substr(0, 14).strip_edges()
	return valid if not valid.is_empty() else "YOU"


func _setup_menu_controls() -> void:
	name_entry = LineEdit.new()
	name_entry.name = "UsernameEntry"
	name_entry.placeholder_text = "Your cell name"
	name_entry.max_length = 14
	name_entry.text = username
	name_entry.add_theme_font_size_override("font_size", 29)
	name_entry.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_entry.text_submitted.connect(_on_name_submitted)
	add_child(name_entry)

	start_button = Button.new()
	start_button.text = "ENTER THE ARENA"
	start_button.add_theme_font_size_override("font_size", 28)
	start_button.pressed.connect(_start_game)
	add_child(start_button)

	shop_button = Button.new()
	shop_button.text = "SKINS"
	shop_button.add_theme_font_size_override("font_size", 24)
	shop_button.pressed.connect(_on_shop_button)
	add_child(shop_button)

	secondary_button = Button.new()
	secondary_button.text = "SETTINGS"
	secondary_button.add_theme_font_size_override("font_size", 24)
	secondary_button.pressed.connect(_on_secondary_button)
	add_child(secondary_button)

	back_button = Button.new()
	back_button.text = "BACK"
	back_button.add_theme_font_size_override("font_size", 24)
	back_button.pressed.connect(_return_from_overlay)
	add_child(back_button)

	settings_sound_button = Button.new()
	settings_sound_button.pressed.connect(_toggle_sound)
	settings_sound_button.add_theme_font_size_override("font_size", 23)
	add_child(settings_sound_button)

	settings_vibration_button = Button.new()
	settings_vibration_button.pressed.connect(_toggle_vibration)
	settings_vibration_button.add_theme_font_size_override("font_size", 23)
	add_child(settings_vibration_button)

	settings_theme_button = Button.new()
	settings_theme_button.pressed.connect(_toggle_theme)
	settings_theme_button.add_theme_font_size_override("font_size", 23)
	add_child(settings_theme_button)

	for i in range(SKINS.size()):
		var option := Button.new()
		option.name = "ShopSkin_" + str(i)
		option.add_theme_font_size_override("font_size", 22)
		option.pressed.connect(_on_skin_pressed.bind(i))
		add_child(option)
		shop_buttons.append(option)
	_layout_menu_controls()


func _on_name_submitted(_submitted: String) -> void:
	if mode == "menu":
		_start_game()


func _menu_geometry(screen: Vector2) -> Rect2:
	var width := minf(630.0, screen.x - 32.0)
	var height := 570.0
	var top := maxf(30.0, (screen.y - height) * 0.34)
	return Rect2((screen.x - width) * 0.5, top, width, height)


func _layout_menu_controls() -> void:
	if name_entry == null or start_button == null:
		return
	var screen := get_viewport_rect().size
	var bounds := _menu_geometry(screen)
	var margin := minf(48.0, bounds.size.x * 0.07)
	var normal := mode == "menu" or mode == "dead" or mode == "won"
	var is_shop := mode == "shop"
	var is_settings := mode == "settings"
	name_entry.position = bounds.position + Vector2(margin, 257.0)
	name_entry.size = Vector2(bounds.size.x - margin * 2.0, 58.0)
	name_entry.visible = mode == "menu"

	start_button.position = bounds.position + Vector2(margin, 338.0)
	start_button.size = Vector2(bounds.size.x - margin * 2.0, 64.0)
	start_button.visible = normal
	start_button.text = "ENTER THE ARENA" if mode == "menu" else "PLAY AGAIN"

	shop_button.position = bounds.position + Vector2(margin, 426.0)
	shop_button.size = Vector2((bounds.size.x - margin * 2.0 - 16.0) * 0.5, 61.0)
	shop_button.visible = normal
	secondary_button.position = shop_button.position + Vector2(shop_button.size.x + 16.0, 0.0)
	secondary_button.size = shop_button.size
	secondary_button.text = "SETTINGS" if mode == "menu" else "HOME"
	secondary_button.visible = normal

	var panel := _options_geometry(screen)
	back_button.position = panel.position + Vector2(24.0, panel.size.y - 86.0)
	back_button.size = Vector2(panel.size.x - 48.0, 60.0)
	back_button.visible = is_shop or is_settings

	for i in range(shop_buttons.size()):
		var option: Dictionary = SKINS[i]
		var skin_control: Button = shop_buttons[i]
		var id: String = option["id"]
		if id == equipped_skin:
			skin_control.text = "EQUIPPED"
		elif owned_skins.has(id):
			skin_control.text = "EQUIP"
		else:
			skin_control.text = str(option["cost"]) + " COINS"
		skin_control.position = panel.position + Vector2(panel.size.x - 196.0, 155.0 + float(i) * 79.0)
		skin_control.size = Vector2(166.0, 58.0)
		skin_control.visible = is_shop
		skin_control.disabled = id == equipped_skin

	var setting_buttons := [settings_sound_button, settings_vibration_button, settings_theme_button]
	var labels := [
		"SOUND EFFECTS     " + ("ON" if sound_enabled else "OFF"),
		"VIBRATION              " + ("ON" if vibration_enabled else "OFF"),
		"APPEARANCE          " + ("LIGHT" if light_mode else "DARK")
	]
	for i in range(setting_buttons.size()):
		var item: Button = setting_buttons[i]
		item.text = labels[i]
		item.position = panel.position + Vector2(43.0, 198.0 + float(i) * 106.0)
		item.size = Vector2(panel.size.x - 86.0, 72.0)
		item.visible = is_settings


func _options_geometry(screen: Vector2) -> Rect2:
	var width := minf(640.0, screen.x - 40.0)
	var height := minf(885.0, screen.y - 64.0)
	return Rect2((screen.x - width) * 0.5, (screen.y - height) * 0.5, width, height)


func _input(event: InputEvent) -> void:
	if mode != "playing":
		return

	# Android sends both touch and synthetic mouse events. Touch is authoritative
	# on phones; a leftover mouse position must never move the cell after release.
	if event is InputEventScreenTouch:
		if event.pressed and touch_index == -1:
			touch_index = event.index
			touch_origin = event.position
			touch_position = event.position
			mouse_aim = false
		elif not event.pressed and event.index == touch_index:
			_release_touch(event.index)
	elif event is InputEventScreenDrag and event.index == touch_index:
		touch_position = event.position
	elif event is InputEventMouseButton and not OS.has_feature("mobile"):
		if event.button_index == MOUSE_BUTTON_LEFT:
			mouse_aim = event.pressed
			mouse_position = event.position
	elif event is InputEventMouseMotion and mouse_aim and not OS.has_feature("mobile"):
		mouse_position = event.position


func _release_touch(index: int) -> void:
	if index == touch_index:
		touch_index = -1
		touch_origin = Vector2.ZERO
		touch_position = Vector2.ZERO
		# Keep the last steering direction and throttle after release.
		mouse_aim = false


func _process(delta: float) -> void:
	delta = minf(delta, 0.06)
	clock += delta
	damage_flash = maxf(damage_flash - delta * 2.2, 0.0)
	if mode == "playing":
		survival_time += delta
		_gain_survival_rewards(delta)
		_think_for_bots(delta)
		_move_cells(delta)
		for cell in cells:
			CellGeometry.relax(cell, delta)
		_consume_food()
		_resolve_bites(delta)
		_cleanup_dead()
		if mode == "playing":
			_check_victory(delta)
		_update_particles(delta)
		if player["alive"]:
			camera_position = camera_position.lerp(player["pos"], minf(1.0, delta * 5.2))
			var ideal_zoom := clampf(1.04 - (sqrt(player["mass"]) - 10.0) * 0.020, 0.66, 1.12)
			camera_zoom = lerpf(camera_zoom, ideal_zoom, minf(1.0, delta * 2.0))
			if int(player["mass"]) > best_mass:
				best_mass = int(player["mass"])
	else:
		for cell in cells:
			cell["phase"] += delta * 0.8
	if mode != "playing":
		_layout_menu_controls()
	queue_redraw()


func _move_input() -> Vector2:
	# A finger sets a cruise vector; releasing it keeps both direction AND
	# throttle. Drag again to steer. No abrupt release-to-zero behavior.
	var axis := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		axis.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		axis.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		axis.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		axis.y += 1.0
	if axis.length_squared() > 0.0:
		cruise_direction = axis.normalized()
		cruise_power = 1.0
	if touch_index >= 0:
		var drag := touch_position - touch_origin
		if drag.length() > 11.0:
			cruise_direction = drag.normalized()
			cruise_power = clampf(drag.length() / 80.0, 0.27, 1.0)
	elif mouse_aim:
		var offset := mouse_position - get_viewport_rect().size * 0.5
		if offset.length() > 28.0:
			cruise_direction = offset.normalized()
			cruise_power = clampf(offset.length() / 120.0, 0.30, 1.0)
	return cruise_direction * cruise_power


func _cell_radius(cell: Dictionary) -> float:
	return maxf(5.0, sqrt(maxf(0.0, cell["mass"])) * 4.0)


func _cell_speed(cell: Dictionary) -> float:
	# Core trade-off: losing mass makes you quicker, without a speed boost button.
	return clampf(470.0 * pow(100.0 / maxf(2.0, cell["mass"]), 0.66), 86.0, 600.0)


func _think_for_bots(delta: float) -> void:
	for bot in cells:
		if bot["human"] or not bot["alive"]:
			continue
		bot["think"] -= delta
		if bot["think"] > 0.0:
			continue
		bot["think"] = randf_range(0.22, 0.48)
		var bot_pos: Vector2 = bot["pos"]
		var threat: Dictionary = {}
		var prey: Dictionary = {}
		var threat_distance := 470.0
		var prey_distance := 335.0
		for other in cells:
			if other == bot or not other["alive"]:
				continue
			var distance: float = bot_pos.distance_to(other["pos"])
			if other["mass"] > bot["mass"] * 1.16 and distance < threat_distance:
				threat = other
				threat_distance = distance
			elif bot["mass"] > other["mass"] * 1.20 and distance < prey_distance:
				prey = other
				prey_distance = distance
		if not threat.is_empty():
			var escape: Vector2 = (bot_pos - threat["pos"]).normalized()
			bot["aim"] = bot_pos + escape * 530.0
		elif not prey.is_empty():
			bot["aim"] = prey["pos"]
		else:
			var best_distance := 460.0 * 460.0
			var closest := Vector2.ZERO
			for morsel in food:
				var distance_sq: float = bot_pos.distance_squared_to(morsel["pos"])
				if distance_sq < best_distance:
					closest = morsel["pos"]
					best_distance = distance_sq
			if best_distance < 460.0 * 460.0:
				bot["aim"] = closest
			elif bot_pos.distance_to(bot["aim"]) < 95.0:
				bot["aim"] = bot_pos + Vector2.RIGHT.rotated(randf() * TAU) * 400.0


func _move_cells(delta: float) -> void:
	var human_input := _move_input()
	for cell in cells:
		if not cell["alive"]:
			continue
		var direction: Vector2
		if cell["human"]:
			direction = human_input
		else:
			var to_aim: Vector2 = cell["aim"] - cell["pos"]
			direction = to_aim.normalized() if to_aim.length() > 12.0 else Vector2.ZERO
		var desired_velocity: Vector2 = direction * _cell_speed(cell)
		var responsiveness := 9.0 if cell["human"] else 3.7
		cell["vel"] = cell["vel"].lerp(desired_velocity, minf(1.0, delta * responsiveness))
		# Reserve most of the natural body radius for the membrane.
		# This avoids the severe clipping/squashing when the center reached 8px.
		# A gentle area-preserving warp makes the rest touch the wall.
		var next_pos: Vector2 = cell["pos"] + cell["vel"] * delta
		var wall_padding: float = CellGeometry.minimum_center(float(cell["mass"]))
		cell["pos"] = next_pos.clamp(Vector2.ONE * wall_padding, ARENA - Vector2.ONE * wall_padding)
		if cell["vel"].length() > 8.0:
			cell["direction"] = lerp_angle(cell["direction"], cell["vel"].angle(), minf(1.0, delta * 4.0))
		cell["phase"] += delta * (1.65 + cell["vel"].length() * 0.005)
		cell["impact"] = maxf(0.0, cell["impact"] - delta * 4.0)


func _consume_food() -> void:
	for food_index in range(food.size() - 1, -1, -1):
		var morsel := food[food_index]
		for cell in cells:
			if not cell["alive"]:
				continue
			var bonus := _pickup_bonus() if cell["human"] else 0.0
			var radius: float = _cell_radius(cell) * 0.83 + PICKUP_RADIUS + bonus + float(morsel["radius"])
			if cell["pos"].distance_squared_to(morsel["pos"]) < radius * radius:
				var nutrients := float(morsel["mass"]) * (1.0 + _food_bonus() if cell["human"] else 1.0)
				CellGeometry.grow(cell, nutrients)
				if cell["human"]:
					_play_sfx("pellet")
				if cell["human"]:
					cell["food_count"] += 1
					pellet_tick += 1
					_award(1, 0)
					if pellet_tick >= 12:
						pellet_tick = 0
						_award(4, 2)
				food.remove_at(food_index)
				break
	while food.size() < FOOD_COUNT:
		food.append(_make_food())


func _resolve_bites(_delta: float) -> void:
	# Each overlap removes real polygon area from the smaller cell. There is
	# no DPS or hitpoint interpolation: what is covered is what disappears.
	for i in range(cells.size()):
		var first := cells[i]
		if not first["alive"]:
			continue
		for j in range(i + 1, cells.size()):
			var second := cells[j]
			if not second["alive"]:
				continue
			var eater: Dictionary
			var victim: Dictionary
			if first["mass"] >= second["mass"] * 1.12:
				eater = first
				victim = second
			elif second["mass"] >= first["mass"] * 1.12:
				eater = second
				victim = first
			else:
				continue
			# Broad-phase culling keeps expensive polygon operations sparse.
			var reach := _cell_radius(eater) + _cell_radius(victim) + 16.0
			if eater["pos"].distance_squared_to(victim["pos"]) >= reach * reach:
				continue
			var result: Dictionary = CellGeometry.consume(eater, victim, ARENA)
			var taken: float = result["mass"]
			if taken <= 0.0:
				continue
			CellGeometry.grow(eater, taken * 0.88)
			victim["impact"] = 1.0
			eater["impact"] = maxf(float(eater["impact"]), 0.45)
			if eater["human"] or victim["human"]:
				_play_sfx("bite")
			var position: Vector2 = result["position"]
			_spawn_bite_droplets(position, victim["color"])
			if victim["human"]:
				damage_flash = minf(0.6, damage_flash + 0.18)
			if eater["human"]:
				bite_progress += taken
				while bite_progress >= 5.0:
					bite_progress -= 5.0
					_award(3, 0)
			if result["dead"]:
				_burst_food(position, victim["color"])
				if eater["human"]:
					takedowns += 1
					_award(32, 16)
					_vibrate(55)


func _spawn_bite_droplets(position: Vector2, color: Color) -> void:
	for n in range(6):
		particles.append({
			"pos": position,
			"vel": Vector2.RIGHT.rotated(randf() * TAU) * randf_range(32.0, 120.0),
			"life": randf_range(0.25, 0.56),
			"max_life": 0.56,
			"radius": randf_range(2.0, 5.0),
			"color": color
		})


func _burst_food(position: Vector2, color: Color) -> void:
	for n in range(9):
		particles.append({
			"pos": position,
			"vel": Vector2.RIGHT.rotated(randf() * TAU) * randf_range(40.0, 185.0),
			"life": randf_range(0.50, 1.10),
			"max_life": 1.10,
			"radius": randf_range(3.0, 8.0),
			"color": color
		})


func _update_particles(delta: float) -> void:
	for index in range(particles.size() - 1, -1, -1):
		var particle := particles[index]
		particle["pos"] += particle["vel"] * delta
		particle["vel"] *= maxf(0.0, 1.0 - delta * 2.5)
		particle["life"] -= delta
		if particle["life"] <= 0.0:
			particles.remove_at(index)


func _cleanup_dead() -> void:
	for index in range(cells.size() - 1, -1, -1):
		if cells[index]["alive"]:
			continue
		if cells[index]["human"]:
			_end_round(false)
		else:
			cells.remove_at(index)
	if mode != "playing":
		return
	var living_bots := cells.size() - 1
	while living_bots < BOT_COUNT:
		_spawn_bot(randi_range(0, BOT_NAMES.size() - 1))
		living_bots += 1


func _visible(position: Vector2, padding: float) -> bool:
	var half_view := get_viewport_rect().size * 0.5 / camera_zoom
	return absf(position.x - camera_position.x) <= half_view.x + padding and absf(position.y - camera_position.y) <= half_view.y + padding


func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.87, 0.94, 0.95) if light_mode else Color(0.034, 0.069, 0.091))
	var camera_offset := viewport_size * 0.5 - camera_position * camera_zoom
	draw_set_transform(camera_offset, 0.0, Vector2.ONE * camera_zoom)
	_draw_arena()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_hud(viewport_size)
	if mode != "playing":
		_draw_overlay(viewport_size)
	if damage_flash > 0.0 and mode == "playing":
		draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(1.0, 0.25, 0.35, damage_flash * 0.18))


func _draw_arena() -> void:
	draw_rect(Rect2(Vector2.ZERO, ARENA), Color(0.91, 0.97, 0.97) if light_mode else Color(0.047, 0.105, 0.126))
	for x in range(0, int(ARENA.x) + 1, GRID_SPACING):
		draw_line(Vector2(x, 0), Vector2(x, ARENA.y), Color(0.26, 0.50, 0.53, 0.20) if light_mode else Color(0.22, 0.40, 0.44, 0.13), 1.5)
	for y in range(0, int(ARENA.y) + 1, GRID_SPACING):
		draw_line(Vector2(0, y), Vector2(ARENA.x, y), Color(0.26, 0.50, 0.53, 0.20) if light_mode else Color(0.22, 0.40, 0.44, 0.13), 1.5)
	for morsel in food:
		if not _visible(morsel["pos"], 10.0):
			continue
		var pulse := 1.0 + 0.12 * sin(clock * 2.5 + morsel["phase"])
		var p: Vector2 = morsel["pos"]
		var r: float = morsel["radius"] * pulse
		var color: Color = morsel["color"]
		draw_circle(p, r * 2.0, Color(color.r, color.g, color.b, 0.10))
		draw_circle(p, r, color)
		draw_circle(p - Vector2(r * 0.28, r * 0.28), r * 0.35, Color(1, 1, 1, 0.78))
	var sorted_cells := cells.duplicate()
	sorted_cells.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["mass"] < b["mass"])
	for cell in sorted_cells:
		if cell["alive"] and _visible(cell["pos"], _cell_radius(cell) + 20.0):
			_draw_cell(cell)
	# Draw arena outline LAST so the wall always stays visually crisp.
	draw_rect(Rect2(Vector2.ZERO, ARENA), Color(0.21, 0.84, 0.80, 0.85), false, 5.0)
	for particle in particles:
		var shade: Color = particle["color"]
		shade.a = clampf(particle["life"] / particle["max_life"], 0.0, 1.0)
		draw_circle(particle["pos"], particle["radius"] * shade.a, shade)


func _draw_cell(cell: Dictionary) -> void:
	var center: Vector2 = cell["pos"]
	var radius := _cell_radius(cell)
	var skin := equipped_skin if cell["human"] else "mint"
	var tint: Color = _skin_render_color(skin) if cell["human"] else cell["color"]
	var pieces: Array[PackedVector2Array] = CellGeometry.world_shapes(cell, ARENA)
	var largest_piece := PackedVector2Array()
	var largest_area := 0.0
	for polygon in pieces:
		if polygon.size() < 3:
			continue
		var area: float = CellGeometry.polygon_area(polygon)
		if area <= 2.0:
			continue
		# One solid fill, two crisp contour lines: visible membrane rim without
		# layered translucent polygons or color glitches at the arena wall.
		draw_colored_polygon(polygon, tint)
		if cell["human"] and not bool(cell.get("needs_reform", false)):
			_draw_skin_pattern(polygon, center, radius, skin)
		var closed := polygon.duplicate()
		closed.append(polygon[0])
		draw_polyline(closed, Color(0.016, 0.20, 0.22, 0.92), 5.0, true)
		draw_polyline(closed, tint.lightened(0.42), 2.4, true)
		if area > largest_area:
			largest_area = area
			largest_piece = polygon
	if largest_area > 150.0 and not bool(cell.get("needs_reform", false)):
		if Geometry2D.is_point_in_polygon(center, largest_piece):
			draw_circle(center, minf(radius * 0.18, 19.0), Color(0.035, 0.29, 0.35, 0.20))
			draw_circle(center + Vector2(-2.5, -2.5), minf(radius * 0.09, 9.0), Color(1, 1, 1, 0.18))
	if radius < 12.0:
		return
	var font := ThemeDB.fallback_font
	draw_string(font, center + Vector2(-radius, 3.0), cell["label"], HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, clampi(int(radius * 0.34), 10, 18), Color(0.015, 0.14, 0.16, 0.93))
	draw_string(font, center + Vector2(-radius, 20.0), str(int(ceil(cell["mass"]))), HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 12, Color(0.02, 0.16, 0.20, 0.78))


func _draw_skin_pattern(polygon: PackedVector2Array, center: Vector2, radius: float, skin: String) -> void:
	# Minimal cellular details. All pigment stays *inside* the edible membrane;
	# no independently rendered square meshes, particles or full-screen wakes.
	if skin == "mint":
		return
	for i in range(8):
		var angle := float(i) * 2.39996 + 0.25
		var orbit := radius * (0.19 + 0.064 * float(i % 5))
		var point := center + Vector2.from_angle(angle + 0.025 * sin(clock * 0.8 + float(i))) * orbit
		if not Geometry2D.is_point_in_polygon(point, polygon):
			continue
		match skin:
			"bubblegum":
				draw_circle(point, 2.8 + float(i % 2), Color(1.0, 0.92, 0.98, 0.50))
				if i % 3 == 0:
					draw_arc(point, 5.0, 0.0, TAU, 14, Color(1.0, 0.96, 0.98, 0.38), 1.0, true)
			"arctic":
				draw_circle(point, 2.2, Color(0.92, 1.0, 1.0, 0.48))
				if i % 2 == 0:
					draw_line(point + Vector2(-3, 0), point + Vector2(3, 0), Color(0.90, 1.0, 1.0, 0.45), 1.2, true)
			"solar":
				var glow := 0.50 + 0.20 * sin(clock * 1.3 + float(i))
				draw_circle(point, 2.3 + glow, Color(1.0, 0.97, 0.72, glow))
			"rainbow":
				var shade := Color.from_hsv(fposmod(float(i) / 8.0 + clock * 0.035, 1.0), 0.53, 1.0, 0.76)
				draw_circle(point, 3.4, shade)
			"galaxy":
				var twinkle := 0.44 + 0.25 * sin(clock * 1.6 + float(i) * 2.0)
				draw_circle(point, 1.8 + 0.8 * twinkle, Color(0.93, 0.93, 1.0, twinkle))
			"gold":
				draw_circle(point, 2.0 + 0.6 * sin(clock * 1.2 + float(i)), Color(1.0, 0.96, 0.75, 0.56))


func _soft_hud_panel(rect: Rect2) -> void:
	# A restrained translucent panel, deliberately not a full-screen effect.
	# Reuse one StyleBox to avoid allocations every animation frame.
	if hud_panel_style == null:
		hud_panel_style = StyleBoxFlat.new()
		hud_panel_style.bg_color = Color(0.018, 0.061, 0.077, 0.76)
		hud_panel_style.border_color = Color(0.58, 0.88, 0.84, 0.24)
		hud_panel_style.set_border_width_all(1)
		hud_panel_style.set_corner_radius_all(10)
		hud_panel_style.shadow_color = Color(0.0, 0.02, 0.03, 0.18)
		hud_panel_style.shadow_size = 5
	draw_style_box(hud_panel_style, rect)




func _draw_hud(viewport_size: Vector2) -> void:
	var font := ThemeDB.fallback_font
	_soft_hud_panel(Rect2(18, 18, 330, 164))
	draw_string(font, Vector2(32, 50), "AMOEBA  ARENA", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color(0.40, 1.0, 0.78))
	draw_string(font, Vector2(32, 82), "MASS " + str(int(ceil(player["mass"]))) + "    KOs " + str(takedowns), HORIZONTAL_ALIGNMENT_LEFT, 310, 21, Color.WHITE)
	draw_string(font, Vector2(32, 109), "TIME " + str(int(survival_time)) + "s    COINS " + str(coins), HORIZONTAL_ALIGNMENT_LEFT, 310, 18, Color(1.0, 0.85, 0.51))
	draw_string(font, Vector2(32, 135), "LEVEL " + str(level) + "     XP " + str(experience) + "/" + str(_experience_needed()), HORIZONTAL_ALIGNMENT_LEFT, 310, 17, Color(0.77, 0.89, 1.0))
	var pct := clampf(float(experience) / float(_experience_needed()), 0.0, 1.0)
	draw_rect(Rect2(32, 151, 296, 10), Color(0.07, 0.21, 0.27))
	draw_rect(Rect2(32, 151, 296 * pct, 10), Color(0.47, 0.84, 1.0))
	var map_rect := Rect2(viewport_size.x - 181.0, 20.0, 158.0, 158.0)
	_soft_hud_panel(map_rect)
	draw_rect(map_rect.grow(-8), Color(0.12, 0.27, 0.30, 0.47), false, 1.5)
	for cell in cells:
		if not cell["alive"]:
			continue
		var dot: Vector2 = map_rect.position + Vector2(8, 8) + (cell["pos"] / ARENA) * Vector2(142, 142)
		draw_circle(dot, 4.5 if cell["human"] else 2.5, cell["color"])
	_draw_leaderboard(viewport_size)
	if mode == "playing":
		_soft_hud_panel(Rect2(18, viewport_size.y - 112.0, 405, 68))
		if crown_time > 0.0:
			draw_string(font, Vector2(31, viewport_size.y - 87.0), "CELL CROWN  " + str(int(ceil(CROWN_HOLD_SECONDS - crown_time))) + "s TO WIN", HORIZONTAL_ALIGNMENT_LEFT, 378, 18, Color(1, 0.86, 0.44))
			draw_rect(Rect2(32, viewport_size.y - 75.0, 364, 10), Color(0.12, 0.26, 0.27))
			draw_rect(Rect2(32, viewport_size.y - 75.0, 364 * minf(1.0, crown_time / CROWN_HOLD_SECONDS), 10), Color(1.0, 0.79, 0.30))
		else:
			draw_string(font, Vector2(31, viewport_size.y - 88.0), "CELL CROWN: STAY #1 FOR 24s", HORIZONTAL_ALIGNMENT_LEFT, 380, 17, Color(0.81, 0.90, 0.84))
		draw_string(font, Vector2(31, viewport_size.y - 56.0), "LIFT TO CRUISE  •  DRAG TO STEER", HORIZONTAL_ALIGNMENT_LEFT, 390, 16, Color(0.62, 0.82, 0.85))
	if touch_index >= 0 and mode == "playing":
		draw_circle(touch_origin, 68.0, Color(0.55, 0.92, 0.91, 0.09))
		draw_arc(touch_origin, 68.0, 0, TAU, 50, Color(0.55, 0.92, 0.91, 0.46), 3.0, true)
		var stick := touch_origin + (touch_position - touch_origin).limit_length(68.0)
		draw_circle(stick, 26.0, Color(0.38, 1.0, 0.82, 0.72))
	if mode == "playing" and player["mass"] < 33.0:
		draw_string(font, Vector2(150, 212), "TINY = FAST  •  ESCAPE AND REGROW!", HORIZONTAL_ALIGNMENT_CENTER, 420, 17, Color(1.0, 0.83, 0.57))


func _draw_leaderboard(viewport_size: Vector2) -> void:
	var ranked := cells.duplicate()
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["mass"] > b["mass"])
	var left := viewport_size.x - 244.0
	var top := 194.0
	var width := 222.0
	var row_height := 29.0
	var rows: Array[Dictionary] = []
	var user_in_top := false
	for i in range(mini(7, ranked.size())):
		rows.append({"cell": ranked[i], "rank": i + 1})
		if ranked[i]["human"]:
			user_in_top = true
	if not user_in_top:
		for i in range(ranked.size()):
			if ranked[i]["human"]:
				rows.append({"cell": ranked[i], "rank": i + 1})
				break
	_soft_hud_panel(Rect2(left, top, width, 48.0 + rows.size() * row_height + 7.0))
	draw_string(ThemeDB.fallback_font, Vector2(left + 12, top + 29), "LEADERBOARD", HORIZONTAL_ALIGNMENT_LEFT, width - 16.0, 21, Color(0.46, 1.0, 0.81))
	for i in range(rows.size()):
		var row: Dictionary = rows[i]
		var cell: Dictionary = row["cell"]
		var y := top + 54.0 + i * row_height
		if cell["human"]:
			draw_rect(Rect2(left + 5, y - 20.0, width - 10.0, row_height - 1.0), Color(0.21, 0.68, 0.53, 0.37))
		draw_circle(Vector2(left + 15, y - 7.0), 5.0, cell["color"])
		var entry := str(row["rank"]) + ". " + str(cell["label"])
		draw_string(ThemeDB.fallback_font, Vector2(left + 28, y), entry, HORIZONTAL_ALIGNMENT_LEFT, 133.0, 17, Color.WHITE if cell["human"] else Color(0.81, 0.93, 0.94))
		draw_string(ThemeDB.fallback_font, Vector2(left + width - 53, y), str(int(cell["mass"])), HORIZONTAL_ALIGNMENT_RIGHT, 42.0, 17, Color(0.80, 1.0, 0.91))


func _draw_overlay(viewport_size: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.01, 0.035, 0.052, 0.80))
	if mode == "shop":
		_draw_shop_overlay(viewport_size)
		return
	if mode == "settings":
		_draw_settings_overlay(viewport_size)
		return
	var bounds := _menu_geometry(viewport_size)
	draw_rect(bounds, Color(0.045, 0.13, 0.16, 0.97))
	draw_rect(bounds, Color(0.36, 0.95, 0.78, 0.58), false, 2.0)
	var top := bounds.position.y
	if mode == "menu":
		_center_text("AMOEBA ARENA", top + 57.0, 42, Color(0.39, 1.0, 0.79), viewport_size)
		_center_text("CELL CROWN", top + 95.0, 19, Color(1.0, 0.83, 0.43), viewport_size)
		_center_text("Engulf smaller cells. Survive. Evolve.", top + 145.0, 20, Color.WHITE, viewport_size)
		_center_text("Hold first place for 24s to win!", top + 179.0, 20, Color(0.90, 0.78, 0.51), viewport_size)
		_center_text("LVL " + str(level) + "    COINS " + str(coins) + "    WINS " + str(victories), top + 215.0, 18, Color(0.71, 0.89, 0.98), viewport_size)
		_center_text("YOUR AMOEBA NAME", top + 246.0, 18, Color(0.73, 0.89, 0.90), viewport_size)
	else:
		if mode == "won":
			_center_text("CELL CROWN CLAIMED!", top + 68.0, 36, Color(1.0, 0.85, 0.40), viewport_size)
			_center_text(username + " ruled the arena", top + 128.0, 24, Color.WHITE, viewport_size)
			_center_text("WIN BONUS  +150 XP   +100 COINS", top + 177.0, 21, Color(1.0, 0.91, 0.54), viewport_size)
		else:
			_center_text("YOU WERE CONSUMED", top + 75.0, 36, Color(1.0, 0.51, 0.59), viewport_size)
			_center_text(username + " survived " + str(int(survival_time)) + " seconds", top + 132.0, 23, Color.WHITE, viewport_size)
		_center_text("ROUND TOTAL  +" + str(round_xp) + " XP   +" + str(round_coins) + " COINS", top + 221.0, 20, Color(1.0, 0.87, 0.56), viewport_size)
		_center_text("LEVEL " + str(level) + "    COINS " + str(coins), top + 265.0, 21, Color(0.77, 0.94, 0.99), viewport_size)
	_center_text("LEVEL PERKS  •  ALWAYS ACTIVE", top + 512.0, 17, Color(0.40, 1.0, 0.83), viewport_size)
	var bonus_line := "Magnet +" + str(int(_pickup_bonus())) + "   Food +" + str(int(_food_bonus() * 100.0)) + "%   Start +" + str(int(_starting_mass_bonus()))
	_center_text(bonus_line, top + 540.0, 17, Color(0.81, 0.95, 0.94), viewport_size)


func _draw_shop_overlay(screen: Vector2) -> void:
	var panel := _options_geometry(screen)
	draw_rect(panel, Color(0.042, 0.11, 0.15, 0.98))
	draw_rect(panel, Color(0.36, 0.93, 0.78, 0.55), false, 2.0)
	var left := panel.position.x
	var top := panel.position.y
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(left + 28.0, top + 54.0), "CELL SKIN LAB", HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 56.0, 39, Color(0.44, 1.0, 0.81))
	draw_string(font, Vector2(left + 29.0, top + 94.0), "WALLET  " + str(coins) + " COINS", HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 58.0, 24, Color(1.0, 0.84, 0.49))
	draw_string(font, Vector2(left + 29.0, top + 124.0), "Cosmetics only — all skins have equal power.", HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 58.0, 17, Color(0.77, 0.91, 0.94))
	for index in range(SKINS.size()):
		var skin: Dictionary = SKINS[index]
		var y := top + 151.0 + float(index) * 79.0
		draw_rect(Rect2(left + 20.0, y, panel.size.x - 40.0, 68.0), Color(0.10, 0.23, 0.28, 0.83))
		var color: Color = _skin_render_color(str(skin["id"]))
		var center := Vector2(left + 55.0, y + 33.0)
		draw_circle(center, 24.0, color)
		draw_arc(center, 24.0, 0.0, TAU, 32, color.lightened(0.38), 3.4, true)
		if skin["id"] == "rainbow":
			for dot in range(6):
				var angle := float(dot) * TAU / 6.0
				draw_circle(center + Vector2.from_angle(angle) * 13.0, 3.4, Color.from_hsv(float(dot) / 6.0 + fposmod(clock * 0.07, 1.0), 0.88, 1.0))
		elif skin["id"] == "galaxy":
			for dot in range(5):
				draw_circle(center + Vector2.from_angle(float(dot) * 2.399) * 11.0, 1.9, Color(1, 1, 1, 0.9))
		elif skin["id"] == "gold":
			draw_circle(center, 7.0, Color(1, 1, 0.74, 0.80))
		draw_string(font, Vector2(left + 96.0, y + 28.0), str(skin["name"]), HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 306.0, 21, Color.WHITE)
		draw_string(font, Vector2(left + 96.0, y + 53.0), str(skin["detail"]), HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 306.0, 15, Color(0.73, 0.87, 0.90))
	draw_string(font, Vector2(left + 26.0, top + 746.0), shop_message, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x - 52.0, 18, Color(1.0, 0.86, 0.51))


func _draw_settings_overlay(screen: Vector2) -> void:
	var panel := _options_geometry(screen)
	draw_rect(panel, Color(0.042, 0.11, 0.15, 0.98))
	draw_rect(panel, Color(0.36, 0.93, 0.78, 0.55), false, 2.0)
	var x := panel.position.x
	var top := panel.position.y
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(x + 31.0, top + 65.0), "SETTINGS", HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 62.0, 44, Color(0.44, 1.0, 0.81))
	draw_string(font, Vector2(x + 31.0, top + 119.0), "Your preferences save automatically.", HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 62.0, 21, Color(0.80, 0.92, 0.94))
	draw_string(font, Vector2(x + 35.0, top + 575.0), "Audio is generated locally — no files or downloads.", HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 70.0, 17, Color(0.79, 0.89, 0.91))
	draw_string(font, Vector2(x + 35.0, top + 611.0), "Light mode changes the arena background.", HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 70.0, 17, Color(0.79, 0.89, 0.91))
	draw_string(font, Vector2(x + 35.0, top + 647.0), "Vibration works on supported Android devices.", HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 70.0, 17, Color(0.79, 0.89, 0.91))


func _center_text(text_value: String, y: float, size: int, tint: Color, viewport_size: Vector2) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(0, y), text_value, HORIZONTAL_ALIGNMENT_CENTER, viewport_size.x, size, tint)


func _load_record() -> void:
	if FileAccess.file_exists("user://amoeba_record.dat"):
		var file := FileAccess.open("user://amoeba_record.dat", FileAccess.READ)
		if file != null:
			best_mass = file.get_32()


func _save_record() -> void:
	var file := FileAccess.open("user://amoeba_record.dat", FileAccess.WRITE)
	if file != null:
		file.store_32(best_mass)


func _experience_needed() -> int:
	return LEVEL_BASE_XP + level * LEVEL_STEP_XP


func _award(xp: int, gained_coins: int) -> void:
	if xp > 0:
		round_xp += xp
		experience += xp
	while experience >= _experience_needed():
		experience -= _experience_needed()
		level += 1
		_play_sfx("level")
		_vibrate(75)
		var level_bonus := 10 + level * 4
		coins += level_bonus
		round_coins += level_bonus
	coins += gained_coins
	round_coins += gained_coins


func _gain_survival_rewards(delta: float) -> void:
	survival_tick += delta
	save_tick += delta
	if survival_tick >= 1.0:
		survival_tick -= 1.0
		_award(1, 0)
		if int(survival_time) % 12 == 0:
			_award(2, 3)
	if save_tick >= 12.0:
		save_tick = 0.0
		_save_profile()


func _check_victory(delta: float) -> void:
	if not player["alive"]:
		return
	var top := true
	for cell in cells:
		if cell != player and cell["alive"] and cell["mass"] >= player["mass"]:
			top = false
			break
	if top and player["mass"] >= 220.0:
		crown_time += delta
		if crown_time >= CROWN_HOLD_SECONDS:
			_award(150, 100)
			victories += 1
			_end_round(true)
	else:
		crown_time = 0.0


func _end_round(was_victory: bool) -> void:
	if mode != "playing":
		return
	mode = "won" if was_victory else "dead"
	_play_sfx("win" if was_victory else "lose")
	_vibrate(140 if was_victory else 65)
	best_survival = maxi(best_survival, int(survival_time))
	_save_record()
	_save_profile()
	_layout_menu_controls()


func _load_profile() -> void:
	var config := ConfigFile.new()
	if config.load("user://amoeba_progress.cfg") != OK:
		return
	coins = maxi(0, int(config.get_value("progress", "coins", 0)))
	level = maxi(1, int(config.get_value("progress", "level", 1)))
	experience = maxi(0, int(config.get_value("progress", "experience", 0)))
	best_survival = int(config.get_value("progress", "best_survival", 0))
	victories = int(config.get_value("progress", "victories", 0))
	owned_skins.clear()
	for value in config.get_value("cosmetics", "owned", ["mint"]):
		var id := str(value)
		if not owned_skins.has(id) and _skin_definition(id)["id"] == id:
			owned_skins.append(id)
	if not owned_skins.has("mint"):
		owned_skins.append("mint")
	equipped_skin = str(config.get_value("cosmetics", "equipped", "mint"))
	if not owned_skins.has(equipped_skin):
		equipped_skin = "mint"
	sound_enabled = bool(config.get_value("settings", "sound", true))
	vibration_enabled = bool(config.get_value("settings", "vibration", true))
	light_mode = bool(config.get_value("settings", "light_mode", false))


func _save_profile() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "coins", coins)
	config.set_value("progress", "level", level)
	config.set_value("progress", "experience", experience)
	config.set_value("progress", "best_survival", best_survival)
	config.set_value("progress", "victories", victories)
	config.set_value("cosmetics", "owned", owned_skins)
	config.set_value("cosmetics", "equipped", equipped_skin)
	config.set_value("settings", "sound", sound_enabled)
	config.set_value("settings", "vibration", vibration_enabled)
	config.set_value("settings", "light_mode", light_mode)
	config.save("user://amoeba_progress.cfg")


func _load_username() -> void:
	if FileAccess.file_exists("user://amoeba_username.txt"):
		var file := FileAccess.open("user://amoeba_username.txt", FileAccess.READ)
		if file != null:
			username = _sanitize_username(file.get_as_text())


func _save_username() -> void:
	var file := FileAccess.open("user://amoeba_username.txt", FileAccess.WRITE)
	if file != null:
		file.store_string(username)
