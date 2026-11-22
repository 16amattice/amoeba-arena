extends Node2D
## Amoeba Arena — a self-contained arcade prototype.
## No external services are required. Every amoeba is drawn procedurally.

const ARENA = Vector2(3600.0, 3600.0)
const FOOD_COUNT = 730
const BOT_COUNT = 19
const GRID_SPACING = 150
const BITE_MARK_SECONDS = 2.5
const CELL_VERTICES = 48
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


func _ready() -> void:
	randomize()
	_load_record()
	_reset_arena()
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
	player = _make_cell(ARENA * 0.5, 100.0, Color(0.26, 0.94, 0.78), "YOU", true)
	cells.append(player)
	for n in range(BOT_COUNT):
		_spawn_bot(n)
	for n in range(FOOD_COUNT):
		food.append(_make_food())
	camera_position = player["pos"]
	camera_zoom = 1.0


func _make_cell(position: Vector2, mass: float, color: Color, label: String, human: bool) -> Dictionary:
	return {
		"pos": position,
		"vel": Vector2.ZERO,
		"mass": mass,
		"color": color,
		"label": label,
		"human": human,
		"alive": true,
		"phase": randf_range(0.0, TAU),
		"direction": randf_range(0.0, TAU),
		"aim": position,
		"think": randf_range(0.05, 0.55),
		"marks": [],
		"last_mark": -10.0,
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


func _make_food() -> Dictionary:
	return {
		"pos": Vector2(randf_range(25.0, ARENA.x - 25.0), randf_range(25.0, ARENA.y - 25.0)),
		"mass": randf_range(2.0, 4.5),
		"radius": randf_range(3.5, 5.8),
		"color": FOOD_COLORS.pick_random(),
		"phase": randf_range(0.0, TAU)
	}


func _start_game() -> void:
	_reset_arena()
	mode = "playing"


func _input(event: InputEvent) -> void:
	if mode != "playing":
		if event is InputEventScreenTouch and event.pressed:
			_start_game()
			touch_index = event.index
			touch_origin = event.position
			touch_position = event.position
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_start_game()
			mouse_aim = true
			mouse_position = event.position
		elif event is InputEventKey and event.pressed and not event.echo:
			_start_game()
		return

	if event is InputEventScreenTouch:
		if event.pressed and touch_index == -1:
			touch_index = event.index
			touch_origin = event.position
			touch_position = event.position
		elif not event.pressed and event.index == touch_index:
			touch_index = -1
	elif event is InputEventScreenDrag and event.index == touch_index:
		touch_position = event.position
	elif event is InputEventMouseMotion:
		mouse_position = event.position
		mouse_aim = true


func _process(delta: float) -> void:
	delta = minf(delta, 0.06)
	clock += delta
	damage_flash = maxf(damage_flash - delta * 2.2, 0.0)
	if mode == "playing":
		survival_time += delta
		_think_for_bots(delta)
		_move_cells(delta)
		_consume_food()
		_resolve_bites(delta)
		_cleanup_dead()
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
	queue_redraw()


func _move_input() -> Vector2:
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
		return axis.normalized()
	if touch_index >= 0:
		return ((touch_position - touch_origin) / 75.0).limit_length(1.0)
	if mouse_aim:
		var offset := mouse_position - get_viewport_rect().size * 0.5
		if offset.length() > 28.0:
			return offset.normalized()
	return Vector2.ZERO


func _cell_radius(cell: Dictionary) -> float:
	return maxf(5.0, sqrt(maxf(0.0, cell["mass"])) * 4.0)


func _cell_speed(cell: Dictionary) -> float:
	# Core trade-off: losing mass makes you quicker, without a speed boost button.
	return clampf(368.0 - 13.0 * sqrt(maxf(0.0, cell["mass"])), 85.0, 335.0)


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
		var responsiveness := 6.5 if cell["human"] else 3.7
		cell["vel"] = cell["vel"].lerp(desired_velocity, minf(1.0, delta * responsiveness))
		cell["pos"] += cell["vel"] * delta
		var radius := _cell_radius(cell)
		cell["pos"] = cell["pos"].clamp(Vector2.ONE * radius, ARENA - Vector2.ONE * radius)
		if cell["vel"].length() > 8.0:
			cell["direction"] = lerp_angle(cell["direction"], cell["vel"].angle(), minf(1.0, delta * 4.0))
		cell["phase"] += delta * (1.65 + cell["vel"].length() * 0.005)
		var marks: Array = cell["marks"]
		for mark_index in range(marks.size() - 1, -1, -1):
			marks[mark_index]["life"] -= delta / BITE_MARK_SECONDS
			if marks[mark_index]["life"] <= 0.0:
				marks.remove_at(mark_index)


func _consume_food() -> void:
	for food_index in range(food.size() - 1, -1, -1):
		var morsel := food[food_index]
		for cell in cells:
			if not cell["alive"]:
				continue
			var radius := _cell_radius(cell) * 0.83
			if cell["pos"].distance_squared_to(morsel["pos"]) < radius * radius:
				cell["mass"] += morsel["mass"]
				if cell["human"]:
					cell["food_count"] += 1
				food.remove_at(food_index)
				break
	while food.size() < FOOD_COUNT:
		food.append(_make_food())


func _resolve_bites(delta: float) -> void:
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
			var reach := _cell_radius(eater) + _cell_radius(victim) * 0.70
			var distance: float = eater["pos"].distance_to(victim["pos"])
			if distance >= reach:
				continue
			var penetration := clampf((reach - distance) / maxf(5.0, _cell_radius(victim)), 0.0, 1.0)
			if penetration < 0.025:
				continue
			var advantage := clampf(pow(eater["mass"] / maxf(1.0, victim["mass"]), 0.35), 1.0, 2.1)
			var taken := minf(victim["mass"], delta * 48.0 * penetration * advantage)
			victim["mass"] -= taken
			eater["mass"] += taken * 0.83
			if victim["human"]:
				damage_flash = minf(0.7, damage_flash + taken * 0.012)
			if clock - victim["last_mark"] >= 0.13:
				victim["last_mark"] = clock
				var angle: float = (eater["pos"] - victim["pos"]).angle()
				var marks: Array = victim["marks"]
				marks.append({"angle": angle, "life": 1.0, "strength": 0.34})
				if marks.size() > 7:
					marks.pop_front()
				_spawn_bite_droplets(victim["pos"] + Vector2.RIGHT.rotated(angle) * _cell_radius(victim) * 0.76, victim["color"])
			if victim["mass"] <= 1.0:
				victim["alive"] = false
				if eater["human"]:
					takedowns += 1
				_burst_food(victim["pos"], victim["color"])


func _spawn_bite_droplets(position: Vector2, color: Color) -> void:
	for n in range(3):
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
			mode = "dead"
			_save_record()
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
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.034, 0.069, 0.091))
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
	draw_rect(Rect2(Vector2.ZERO, ARENA), Color(0.047, 0.105, 0.126))
	for x in range(0, int(ARENA.x) + 1, GRID_SPACING):
		draw_line(Vector2(x, 0), Vector2(x, ARENA.y), Color(0.22, 0.40, 0.44, 0.13), 1.5)
	for y in range(0, int(ARENA.y) + 1, GRID_SPACING):
		draw_line(Vector2(0, y), Vector2(ARENA.x, y), Color(0.22, 0.40, 0.44, 0.13), 1.5)
	draw_rect(Rect2(Vector2.ZERO, ARENA), Color(0.21, 0.84, 0.80, 0.65), false, 12.0)
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
	for particle in particles:
		var shade: Color = particle["color"]
		shade.a = clampf(particle["life"] / particle["max_life"], 0.0, 1.0)
		draw_circle(particle["pos"], particle["radius"] * shade.a, shade)


func _draw_cell(cell: Dictionary) -> void:
	var center: Vector2 = cell["pos"]
	var radius := _cell_radius(cell)
	var color: Color = cell["color"]
	var points := PackedVector2Array()
	var shine_points := PackedVector2Array()
	var velocity_amount := clampf(cell["vel"].length() / 300.0, 0.0, 1.0)
	for i in range(CELL_VERTICES):
		var angle := TAU * float(i) / float(CELL_VERTICES)
		var wobble := 1.0 + 0.072 * sin(angle * 3.0 + cell["phase"]) + 0.047 * sin(angle * 5.0 - cell["phase"] * 1.2) + 0.028 * sin(angle * 8.0 + cell["phase"] * 1.8)
		var stretch := 1.0 + 0.12 * velocity_amount * cos(angle - cell["direction"])
		var dent := 1.0
		for mark in cell["marks"]:
			var diff := absf(wrapf(angle - mark["angle"], -PI, PI))
			var influence := exp(-pow(diff / 0.34, 2.0))
			dent -= mark["strength"] * mark["life"] * influence
		var displacement := Vector2(cos(angle), sin(angle)) * radius * wobble * stretch * maxf(0.30, dent)
		points.append(center + displacement)
		shine_points.append(center + displacement * 0.81)
	var shadow := PackedVector2Array()
	for p in points:
		shadow.append(p + Vector2(3.0, 10.0))
	draw_colored_polygon(shadow, Color(0.00, 0.02, 0.04, 0.32))
	draw_colored_polygon(points, color.darkened(0.28))
	draw_colored_polygon(shine_points, color)
	var highlight := PackedVector2Array()
	for p in points:
		highlight.append(p)
	highlight.append(points[0])
	draw_polyline(highlight, color.lightened(0.32), 3.5, true)
	# A translucent nucleus and two organelles emphasize the living-cell look.
	draw_circle(center + Vector2(-radius * 0.11, radius * 0.02), radius * 0.30, Color(0.10, 0.31, 0.40, 0.20))
	draw_circle(center + Vector2(-radius * 0.14, -radius * 0.02), radius * 0.19, Color(0.97, 1.0, 1.0, 0.18))
	draw_circle(center + Vector2(radius * 0.38, radius * 0.19), maxf(2.0, radius * 0.075), Color(1, 1, 1, 0.32))
	draw_circle(center + Vector2(-radius * 0.34, radius * 0.29), maxf(2.0, radius * 0.065), Color(1, 1, 1, 0.28))
	var font := ThemeDB.fallback_font
	var label_text: String = cell["label"]
	draw_string(font, center + Vector2(-radius, 4.0), label_text, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, clampi(int(radius * 0.34), 10, 18), Color(0.03, 0.16, 0.20, 0.90))
	draw_string(font, center + Vector2(-radius, 20.0), str(int(ceil(cell["mass"]))), HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 12, Color(0.03, 0.16, 0.20, 0.68))


func _draw_hud(viewport_size: Vector2) -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(20, 20, 252, 115), Color(0.015, 0.035, 0.06, 0.77))
	draw_string(font, Vector2(37, 53), "AMOEBA  ARENA", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color(0.40, 1.0, 0.78))
	draw_string(font, Vector2(37, 88), "MASS   " + str(int(ceil(player["mass"]))), HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color.WHITE)
	draw_string(font, Vector2(37, 115), "KOs  " + str(takedowns) + "    TIME  " + str(int(survival_time)) + "s", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.68, 0.83, 0.85))
	var map_rect := Rect2(viewport_size.x - 182.0, 20.0, 160.0, 160.0)
	draw_rect(map_rect, Color(0.018, 0.045, 0.062, 0.83))
	draw_rect(map_rect.grow(-8), Color(0.12, 0.27, 0.30, 0.47), false, 1.5)
	for cell in cells:
		if not cell["alive"]:
			continue
		var dot := map_rect.position + Vector2(8, 8) + (cell["pos"] / ARENA) * Vector2(144, 144)
		draw_circle(dot, 4.5 if cell["human"] else 2.5, cell["color"])
	if touch_index >= 0 and mode == "playing":
		draw_circle(touch_origin, 68.0, Color(0.55, 0.92, 0.91, 0.09))
		draw_arc(touch_origin, 68.0, 0, TAU, 50, Color(0.55, 0.92, 0.91, 0.46), 3.0, true)
		var stick := touch_origin + (touch_position - touch_origin).limit_length(68.0)
		draw_circle(stick, 26.0, Color(0.38, 1.0, 0.82, 0.72))
	elif mode == "playing":
		draw_string(font, Vector2(25, viewport_size.y - 28), "DRAG TO MOVE   /   WASD OR MOUSE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.62, 0.82, 0.85, 0.75))
	if mode == "playing" and player["mass"] < 33.0:
		draw_string(font, Vector2(viewport_size.x * 0.5 - 200.0, 64), "TINY = FAST  •  ESCAPE AND REGROW!", HORIZONTAL_ALIGNMENT_CENTER, 400.0, 18, Color(1.0, 0.83, 0.57))


func _draw_overlay(viewport_size: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.01, 0.035, 0.052, 0.71))
	var font := ThemeDB.fallback_font
	var width := minf(650.0, viewport_size.x - 38.0)
	var height := 360.0
	var left := (viewport_size.x - width) * 0.5
	var top := (viewport_size.y - height) * 0.5
	draw_rect(Rect2(left, top, width, height), Color(0.045, 0.13, 0.16, 0.96))
	draw_rect(Rect2(left, top, width, height), Color(0.36, 0.95, 0.78, 0.58), false, 2.0)
	if mode == "menu":
		_center_text("AMOEBA ARENA", top + 69.0, 46, Color(0.39, 1.0, 0.79), viewport_size)
		_center_text("EAT  •  ESCAPE  •  EVOLVE", top + 111.0, 18, Color(0.90, 0.98, 0.99), viewport_size)
		_center_text("BIGGER CELLS CAN BITE SMALLER ONES", top + 157.0, 20, Color.WHITE, viewport_size)
		_center_text("LOSING MASS MAKES YOU FASTER", top + 189.0, 20, Color(0.94, 0.76, 0.45), viewport_size)
		_center_text("Collect glowing nutrients to grow again.", top + 226.0, 18, Color(0.73, 0.86, 0.89), viewport_size)
		_center_text("TAP OR CLICK ANYWHERE TO PLAY", top + 303.0, 24, Color(0.38, 1.0, 0.76), viewport_size)
	else:
		_center_text("YOU WERE CONSUMED", top + 73.0, 39, Color(1.0, 0.51, 0.59), viewport_size)
		_center_text("Survived  " + str(int(survival_time)) + "s", top + 132.0, 25, Color.WHITE, viewport_size)
		_center_text("Largest mass  " + str(best_mass) + "     KOs  " + str(takedowns), top + 183.0, 22, Color(0.79, 0.94, 0.95), viewport_size)
		_center_text("A cell is never out until its last bit is eaten.", top + 232.0, 18, Color(0.71, 0.85, 0.89), viewport_size)
		_center_text("TAP OR CLICK TO TRY AGAIN", top + 309.0, 25, Color(0.38, 1.0, 0.76), viewport_size)


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
