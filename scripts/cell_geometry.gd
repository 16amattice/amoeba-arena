extends RefCounted
## Physical amoeba geometry. Each body's polygons ARE its remaining tissue.
## Boolean subtraction removes exactly the overlapped region. No health bar or
## damage-per-second exists: death only occurs when the body has been consumed.
const AREA_PER_MASS = 50.0
const MIN_FRAGMENT_AREA = 3.0
const MIN_ALIVE_MASS = 0.6

static func polygon_area(points: PackedVector2Array) -> float:
	if points.size() < 3:
		return 0.0
	var twice_area := 0.0
	for i in range(points.size()):
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % points.size()]
		twice_area += a.x * b.y - b.x * a.y
	return absf(twice_area) * 0.5


static func total_area(polygons: Array[PackedVector2Array]) -> float:
	var value := 0.0
	for poly in polygons:
		value += polygon_area(poly)
	return value


static func initial_shapes(mass: float, seed: float) -> Array[PackedVector2Array]:
	var radius := sqrt(maxf(1.0, mass) * AREA_PER_MASS / PI)
	var body := PackedVector2Array()
	for i in range(64):
		var angle := TAU * float(i) / 64.0
		var ripple := 1.0 + 0.065 * sin(angle * 3.0 + seed) \
				+ 0.042 * sin(angle * 5.0 - seed * 0.7) \
				+ 0.024 * sin(angle * 7.0 + seed * 1.4)
		body.append(Vector2.from_angle(angle) * radius * ripple)
	# Set mass precisely from the body's actual area, not its bounding circle.
	var normalization := sqrt((mass * AREA_PER_MASS) / maxf(1.0, polygon_area(body)))
	for i in range(body.size()):
		body[i] *= normalization
	var result: Array[PackedVector2Array] = [body]
	return result


static func world_poly(cell: Dictionary, polygon: PackedVector2Array, arena: Vector2) -> PackedVector2Array:
	# The membrane actually flattens along the wall, instead of keeping the
	# circular body away from corners. This is shared by rendering and biting.
	var points := PackedVector2Array()
	var center: Vector2 = cell["pos"]
	for p in polygon:
		var world: Vector2 = center + p
		world.x = clampf(world.x, 0.0, arena.x)
		world.y = clampf(world.y, 0.0, arena.y)
		points.append(world)
	return points


static func world_shapes(cell: Dictionary, arena: Vector2) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	var shapes: Array = cell["shapes"]
	for polygon in shapes:
		var world := world_poly(cell, polygon, arena)
		if world.size() >= 3 and polygon_area(world) >= MIN_FRAGMENT_AREA:
			result.append(world)
	return result


static func grow(cell: Dictionary, gain: float) -> void:
	if gain <= 0.0 or not cell["alive"]:
		return
	var previous: float = maxf(0.01, cell["mass"])
	var new_mass := previous + gain
	var factor := sqrt(new_mass / previous)
	var grown: Array[PackedVector2Array] = []
	for polygon in cell["shapes"]:
		var expanded := PackedVector2Array()
		for p in polygon:
			expanded.append(p * factor)
		grown.append(expanded)
	cell["shapes"] = grown
	cell["mass"] = new_mass


static func consume(eater: Dictionary, victim: Dictionary, arena: Vector2) -> Dictionary:
	# NOTE: clipping is in world coordinates, after each membrane was pressed
	# against the arena's walls. Surviving shards keep their true positions.
	var originals := world_shapes(victim, arena)
	var cutters := world_shapes(eater, arena)
	var original_area := total_area(originals)
	if original_area <= MIN_FRAGMENT_AREA or cutters.is_empty():
		return {"mass": 0.0, "dead": false, "position": victim["pos"]}
	var surviving: Array[PackedVector2Array] = []
	for subject in originals:
		var fragments: Array[PackedVector2Array] = [subject]
		for cutter in cutters:
			var next_fragments: Array[PackedVector2Array] = []
			for fragment in fragments:
				# This is geometric subtraction, not gradual health damage.
				var difference := Geometry2D.clip_polygons(fragment, cutter)
				for piece in difference:
					if piece.size() >= 3 and polygon_area(piece) >= MIN_FRAGMENT_AREA:
						next_fragments.append(piece)
			fragments = next_fragments
			if fragments.is_empty():
				break
		surviving.append_array(fragments)

	var remaining_area := total_area(surviving)
	var eaten_area := maxf(0.0, original_area - remaining_area)
	if eaten_area < 0.25:
		return {"mass": 0.0, "dead": false, "position": victim["pos"]}

	var previous_mass: float = victim["mass"]
	var eaten_mass: float = previous_mass * clampf(eaten_area / original_area, 0.0, 1.0)
	var new_mass := maxf(0.0, previous_mass - eaten_mass)
	if new_mass <= MIN_ALIVE_MASS or surviving.is_empty():
		victim["mass"] = 0.0
		victim["shapes"] = []
		victim["alive"] = false
		return {"mass": previous_mass, "dead": true, "position": victim["pos"]}

	# Keep every surviving piece, including separated shards. Don't silently
	# round them away or reconstruct the victim as a smaller circle.
	var weighted_center := Vector2.ZERO
	var total_weight := 0.0
	for polygon in surviving:
		var area := polygon_area(polygon)
		var center := Vector2.ZERO
		for vertex in polygon:
			center += vertex
		center /= float(polygon.size())
		weighted_center += center * area
		total_weight += area
	if total_weight > 0.0:
		weighted_center /= total_weight
	else:
		weighted_center = victim["pos"]
	var local_shapes: Array[PackedVector2Array] = []
	for polygon in surviving:
		var local := PackedVector2Array()
		for vertex in polygon:
			local.append(vertex - weighted_center)
		local_shapes.append(local)
	victim["pos"] = weighted_center
	victim["shapes"] = local_shapes
	victim["mass"] = new_mass
	return {"mass": eaten_mass, "dead": false, "position": weighted_center}


static func visible_area(cell: Dictionary, arena: Vector2) -> float:
	return total_area(world_shapes(cell, arena))
