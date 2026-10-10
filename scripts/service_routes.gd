extends RefCounted

const Router = preload("res://scripts/rail_router.gd")
const STATIONS: Dictionary = {
	"a": {"name": "Station A", "cell": Vector2i(4, 8)},
	"b": {"name": "Station B", "cell": Vector2i(20, 8)},
	"c": {"name": "Station C", "cell": Vector2i(36, 8)},
}

static func defaults() -> Dictionary:
	return {
		"passenger": {"name": "Passenger Shuttle", "stops": ["a", "b"]},
		"freight": {"name": "Timber Service", "stops": ["forest", "terminal"]},
	}

static func is_valid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for key in ["passenger", "freight"]:
		if not value.get(key) is Dictionary:
			return false
		var service: Dictionary = value[key]
		if not service.get("name") is String or not service.get("stops") is Array:
			return false
		var title: String = service["name"]
		if title != title.strip_edges() or title.is_empty() or title.length() > 40 or "\n" in title or "\r" in title:
			return false
	var stops: Array = value["passenger"]["stops"]
	if stops.size() < 2 or stops.size() > STATIONS.size():
		return false
	var seen: Dictionary = {}
	for stop in stops:
		if not stop is String or not STATIONS.has(stop) or seen.has(stop):
			return false
		seen[stop] = true
	return value["freight"]["stops"] == ["forest", "terminal"]

static func build(tracks: Dictionary, stops: Array, tile_size: float) -> Dictionary:
	var cells: Array[Vector2i] = []
	var path := Curve2D.new()
	path.bake_interval = 1.0
	var distances: Array[float] = [0.0]
	for index in range(stops.size() - 1):
		var from_stop: Dictionary = STATIONS[stops[index]]
		var to_stop: Dictionary = STATIONS[stops[index + 1]]
		var leg: Array[Vector2i] = Router.find_route(tracks, from_stop["cell"], to_stop["cell"])
		if leg.is_empty():
			return {"cells": [], "path": Curve2D.new(), "distances": [], "error": "Missing track: %s → %s" % [from_stop["name"], to_stop["name"]]}
		for cell in leg:
			if cells.is_empty() or cells.back() != cell:
				cells.append(cell)
		# Build each leg separately: an ordered stop can require reversal.
		var leg_path: Curve2D = Router.make_path(leg, tile_size)
		for point_index in range(leg_path.point_count):
			var point: Vector2 = leg_path.get_point_position(point_index)
			if path.point_count == 0 or path.get_point_position(path.point_count - 1).distance_to(point) > 0.001:
				path.add_point(point)
		distances.append(path.get_baked_length())
	return {"cells": cells, "path": path, "distances": distances, "error": ""}
