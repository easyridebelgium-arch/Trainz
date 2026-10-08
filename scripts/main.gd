extends Node2D

const TILE_SIZE: int = 32
const BUILD_START_ROW: int = 5

const GRID_COLOR: Color = Color(0.18, 0.23, 0.25)
const SLEEPER_COLOR: Color = Color(0.43, 0.29, 0.17)
const RAIL_COLOR: Color = Color(0.78, 0.82, 0.85)
const PREVIEW_COLOR: Color = Color(0.35, 0.9, 0.55, 0.8)

const TRAIN_CAPACITY: int = 20
const PASSENGER_INTERVAL: float = 5.0
const PASSENGERS_PER_BATCH: int = 3
const MAX_STATION_QUEUE: int = 100
const TICKET_PRICE: int = 5

const STARTING_BALANCE: int = 1000
const TRACK_BUILD_COST: int = 10
const TRACK_REFUND: int = 5
const OPERATING_COST_PER_SECOND: int = 1

# Station positions in grid coordinates.
const STATION_A: Vector2i = Vector2i(4, 8)
const STATION_B: Vector2i = Vector2i(20, 8)

const TRAIN_SPEED: float = 80.0
const STATION_WAIT: float = 2.0

const SAVE_PATH: String = "user://trainz_save.json"
const SAVE_TEMP_PATH: String = "user://trainz_save.tmp"

const SAVE_FIELDS: Array[String] = [
	"money",
	"total_operating_cost",
	"total_construction_cost",
	"waiting_at_a",
	"waiting_at_b",
	"passengers_on_train",
	"passengers_delivered",
	"passenger_timer",
	"operating_timer",
	"travelling_to_b",
	"wait_remaining",
	"train_needs_boarding",
	"paused"
]

# A false value means horizontal; true means vertical.
var tracks: Dictionary = {}
var placing_vertical: bool = false
var hovered_cell: Vector2i = Vector2i(-1, -1)

var route_connected: bool = false
var train_position: Vector2
var travelling_to_b: bool = true
var wait_remaining: float = 0.0
var paused: bool = false
var is_dragging: bool = false
var drag_start: Vector2i = Vector2i.ZERO

var waiting_at_a: int = 8
var waiting_at_b: int = 8
var passengers_on_train: int = 0

var passengers_delivered: int = 0
var money: int = STARTING_BALANCE

var passenger_timer: float = 0.0
var train_needs_boarding: bool = true

var operating_timer: float = 0.0
var total_operating_cost: int = 0
var total_construction_cost: int = 0

var notice: String = ""
var notice_remaining: float = 0.0

# Empty means straight track. Other values connect two compass directions.
var selected_curve: String = ""

@onready var instructions: Label = $Interface/Instructions


func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_size_changed)

	# Each station includes a horizontal platform track.
	tracks[STATION_A] = false
	tracks[STATION_B] = false

	train_position = _cell_center(STATION_A)
	_update_instructions()
	queue_redraw()


func _process(delta: float) -> void:
	hovered_cell = _mouse_to_cell()

	# Interface messages expire even while simulation is paused.
	if notice_remaining > 0.0:
		notice_remaining = maxf(0.0, notice_remaining - delta)

	if not paused:
		_generate_passengers(delta)

		if route_connected:
			_move_train(delta)
			_charge_operating_cost(delta)

	_update_instructions()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.keycode == KEY_F6:
				_save_game()
				return

			if event.keycode == KEY_F9:
				_load_game()
				return

			if event.keycode == KEY_ESCAPE:
				is_dragging = false

			if event.keycode == KEY_T and not is_dragging:
				if selected_curve.is_empty():
					selected_curve = "NE"
				else:
					selected_curve = ""

			if event.keycode == KEY_R and not is_dragging:
				if selected_curve.is_empty():
					placing_vertical = not placing_vertical
				else:
					match selected_curve:
						"NE":
							selected_curve = "SE"
						"SE":
							selected_curve = "SW"
						"SW":
							selected_curve = "NW"
						"NW":
							selected_curve = "NE"

			if event.keycode == KEY_SPACE:
				paused = not paused

	if event is InputEventMouseButton:
		var cell: Vector2i = _mouse_to_cell()

		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _can_build_at(cell):
					drag_start = cell
					is_dragging = true
			elif is_dragging:
				_finish_track_drag(cell)

		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# Right-click cancels an active construction preview.
			if is_dragging:
				is_dragging = false
				return

			if not _can_build_at(cell):
				return

			if cell == STATION_A or cell == STATION_B:
				return

			if tracks.erase(cell):
				money += TRACK_REFUND
				_show_notice("Track removed. Refunded £%d." % TRACK_REFUND)
				_check_route()


func _check_route() -> void:
	route_connected = true

	# Every cell between the stations must have horizontal track.
	for x in range(STATION_A.x, STATION_B.x + 1):
		var cell := Vector2i(x, STATION_A.y)

		if not tracks.has(cell):
			route_connected = false
			break

		if tracks[cell] != false:
			route_connected = false
			break

	# Reset the demonstration train if the connection is broken.
	if not route_connected:
		# Return any onboard passengers to their departure station.
		# These refunds may temporarily exceed the normal queue limit.
		if passengers_on_train > 0:
			if travelling_to_b:
				waiting_at_a += passengers_on_train
			else:
				waiting_at_b += passengers_on_train

		passengers_on_train = 0
		train_position = _cell_center(STATION_A)
		travelling_to_b = true
		wait_remaining = 0.0
		train_needs_boarding = true


func _move_train(delta: float) -> void:
	if wait_remaining > 0.0:
		wait_remaining = maxf(0.0, wait_remaining - delta)
		return

	# Board once, immediately before departure.
	if train_needs_boarding:
		_board_passengers()
		train_needs_boarding = false

	var destination: Vector2 = _cell_center(
		STATION_B if travelling_to_b else STATION_A
	)

	train_position = train_position.move_toward(
		destination,
		TRAIN_SPEED * delta
	)

	if train_position.distance_to(destination) < 0.01:
		train_position = destination

		_unload_passengers()

		travelling_to_b = not travelling_to_b
		wait_remaining = STATION_WAIT
		train_needs_boarding = true


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * TILE_SIZE + Vector2(
		TILE_SIZE / 2.0,
		TILE_SIZE / 2.0
	)


func _mouse_to_cell() -> Vector2i:
	var mouse_position: Vector2 = get_local_mouse_position()

	return Vector2i(
		int(floor(mouse_position.x / TILE_SIZE)),
		int(floor(mouse_position.y / TILE_SIZE))
	)


func _can_build_at(cell: Vector2i) -> bool:
	var viewport_size: Vector2 = get_viewport_rect().size
	var columns: int = int(floor(viewport_size.x / TILE_SIZE))
	var rows: int = int(floor(viewport_size.y / TILE_SIZE))

	return (
		cell.x >= 0
		and cell.x < columns
		and cell.y >= BUILD_START_ROW
		and cell.y < rows
	)


func _update_instructions() -> void:
	var direction: String = "Vertical" if placing_vertical else "Horizontal"

	if not selected_curve.is_empty():
		direction = "Curve " + selected_curve
	elif is_dragging:
		direction = (
			"Vertical" if _drag_is_vertical(hovered_cell)
			else "Horizontal"
		)

	var status: String = "Connect the stations with horizontal track."

	if route_connected:
		if wait_remaining > 0.0:
			status = "At station: departing in %.1f seconds." % wait_remaining
		else:
			status = "Travelling to " + (
				"Station B." if travelling_to_b else "Station A."
			)

	if paused:
		status = "Paused. Press Space to resume."

	if notice_remaining > 0.0:
		status = notice

	var preview_cost: int = _get_preview_cost()
	var affordability: String = ""

	if preview_cost > 0 and preview_cost > money:
		affordability = " — insufficient funds"

	instructions.text = (
		"Left-drag: build | Right-click: remove/cancel"
		+ " | T: straight/curve | R: rotate"
		+ " | Space: pause | Esc: cancel | F6/F9: save/load"
		+ "\n%s | Build: £%d%s | %s"
		% [direction, preview_cost, affordability, status]
		+ "\nWaiting: A %d / B %d | Onboard: %d/%d | Delivered: %d"
		% [
			waiting_at_a,
			waiting_at_b,
			passengers_on_train,
			TRAIN_CAPACITY,
			passengers_delivered
		]
		+ "\nBalance: £%d | Fares: £%d | Construction: £%d | Operations: £%d"
		% [
			money,
			passengers_delivered * TICKET_PRICE,
			total_construction_cost,
			total_operating_cost
		]
	)


func _on_viewport_size_changed() -> void:
	queue_redraw()


func _draw() -> void:
	_draw_grid()

	for cell in tracks:
		_draw_track(cell, tracks[cell], false)

	_draw_station(STATION_A, "Station A")
	_draw_station(STATION_B, "Station B")

	if is_dragging:
		var track_type: Variant = _drag_is_vertical(hovered_cell)

		if not selected_curve.is_empty():
			track_type = selected_curve

		for cell in _get_drag_cells(hovered_cell):
			if not tracks.has(cell):
				_draw_track(cell, track_type, true)
	else:
		if _can_build_at(hovered_cell) and not tracks.has(hovered_cell):
			var track_type: Variant = placing_vertical

			if not selected_curve.is_empty():
				track_type = selected_curve

			_draw_track(hovered_cell, track_type, true)

	_draw_train()


func _draw_grid() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var columns: int = int(ceil(viewport_size.x / TILE_SIZE))
	var rows: int = int(ceil(viewport_size.y / TILE_SIZE))
	var top: float = float(BUILD_START_ROW * TILE_SIZE)

	for column in range(columns + 1):
		var x: float = float(column * TILE_SIZE)

		draw_line(
			Vector2(x, top),
			Vector2(x, viewport_size.y),
			GRID_COLOR
		)

	for row in range(BUILD_START_ROW, rows + 1):
		var y: float = float(row * TILE_SIZE)

		draw_line(
			Vector2(0.0, y),
			Vector2(viewport_size.x, y),
			GRID_COLOR
		)


func _draw_track(
	cell: Vector2i,
	track_type: Variant,
	preview: bool
) -> void:
	if track_type is String:
		_draw_curve(cell, track_type, preview)
		return

	var vertical: bool = bool(track_type)
	var origin: Vector2 = Vector2(cell) * TILE_SIZE
	var rail_color: Color = PREVIEW_COLOR if preview else RAIL_COLOR
	var sleeper_color: Color = SLEEPER_COLOR

	if preview:
		sleeper_color.a = 0.5

		draw_rect(
			Rect2(origin, Vector2(TILE_SIZE, TILE_SIZE)),
			Color(0.35, 0.9, 0.55, 0.12)
		)

	for offset in [5, 13, 21, 29]:
		var sleeper_position: Vector2
		var sleeper_size: Vector2

		if vertical:
			sleeper_position = origin + Vector2(6, offset - 2)
			sleeper_size = Vector2(20, 4)
		else:
			sleeper_position = origin + Vector2(offset - 2, 6)
			sleeper_size = Vector2(4, 20)

		draw_rect(
			Rect2(sleeper_position, sleeper_size),
			sleeper_color
		)

	for rail_offset in [10, 22]:
		if vertical:
			draw_line(
				origin + Vector2(rail_offset, 0),
				origin + Vector2(rail_offset, TILE_SIZE),
				rail_color,
				2.0
			)
		else:
			draw_line(
				origin + Vector2(0, rail_offset),
				origin + Vector2(TILE_SIZE, rail_offset),
				rail_color,
				2.0
			)


func _draw_station(cell: Vector2i, station_name: String) -> void:
	var origin: Vector2 = Vector2(cell) * TILE_SIZE

	# A platform just above the track.
	draw_rect(
		Rect2(origin + Vector2(-8, -12), Vector2(48, 10)),
		Color(0.65, 0.68, 0.7)
	)

	# Yellow platform edge.
	draw_line(
		origin + Vector2(-8, -3),
		origin + Vector2(40, -3),
		Color(0.95, 0.8, 0.25),
		2.0
	)

	draw_string(
		ThemeDB.fallback_font,
		origin + Vector2(-12, -22),
		station_name,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		16,
		Color.WHITE
	)


func _draw_train() -> void:
	var body := Rect2(
		train_position - Vector2(13, 7),
		Vector2(26, 14)
	)

	draw_rect(body, Color(0.85, 0.22, 0.18))
	draw_rect(body, Color(0.15, 0.08, 0.08), false, 1.0)

	# The cab window indicates the next direction of travel.
	var window_offset: float = 5.0 if travelling_to_b else -11.0

	draw_rect(
		Rect2(
			train_position + Vector2(window_offset, -5),
			Vector2(6, 10)
		),
		Color(0.65, 0.85, 0.95)
	)

func _drag_is_vertical(end_cell: Vector2i) -> bool:
	var difference: Vector2i = end_cell - drag_start

	# A single click uses the orientation selected with R.
	if difference == Vector2i.ZERO:
		return placing_vertical

	# A drag snaps to the axis with the largest movement.
	return abs(difference.y) > abs(difference.x)


func _get_drag_cells(end_cell: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []

	if not selected_curve.is_empty():
		if _can_build_at(drag_start):
			cells.append(drag_start)

		return cells

	if _drag_is_vertical(end_cell):
		var first_y: int = mini(drag_start.y, end_cell.y)
		var last_y: int = maxi(drag_start.y, end_cell.y)

		for y in range(first_y, last_y + 1):
			var cell := Vector2i(drag_start.x, y)

			if _can_build_at(cell):
				cells.append(cell)
	else:
		var first_x: int = mini(drag_start.x, end_cell.x)
		var last_x: int = maxi(drag_start.x, end_cell.x)

		for x in range(first_x, last_x + 1):
			var cell := Vector2i(x, drag_start.y)

			if _can_build_at(cell):
				cells.append(cell)

	return cells


func _finish_track_drag(end_cell: Vector2i) -> void:
	var vertical: bool = _drag_is_vertical(end_cell)
	var new_cells: Array[Vector2i] = []

	for cell in _get_drag_cells(end_cell):
		if not tracks.has(cell):
			new_cells.append(cell)

	is_dragging = false

	if new_cells.is_empty():
		queue_redraw()
		return

	var cost: int = new_cells.size() * TRACK_BUILD_COST

	if money < cost:
		_show_notice(
			"Insufficient funds: need £%d, available £%d."
			% [cost, money]
		)
		queue_redraw()
		return

	for cell in new_cells:
		if selected_curve.is_empty():
			tracks[cell] = vertical
		else:
			tracks[cell] = selected_curve

	money -= cost
	total_construction_cost += cost

	_check_route()

	_show_notice(
		"Built %d track tiles for £%d."
		% [new_cells.size(), cost]
	)

	queue_redraw()

func _generate_passengers(delta: float) -> void:
	passenger_timer += delta

	while passenger_timer >= PASSENGER_INTERVAL:
		passenger_timer -= PASSENGER_INTERVAL

		if waiting_at_a < MAX_STATION_QUEUE:
			waiting_at_a = mini(
				waiting_at_a + PASSENGERS_PER_BATCH,
				MAX_STATION_QUEUE
			)

		if waiting_at_b < MAX_STATION_QUEUE:
			waiting_at_b = mini(
				waiting_at_b + PASSENGERS_PER_BATCH,
				MAX_STATION_QUEUE
			)


func _board_passengers() -> void:
	var available_seats: int = TRAIN_CAPACITY - passengers_on_train
	var boarding: int = 0

	if travelling_to_b:
		# Departing Station A.
		boarding = mini(waiting_at_a, available_seats)
		waiting_at_a -= boarding
	else:
		# Departing Station B.
		boarding = mini(waiting_at_b, available_seats)
		waiting_at_b -= boarding

	passengers_on_train += boarding


func _unload_passengers() -> void:
	passengers_delivered += passengers_on_train
	money += passengers_on_train * TICKET_PRICE
	passengers_on_train = 0

func _charge_operating_cost(delta: float) -> void:
	operating_timer += delta

	while operating_timer >= 1.0:
		operating_timer -= 1.0
		money -= OPERATING_COST_PER_SECOND
		total_operating_cost += OPERATING_COST_PER_SECOND


func _show_notice(message: String) -> void:
	notice = message
	notice_remaining = 4.0
	
func _get_preview_cost() -> int:
	var tile_count: int = 0

	if is_dragging:
		for cell in _get_drag_cells(hovered_cell):
			if not tracks.has(cell):
				tile_count += 1
	elif _can_build_at(hovered_cell) and not tracks.has(hovered_cell):
		tile_count = 1

	return tile_count * TRACK_BUILD_COST

func _save_game() -> void:
	if is_dragging:
		_show_notice("Finish or cancel track placement before saving.")
		return

	var saved_tracks: Array = []

	for cell in tracks:
		saved_tracks.append([
			cell.x,
			cell.y,
			tracks[cell]
		])

	var state: Dictionary = {}

	for field in SAVE_FIELDS:
		state[field] = get(field)

	var data: Dictionary = {
		"version": 2,
		"tracks": saved_tracks,
		"train_x": train_position.x,
		"state": state
	}

	# Write a temporary file first to protect the previous save
	# if writing fails.
	var file := FileAccess.open(SAVE_TEMP_PATH, FileAccess.WRITE)

	if file == null:
		_show_notice("Could not open the save file.")
		return

	file.store_string(JSON.stringify(data, "\t"))
	file.flush()

	var write_error: Error = file.get_error()
	file.close()

	if write_error != OK:
		_show_notice("Saving failed while writing the file.")
		return

	var rename_error: Error = DirAccess.rename_absolute(
		ProjectSettings.globalize_path(SAVE_TEMP_PATH),
		ProjectSettings.globalize_path(SAVE_PATH)
	)

	if rename_error != OK:
		_show_notice("Could not replace the previous save.")
		return

	_show_notice("Game saved.")
	
func _is_valid_number(value: Variant) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false

	return is_finite(float(value))


func _is_valid_save(data: Dictionary) -> bool:
	if data.get("version") not in [1, 2]:
		return false

	if not data.get("tracks") is Array:
		return false

	if not data.get("state") is Dictionary:
		return false

	if not _is_valid_number(data.get("train_x")):
		return false

	var train_x: float = float(data["train_x"])

	if train_x < _cell_center(STATION_A).x:
		return false

	if train_x > _cell_center(STATION_B).x:
		return false

	var state: Dictionary = data["state"]

	for field in SAVE_FIELDS:
		if not state.has(field):
			return false

		var current_value: Variant = get(field)
		var saved_value: Variant = state[field]

		if typeof(current_value) == TYPE_BOOL:
			if typeof(saved_value) != TYPE_BOOL:
				return false
		else:
			if not _is_valid_number(saved_value):
				return false

			var number: float = float(saved_value)

			# Keep values within a reasonable range for this prototype.
			if absf(number) > 1_000_000_000.0:
				return false

			if typeof(current_value) == TYPE_INT:
				if number != floor(number):
					return false

			if field != "money" and number < 0.0:
				return false

	if float(state["passengers_on_train"]) > TRAIN_CAPACITY:
		return false

	if float(state["wait_remaining"]) > STATION_WAIT:
		return false

	if float(state["passenger_timer"]) >= PASSENGER_INTERVAL:
		return false

	if float(state["operating_timer"]) >= 1.0:
		return false

	var checked_tracks: Dictionary = {}

	for entry in data["tracks"]:
		if not entry is Array:
			return false

		if entry.size() != 3:
			return false

		if not _is_valid_number(entry[0]):
			return false

		if not _is_valid_number(entry[1]):
			return false

		if not _is_valid_track_type(entry[2]):
			return false

		var x: float = float(entry[0])
		var y: float = float(entry[1])

		if x != floor(x) or y != floor(y):
			return false

		if x < 0 or x > 10000:
			return false

		if y < BUILD_START_ROW or y > 10000:
			return false

		var cell := Vector2i(int(x), int(y))

		if checked_tracks.has(cell):
			return false

		checked_tracks[cell] = entry[2]

	# Both stations must retain their horizontal tracks.
	for station in [STATION_A, STATION_B]:
		if not checked_tracks.has(station):
			return false

		if checked_tracks[station] != false:
			return false

	return true
	
func _load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_show_notice("No saved game yet. Press F6 to save.")
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)

	if file == null:
		_show_notice("Could not open the saved game.")
		return

	var contents: String = file.get_as_text()
	file.close()

	var parser := JSON.new()

	if parser.parse(contents) != OK:
		_show_notice("The save file could not be read.")
		return

	if not parser.data is Dictionary:
		_show_notice("The save file has an invalid format.")
		return

	var data: Dictionary = parser.data

	if not _is_valid_save(data):
		_show_notice("The save file is damaged or incompatible.")
		return

	# Validation succeeded. It is now safe to replace the game state.
	var loaded_tracks: Dictionary = {}

	for entry in data["tracks"]:
		var cell := Vector2i(int(entry[0]), int(entry[1]))
		loaded_tracks[cell] = entry[2]

	tracks = loaded_tracks

	var state: Dictionary = data["state"]

	for field in SAVE_FIELDS:
		var current_value: Variant = get(field)

		match typeof(current_value):
			TYPE_INT:
				set(field, int(state[field]))
			TYPE_FLOAT:
				set(field, float(state[field]))
			TYPE_BOOL:
				set(field, state[field])

	train_position = Vector2(
		float(data["train_x"]),
		_cell_center(STATION_A).y
	)

	is_dragging = false

	# Recalculate connectivity from the loaded track layout.
	_check_route()

	_update_instructions()
	_show_notice("Game loaded.")
	queue_redraw()

func _draw_curve(
	cell: Vector2i,
	curve: String,
	preview: bool
) -> void:
	var origin: Vector2 = Vector2(cell) * TILE_SIZE
	var center: Vector2
	var start_angle: float

	match curve:
		"NE":
			center = origin + Vector2(TILE_SIZE, 0)
			start_angle = PI / 2.0
		"SE":
			center = origin + Vector2(TILE_SIZE, TILE_SIZE)
			start_angle = PI
		"SW":
			center = origin + Vector2(0, TILE_SIZE)
			start_angle = PI * 1.5
		"NW":
			center = origin
			start_angle = 0.0
		_:
			return

	var end_angle: float = start_angle + PI / 2.0
	var rail_color: Color = PREVIEW_COLOR if preview else RAIL_COLOR
	var sleeper_color: Color = SLEEPER_COLOR

	if preview:
		sleeper_color.a = 0.5

		draw_rect(
			Rect2(origin, Vector2(TILE_SIZE, TILE_SIZE)),
			Color(0.35, 0.9, 0.55, 0.12)
		)

	# Sleepers cross the curved rails.
	for index in range(4):
		var fraction: float = (float(index) + 0.5) / 4.0
		var angle: float = lerpf(start_angle, end_angle, fraction)
		var direction := Vector2(cos(angle), sin(angle))

		draw_line(
			center + direction * 6.0,
			center + direction * 26.0,
			sleeper_color,
			4.0
		)

	# Match the spacing of the straight rails at each cell edge.
	for radius in [10.0, 22.0]:
		draw_arc(
			center,
			radius,
			start_angle,
			end_angle,
			13,
			rail_color,
			2.0,
			false
		)
		
func _is_valid_track_type(value: Variant) -> bool:
	if typeof(value) == TYPE_BOOL:
		return true

	if typeof(value) == TYPE_STRING:
		return value in ["NE", "SE", "SW", "NW"]

	return false
