extends RefCounted

# Ports are clockwise from north. A tile has exactly two ports: no switches yet.
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1)
]
static var _drawing_cache: Dictionary = {}


static func connections(track_type: Variant) -> Array[Vector2i]:
	var ports: Array[Vector2i] = []
	if typeof(track_type) == TYPE_BOOL:
		ports.assign([Vector2i.UP, Vector2i.DOWN] if track_type else [Vector2i.RIGHT, Vector2i.LEFT])
		return ports
	if typeof(track_type) != TYPE_STRING:
		return ports
	match track_type:
		"NE": ports.assign([Vector2i.UP, Vector2i.RIGHT])
		"SE": ports.assign([Vector2i.RIGHT, Vector2i.DOWN])
		"SW": ports.assign([Vector2i.DOWN, Vector2i.LEFT])
		"NW": ports.assign([Vector2i.UP, Vector2i.LEFT])
	if not ports.is_empty():
		return ports
	var parts: PackedStringArray = track_type.split("_")
	if parts.size() != 3 or parts[0] != "rail":
		return ports
	if not parts[1].is_valid_int() or not parts[2].is_valid_int():
		return ports
	var a: int = int(parts[1])
	var b: int = int(parts[2])
	if a < 0 or b > 7 or a >= b or mini(b - a, 8 - b + a) < 2:
		return ports
	if track_type != "rail_%d_%d" % [a, b]:
		return ports
	ports.assign([DIRECTIONS[a], DIRECTIONS[b]])
	return ports


static func from_ports(first: Vector2i, second: Vector2i) -> Variant:
	var a: int = DIRECTIONS.find(first)
	var b: int = DIRECTIONS.find(second)
	if a < 0 or b < 0:
		return null
	if a > b:
		var temporary: int = a
		a = b
		b = temporary
	if mini(b - a, 8 - b + a) < 2:
		return null
	if a == 0 and b == 4: return true
	if a == 2 and b == 6: return false
	if a == 0 and b == 2: return "NE"
	if a == 2 and b == 4: return "SE"
	if a == 4 and b == 6: return "SW"
	if a == 0 and b == 6: return "NW"
	return "rail_%d_%d" % [a, b]


static func same_connections(first: Variant, second: Variant) -> bool:
	var a: Array[Vector2i] = connections(first)
	var b: Array[Vector2i] = connections(second)
	return a.size() == 2 and b.size() == 2 and b.has(a[0]) and b.has(a[1])


static func centerline(entry: Vector2i, exit_port: Vector2i, tile_size: float) -> PackedVector2Array:
	var center := Vector2.ONE * tile_size / 2.0
	var first: Vector2 = center + Vector2(entry) * tile_size / 2.0
	var last: Vector2 = center + Vector2(exit_port) * tile_size / 2.0
	if entry == -exit_port:
		return PackedVector2Array([first, last])
	# Both rendering and train movement use this same rounded bend.
	var points := PackedVector2Array()
	for sample in range(17):
		var t: float = float(sample) / 16.0
		points.append(first * (1.0 - t) * (1.0 - t) + center * 2.0 * t * (1.0 - t) + last * t * t)
	return points


static func drawing_data(track_type: Variant, tile_size: float) -> Dictionary:
	var key: String = str(track_type) + ":" + str(tile_size)
	if _drawing_cache.has(key):
		return _drawing_cache[key]
	var ports: Array[Vector2i] = connections(track_type)
	if ports.size() != 2:
		return {}
	var points: PackedVector2Array = centerline(ports[0], ports[1], tile_size)
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var curve := Curve2D.new()
	curve.bake_interval = 1.0
	for index in range(points.size()):
		var tangent: Vector2
		if index == 0:
			tangent = -Vector2(ports[0]).normalized()
		elif index == points.size() - 1:
			tangent = Vector2(ports[1]).normalized()
		else:
			tangent = (points[index + 1] - points[index - 1]).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		left.append(points[index] + normal * 6.0)
		right.append(points[index] - normal * 6.0)
		curve.add_point(points[index])
	var sleepers := PackedVector2Array()
	var length: float = curve.get_baked_length()
	var distance: float = 4.0
	while distance < length:
		var center: Vector2 = curve.sample_baked(distance)
		var tangent: Vector2 = (curve.sample_baked(minf(distance + 0.5, length)) - curve.sample_baked(maxf(distance - 0.5, 0.0))).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		sleepers.append(center - normal * 10.0)
		sleepers.append(center + normal * 10.0)
		distance += 8.0
	var result: Dictionary = {"left": left, "right": right, "sleepers": sleepers}
	_drawing_cache[key] = result
	return result
