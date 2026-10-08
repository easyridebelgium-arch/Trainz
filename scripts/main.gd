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

# Station positions in grid coordinates.
const STATION_A: Vector2i = Vector2i(4, 8)
const STATION_B: Vector2i = Vector2i(20, 8)

const TRAIN_SPEED: float = 80.0
const STATION_WAIT: float = 2.0

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
var money: int = 0

var passenger_timer: float = 0.0
var train_needs_boarding: bool = true

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

	if not paused:
		_generate_passengers(delta)

		if route_connected:
			_move_train(delta)

	_update_instructions()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				is_dragging = false

			if event.keycode == KEY_R and not is_dragging:
				placing_vertical = not placing_vertical

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
				_check_route()


func _check_route() -> void:
	route_connected = true

	# Every cell between the stations must have horizontal track.
	for x in range(STATION_A.x, STATION_B.x + 1):
		var cell := Vector2i(x, STATION_A.y)

		if not tracks.has(cell):
			route_connected = false
			break

		if tracks[cell] == true:
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

	instructions.text = (
		"Left-drag: build | Right-click: remove/cancel"
		+ " | R: rotate | Space: pause | Esc: cancel"
		+ "\nPlacement: " + direction + " | " + status
		+ "\nWaiting: A %d / B %d | Onboard: %d/%d"
		% [
			waiting_at_a,
			waiting_at_b,
			passengers_on_train,
			TRAIN_CAPACITY
		]
		+ "\nDelivered: %d | Ticket income: £%d"
		% [passengers_delivered, money]
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
		var vertical: bool = _drag_is_vertical(hovered_cell)

		for cell in _get_drag_cells(hovered_cell):
			if not tracks.has(cell):
				_draw_track(cell, vertical, true)
	else:
		if _can_build_at(hovered_cell) and not tracks.has(hovered_cell):
			_draw_track(hovered_cell, placing_vertical, true)

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
	vertical: bool,
	preview: bool
) -> void:
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
	var changed: bool = false

	for cell in _get_drag_cells(end_cell):
		# Preserve existing tracks, including station tracks.
		if not tracks.has(cell):
			tracks[cell] = vertical
			changed = true

	is_dragging = false

	if changed:
		_check_route()

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
