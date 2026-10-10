extends RefCounted

const Geometry = preload("res://scripts/track_geometry.gd")


static func segment(start: Vector2i, finish: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [start]
	var current: Vector2i = start
	while current != finish:
		var offset: Vector2i = finish - current
		current += Vector2i(signi(offset.x), signi(offset.y))
		cells.append(current)
	return cells


static func line(start: Vector2i, finish: Vector2i, tracks: Dictionary) -> Array[Vector2i]:
	if start == finish:
		return segment(start, finish)
	var direct: Vector2i = finish - start
	if maxi(absi(direct.x), absi(direct.y)) <= 1:
		if (not tracks.has(start) or Geometry.connections(tracks[start]).has(direct)) and (not tracks.has(finish) or Geometry.connections(tracks[finish]).has(-direct)):
			return segment(start, finish)
	var first: Vector2i = start
	var last: Vector2i = finish
	if tracks.has(start):
		first += _endpoint_port(start, finish, tracks)
	if tracks.has(finish):
		last += _endpoint_port(finish, start, tracks)
	var cells: Array[Vector2i] = [start]
	for cell in segment(first, last):
		if cell != cells.back():
			cells.append(cell)
	if cells.back() != finish:
		cells.append(finish)
	return cells


static func _endpoint_port(cell: Vector2i, toward: Vector2i, tracks: Dictionary) -> Vector2i:
	var best: Vector2i = Vector2i.RIGHT
	var best_score: float = -INF
	for port in Geometry.connections(tracks[cell]):
		var score: float = Vector2(port).normalized().dot(Vector2(toward - cell).normalized())
		if score > best_score:
			best = port
			best_score = score
	return best


static func append_stroke(cells: Array[Vector2i], target: Vector2i) -> void:
	if cells.is_empty():
		cells.append(target)
		return
	var additions: Array[Vector2i] = segment(cells.back(), target)
	for index in range(1, additions.size()):
		var cell: Vector2i = additions[index]
		var previous_index: int = cells.find(cell)
		if previous_index >= 0:
			cells.resize(previous_index + 1)
		else:
			cells.append(cell)


static func plan(cells: Array[Vector2i], tracks: Dictionary, map_size: Vector2i, blocked: Callable, fixed: Array[Vector2i]) -> Dictionary:
	var result: Dictionary = {"tiles": {}, "changes": {}, "invalid": {}, "error": "", "new_count": 0}
	if cells.size() < 2:
		result["error"] = "Drag across at least two cells; direction is automatic."
		return result
	var seen: Dictionary = {}
	for index in range(cells.size()):
		var cell: Vector2i = cells[index]
		if seen.has(cell):
			_fail(result, cell, "A drag cannot cross itself. Backtrack or use a new drag.")
			continue
		seen[cell] = true
		if cell.x < 0 or cell.y < 0 or cell.x >= map_size.x or cell.y >= map_size.y:
			_fail(result, cell, "Keep the route inside the map.")
			continue
		if blocked.call(cell):
			_fail(result, cell, "Station and industry grounds cannot contain track.")
			continue
		var first: Vector2i
		var second: Vector2i
		if index == 0 or index == cells.size() - 1:
			var neighbor: Vector2i = cells[1] if index == 0 else cells[index - 1]
			first = neighbor - cell
			second = -first
			if tracks.has(cell):
				var old_ports: Array[Vector2i] = Geometry.connections(tracks[cell])
				if old_ports.has(first):
					second = old_ports[1] if old_ports[0] == first else old_ports[0]
				else:
					for port in old_ports:
						var old_neighbor: Vector2i = cell + port
						if tracks.has(old_neighbor) and Geometry.connections(tracks[old_neighbor]).has(-port):
							second = port
		else:
			first = cells[index - 1] - cell
			second = cells[index + 1] - cell
		var kind: Variant = Geometry.from_ports(first, second)
		if kind == null:
			_fail(result, cell, "Turn too tight. Draw a wider bend.")
			continue
		result["tiles"][cell] = kind
		if tracks.has(cell):
			if Geometry.same_connections(tracks[cell], kind):
				continue
			if fixed.has(cell):
				_fail(result, cell, "Platform tracks stay horizontal. Leave or enter along their rails.")
				continue
			var new_ports: Array[Vector2i] = Geometry.connections(kind)
			for port in Geometry.connections(tracks[cell]):
				var neighbor: Vector2i = cell + port
				if tracks.has(neighbor) and Geometry.connections(tracks[neighbor]).has(-port) and not new_ports.has(port):
					_fail(result, cell, "This would break an existing connection. Remove it first; switches are not available yet.")
		else:
			result["new_count"] += 1
		result["changes"][cell] = kind
	var proposed: Dictionary = tracks.duplicate()
	proposed.merge(result["tiles"], true)
	for cell in result["tiles"]:
		for port in Geometry.connections(result["tiles"][cell]):
			if port.x == 0 or port.y == 0:
				continue
			var side_a: Vector2i = cell + Vector2i(port.x, 0)
			var side_b: Vector2i = cell + Vector2i(0, port.y)
			if (proposed.has(side_a) and Geometry.connections(proposed[side_a]).has(Vector2i(-port.x, port.y))) or (proposed.has(side_b) and Geometry.connections(proposed[side_b]).has(Vector2i(port.x, -port.y))):
				_fail(result, cell, "Diagonal tracks cannot cross at a tile corner.")
	return result


static func _fail(result: Dictionary, cell: Vector2i, message: String) -> void:
	result["invalid"][cell] = true
	if result["error"].is_empty():
		result["error"] = message
