extends Node2D
const CellGeometry = preload("res://scripts/cell_geometry.gd")
const ArenaUI = preload("res://scripts/arena_ui.gd")
const SkinFX = preload("res://scripts/skin_fx.gd")
const FONT_DISPLAY = preload("res://assets/fonts/ChakraPetch-Bold.ttf")
const FONT_BODY = preload("res://assets/fonts/ChakraPetch-Medium.ttf")
const FONT_MONO = preload("res://assets/fonts/DMMono-Regular.ttf")
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
	{"id":"mint","name":"Tidepool","cost":0,"color":Color(0.26,0.94,0.78),"detail":"Bioluminescent ripples"},
	{"id":"bubblegum","name":"Coral Bloom","cost":75,"color":Color(1.0,0.46,0.71),"detail":"Living petals + coral wake"},
	{"id":"arctic","name":"Cryoglass","cost":140,"color":Color(0.30,0.77,1.0),"detail":"Ice facets + frozen mist"},
	{"id":"solar","name":"Starfall","cost":215,"color":Color(1.0,0.60,0.24),"detail":"Solar corona + ember tail"},
	{"id":"rainbow","name":"Prismatic","cost":365,"color":Color(1.0,0.35,0.65),"detail":"Spectrum body + twin trails"},
	{"id":"galaxy","name":"Dark Matter","cost":490,"color":Color(0.47,0.30,0.80),"detail":"Orbiting stars + void wake"},
	{"id":"gold","name":"Sunforged","cost":650,"color":Color(0.96,0.78,0.28),"detail":"Royal flare + golden dust"}
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
var ui
var name_entry: LineEdit
var start_button: Button
var shop_button: Button
var secondary_button: Button
var back_button: Button
var settings_sound_button: Button
var settings_vibration_button: Button
var settings_theme_button: Button
var shop_buttons: Array[Button] = []


func _ready() -> void:
	randomize()
	_load_record()
	_load_profile()
	_load_username()
	_reset_arena()
	ui = ArenaUI.new()
	add_child(ui)
	ui.attach(self)
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
		"trail": [],
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
		return Color.from_hsv(fposmod(clock * 0.14, 1.0), 0.80, 0.99)
	if id == "galaxy":
		return Color.from_hsv(0.75 + 0.025 * sin(clock), 0.62, 0.72)
	if id == "gold":
		return Color(1.0, 0.71 + 0.10 * sin(clock * 3.0), 0.22)
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
	ui.root.add_child(name_entry)

	start_button = Button.new()
	start_button.text = "ENTER THE ARENA"
	start_button.add_theme_font_size_override("font_size", 28)
	start_button.pressed.connect(_start_game)
	ui.root.add_child(start_button)

	shop_button = Button.new()
	shop_button.text = "SKINS"
	shop_button.add_theme_font_size_override("font_size", 24)
	shop_button.pressed.connect(_on_shop_button)
	ui.root.add_child(shop_button)

	secondary_button = Button.new()
	secondary_button.text = "SETTINGS"
	secondary_button.add_theme_font_size_override("font_size", 24)
	secondary_button.pressed.connect(_on_secondary_button)
	ui.root.add_child(secondary_button)

	back_button = Button.new()
	back_button.text = "BACK"
	back_button.add_theme_font_size_override("font_size", 24)
	back_button.pressed.connect(_return_from_overlay)
	ui.root.add_child(back_button)

	settings_sound_button = Button.new()
	settings_sound_button.pressed.connect(_toggle_sound)
	settings_sound_button.add_theme_font_size_override("font_size", 23)
	ui.root.add_child(settings_sound_button)

	settings_vibration_button = Button.new()
	settings_vibration_button.pressed.connect(_toggle_vibration)
	settings_vibration_button.add_theme_font_size_override("font_size", 23)
	ui.root.add_child(settings_vibration_button)

	settings_theme_button = Button.new()
	settings_theme_button.pressed.connect(_toggle_theme)
	settings_theme_button.add_theme_font_size_override("font_size", 23)
	ui.root.add_child(settings_theme_button)

	for i in range(SKINS.size()):
		var option := Button.new()
		option.name = "ShopSkin_" + str(i)
		option.add_theme_font_size_override("font_size", 22)
		option.pressed.connect(_on_skin_pressed.bind(i))
		ui.root.add_child(option)
		shop_buttons.append(option)
	_style_controls()
	_layout_menu_controls()


func _style_controls() -> void:
	var plain := [shop_button, secondary_button, back_button,
		settings_sound_button, settings_vibration_button, settings_theme_button]
	for item in shop_buttons:
		plain.append(item)
	for item in plain:
		_style_button(item, false)
	_style_button(start_button, true)

	var field := StyleBoxFlat.new()
	field.bg_color = Color(0.06,0.16,0.19,0.93)
	field.border_color = Color(0.40,0.96,0.81,0.55)
	field.border_width_bottom = 2
	field.content_margin_left = 18
	field.content_margin_right = 18
	field.corner_radius_top_left = 5
	field.corner_radius_bottom_left = 5
	field.corner_radius_top_right = 5
	field.corner_radius_bottom_right = 5
	name_entry.add_theme_stylebox_override("normal",field)
	name_entry.add_theme_stylebox_override("focus",field)
	name_entry.add_theme_font_override("font", FONT_MONO)
	name_entry.add_theme_color_override("font_color",Color(0.94,0.99,0.99))
	name_entry.add_theme_color_override("font_placeholder_color",Color(0.52,0.77,0.79))
	name_entry.add_theme_font_size_override("font_size",25)


func _style_button(button: Button, primary: bool) -> void:
	button.add_theme_font_override("font",FONT_DISPLAY if primary else FONT_BODY)
	button.add_theme_font_size_override("font_size",27 if primary else 23)
	button.add_theme_color_override("font_color",Color(0.03,0.12,0.14) if primary else Color(0.89,0.99,0.98))
	button.add_theme_color_override("font_hover_color",Color(0.04,0.13,0.14) if primary else Color.WHITE)
	button.add_theme_color_override("font_pressed_color",Color(0.04,0.13,0.14) if primary else Color.WHITE)
	button.add_theme_color_override("font_disabled_color",Color(0.45,0.75,0.74))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.43,0.96,0.81,0.95) if primary else Color(0.09,0.22,0.26,0.85)
	normal.border_color = Color(0.74,1.0,0.90,0.67) if primary else Color(0.43,0.90,0.84,0.43)
	normal.border_width_left = 1
	normal.border_width_right = 1
	normal.border_width_top = 1
	normal.border_width_bottom = 2
	normal.corner_radius_top_left = 5
	normal.corner_radius_top_right = 5
	normal.corner_radius_bottom_left = 5
	normal.corner_radius_bottom_right = 5
	button.add_theme_stylebox_override("normal",normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.73,1.0,0.86) if primary else Color(0.14,0.33,0.38,0.94)
	button.add_theme_stylebox_override("hover",hover)
	button.add_theme_stylebox_override("pressed",hover)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.06,0.18,0.19,0.85)
	button.add_theme_stylebox_override("disabled",disabled)


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
	var screen: Vector2 = get_viewport_rect().size
	var w := screen.x
	var h := screen.y
	var pad := 40.0
	var usable := w - pad * 2.0
	var is_home := mode == "menu"
	var is_result := mode == "dead" or mode == "won"
	var is_normal := is_home or is_result
	var is_shop := mode == "shop"
	var is_settings := mode == "settings"

	name_entry.visible = is_home
	name_entry.position = Vector2(pad, 673)
	name_entry.size = Vector2(usable, 67)

	start_button.visible = is_normal
	start_button.position = Vector2(pad, 826)
	start_button.size = Vector2(usable, 77)
	start_button.text = "DEPLOY SPECIMEN" if is_home else "RE-ENTER ARENA"

	shop_button.visible = is_normal
	shop_button.position = Vector2(pad, 929)
	shop_button.size = Vector2((usable-16.0)*0.5, 67)
	shop_button.text = "COLLECTION"
	secondary_button.visible = is_normal
	secondary_button.position = Vector2(pad + (usable-16.0)*0.5 + 16.0, 929)
	secondary_button.size = shop_button.size
	secondary_button.text = "SETTINGS" if is_home else "HOME"

	back_button.visible = is_shop or is_settings
	back_button.position = Vector2(pad, h-127.0)
	back_button.size = Vector2(usable, 71)
	back_button.text = "RETURN  /  BACK"

	for i in range(shop_buttons.size()):
		var item: Button = shop_buttons[i]
		var skin: Dictionary = SKINS[i]
		var id: String = skin["id"]
		item.visible = is_shop
		item.position = Vector2(w - 213.0, 406.0+float(i)*95.0)
		item.size = Vector2(163, 59)
		if equipped_skin == id:
			item.text = "ACTIVE"
		elif owned_skins.has(id):
			item.text = "EQUIP"
		else:
			item.text = str(skin["cost"])+" ◉"
		item.disabled = equipped_skin == id

	var controls := [settings_sound_button,settings_vibration_button,settings_theme_button]
	var labels := [
		"AUDIO    " + ("ON" if sound_enabled else "OFF"),
		"HAPTICS    " + ("ON" if vibration_enabled else "OFF"),
		"THEME    " + ("LIGHT" if light_mode else "DARK")
	]
	for i in range(controls.size()):
		var control: Button = controls[i]
		control.visible = is_settings
		control.text = labels[i]
		control.position = Vector2(pad, 438.0+float(i)*116.0)
		control.size = Vector2(usable, 78)


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
		if cell["human"]:
			var wake: Array = cell["trail"]
			if cell["vel"].length() > 18.0:
				if wake.is_empty() or (wake.back() as Vector2).distance_to(cell["pos"]) > 5.0:
					wake.append(cell["pos"])
					if wake.size() > 19:
						wake.pop_front()
			elif not wake.is_empty():
				wake.remove_at(0)


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
	var tint: Color = SkinFX.phenotype_color(skin, clock) if cell["human"] else cell["color"]
	var polygons: Array[PackedVector2Array] = CellGeometry.world_shapes(cell, ARENA)

	if cell["human"]:
		SkinFX.draw_wake(self,cell,skin,clock)

	var main_polygon := PackedVector2Array()
	var main_area := 0.0
	for poly in polygons:
		if poly.size() < 3:
			continue
		var area: float = CellGeometry.polygon_area(poly)
		if area < 3.0:
			continue
		if cell["human"] and not cell.get("needs_reform",false):
			SkinFX.draw_tissue(self,poly,cell,skin,clock)
		else:
			draw_colored_polygon(poly,tint)
		# A fine illuminated membrane rim makes the cells look like polished
		# living organisms rather than flat geometric circles.
		var closed := poly.duplicate()
		closed.append(poly[0])
		draw_polyline(closed,Color(0.025,0.14,0.18,0.78),4.1,true)
		draw_polyline(closed,tint.lightened(0.31),1.8,true)
		if area > main_area:
			main_area = area
			main_polygon = poly

	if cell["human"] and not cell.get("needs_reform",false):
		SkinFX.draw_aura(self,cell,skin,clock)

	if main_area > 150.0 and not cell.get("needs_reform",false):
		if Geometry2D.is_point_in_polygon(center,main_polygon):
			draw_circle(center,minf(radius*0.16,18.0),Color(0.04,0.27,0.33,0.18))
			draw_circle(center+Vector2(-3.0,-3.0),minf(radius*0.075,9.0),Color(1,1,1,0.15))
	if radius < 12.0:
		return
	var label_text: String = cell["label"]
	draw_string(FONT_DISPLAY,center+Vector2(-radius,4.0),label_text,HORIZONTAL_ALIGNMENT_CENTER,radius*2.0,clampi(int(radius*0.33),12,19),Color(0.025,0.11,0.15,0.88))
	draw_string(FONT_MONO,center+Vector2(-radius,23.0),str(int(ceil(cell["mass"]))),HORIZONTAL_ALIGNMENT_CENTER,radius*2.0,12,Color(0.02,0.15,0.18,0.73))


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
