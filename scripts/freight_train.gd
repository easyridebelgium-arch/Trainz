extends Node2D

signal delivered(amount: int)
signal operating_expense(amount: int)
const Router = preload("res://scripts/rail_router.gd")

const CAPACITY: int = 20
const SPEED: float = 60.0
const STATION_WAIT: float = 2.0
const OPERATING_COST_PER_SECOND: int = 1
const MAX_CAPACITY_LEVEL: int = 3
const MAX_SPEED_LEVEL: int = 3

const CAPACITY_PER_UPGRADE: int = 10
const SPEED_PER_UPGRADE: float = 20.0

const BASE_CAPACITY_UPGRADE_PRICE: int = 300
const BASE_SPEED_UPGRADE_PRICE: int = 250

enum LoadingRule {
	ANY,
	HALF,
	FULL
}

var loading_rule: int = LoadingRule.ANY
var home_position: Vector2 = Vector2.ZERO
var cargo: int = 0

var route_cells: Array[Vector2i] = []
var route_path: Curve2D = Curve2D.new()

var distance_along_route: float = 0.0
var to_terminal: bool = true
var dwell: float = 0.0
var operating_timer: float = 0.0
var capacity_level: int = 0
var speed_level: int = 0
var service_enabled: bool = true

func set_route(cells: Array[Vector2i], tile_size: float) -> void:
	if cells == route_cells:
		return

	route_cells = cells.duplicate()
	route_path = Router.make_path(route_cells, tile_size)

	distance_along_route = 0.0
	to_terminal = true
	dwell = 0.0

	# Keep onboard logs when a route changes or is disconnected.
	_update_transform()


func advance(delta: float, available_logs: int) -> int:
	if not service_is_active():
		return 0

	_charge_operating_expenses(delta)

	if dwell > 0.0:
		dwell = maxf(0.0, dwell - delta)
		return 0

	var loaded: int = 0

	# Load at the forest before departing.
	if to_terminal and distance_along_route <= 0.001:
		loaded = mini(get_capacity() - cargo, available_logs)
		cargo += loaded

		if cargo < get_minimum_load():
			return loaded

	var route_length: float = route_path.get_baked_length()
	var target: float = route_length if to_terminal else 0.0

	distance_along_route = move_toward(
		distance_along_route,
		target,
		get_speed() * delta
	)

	if absf(distance_along_route - target) < 0.001:
		distance_along_route = target

		if to_terminal:
			var delivered_amount: int = cargo
			cargo = 0

			if delivered_amount > 0:
				delivered.emit(delivered_amount)

		to_terminal = not to_terminal
		dwell = STATION_WAIT

	_update_transform()
	return loaded


func _update_transform() -> void:
	if route_cells.is_empty():
		position = home_position
		rotation = 0.0
		return

	var route_length: float = route_path.get_baked_length()

	position = route_path.sample_baked(distance_along_route)

	var before: Vector2 = route_path.sample_baked(
		maxf(0.0, distance_along_route - 1.0)
	)
	var after: Vector2 = route_path.sample_baked(
		minf(route_length, distance_along_route + 1.0)
	)

	var direction: Vector2 = after - before

	if not to_terminal:
		direction = -direction

	rotation = direction.angle()


func _draw() -> void:
	var body := Rect2(Vector2(-14, -8), Vector2(28, 16))

	draw_rect(body, Color(0.15, 0.45, 0.85))
	draw_rect(body, Color(0.05, 0.12, 0.22), false, 1.0)

	draw_rect(
		Rect2(Vector2(6, -5), Vector2(6, 10)),
		Color(0.75, 0.9, 1.0)
	)


func status_text() -> String:
	if route_cells.is_empty():
		return "Needs a separate connected freight route"
	if not service_enabled:
		if service_is_active():
			return "Withdrawing after return to forest"

		return "Freight service stopped at forest"

	if dwell > 0.0:
		return "Stopped at loading track"

	if to_terminal:
		if distance_along_route <= 0.001 and cargo < get_minimum_load():
			return "Loading: %d / %d logs required" % [
				cargo,
				get_minimum_load()
			]

		return "Travelling to terminal"

	return "Returning to forest"


func save_state() -> Dictionary:
	return {
		"cargo": cargo,
		"distance": distance_along_route,
		"to_terminal": to_terminal,
		"dwell": dwell,
		"operating_timer": operating_timer,
		"loading_rule": loading_rule,
		"capacity_level": capacity_level,
		"speed_level": speed_level,
		"service_enabled": service_enabled
	}


func restore_state(state: Dictionary) -> void:
	cargo = int(state["cargo"])
	distance_along_route = clampf(
		float(state["distance"]),
		0.0,
		route_path.get_baked_length()
	)
	to_terminal = state["to_terminal"]
	dwell = float(state["dwell"])
	operating_timer = float(state["operating_timer"])
	loading_rule = int(state["loading_rule"])
	capacity_level = int(state["capacity_level"])
	speed_level = int(state["speed_level"])
	service_enabled = state["service_enabled"]
	_update_transform()


static func empty_state() -> Dictionary:
	return {
		"cargo": 0,
		"distance": 0.0,
		"to_terminal": true,
		"dwell": 0.0,
		"operating_timer": 0.0,
		"loading_rule": LoadingRule.ANY,
		"capacity_level": 0,
		"speed_level": 0,
		"service_enabled": true
	}


static func is_valid_state(state: Dictionary, route_length: float) -> bool:
	if typeof(state.get("service_enabled")) != TYPE_BOOL:
		return false
	if typeof(state.get("to_terminal")) != TYPE_BOOL:
		return false

	for field in [
		"cargo",
		"distance",
		"dwell",
		"operating_timer",
		"loading_rule",
		"capacity_level",
		"speed_level"
	]:
		var value: Variant = state.get(field)

		if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
			return false

		var number: float = float(value)

		if not is_finite(number) or number < 0.0:
			return false

	# These fields must contain whole numbers.
	for field in [
		"cargo",
		"loading_rule",
		"capacity_level",
		"speed_level"
	]:
		var number: float = float(state[field])

		if number != floor(number):
			return false

	var saved_capacity_level: float = float(state["capacity_level"])
	var saved_speed_level: float = float(state["speed_level"])

	if saved_capacity_level > MAX_CAPACITY_LEVEL:
		return false

	if saved_speed_level > MAX_SPEED_LEVEL:
		return false

	var saved_capacity: int = (
		CAPACITY + int(saved_capacity_level) * CAPACITY_PER_UPGRADE
	)

	if float(state["cargo"]) > saved_capacity:
		return false

	if float(state["distance"]) > route_length + 0.001:
		return false

	if float(state["dwell"]) > STATION_WAIT:
		return false

	if float(state["operating_timer"]) >= 1.0:
		return false

	var saved_rule: float = float(state["loading_rule"])

	if saved_rule < LoadingRule.ANY or saved_rule > LoadingRule.FULL:
		return false

	return true
	
func _charge_operating_expenses(delta: float) -> void:
	operating_timer += delta

	while operating_timer >= 1.0:
		operating_timer -= 1.0
		operating_expense.emit(OPERATING_COST_PER_SECOND)
func get_minimum_load() -> int:
	match loading_rule:
		LoadingRule.HALF:
			return ceili(float(get_capacity()) / 2.0)

		LoadingRule.FULL:
			return get_capacity()

		_:
			return 1
func get_capacity() -> int:
	return CAPACITY + capacity_level * CAPACITY_PER_UPGRADE


func get_speed() -> float:
	return SPEED + speed_level * SPEED_PER_UPGRADE


func get_capacity_upgrade_price() -> int:
	return BASE_CAPACITY_UPGRADE_PRICE * (capacity_level + 1)


func get_speed_upgrade_price() -> int:
	return BASE_SPEED_UPGRADE_PRICE * (speed_level + 1)
func service_is_active() -> bool:
	if route_cells.is_empty():
		return false

	if service_enabled:
		return true

	var parked_at_forest: bool = (
		distance_along_route <= 0.001
		and to_terminal
	)

	return not parked_at_forest
