extends RefCounted


const Geometry = preload("res://scripts/track_geometry.gd")


static func connections(track_type: Variant) -> Array[Vector2i]:
	return Geometry.connections(track_type)


static func find_route(
	tracks: Dictionary,
	start: Vector2i,
	destination: Vector2i
) -> Array[Vector2i]:
	var empty_route: Array[Vector2i] = []

	if not tracks.has(start) or not tracks.has(destination):
		return empty_route

	var frontier: Array[Vector2i] = [start]
	var visited: Dictionary = {start: true}
	var previous: Dictionary = {}
	var index: int = 0

	while index < frontier.size():
		var current: Vector2i = frontier[index]
		index += 1

		if current == destination:
			var route: Array[Vector2i] = [current]

			while current != start:
				current = previous[current]
				route.append(current)

			route.reverse()
			return route

		for direction in connections(tracks[current]):
			var neighbor: Vector2i = current + direction

			if visited.has(neighbor) or not tracks.has(neighbor):
				continue

			# Both pieces must connect across their shared edge.
			if not connections(tracks[neighbor]).has(-direction):
				continue

			visited[neighbor] = true
			previous[neighbor] = current
			frontier.append(neighbor)

	return empty_route


static func make_path(cells: Array[Vector2i], tile_size: float) -> Curve2D:
	var path := Curve2D.new()
	path.bake_interval = 1.0
	if cells.size() < 2:
		return path
	var half: float = tile_size / 2.0
	for index in range(cells.size()):
		var origin: Vector2 = Vector2(cells[index]) * tile_size
		var center: Vector2 = origin + Vector2(half, half)
		if index == 0:
			_append_point(path, center)
			_append_point(path, center + Vector2(cells[1] - cells[0]) * half)
		elif index == cells.size() - 1:
			_append_point(path, center + Vector2(cells[index - 1] - cells[index]) * half)
			_append_point(path, center)
		else:
			for point in Geometry.centerline(cells[index - 1] - cells[index], cells[index + 1] - cells[index], tile_size):
				_append_point(path, origin + point)
	return path


static func _append_point(path: Curve2D, point: Vector2) -> void:
	if path.point_count > 0:
		var previous: Vector2 = path.get_point_position(
			path.point_count - 1
		)

		if previous.distance_to(point) < 0.001:
			return

	path.add_point(point)
