extends RefCounted
## Amoeba geometry v0.4. An eater subtracts REAL overlapping tissue.
## Once the survivor escapes, surface tension rounds the reduced-mass body.
## Geometry and rendering both use the same smoothly wall-deformed polygons.

const AREA_PER_MASS = 50.0
const MIN_FRAGMENT_AREA = 3.0
const MIN_ALIVE_MASS = 0.6
const RING_POINTS = 64
const RECOVER_DELAY = 0.13
const WALL_CENTER_FRACTION = 0.78


static func polygon_area(points: PackedVector2Array) -> float:
	if points.size() < 3:
		return 0.0
	var cross_sum := 0.0
	for i in range(points.size()):
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % points.size()]
		cross_sum += a.cross(b)
	return absf(cross_sum) * 0.5


static func total_area(polygons: Array[PackedVector2Array]) -> float:
	var result := 0.0
	for polygon in polygons:
		result += polygon_area(polygon)
	return result


static func body_radius(mass: float) -> float:
	return sqrt(maxf(1.0, mass) * AREA_PER_MASS / PI)


static func minimum_center(mass: float) -> float:
	return body_radius(mass) * WALL_CENTER_FRACTION


static func initial_shapes(mass: float, seed: float) -> Array[PackedVector2Array]:
	var radius := body_radius(mass)
	var body := PackedVector2Array()
	for i in range(RING_POINTS):
		var angle := TAU * float(i) / float(RING_POINTS)
		var ripple := 1.0 + 0.028 * sin(angle * 3.0 + seed) \
				+ 0.019 * sin(angle * 5.0 - seed * 0.7) \
				+ 0.011 * sin(angle * 7.0 + seed * 1.4)
		body.append(Vector2.from_angle(angle) * radius * ripple)
	_normalize_ring(body, mass)
	var result: Array[PackedVector2Array] = [body]
	return result


static func _normalize_ring(polygon: PackedVector2Array, mass: float) -> void:
	var target: float = mass * AREA_PER_MASS
	var current := polygon_area(polygon)
	if current <= 0.01:
		return
	var factor := sqrt(target / current)
	for i in range(polygon.size()):
		polygon[i] *= factor


static func _squircle_coordinate(value: float, radius: float, exponent: float) -> float:
	if absf(value) <= 0.0001:
		return 0.0
	# Strictly monotone: no folding, no crossing edges and no colored overlaps.
	return signf(value) * radius * pow(absf(value) / radius, exponent)


static func _wall_strength(center: Vector2, arena: Vector2, radius: float) -> float:
	var nearest := minf(minf(center.x, center.y), minf(arena.x - center.x, arena.y - center.y))
	return clampf((radius - nearest) / maxf(1.0, radius * (1.0 - WALL_CENTER_FRACTION)), 0.0, 1.0)


static func world_shapes(cell: Dictionary, arena: Vector2) -> Array[PackedVector2Array]:
	var originals: Array = cell["shapes"]
	var center: Vector2 = cell["pos"]
	var radius: float = body_radius(float(cell["mass"]))
	var strength := _wall_strength(center, arena, radius)

	# Round becomes subtly squarer toward a boundary. In a corner this covers
	# much more of the corner than a circle, without chopping off its tissue.
	var exponent := 1.0 - 0.17 * strength
	var warped: Array[PackedVector2Array] = []
	for original in originals:
		if original.size() < 3:
			continue
		var points := PackedVector2Array()
		for p in original:
			points.append(Vector2(
				_squircle_coordinate(p.x, radius, exponent),
				_squircle_coordinate(p.y, radius, exponent)))
		if polygon_area(points) >= MIN_FRAGMENT_AREA:
			warped.append(points)
	if warped.is_empty():
		return warped

	# The corner-filling deformation increases area; normalize BEFORE shaping
	# to the wall so cells never shrink or gain mass just by touching a wall.
	var source_area := 0.0
	for polygon in originals:
		source_area += polygon_area(polygon)
	var deformed_area := total_area(warped)
	var area_scale := sqrt(maxf(0.01, source_area) / maxf(0.01, deformed_area))
	var x_negative := 0.0
	var x_positive := 0.0
	var y_negative := 0.0
	var y_positive := 0.0
	var normalized: Array[PackedVector2Array] = []
	for polygon in warped:
		var scaled := PackedVector2Array()
		for p in polygon:
			var point: Vector2 = p * area_scale
			scaled.append(point)
			x_negative = maxf(x_negative, -point.x)
			x_positive = maxf(x_positive, point.x)
			y_negative = maxf(y_negative, -point.y)
			y_positive = maxf(y_positive, point.y)
		normalized.append(scaled)

	# Compress only the side pressing the wall, and expand the opposite side
	# by the matching amount. This preserves tissue area rather than cropping.
	var left_factor := minf(1.0, center.x / maxf(0.001, x_negative))
	var right_factor := minf(1.0, (arena.x - center.x) / maxf(0.001, x_positive))
	var top_factor := minf(1.0, center.y / maxf(0.001, y_negative))
	var bottom_factor := minf(1.0, (arena.y - center.y) / maxf(0.001, y_positive))
	if left_factor < 1.0:
		right_factor = 2.0 - left_factor
	elif right_factor < 1.0:
		left_factor = 2.0 - right_factor
	if top_factor < 1.0:
		bottom_factor = 2.0 - top_factor
	elif bottom_factor < 1.0:
		top_factor = 2.0 - bottom_factor

	var world: Array[PackedVector2Array] = []
	for polygon in normalized:
		var final_points := PackedVector2Array()
		for p in polygon:
			var sx := left_factor if p.x < 0.0 else right_factor
			var sy := top_factor if p.y < 0.0 else bottom_factor
			var transformed := center + Vector2(p.x * sx, p.y * sy)
			# Numeric-only guard; this is not the old vertex-clipping behavior.
			transformed.x = clampf(transformed.x, -0.005, arena.x + 0.005)
			transformed.y = clampf(transformed.y, -0.005, arena.y + 0.005)
			final_points.append(transformed)
		if polygon_area(final_points) >= MIN_FRAGMENT_AREA:
			# A round silhouette can still leave a tiny diagonal notch at the
			# precise corner, even though both wall edges are touched. When a
			# fully recovered cell pushes into BOTH walls, extend its membrane
			# to that corner. The convex hull is safe ONLY for a single round
			# ring, never bitten fragments: we must not fill eaten holes.
			if originals.size() == 1 and originals[0].size() == RING_POINTS \
					and not bool(cell.get("needs_reform", false)):
				final_points = _fill_corner(final_points, center, arena, radius)
			world.append(final_points)
	return world


static func _fill_corner(points: PackedVector2Array, center: Vector2, arena: Vector2, radius: float) -> PackedVector2Array:
	var near_left := center.x <= radius * 0.86
	var near_right := arena.x - center.x <= radius * 0.86
	var near_top := center.y <= radius * 0.86
	var near_bottom := arena.y - center.y <= radius * 0.86
	if not (near_left or near_right) or not (near_top or near_bottom):
		return points
	var corner := Vector2(arena.x if near_right else 0.0, arena.y if near_bottom else 0.0)
	var dx := center.x if near_left else arena.x - center.x
	var dy := center.y if near_top else arena.y - center.y
	var alpha_x := clampf((radius * 0.86 - dx) / maxf(1.0, radius * 0.08), 0.0, 1.0)
	var alpha_y := clampf((radius * 0.86 - dy) / maxf(1.0, radius * 0.08), 0.0, 1.0)
	var alpha := minf(alpha_x, alpha_y)
	if alpha <= 0.001 or points.size() < 8:
		return points
	var nearest_index := 0
	var nearest_distance := INF
	for i in range(points.size()):
		var d := points[i].distance_squared_to(corner)
		if d < nearest_distance:
			nearest_distance = d
			nearest_index = i

	# No convex hull and no rebuilding the body as a square. Preserve its
	# original vertex order and blend the corner into the nearby membrane.
	var output := points.duplicate()
	var count := points.size()
	var delta: Vector2 = (corner - points[nearest_index]) * alpha
	for step in range(-3, 4):
		var index := posmod(nearest_index + step, count)
		var weight := 1.0
		match abs(step):
			1:
				weight = 0.54
			2:
				weight = 0.18
			3:
				weight = 0.04
		output[index] = (points[index] + delta * weight).clamp(Vector2.ZERO, arena)
	return output


static func world_poly(cell: Dictionary, _polygon: PackedVector2Array, arena: Vector2) -> PackedVector2Array:
	# Compatibility helper. Call world_shapes for all fragments so every
	# piece receives the same wall deformation.
	var shapes := world_shapes(cell, arena)
	return shapes[0] if not shapes.is_empty() else PackedVector2Array()


static func grow(cell: Dictionary, gain: float) -> void:
	if gain <= 0.0 or not cell["alive"]:
		return
	var previous: float = maxf(0.01, cell["mass"])
	var factor := sqrt((previous + gain) / previous)
	var grown: Array[PackedVector2Array] = []
	for poly in cell["shapes"]:
		var expanded := PackedVector2Array()
		for point in poly:
			expanded.append(point * factor)
		grown.append(expanded)
	cell["shapes"] = grown
	cell["mass"] = previous + gain


static func consume(eater: Dictionary, victim: Dictionary, arena: Vector2) -> Dictionary:
	var subjects := world_shapes(victim, arena)
	var cutters := world_shapes(eater, arena)
	var original_area := total_area(subjects)
	if original_area <= MIN_FRAGMENT_AREA or cutters.is_empty():
		return {"mass": 0.0, "dead": false, "position": victim["pos"]}

	var surviving: Array[PackedVector2Array] = []
	var eaten_area := 0.0
	for subject in subjects:
		var fragments: Array[PackedVector2Array] = [subject]
		for cutter in cutters:
			var next_fragments: Array[PackedVector2Array] = []
			for fragment in fragments:
				# Intersection area is the precise eaten tissue. In particular,
				# subtracting an internal overlap is counted even if the polygon
				# difference returns a reversed-winding hole contour.
				for intersection in Geometry2D.intersect_polygons(fragment, cutter):
					eaten_area += polygon_area(intersection)
				for piece in Geometry2D.clip_polygons(fragment, cutter):
					if piece.size() >= 3 and polygon_area(piece) >= MIN_FRAGMENT_AREA:
						next_fragments.append(piece)
			fragments = next_fragments
			if fragments.is_empty():
				break
		surviving.append_array(fragments)

	eaten_area = minf(eaten_area, original_area)
	if eaten_area <= 0.25:
		return {"mass": 0.0, "dead": false, "position": victim["pos"]}
	var mass_before: float = victim["mass"]
	var taken := mass_before * eaten_area / original_area
	var left := maxf(0.0, mass_before - taken)
	if left <= MIN_ALIVE_MASS or surviving.is_empty():
		victim["mass"] = 0.0
		victim["alive"] = false
		victim["shapes"] = []
		return {"mass": mass_before, "dead": true, "position": victim["pos"]}

	var weighted_center := Vector2.ZERO
	var total_weight := 0.0
	for poly in surviving:
		var area := polygon_area(poly)
		var c := Vector2.ZERO
		for point in poly:
			c += point
		c /= float(poly.size())
		weighted_center += c * area
		total_weight += area
	if total_weight > 0.0:
		weighted_center /= total_weight
	else:
		weighted_center = victim["pos"]
	var local: Array[PackedVector2Array] = []
	for poly in surviving:
		var points := PackedVector2Array()
		for point in poly:
			points.append(point - weighted_center)
		local.append(points)
	victim["pos"] = weighted_center
	victim["shapes"] = local
	victim["mass"] = left
	victim["needs_reform"] = true
	victim["reform_delay"] = RECOVER_DELAY
	return {"mass": taken, "dead": false, "position": weighted_center}


static func _radialize(cell: Dictionary) -> void:
	var shapes: Array = cell["shapes"]
	if shapes.is_empty():
		return
	# Put origin inside the largest surviving piece, if the bite removed the
	# original center. This keeps the recovery ring simple and non-self-crossing.
	var inside := false
	for poly in shapes:
		if Geometry2D.is_point_in_polygon(Vector2.ZERO, poly):
			inside = true
			break
	if not inside:
		var largest_area := -1.0
		var shift := Vector2.ZERO
		for poly in shapes:
			var area := polygon_area(poly)
			if area > largest_area:
				largest_area = area
				shift = Vector2.ZERO
				for point in poly:
					shift += point
				shift /= float(poly.size())
		var translated: Array[PackedVector2Array] = []
		for poly in shapes:
			var shifted := PackedVector2Array()
			for point in poly:
				shifted.append(point - shift)
			translated.append(shifted)
		cell["pos"] += shift
		cell["shapes"] = translated
		shapes = translated

	var radius := body_radius(float(cell["mass"]))
	var ring := PackedVector2Array()
	for i in range(RING_POINTS):
		var direction := Vector2.from_angle(TAU * float(i) / float(RING_POINTS))
		var nearest := INF
		for poly in shapes:
			for j in range(poly.size()):
				var a: Vector2 = poly[j]
				var b: Vector2 = poly[(j + 1) % poly.size()]
				var edge := b - a
				var det := direction.cross(edge)
				if absf(det) < 0.00001:
					continue
				var travel := a.cross(edge) / det
				var u := a.cross(direction) / det
				if travel >= 0.0 and u >= 0.0 and u <= 1.0:
					nearest = minf(nearest, travel)
		var distance := radius * 0.30 if is_inf(nearest) else clampf(nearest, radius * 0.14, radius * 2.0)
		ring.append(direction * distance)
	_normalize_ring(ring, float(cell["mass"]))
	var new_shapes: Array[PackedVector2Array] = [ring]
	cell["shapes"] = new_shapes
	cell["needs_reform"] = false


static func relax(cell: Dictionary, delta: float) -> void:
	# After a bite, preserve the genuine cut edge for a moment. Then pull its
	# remaining membrane into a 64-point ring and smoothly round it.
	if not cell["alive"]:
		return
	if cell.get("needs_reform", false):
		cell["reform_delay"] = float(cell.get("reform_delay", RECOVER_DELAY)) - delta
		if float(cell["reform_delay"]) > 0.0:
			return
		_radialize(cell)

	var shapes: Array = cell["shapes"]
	if shapes.size() != 1:
		return
	var poly: PackedVector2Array = shapes[0]
	if poly.size() != RING_POINTS:
		return
	var radius := body_radius(float(cell["mass"]))
	var phase: float = cell.get("phase", 0.0)
	var factor := 1.0 - exp(-delta * 7.5)
	for i in range(RING_POINTS):
		var angle := TAU * float(i) / float(RING_POINTS)
		var desired := radius * (1.0
			+ 0.028 * sin(angle * 3.0 + phase)
			+ 0.020 * sin(angle * 5.0 - phase * 0.8)
			+ 0.012 * sin(angle * 7.0 + phase * 1.7))
		var now: float = poly[i].length()
		poly[i] = Vector2.from_angle(angle) * lerpf(now, desired, factor)
	_normalize_ring(poly, float(cell["mass"]))
	cell["shapes"] = [poly]


static func visible_area(cell: Dictionary, arena: Vector2) -> float:
	return total_area(world_shapes(cell, arena))
