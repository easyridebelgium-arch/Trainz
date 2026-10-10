extends SceneTree

const Geometry = preload("res://scripts/track_geometry.gd")
const Builder = preload("res://scripts/track_builder.gd")
const Router = preload("res://scripts/rail_router.gd")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _open(_cell: Vector2i) -> bool:
	return false


func _plan(cells: Array[Vector2i], tracks: Dictionary = {}) -> Dictionary:
	var fixed: Array[Vector2i] = []
	return Builder.plan(cells, tracks, Vector2i(80, 50), _open, fixed)


func _run() -> void:
	for direction in Geometry.DIRECTIONS:
		var cells: Array[Vector2i] = Builder.line(Vector2i(15, 15), Vector2i(15, 15) + direction * 5, {})
		var plan: Dictionary = _plan(cells)
		check(plan["error"].is_empty(), "All eight straight directions must build: " + str(direction))
		var found: Array[Vector2i] = Router.find_route(plan["tiles"], cells.front(), cells.back())
		check(found == cells, "Every diagonal/cardinal tile must connect bidirectionally")
		var path: Curve2D = Router.make_path(found, 32.0)
		check(absf(path.get_baked_length() - Vector2(direction * 5).length() * 32.0) < 0.1, "Straight route length must match actual geometry")
	var stroke: Array[Vector2i] = [Vector2i(10, 10)]
	Builder.append_stroke(stroke, Vector2i(14, 10))
	Builder.append_stroke(stroke, Vector2i(18, 14))
	Builder.append_stroke(stroke, Vector2i(18, 18))
	var stroke_plan: Dictionary = _plan(stroke)
	check(stroke_plan["error"].is_empty(), "Mouse stroke should combine horizontal, diagonal, and vertical pieces")
	check(Router.find_route(stroke_plan["tiles"], stroke.front(), stroke.back()) == stroke, "Mixed stroke must form one routable line")
	Builder.append_stroke(stroke, Vector2i(18, 16))
	check(stroke.back() == Vector2i(18, 16) and stroke.size() == 11, "Backtracking removes the preview tail")
	var crossing: Dictionary = {Vector2i(11, 10): Geometry.from_ports(Vector2i(-1, 1), Vector2i(1, -1))}
	check(not _plan(Builder.segment(Vector2i(10, 10), Vector2i(12, 12)), crossing)["error"].is_empty(), "Opposite diagonals at one corner must be rejected")
	var old_line: Dictionary = _plan(Builder.segment(Vector2i(5, 10), Vector2i(15, 10)))["tiles"]
	var retrace: Dictionary = _plan(Builder.line(Vector2i(5, 10), Vector2i(15, 10), old_line), old_line)
	check(retrace["error"].is_empty() and retrace["changes"].is_empty(), "Retracing existing straight track should be a free no-op")
	check(not _plan(Builder.segment(Vector2i(10, 5), Vector2i(10, 15)), old_line)["error"].is_empty(), "Crossing an existing connected line must be rejected")
	check(not _plan(Builder.segment(Vector2i(79, 10), Vector2i(82, 10)))["error"].is_empty(), "Map boundary must reject the entire action")
	var sharp: Array[Vector2i] = [Vector2i(10, 10), Vector2i(11, 10), Vector2i(10, 11)]
	check(not _plan(sharp)["error"].is_empty(), "A 135-degree hairpin is invalid")
	check(Geometry.connections("rail_0_1").is_empty(), "Malformed/tight track codes must not load")
	check(Geometry.connections("rail_1_5").size() == 2, "Diagonal track codes must load")

	var scene: PackedScene = load("res://scenes/main/main.tscn")
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.paused = true
	game.money = 5000
	check(not game.rotate_button.visible, "Rotate control must be hidden")
	check(game.backup_button.pressed.get_connections().size() == 1, "Backup button must connect only once")
	var initial: Dictionary = game.tracks.duplicate()
	# Simple mouse-directed construction can leave a fixed horizontal platform.
	game.draw_track_mode = false
	game.drag_start = game.STATION_A
	game.is_dragging = true
	game._finish_track_drag(Vector2i(10, 12))
	check(game.tracks.size() > initial.size(), "Automatic diagonal departure from a platform must build")
	game._undo_construction()
	check(game.tracks == initial and game.money == 5000, "Undo must restore the original rails and exact funds")

	# One freehand gesture creates a complete passenger detour with true diagonals.
	var passenger: Array[Vector2i] = [game.STATION_A]
	for point in [Vector2i(8, 8), Vector2i(12, 12), Vector2i(16, 8), game.STATION_B]:
		Builder.append_stroke(passenger, point)
	game.draw_track_mode = true
	game.drag_start = passenger.front()
	game.build_stroke.clear()
	game.build_stroke.append(game.drag_start)
	game.is_dragging = true
	for point in [Vector2i(8, 8), Vector2i(12, 12), Vector2i(16, 8), game.STATION_B]:
		game._refresh_build_plan(point, true)
	check(game.build_stroke == passenger, "Live mouse preview must preserve a changing-direction stroke")
	game._finish_track_drag(passenger.back())
	check(game.route_connected, "Passenger service must route through the drawn diagonal detour")
	var cost: int = (passenger.size() - 2) * game.TRACK_BUILD_COST
	check(game.money == 5000 - cost, "Only newly placed tiles should be charged")
	var built: Dictionary = game.tracks.duplicate()
	game._undo_construction()
	check(game.tracks == initial and game.money == 5000, "A whole changing-direction drag is one undo action")
	game._redo_construction()
	check(game.tracks == built and game.route_connected, "Redo must restore bends, diagonals, and connectivity")
	# An invalid station footprint drag must be atomic.
	var before_money: int = game.money
	game.draw_track_mode = false
	game.drag_start = Vector2i(1, 7)
	game.is_dragging = true
	game._finish_track_drag(Vector2i(8, 7))
	check(game.tracks == built and game.money == before_money, "Reserved grounds must reject placement without charging")
	# Passenger must actually deliver through the curved geometry.
	for index in range(500):
		game._move_train(0.1)
	check(game.passengers_delivered > 0, "Passenger delivery must work on the diagonal path")
	var freight: Array[Vector2i] = [game.FOREST_SITE]
	for point in [Vector2i(12, 24), Vector2i(18, 30), Vector2i(24, 24), game.CARGO_TERMINAL]:
		Builder.append_stroke(freight, point)
	game.draw_track_mode = true
	game.build_stroke = freight.duplicate()
	game.drag_start = freight.front()
	game.is_dragging = true
	game._finish_track_drag(freight.back())
	check(not game.freight_train.route_cells.is_empty(), "Freight service must find its diagonal detour")
	game.forest_stock = 50
	game.logs_produced = 50
	for index in range(650):
		game.forest_stock -= game.freight_train.advance(0.1, game.forest_stock)
	check(game.logs_delivered > 0 and game.freight_income > 0, "Freight must deliver cargo and earn income on diagonal rails")
	check(game.forest_stock + game.freight_train.cargo + game.logs_delivered == 50, "Freight movement must conserve cargo")
	var all_built: Dictionary = game.tracks.duplicate()
	game._save_game()
	var saved_money: int = game.money
	var saved_position: Vector2 = game.train_position
	var saved_freight_position: Vector2 = game.freight_train.position
	game.money = 1
	game.tracks.clear()
	game._load_game()
	check(game.money == saved_money and game.tracks == all_built, "New-format save must restore tracks and money")
	check(game.train_position.distance_to(saved_position) < 0.1, "Save must restore passenger position")
	check(game.freight_train.position.distance_to(saved_freight_position) < 0.1, "Save must restore freight position")
	game.paused = true
	game.demolition_cells = {Vector2i(9, 9): true, Vector2i(10, 10): true}
	game.demolition_last_cell = Vector2i(10, 10)
	game._finish_demolition(Vector2i(10, 10))
	check(not game.tracks.has(Vector2i(9, 9)) and not game.route_connected, "Drag demolition must remove diagonal pieces")
	game._undo_construction()
	check(game.tracks == all_built and game.route_connected, "Undo demolition must restore diagonal geometry")
	var key := InputEventKey.new()
	key.keycode = KEY_R
	key.pressed = true
	game._unhandled_input(key)
	check(game.tracks == all_built and game.draw_track_mode, "R must no longer rotate or change construction mode")
	game.queue_free()
	await process_frame
	print("Mouse track tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
