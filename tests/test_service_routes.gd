extends SceneTree

const Services = preload("res://scripts/service_routes.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	var defaults: Dictionary = Services.defaults()
	check(Services.is_valid(defaults), "Default routes must validate")
	for bad_stops in [["a"], ["a", "a"], ["a", "forest"], ["a", 7]]:
		var bad: Dictionary = defaults.duplicate(true)
		bad["passenger"]["stops"] = bad_stops
		check(not Services.is_valid(bad), "Invalid stop lists must be rejected")
	for bad_name in ["", "  ", "a\nb", "x".repeat(41)]:
		var bad: Dictionary = defaults.duplicate(true)
		bad["passenger"]["name"] = bad_name
		check(not Services.is_valid(bad), "Invalid names must be rejected")
	var bad_freight: Dictionary = defaults.duplicate(true)
	bad_freight["freight"]["stops"].reverse()
	check(not Services.is_valid(bad_freight), "Cargo roles must retain load-then-unload order")
	var scene: PackedScene = load("res://scenes/main/main.tscn")
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.paused = true
	for x in range(4, 37):
		game.tracks[Vector2i(x, 8)] = false
	game._check_route()
	check(game.route_connected, "Existing two-stop service must still work")
	check(game._is_station_space(game.STATION_C + Vector2i.UP), "New station must reserve its grounds")
	check(not game._can_demolish(game.STATION_C), "New station platform must be protected")
	# Use the actual editor signals to create and rename a three-stop service.
	game._open_routes_editor()
	await process_frame
	var editor = game.route_editor
	check(editor.visible and game.paused, "Opening Routes pauses simulation and opens the dialog")
	check(editor.size.x <= 1280 and editor.size.y <= 720, "Route dialog must fit the default viewport")
	check(game.routes_button.get_global_rect().end.x <= 1280, "Routes toolbar button must fit the default viewport")
	var camera_before: Vector2 = game.camera.position
	var zoom_before: Vector2 = game.camera.zoom
	var wheel := InputEventMouseButton.new()
	wheel.pressed = true
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	game._input(wheel)
	var space := InputEventKey.new()
	space.pressed = true
	space.keycode = KEY_SPACE
	game._unhandled_input(space)
	check(game.paused and game.camera.position == camera_before and game.camera.zoom == zoom_before, "Dialog input must not resume the game or move the map")
	editor.name_field.text = "  Regional Express  "
	editor.service_choice.select(1)
	editor.service_choice.item_selected.emit(1)
	check(not editor.editing_controls.visible, "Freight must expose its fixed load/unload order")
	editor.name_field.text = "Log Runner"
	editor.service_choice.select(0)
	editor.service_choice.item_selected.emit(0)
	check(editor.name_field.text == "Regional Express" and editor.draft["freight"]["name"] == "Log Runner", "Switching services must retain each draft name")
	editor.station_choice.select(2)
	editor.add_button.pressed.emit()
	check(editor.draft["passenger"]["stops"] == ["a", "b", "c"], "Editor Add must append Station C")
	editor.add_button.pressed.emit()
	check(editor.draft["passenger"]["stops"].size() == 3, "Editor must reject duplicate stops")
	editor.confirmed.emit()
	check(game.services["passenger"]["name"] == "Regional Express", "Apply must trim and persist the route name")
	check(game.services["passenger"]["stops"] == ["a", "b", "c"], "Apply must persist stop order")
	check(game.stop_distances.size() == 3 and game.route_connected, "Three stops must produce three stopping distances")
	editor.hide()
	game.waiting_at_a = 8
	game.waiting_at_b = 8
	game.waiting_at_c = 8
	var visits: Array[int] = []
	var last_index: int = game.passenger_stop_index
	for step in range(350):
		game._move_train(0.1)
		if game.passenger_stop_index != last_index:
			last_index = game.passenger_stop_index
			visits.append(last_index)
			check(game.train_position.distance_to(game._cell_center(Services.STATIONS[game.services["passenger"]["stops"][last_index]]["cell"])) < 0.1, "Train must stop at the station centre")
			check(game.wait_remaining > 0.0, "Each intermediate and terminal stop must dwell")
			if visits.size() == 4:
				break
	check(visits == [1, 2, 1, 0], "Train must visit A → B → C → B → A")
	check(game.passengers_delivered == 24, "Each station's passengers must be delivered once")
	# Renaming preserves movement, while changing order returns onboard passengers.
	game.waiting_at_a = 10
	game.wait_remaining = 0.0
	game._move_train(0.2)
	var distance: float = game.route_distance
	var position_before: Vector2 = game.train_position
	var onboard: int = game.passengers_on_train
	var renamed: Dictionary = game.services.duplicate(true)
	renamed["freight"]["name"] = "Forest Logistics"
	game.apply_service_routes(renamed)
	check(game.route_distance == distance and game.passengers_on_train == onboard, "Renaming must not reset trains or passengers")
	game._save_game()
	game.services = Services.defaults()
	game.waiting_at_c = 99
	game._load_game()
	check(game.services == renamed and game.waiting_at_c == 0, "Save/load must restore both route names, ordered stops and third-station queue")
	check(game.train_position.distance_to(position_before) < 0.1 and game.passengers_on_train == onboard, "Save/load must restore the journey and onboard passengers")
	# Reorder with reversal at an intermediate station (A → C → B).
	var reordered: Dictionary = renamed.duplicate(true)
	reordered["passenger"]["stops"] = ["a", "c", "b"]
	game.apply_service_routes(reordered)
	check(game.waiting_at_a == 10 and game.passengers_on_train == 0, "Reordering must return passengers without loss or duplication")
	check(game.route_distance == 0.0 and game.passenger_stop_index == 0, "Reordering resets to the first stop")
	for step in range(150):
		game._move_train(0.1)
		if game.passenger_stop_index == 1:
			break
	check(game.train_position.distance_to(game._cell_center(game.STATION_C)) < 0.1, "A → C → B must pass B without stopping and stop at C first")
	game.wait_remaining = 0.0
	game._move_train(0.1)
	check(game.train_position.x < game._cell_center(game.STATION_C).x, "Intermediate reversal must travel back toward B")
	game._save_game()
	var saved_index: int = game.passenger_stop_index
	position_before = game.train_position
	game._move_train(0.5)
	game._load_game()
	check(game.passenger_stop_index == saved_index and game.train_position.distance_to(position_before) < 0.1, "Mid-leg save after an intermediate reversal must restore exactly")
	# Invalid saves must not partially replace live route state.
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
	data["services"]["passenger"]["stops"] = ["a", "a"]
	var invalid_path: String = "user://invalid_routes_test.json"
	var file := FileAccess.open(invalid_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t", true, true))
	file.close()
	game._load_game(invalid_path)
	check(game.services == reordered and game.train_position.distance_to(position_before) < 0.1, "Malformed saved routes must be rejected atomically")
	# Disconnection returns passengers to their actual departure stop.
	game.waiting_at_c = 7
	game.passengers_on_train = 4
	game.tracks.erase(Vector2i(30, 8))
	game._check_route()
	check(not game.route_connected and game.waiting_at_c == 11 and game.passengers_on_train == 0, "Broken later leg must stop the service and preserve passengers")
	check("Missing track" in game._passenger_service_status(), "Disconnected route must explain the missing leg")
	game.tracks[Vector2i(30, 8)] = false
	game._check_route()
	check(game.route_connected, "Repairing a later leg must restore the complete service")
	# Editor cancellation and ordering controls operate on a draft.
	game._open_routes_editor()
	editor.stop_list.select(2)
	editor.up_button.pressed.emit()
	check(editor.draft["passenger"]["stops"] == ["a", "b", "c"], "Up must reorder the selected stop")
	editor.hide()
	check(game.services == reordered, "Closing without Apply must leave the live route unchanged")
	# Withdrawing a service parks at its configured first station.
	var reversed_route: Dictionary = defaults.duplicate(true)
	reversed_route["passenger"]["stops"] = ["c", "b", "a"]
	game.apply_service_routes(reversed_route)
	game.passenger_service_enabled = true
	game._move_train(0.2)
	game.passenger_service_enabled = false
	for step in range(700):
		if game._passenger_service_is_active():
			game._move_train(0.1)
	check(not game._passenger_service_is_active() and game.train_position.distance_to(game._cell_center(game.STATION_C)) < 0.1, "Withdrawal must park at the configured first stop, not always Station A")
	game.queue_free()
	await process_frame
	print("Service route tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
