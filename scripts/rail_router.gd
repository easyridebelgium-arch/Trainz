extends RefCounted


static func connections(track_type: Variant) -> Array[Vector2i]:
	var result: Array[Vector2i] = []

	if typeof(track_type) == TYPE_BOOL:
		if track_type:
			result.assign([Vector2i.UP, Vector2i.DOWN])
		else:
			result.assign([Vector2i.LEFT, Vector2i.RIGHT])
	else:
		match track_type:
			"NE":
				result.assign([Vector2i.UP, Vector2i.RIGHT])
			"SE":
				result.assign([Vector2i.DOWN, Vector2i.RIGHT])
			"SW":
				result.assign([Vector2i.DOWN, Vector2i.LEFT])
			"NW":
				result.assign([Vector2i.UP, Vector2i.LEFT])

	return result


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


static func make_path(
	cells: Array[Vector2i],
	tile_size: float
) -> Curve2D:
	var path := Curve2D.new()
	path.bake_interval = 1.0

	if cells.size() < 2:
		return path

	var half: float = tile_size / 2.0

	for index in range(cells.size()):
		var center: Vector2 = (
			Vector2(cells[index]) * tile_size
			+ Vector2(half, half)
		)

		if index == 0:
			var outgoing: Vector2 = Vector2(cells[1] - cells[0])
			_append_point(path, center)
			_append_point(path, center + outgoing * half)
			continue

		if index == cells.size() - 1:
			var incoming: Vector2 = Vector2(
				cells[index - 1] - cells[index]
			)
			_append_point(path, center + incoming * half)
			_append_point(path, center)
			continue

		var entry_direction: Vector2 = Vector2(
			cells[index - 1] - cells[index]
		)
		var exit_direction: Vector2 = Vector2(
			cells[index + 1] - cells[index]
		)

		var entry_point: Vector2 = center + entry_direction * half
		var exit_point: Vector2 = center + exit_direction * half

		if entry_direction == -exit_direction:
			_append_point(path, entry_point)
			_append_point(path, exit_point)
		else:
			# Follow the centerline between the curved rails.
			var arc_center: Vector2 = (
				center + (entry_direction + exit_direction) * half
			)

			var start_angle: float = (entry_point - arc_center).angle()
			var end_angle: float = (exit_point - arc_center).angle()
			var turn_angle: float = wrapf(
				end_angle - start_angle,
				-PI,
				PI
			)

			for sample in range(13):
				var fraction: float = float(sample) / 12.0
				var angle: float = start_angle + turn_angle * fraction
				var point: Vector2 = (
					arc_center
					+ Vector2(cos(angle), sin(angle)) * half
				)
				_append_point(path, point)

	return path


static func _append_point(path: Curve2D, point: Vector2) -> void:
	if path.point_count > 0:
		var previous: Vector2 = path.get_point_position(
			path.point_count - 1
		)

		if previous.distance_to(point) < 0.001:
			return

	path.add_point(point)
