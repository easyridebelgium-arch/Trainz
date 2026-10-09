extends Node2D

const TILE_SIZE: int = 32

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
const RailRouter = preload("res://scripts/rail_router.gd")
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
	"paused",
	"capacity_upgrade_level",
	"speed_upgrade_level",
	"forest_stock",
	"logs_produced",
	"log_production_timer",
	"logs_delivered",
	"freight_income",
	"freight_operating_cost"
]
const MAP_WIDTH: int = 80
const MAP_HEIGHT: int = 50
const KEYBOARD_PAN_SPEED: float = 600.0
const MIN_ZOOM: float = 0.5
const MAX_ZOOM: float = 3.0
const ZOOM_STEP: float = 1.15
const SAVE_BACKUP_PATH: String = "user://trainz_save.backup.json"
const MAX_CAPACITY_LEVEL: int = 3
const MAX_SPEED_LEVEL: int = 3

const BASE_CAPACITY_UPGRADE_PRICE: int = 250
const BASE_SPEED_UPGRADE_PRICE: int = 200
const CAPACITY_PER_UPGRADE: int = 10
const SPEED_PER_UPGRADE: float = 20.0

const FOREST_SITE: Vector2i = Vector2i(8, 24)
const CARGO_TERMINAL: Vector2i = Vector2i(28, 24)

const LOG_PRODUCTION_INTERVAL: float = 10.0
const LOGS_PER_BATCH: int = 5
const MAX_FOREST_STOCK: int = 100
const FreightTrain = preload("res://scripts/freight_train.gd")
const LOG_DELIVERY_PRICE: int = 8
const SAVE_VERSION: int = 10
const MAX_CONSTRUCTION_HISTORY: int = 100

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
var route_cells: Array[Vector2i] = []
var route_path: Curve2D = Curve2D.new()
var route_distance: float = 0.0
var train_heading: float = 0.0
# Empty means straight track. Other values connect two compass directions.
var selected_curve: String = ""
var is_panning: bool = false
var inspect_mode: bool = false
var selected_station: Vector2i = Vector2i(-1, -1)

var station_panel: PanelContainer
var station_title: Label
var station_details: Label
var capacity_upgrade_level: int = 0
var speed_upgrade_level: int = 0

var capacity_upgrade_button: Button
var speed_upgrade_button: Button
var forest_stock: int = 0
var logs_produced: int = 0
var log_production_timer: float = 0.0
var freight_train: FreightTrain
var logs_delivered: int = 0
var freight_income: int = 0
var freight_operating_cost: int = 0
var freight_rule_label: Label
var freight_rule_option: OptionButton

var construction_undo: Array[Dictionary] = []
var construction_redo: Array[Dictionary] = []

var undo_button: Button
var redo_button: Button

@onready var instructions: Label = $Interface/Instructions
@onready var straight_button: Button = $Interface/Toolbar/StraightButton
@onready var curve_button: Button = $Interface/Toolbar/CurveButton
@onready var rotate_button: Button = $Interface/Toolbar/RotateButton
@onready var pause_button: Button = $Interface/Toolbar/PauseButton
@onready var save_button: Button = $Interface/Toolbar/SaveButton
@onready var load_button: Button = $Interface/Toolbar/LoadButton
@onready var folder_button: Button = $Interface/Toolbar/FolderButton
@onready var camera: Camera2D = $Camera2D
@onready var header_background: ColorRect = $Interface/HeaderBackground
@onready var backup_button: Button = $Interface/Toolbar/BackupButton
@onready var inspect_button: Button = $Interface/Toolbar/InspectButton

func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_size_changed)

	# Each station includes a horizontal platform track.
	tracks[STATION_A] = false
	tracks[STATION_B] = false
	tracks[FOREST_SITE] = false
	tracks[CARGO_TERMINAL] = false

	train_position = _cell_center(STATION_A)
	_update_instructions()
	queue_redraw()
	_setup_toolbar()
	_reset_camera()
	_setup_station_inspector()
	_setup_camera_keys()
	_setup_freight_train()
	_setup_history_controls()

func _process(delta: float) -> void:
	_move_camera_with_keyboard(delta)
	hovered_cell = _mouse_to_cell()

	# Interface messages expire even while simulation is paused.
	if notice_remaining > 0.0:
		notice_remaining = maxf(0.0, notice_remaining - delta)

	if not paused:
		_generate_passengers(delta)
		_produce_logs(delta)
		forest_stock -= freight_train.advance(delta, forest_stock)

		if route_connected:
			_move_train(delta)
			_charge_operating_cost(delta)

	_update_instructions()
	_update_toolbar()
	_update_station_inspector()
	_update_history_controls()
	queue_redraw()
	
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.keycode == KEY_HOME:
				is_dragging = false
				is_panning = false
				_reset_camera()
				return
			
			if event.keycode == KEY_ESCAPE:
				is_dragging = false

			if event.keycode == KEY_T and not is_dragging:
				if selected_curve.is_empty():
					_select_curved_track()
				else:
					_select_straight_track()

			if event.keycode == KEY_R and not is_dragging:
				_rotate_selected_track()

			if event.keycode == KEY_SPACE:
				_toggle_pause()
			
			if event.keycode == KEY_I:
				_toggle_inspect_mode()
				return

	if event is InputEventMouseButton:
		var cell: Vector2i = _mouse_to_cell()

		if event.button_index == MOUSE_BUTTON_LEFT:
			if inspect_mode:
				if event.pressed:
					_inspect_station_at(cell)
				return
			
			if event.pressed:
				if _can_build_at(cell):
					drag_start = cell
					is_dragging = true
			elif is_dragging:
				_finish_track_drag(cell)

		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if inspect_mode:
				_close_station_inspector()
				return
			# Right-click cancels an active construction preview.
			if is_dragging:
				is_dragging = false
				return

			if not _can_build_at(cell):
				return

			if cell in [STATION_A, STATION_B, FOREST_SITE, CARGO_TERMINAL]:
				return

			_remove_track_with_history(cell)


func _check_route() -> void:
	var new_route: Array[Vector2i] = RailRouter.find_route(
		tracks,
		STATION_A,
		STATION_B
	)
	_refresh_freight_route(new_route)

	# Building elsewhere should not interrupt the current service.
	if new_route == route_cells:
		return

	# Return onboard passengers before resetting a changed route.
	if passengers_on_train > 0:
		if travelling_to_b:
			waiting_at_a += passengers_on_train
		else:
			waiting_at_b += passengers_on_train

	passengers_on_train = 0

	route_cells = new_route
	route_path = RailRouter.make_path(route_cells, float(TILE_SIZE))
	route_connected = not route_cells.is_empty()

	route_distance = 0.0
	travelling_to_b = true
	wait_remaining = 0.0
	train_needs_boarding = true

	_update_train_transform()


func _move_train(delta: float) -> void:
	if wait_remaining > 0.0:
		wait_remaining = maxf(0.0, wait_remaining - delta)
		return

	if train_needs_boarding:
		_board_passengers()
		train_needs_boarding = false

	var route_length: float = route_path.get_baked_length()
	var target_distance: float = route_length if travelling_to_b else 0.0

	route_distance = move_toward(
		route_distance,
		target_distance,
		_get_train_speed() * delta
	)

	if absf(route_distance - target_distance) < 0.001:
		route_distance = target_distance
		_unload_passengers()

		travelling_to_b = not travelling_to_b
		wait_remaining = STATION_WAIT
		train_needs_boarding = true

	_update_train_transform()


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


func _is_inside_map(cell: Vector2i) -> bool:
	return (
		cell.x >= 0
		and cell.x < MAP_WIDTH
		and cell.y >= 0
		and cell.y < MAP_HEIGHT
	)


func _is_station_space(cell: Vector2i) -> bool:
	for station in [STATION_A, STATION_B, FOREST_SITE, CARGO_TERMINAL]:
		var inside_columns: bool = (
			cell.x >= station.x - 1
			and cell.x <= station.x + 1
		)

		var inside_rows: bool = (
			cell.y >= station.y - 2
			and cell.y < station.y
		)

		if inside_columns and inside_rows:
			return true

	return false


func _can_build_at(cell: Vector2i) -> bool:
	return _is_inside_map(cell) and not _is_station_space(cell)


func _update_instructions() -> void:
	var direction: String = "Vertical" if placing_vertical else "Horizontal"
	if inspect_mode:
		direction = "Inspect: click a station track"

	if not selected_curve.is_empty():
		direction = "Curve " + selected_curve
	elif is_dragging:
		direction = (
			"Vertical" if _drag_is_vertical(hovered_cell)
			else "Horizontal"
		)

	var status: String = "Connect the stations with matching track pieces."

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
		+ " | Space: pause | Esc: cancel"
		+ "\n%s | Cell: %d,%d | Build: £%d%s | %s"
		% [
			direction,
			hovered_cell.x,
			hovered_cell.y,
			preview_cost,
			affordability,
			status
		]
		+ "\nWaiting: A %d / B %d | Onboard: %d/%d | Delivered: %d"
		% [
			waiting_at_a,
			waiting_at_b,
			passengers_on_train,
			_get_train_capacity(),
			passengers_delivered
		]
		+ "\nBalance: £%d | Fares: £%d | Freight: £%d | Build: £%d | Running: £%d"
		% [
			money,
			passengers_delivered * TICKET_PRICE,
			freight_income,
			total_construction_cost,
			total_operating_cost + freight_operating_cost
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
	_draw_station(FOREST_SITE, "Forest")
	_draw_station(CARGO_TERMINAL, "Terminal")

	if inspect_mode:
		if selected_station != Vector2i(-1, -1):
			var selection_rect := Rect2(
				Vector2(selected_station) * TILE_SIZE,
				Vector2(TILE_SIZE, TILE_SIZE)
			)

			draw_rect(
				selection_rect.grow(3.0),
				Color(1.0, 0.85, 0.25),
				false,
				2.0
			)
	else:
		if is_dragging:
			var track_type: Variant = _drag_is_vertical(hovered_cell)

			if not selected_curve.is_empty():
				track_type = selected_curve

			for cell in _get_drag_cells(hovered_cell):
				if not tracks.has(cell):
					_draw_build_preview(cell, track_type)
		else:
			if _is_inside_map(hovered_cell) and not tracks.has(hovered_cell):
				var track_type: Variant = placing_vertical

				if not selected_curve.is_empty():
					track_type = selected_curve

				_draw_build_preview(hovered_cell, track_type)

	_draw_train()

func _draw_grid() -> void:
	var map_size := Vector2(
		MAP_WIDTH * TILE_SIZE,
		MAP_HEIGHT * TILE_SIZE
	)

	draw_rect(
		Rect2(Vector2.ZERO, map_size),
		Color(0.10, 0.15, 0.13)
	)

	for column in range(MAP_WIDTH + 1):
		var x: float = float(column * TILE_SIZE)

		draw_line(
			Vector2(x, 0.0),
			Vector2(x, map_size.y),
			GRID_COLOR
		)

	for row in range(MAP_HEIGHT + 1):
		var y: float = float(row * TILE_SIZE)

		draw_line(
			Vector2(0.0, y),
			Vector2(map_size.x, y),
			GRID_COLOR
		)

	draw_rect(
		Rect2(Vector2.ZERO, map_size),
		Color(0.45, 0.55, 0.48),
		false,
		2.0
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

	var footprint := Rect2(
		origin + Vector2(-TILE_SIZE, -2 * TILE_SIZE),
		Vector2(3 * TILE_SIZE, 2 * TILE_SIZE)
	)

	# Reserved station grounds.
	draw_rect(
		footprint,
		Color(0.17, 0.20, 0.22)
	)

	draw_rect(
		footprint,
		Color(0.35, 0.40, 0.43),
		false,
		1.0
	)

	# Name centered inside the reserved area.
	draw_string(
		ThemeDB.fallback_font,
		origin + Vector2(-24, -38),
		station_name,
		HORIZONTAL_ALIGNMENT_CENTER,
		80.0,
		16,
		Color.WHITE
	)

	# Platform alongside the station track.
	draw_rect(
		Rect2(
			origin + Vector2(-24, -16),
			Vector2(80, 12)
		),
		Color(0.65, 0.68, 0.70)
	)

	draw_line(
		origin + Vector2(-24, -4),
		origin + Vector2(56, -4),
		Color(0.95, 0.80, 0.25),
		2.0
	)


func _draw_train() -> void:
	draw_set_transform(train_position, train_heading)

	var body := Rect2(
		Vector2(-13, -7),
		Vector2(26, 14)
	)

	draw_rect(body, Color(0.85, 0.22, 0.18))
	draw_rect(body, Color(0.15, 0.08, 0.08), false, 1.0)

	# The front of the train always points along its heading.
	draw_rect(
		Rect2(Vector2(5, -5), Vector2(6, 10)),
		Color(0.65, 0.85, 0.95)
	)

	# Restore normal drawing coordinates.
	draw_set_transform(Vector2.ZERO, 0.0)

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
		if _is_inside_map(drag_start):
			cells.append(drag_start)

		return cells

	if _drag_is_vertical(end_cell):
		var first_y: int = mini(drag_start.y, end_cell.y)
		var last_y: int = maxi(drag_start.y, end_cell.y)

		for y in range(first_y, last_y + 1):
			var cell := Vector2i(drag_start.x, y)

			if _is_inside_map(cell):
				cells.append(cell)
	else:
		var first_x: int = mini(drag_start.x, end_cell.x)
		var last_x: int = maxi(drag_start.x, end_cell.x)

		for x in range(first_x, last_x + 1):
			var cell := Vector2i(x, drag_start.y)

			if _is_inside_map(cell):
				cells.append(cell)

	return cells


func _finish_track_drag(end_cell: Vector2i) -> void:
	var vertical: bool = _drag_is_vertical(end_cell)
	var new_cells: Array[Vector2i] = []

	for cell in _get_drag_cells(end_cell):
		if _is_station_space(cell):
			is_dragging = false
			_show_notice("Cannot build through a station platform.")
			queue_redraw()
			return

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

	var before: Dictionary = {}
	var after: Dictionary = {}

	for cell in new_cells:
		before[cell] = null

		if selected_curve.is_empty():
			tracks[cell] = vertical
		else:
			tracks[cell] = selected_curve

		after[cell] = tracks[cell]

	money -= cost
	total_construction_cost += cost

	_record_construction_change(
		before,
		after,
		-cost,
		cost
	)

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
	var available_seats: int = _get_train_capacity() - passengers_on_train
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
	if inspect_mode:
		return 0
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
		"version": SAVE_VERSION,
		"tracks": saved_tracks,
		"route_distance": route_distance,
		"state": state,
		"freight": freight_train.save_state()
	}

	# Prepare the new save before touching the existing one.
	var file := FileAccess.open(SAVE_TEMP_PATH, FileAccess.WRITE)

	if file == null:
		_show_notice("Could not open the temporary save file.")
		return

	file.store_string(JSON.stringify(data, "\t"))
	file.flush()

	var write_error: Error = file.get_error()
	file.close()

	if write_error != OK:
		_show_notice("Saving failed while writing the file.")
		return

	# Preserve the previous manual save.
	if FileAccess.file_exists(SAVE_PATH):
		var backup_error: Error = DirAccess.copy_absolute(
			ProjectSettings.globalize_path(SAVE_PATH),
			ProjectSettings.globalize_path(SAVE_BACKUP_PATH)
		)

		if backup_error != OK:
			_show_notice("Could not create a backup. Save cancelled.")
			return

	# Replace the main save only after writing and backup succeed.
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
	var saved_version: Variant = data.get("version")

	if not _is_valid_number(saved_version):
		return false

	var version_number: float = float(saved_version)

	if version_number != floor(version_number):
		return false

	if version_number != float(SAVE_VERSION):
		return false

	var version: int = int(version_number)

	if not data.get("tracks") is Array:
		return false

	if not data.get("state") is Dictionary:
		return false
	if not data.get("freight") is Dictionary:
		return false

	if version >= 3:
		if not _is_valid_number(data.get("route_distance")):
			return false

		if float(data["route_distance"]) < 0.0:
			return false
	else:
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

	var saved_capacity_level: int = int(state["capacity_upgrade_level"])
	var saved_speed_level: int = int(state["speed_upgrade_level"])

	if saved_capacity_level < 0 or saved_capacity_level > MAX_CAPACITY_LEVEL:
		return false

	if saved_speed_level < 0 or saved_speed_level > MAX_SPEED_LEVEL:
		return false

	var saved_capacity: int = (
		TRAIN_CAPACITY
		+ saved_capacity_level * CAPACITY_PER_UPGRADE
	)

	if float(state["passengers_on_train"]) > saved_capacity:
		return false

	if float(state["wait_remaining"]) > STATION_WAIT:
		return false

	if float(state["passenger_timer"]) >= PASSENGER_INTERVAL:
		return false

	if float(state["operating_timer"]) >= 1.0:
		return false
	if int(state["forest_stock"]) > MAX_FOREST_STOCK:
		return false

	if int(state["logs_produced"]) < int(state["forest_stock"]):
		return false

	if float(state["log_production_timer"]) >= LOG_PRODUCTION_INTERVAL:
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

		if y < 0 or y > 10000:
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
	
func _load_game(save_path: String = SAVE_PATH) -> void:
	if not FileAccess.file_exists(save_path):
		if save_path == SAVE_BACKUP_PATH:
			_show_notice("No previous save yet. Save twice to create one.")
		else:
			_show_notice("No saved game yet. Click Save first.")
		return

	var file := FileAccess.open(save_path, FileAccess.READ)

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
	if not _is_valid_number(data.get("version")):
		_show_notice("Save file has no valid format version.")
		return

	if float(data["version"]) != float(SAVE_VERSION):
		_show_notice("This save is from another development version. Start a new game.")
		return
	if not _is_valid_save(data):
		_show_notice("The save file is damaged or incompatible.")
		return

	var loaded_tracks: Dictionary = {}

	for entry in data["tracks"]:
		var cell := Vector2i(int(entry[0]), int(entry[1]))
		loaded_tracks[cell] = entry[2]

	var removed_count: int = _remove_station_space_tracks(loaded_tracks)
	var loaded_cells: Array[Vector2i] = RailRouter.find_route(
		loaded_tracks,
		STATION_A,
		STATION_B
	)
	var loaded_path: Curve2D = RailRouter.make_path(
		loaded_cells,
		float(TILE_SIZE)
	)

	var loaded_distance: float = 0.0

	if int(data["version"]) >= 3:
		loaded_distance = float(data["route_distance"])
	else:
		# Earlier versions only moved along the direct horizontal route.
		loaded_distance = (
			float(data["train_x"]) - _cell_center(STATION_A).x
		)

	var state: Dictionary = data["state"]
	if removed_count > 0:
		state["money"] = (
			int(state["money"])
			+ removed_count * TRACK_BUILD_COST
		)

		# Return passengers before resetting the affected saved session.
		var onboard: int = int(state["passengers_on_train"])

		if bool(state["travelling_to_b"]):
			state["waiting_at_a"] = int(state["waiting_at_a"]) + onboard
		else:
			state["waiting_at_b"] = int(state["waiting_at_b"]) + onboard

		state["passengers_on_train"] = 0
		state["travelling_to_b"] = true
		state["wait_remaining"] = 0.0
		state["train_needs_boarding"] = true
		loaded_distance = 0.0

	if loaded_cells.is_empty():
		if loaded_distance > 0.001 or int(state["passengers_on_train"]) > 0:
			_show_notice("Save contains a train without a valid route.")
			return
	elif loaded_distance > loaded_path.get_baked_length() + 0.001:
		_show_notice("Saved train position is outside the route.")
		return
	var loaded_freight_cells: Array[Vector2i] = _find_freight_route(
		loaded_tracks,
		loaded_cells
	)

	var loaded_freight_path: Curve2D = RailRouter.make_path(
		loaded_freight_cells,
		float(TILE_SIZE)
	)

	var loaded_freight_state: Dictionary = data["freight"].duplicate()

	# If facility cleanup changed the map, return the freight train
	# to the forest while keeping its cargo onboard.
	if removed_count > 0:
		loaded_freight_state["distance"] = 0.0
		loaded_freight_state["to_terminal"] = true
		loaded_freight_state["dwell"] = 0.0

	if not FreightTrain.is_valid_state(
		loaded_freight_state,
		loaded_freight_path.get_baked_length()
	):
		_show_notice("Saved freight train state is invalid.")
		return
	# All checks passed. Apply the loaded state.
	tracks = loaded_tracks
	route_cells = loaded_cells
	route_path = loaded_path
	route_connected = not route_cells.is_empty()

	for field in SAVE_FIELDS:
		var current_value: Variant = get(field)

		match typeof(current_value):
			TYPE_INT:
				set(field, int(state[field]))
			TYPE_FLOAT:
				set(field, float(state[field]))
			TYPE_BOOL:
				set(field, state[field])

	route_distance = clampf(
		loaded_distance,
		0.0,
		route_path.get_baked_length()
	)

	is_dragging = false

	_update_train_transform()
	freight_train.set_route(loaded_freight_cells, float(TILE_SIZE))
	freight_train.restore_state(loaded_freight_state)
	if removed_count > 0:
		_show_notice(
			"Loaded: removed %d tracks from station space; refunded £%d."
			% [removed_count, removed_count * TRACK_BUILD_COST]
		)
	elif save_path == SAVE_BACKUP_PATH:
		_show_notice("Previous save loaded.")
	else:
		_show_notice("Game loaded.")
	_update_instructions()
	_clear_construction_history()
	_update_history_controls()
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

func _update_train_transform() -> void:
	if not route_connected:
		train_position = _cell_center(STATION_A)
		train_heading = 0.0
		return

	var route_length: float = route_path.get_baked_length()

	train_position = route_path.sample_baked(route_distance)

	var before: Vector2 = route_path.sample_baked(
		maxf(0.0, route_distance - 1.0)
	)
	var after: Vector2 = route_path.sample_baked(
		minf(route_length, route_distance + 1.0)
	)

	var direction: Vector2 = after - before

	if not travelling_to_b:
		direction = -direction

	train_heading = direction.angle()
func _setup_toolbar() -> void:
	straight_button.pressed.connect(_select_straight_track)
	curve_button.pressed.connect(_select_curved_track)
	rotate_button.pressed.connect(_rotate_selected_track)
	pause_button.pressed.connect(_toggle_pause)
	save_button.pressed.connect(_save_game)
	load_button.pressed.connect(_load_game)
	folder_button.pressed.connect(_open_save_folder)
	inspect_button.pressed.connect(_toggle_inspect_mode)
	inspect_button.tooltip_text = "Inspect a station. Shortcut: I"
	inspect_button.focus_mode = Control.FOCUS_NONE

	straight_button.tooltip_text = "Drag to build straight track."
	curve_button.tooltip_text = "Click to place a curved track."
	rotate_button.tooltip_text = "Rotate the selected piece. Shortcut: R"
	pause_button.tooltip_text = "Pause or resume. Shortcut: Space"
	save_button.tooltip_text = "Save your current railway."
	load_button.tooltip_text = "Restore your latest saved railway."
	folder_button.tooltip_text = "Open the folder containing your saved game."

	# Keep Space available for pausing after clicking a button.
	for button in [
		straight_button,
		curve_button,
		rotate_button,
		pause_button,
		save_button,
		load_button,
		folder_button
	]:
		button.focus_mode = Control.FOCUS_NONE
		backup_button.pressed.connect(
		_load_game.bind(SAVE_BACKUP_PATH)
	)

	backup_button.tooltip_text = "Restore the version before your latest save."
	backup_button.focus_mode = Control.FOCUS_NONE

	_update_toolbar()


func _select_straight_track() -> void:
	inspect_mode = false
	_close_station_inspector()
	is_dragging = false
	selected_curve = ""
	_update_toolbar()


func _select_curved_track() -> void:
	inspect_mode = false
	_close_station_inspector()
	is_dragging = false

	if selected_curve.is_empty():
		selected_curve = "NE"

	_update_toolbar()


func _rotate_selected_track() -> void:
	if is_dragging or inspect_mode:
		return

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

	_update_toolbar()


func _toggle_pause() -> void:
	paused = not paused
	if not paused:
		_clear_construction_history()
	_update_toolbar()


func _open_save_folder() -> void:
	var error: Error = OS.shell_open(
		ProjectSettings.globalize_path("user://")
	)

	if error != OK:
		_show_notice("Could not open the save folder.")


func _update_toolbar() -> void:
	inspect_button.set_pressed_no_signal(inspect_mode)

	straight_button.set_pressed_no_signal(
		not inspect_mode and selected_curve.is_empty()
	)

	curve_button.set_pressed_no_signal(
		not inspect_mode and not selected_curve.is_empty()
	)
	pause_button.set_pressed_no_signal(paused)

	pause_button.text = "Resume" if paused else "Pause"

	rotate_button.disabled = is_dragging or inspect_mode
	save_button.disabled = is_dragging
	load_button.disabled = is_dragging
	backup_button.disabled = is_dragging
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		# Release the middle button anywhere to stop panning.
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				if not _mouse_is_over_interface():
					is_panning = true
					is_dragging = false
					get_viewport().set_input_as_handled()
			else:
				is_panning = false
				get_viewport().set_input_as_handled()

			return

		# Cancel construction if its drag ends over the interface.
		if (
			event.button_index == MOUSE_BUTTON_LEFT
			and not event.pressed
			and is_dragging
			and _mouse_is_over_interface()
		):
			is_dragging = false
			get_viewport().set_input_as_handled()
			return

		# Avoid building while moving the camera.
		if is_panning:
			get_viewport().set_input_as_handled()
			return

		if event.pressed and not _mouse_is_over_interface():
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				if not is_dragging:
					_zoom_camera(ZOOM_STEP)

				get_viewport().set_input_as_handled()

			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				if not is_dragging:
					_zoom_camera(1.0 / ZOOM_STEP)

				get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion and is_panning:
		camera.position -= event.relative / camera.zoom.x
		camera.force_update_scroll()
		get_viewport().set_input_as_handled()
func _reset_camera() -> void:
	camera.zoom = Vector2.ONE
	camera.position = get_viewport_rect().size / 2.0
	camera.force_update_scroll()


func _zoom_camera(factor: float) -> void:
	var mouse_before: Vector2 = get_global_mouse_position()

	var new_zoom: float = clampf(
		camera.zoom.x * factor,
		MIN_ZOOM,
		MAX_ZOOM
	)

	camera.zoom = Vector2(new_zoom, new_zoom)
	camera.force_update_scroll()

	# Keep the map location beneath the cursor in the same place.
	var mouse_after: Vector2 = get_global_mouse_position()
	camera.position += mouse_before - mouse_after
	camera.force_update_scroll()


func _mouse_is_over_interface() -> bool:
	return get_viewport().gui_get_hovered_control() != null
func _setup_station_inspector() -> void:
	station_panel = PanelContainer.new()
	station_panel.name = "StationInspector"
	$Interface.add_child(station_panel)

	station_panel.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_RIGHT
	)
	station_panel.offset_left = -304.0
	station_panel.offset_right = -16.0
	station_panel.offset_top = 176.0
	station_panel.anchor_bottom = 1.0
	station_panel.offset_bottom = -16.0
	station_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	station_panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)

	station_title = Label.new()
	station_title.add_theme_font_size_override("font_size", 22)
	content.add_child(station_title)

	station_details = Label.new()
	station_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(station_details)
	
	capacity_upgrade_button = Button.new()
	capacity_upgrade_button.focus_mode = Control.FOCUS_NONE
	capacity_upgrade_button.pressed.connect(_upgrade_capacity)
	content.add_child(capacity_upgrade_button)

	speed_upgrade_button = Button.new()
	speed_upgrade_button.focus_mode = Control.FOCUS_NONE
	speed_upgrade_button.pressed.connect(_upgrade_speed)
	content.add_child(speed_upgrade_button)
	freight_rule_label = Label.new()
	freight_rule_label.text = "Freight departure rule"
	content.add_child(freight_rule_label)

	freight_rule_option = OptionButton.new()
	freight_rule_option.focus_mode = Control.FOCUS_NONE

	freight_rule_option.add_item(
		"Depart with any logs",
		FreightTrain.LoadingRule.ANY
	)
	freight_rule_option.add_item(
		"Depart at least half-full",
		FreightTrain.LoadingRule.HALF
	)
	freight_rule_option.add_item(
		"Depart only when full",
		FreightTrain.LoadingRule.FULL
	)

	freight_rule_option.item_selected.connect(
		_on_freight_rule_selected
	)

	content.add_child(freight_rule_option)

	freight_rule_label.hide()
	freight_rule_option.hide()
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(_close_station_inspector)
	content.add_child(close_button)

	station_panel.hide()


func _toggle_inspect_mode() -> void:
	inspect_mode = not inspect_mode
	is_dragging = false

	if not inspect_mode:
		station_panel.hide()
		selected_station = Vector2i(-1, -1)

	_update_toolbar()


func _close_station_inspector() -> void:
	station_panel.hide()
	selected_station = Vector2i(-1, -1)


func _inspect_station_at(cell: Vector2i) -> void:
	for station in [STATION_A, STATION_B, FOREST_SITE, CARGO_TERMINAL]:
		var inside_station_grounds: bool = (
			cell.x >= station.x - 1
			and cell.x <= station.x + 1
			and cell.y >= station.y - 2
			and cell.y < station.y
		)

		if cell == station or inside_station_grounds:
			selected_station = station
			station_panel.show()
			_update_station_inspector()
			return

	_close_station_inspector()


func _update_station_inspector() -> void:
	if not station_panel.visible:
		return

	if selected_station == FOREST_SITE or selected_station == CARGO_TERMINAL:
		_update_freight_inspector()
		return

	capacity_upgrade_button.show()
	speed_upgrade_button.show()
	freight_rule_label.hide()
	freight_rule_option.hide()

	var is_station_a: bool = selected_station == STATION_A
	var station_name: String = "Station A" if is_station_a else "Station B"
	var destination_name: String = "Station B" if is_station_a else "Station A"

	var waiting: int = waiting_at_a if is_station_a else waiting_at_b
	var incoming: int = 0

	if route_connected:
		if is_station_a and not travelling_to_b:
			incoming = passengers_on_train
		elif not is_station_a and travelling_to_b:
			incoming = passengers_on_train

	var train_at_station: bool = (
		train_position.distance_to(_cell_center(selected_station)) < 0.5
	)

	var service_status: String = "No connected service"

	if route_connected:
		service_status = "Service connected"

	if train_at_station:
		service_status += "\nTrain at platform"

	station_title.text = station_name

	station_details.text = (
		"Destination: %s"
		+ "\n\nWaiting passengers: %d"
		+ "\nIncoming passengers: %d"
		+ "\n\nShared train"
		+ "\nCapacity: %d passengers (%d/%d)"
		+ "\nSpeed: %.0f px/s (%d/%d)"
		+ "\n\n%s"
	) % [
		destination_name,
		waiting,
		incoming,
		_get_train_capacity(),
		capacity_upgrade_level,
		MAX_CAPACITY_LEVEL,
		_get_train_speed(),
		speed_upgrade_level,
		MAX_SPEED_LEVEL,
		service_status
	]

	_update_upgrade_button(
		capacity_upgrade_button,
		"Capacity",
		capacity_upgrade_level,
		MAX_CAPACITY_LEVEL,
		_get_capacity_upgrade_price(),
		"Adds %d passenger seats." % CAPACITY_PER_UPGRADE
	)

	_update_upgrade_button(
		speed_upgrade_button,
		"Speed",
		speed_upgrade_level,
		MAX_SPEED_LEVEL,
		_get_speed_upgrade_price(),
		"Adds %.0f pixels/second." % SPEED_PER_UPGRADE
	)
			
func _update_upgrade_button(
	button: Button,
	upgrade_name: String,
	level: int,
	maximum_level: int,
	price: int,
	benefit: String
) -> void:
	if level >= maximum_level:
		button.text = upgrade_name + ": fully upgraded"
		button.disabled = true
		button.tooltip_text = "All upgrades of this type are installed."
		return

	button.text = "%s + (£%d)" % [upgrade_name, price]
	button.disabled = not paused or money < price

	if not paused:
		button.tooltip_text = "Pause the game to upgrade."
	elif money < price:
		button.tooltip_text = "Requires £%d. %s" % [price, benefit]
	else:
		button.tooltip_text = benefit

func _draw_build_preview(cell: Vector2i, track_type: Variant) -> void:
	if _is_station_space(cell):
		var origin: Vector2 = Vector2(cell) * TILE_SIZE
		var warning_color := Color(1.0, 0.3, 0.25)

		draw_rect(
			Rect2(origin, Vector2(TILE_SIZE, TILE_SIZE)),
			Color(1.0, 0.15, 0.1, 0.25)
		)

		draw_line(
			origin + Vector2(6, 6),
			origin + Vector2(TILE_SIZE - 6, TILE_SIZE - 6),
			warning_color,
			2.0
		)

		draw_line(
			origin + Vector2(TILE_SIZE - 6, 6),
			origin + Vector2(6, TILE_SIZE - 6),
			warning_color,
			2.0
		)

		return

	_draw_track(cell, track_type, true)

func _remove_station_space_tracks(track_data: Dictionary) -> int:
	var removed_count: int = 0

	# Clear track from reserved building grounds.
	for cell in track_data.keys():
		if _is_station_space(cell):
			track_data.erase(cell)
			removed_count += 1

	# Install the new permanent horizontal loading tracks.
	for facility in [FOREST_SITE, CARGO_TERMINAL]:
		if track_data.has(facility):
			if track_data[facility] != false:
				track_data.erase(facility)
				removed_count += 1

		track_data[facility] = false

	return removed_count
func _get_train_capacity() -> int:
	return TRAIN_CAPACITY + capacity_upgrade_level * CAPACITY_PER_UPGRADE


func _get_train_speed() -> float:
	return TRAIN_SPEED + speed_upgrade_level * SPEED_PER_UPGRADE

func _get_capacity_upgrade_price() -> int:
	return BASE_CAPACITY_UPGRADE_PRICE * (capacity_upgrade_level + 1)


func _get_speed_upgrade_price() -> int:
	return BASE_SPEED_UPGRADE_PRICE * (speed_upgrade_level + 1)


func _upgrade_capacity() -> void:
	if selected_station == FOREST_SITE or selected_station == CARGO_TERMINAL:
		_upgrade_freight_capacity()
		return
	if capacity_upgrade_level >= MAX_CAPACITY_LEVEL:
		_show_notice("Passenger capacity is fully upgraded.")
		return

	if not paused:
		_show_notice("Pause the game before upgrading.")
		return

	var price: int = _get_capacity_upgrade_price()

	if money < price:
		_show_notice("Insufficient funds. Capacity upgrade costs £%d." % price)
		return

	money -= price
	capacity_upgrade_level += 1

	_show_notice(
		"Capacity upgraded to %d passengers." % _get_train_capacity()
	)

	_update_station_inspector()


func _upgrade_speed() -> void:
	if selected_station == FOREST_SITE or selected_station == CARGO_TERMINAL:
		_upgrade_freight_speed()
		return
	if speed_upgrade_level >= MAX_SPEED_LEVEL:
		_show_notice("Train speed is fully upgraded.")
		return

	if not paused:
		_show_notice("Pause the game before upgrading.")
		return

	var price: int = _get_speed_upgrade_price()

	if money < price:
		_show_notice("Insufficient funds. Speed upgrade costs £%d." % price)
		return

	money -= price
	speed_upgrade_level += 1

	_show_notice(
		"Speed upgraded to %.0f pixels/second." % _get_train_speed()
	)

	_update_station_inspector()

func _produce_logs(delta: float) -> void:
	log_production_timer += delta

	while log_production_timer >= LOG_PRODUCTION_INTERVAL:
		log_production_timer -= LOG_PRODUCTION_INTERVAL

		var free_storage: int = MAX_FOREST_STOCK - forest_stock
		var produced: int = mini(LOGS_PER_BATCH, free_storage)

		if produced > 0:
			forest_stock += produced
			logs_produced += produced

func _update_freight_inspector() -> void:
	capacity_upgrade_button.show()
	speed_upgrade_button.show()

	_update_upgrade_button(
		capacity_upgrade_button,
		"Capacity",
		freight_train.capacity_level,
		FreightTrain.MAX_CAPACITY_LEVEL,
		freight_train.get_capacity_upgrade_price(),
		"Adds %d log capacity." % FreightTrain.CAPACITY_PER_UPGRADE
	)

	_update_upgrade_button(
		speed_upgrade_button,
		"Speed",
		freight_train.speed_level,
		FreightTrain.MAX_SPEED_LEVEL,
		freight_train.get_speed_upgrade_price(),
		"Adds %.0f pixels/second." % FreightTrain.SPEED_PER_UPGRADE
	)
	freight_rule_label.show()
	freight_rule_option.show()

	var rule_index: int = freight_rule_option.get_item_index(
		freight_train.loading_rule
	)

	if rule_index >= 0:
		freight_rule_option.select(rule_index)
	var train_status: String = freight_train.status_text()

	if paused:
		train_status = "Paused — " + train_status

	if selected_station == FOREST_SITE:
		station_title.text = "Forest"

		var production_status: String = "Producing"

		if forest_stock >= MAX_FOREST_STOCK:
			production_status = "Storage full"
		elif paused:
			production_status = "Paused"

		station_details.text = (
			"Produces: logs"
			+ "\nDestination: cargo terminal"
			+ "\n\nStored: %d / %d"
			+ "\nTotal produced: %d"
			+ "\nOn train: %d / %d"
			+ "\n\nProduction: %s"
			+ "\nFreight train: %s"
		) % [
			forest_stock,
			MAX_FOREST_STOCK,
			logs_produced,
			freight_train.cargo,
			freight_train.get_capacity(),
			production_status,
			train_status
		]
	else:
		station_title.text = "Cargo terminal"

		var operating_profit: int = freight_income - freight_operating_cost

		station_details.text = (
			"Accepts: logs"
			+ "\nPayment: £%d per log"
			+ "\n\nLogs delivered: %d"
			+ "\nFreight income: £%d"
			+ "\nOperating expenses: £%d"
			+ "\nOperating profit: £%d"
			+ "\n\nOn train: %d / %d"
			+ "\nRunning cost: £%d per second"
			+ "\n\nFreight train: %s"
		) % [
			LOG_DELIVERY_PRICE,
			logs_delivered,
			freight_income,
			freight_operating_cost,
			operating_profit,
			freight_train.cargo,
			freight_train.get_capacity(),
			FreightTrain.OPERATING_COST_PER_SECOND,
			train_status
		]
		station_details.text += (
		"\n\nCapacity upgrades: %d/%d"
		+ "\nSpeed: %.0f px/s"
		+ "\nSpeed upgrades: %d/%d"
	) % [
		freight_train.capacity_level,
		FreightTrain.MAX_CAPACITY_LEVEL,
		freight_train.get_speed(),
		freight_train.speed_level,
		FreightTrain.MAX_SPEED_LEVEL
	]
		
func _setup_camera_keys() -> void:
	_add_camera_key(&"camera_up", KEY_W)
	_add_camera_key(&"camera_up", KEY_UP)

	_add_camera_key(&"camera_down", KEY_S)
	_add_camera_key(&"camera_down", KEY_DOWN)

	_add_camera_key(&"camera_left", KEY_A)
	_add_camera_key(&"camera_left", KEY_LEFT)

	_add_camera_key(&"camera_right", KEY_D)
	_add_camera_key(&"camera_right", KEY_RIGHT)


func _add_camera_key(action: StringName, physical_key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)

	var key_event := InputEventKey.new()
	key_event.physical_keycode = physical_key

	if not InputMap.action_has_event(action, key_event):
		InputMap.action_add_event(action, key_event)


func _move_camera_with_keyboard(delta: float) -> void:
	# Avoid shifting an unfinished construction preview.
	if is_dragging or is_panning:
		return

	var focused_control: Control = get_viewport().gui_get_focus_owner()

	if focused_control is LineEdit or focused_control is TextEdit:
		return

	var direction: Vector2 = Input.get_vector(
		&"camera_left",
		&"camera_right",
		&"camera_up",
		&"camera_down"
	)

	if direction == Vector2.ZERO:
		return

	var speed: float = KEYBOARD_PAN_SPEED

	if Input.is_key_pressed(KEY_SHIFT):
		speed *= 2.0

	camera.position += direction * speed * delta / camera.zoom.x
	camera.force_update_scroll()
func _setup_freight_train() -> void:
	freight_train = FreightTrain.new()
	freight_train.name = "FreightTrain"
	freight_train.home_position = _cell_center(FOREST_SITE)
	freight_train.position = freight_train.home_position
	freight_train.delivered.connect(_on_logs_delivered)
	freight_train.operating_expense.connect(_on_freight_operating_expense)

	add_child(freight_train)
	_refresh_freight_route(route_cells)


func _find_freight_route(
	track_data: Dictionary,
	passenger_cells: Array[Vector2i]
) -> Array[Vector2i]:
	var candidate: Array[Vector2i] = RailRouter.find_route(
		track_data,
		FOREST_SITE,
		CARGO_TERMINAL
	)

	var empty_route: Array[Vector2i] = []

	# Keep services separate until we introduce signals.
	for cell in candidate:
		if passenger_cells.has(cell):
			return empty_route

		if cell == STATION_A or cell == STATION_B:
			return empty_route

	return candidate


func _refresh_freight_route(passenger_cells: Array[Vector2i]) -> void:
	if freight_train == null:
		return

	var cells: Array[Vector2i] = _find_freight_route(
		tracks,
		passenger_cells
	)

	freight_train.set_route(cells, float(TILE_SIZE))


func _on_logs_delivered(amount: int) -> void:
	var payment: int = amount * LOG_DELIVERY_PRICE

	logs_delivered += amount
	freight_income += payment
	money += payment
func _on_freight_operating_expense(amount: int) -> void:
	money -= amount
	freight_operating_cost += amount
func _on_freight_rule_selected(index: int) -> void:
	freight_train.loading_rule = freight_rule_option.get_item_id(index)

	_show_notice("Freight departure rule updated.")
	_update_freight_inspector()

func _upgrade_freight_capacity() -> void:
	if freight_train.capacity_level >= FreightTrain.MAX_CAPACITY_LEVEL:
		_show_notice("Freight capacity is fully upgraded.")
		return

	if not paused:
		_show_notice("Pause the game before upgrading.")
		return

	var price: int = freight_train.get_capacity_upgrade_price()

	if money < price:
		_show_notice("Insufficient funds. Capacity upgrade costs £%d." % price)
		return

	money -= price
	freight_train.capacity_level += 1

	_show_notice(
		"Freight capacity increased to %d logs."
		% freight_train.get_capacity()
	)

	_update_freight_inspector()


func _upgrade_freight_speed() -> void:
	if freight_train.speed_level >= FreightTrain.MAX_SPEED_LEVEL:
		_show_notice("Freight speed is fully upgraded.")
		return

	if not paused:
		_show_notice("Pause the game before upgrading.")
		return

	var price: int = freight_train.get_speed_upgrade_price()

	if money < price:
		_show_notice("Insufficient funds. Speed upgrade costs £%d." % price)
		return

	money -= price
	freight_train.speed_level += 1

	_show_notice(
		"Freight speed increased to %.0f pixels/second."
		% freight_train.get_speed()
	)

	_update_freight_inspector()
func _record_construction_change(
	before: Dictionary,
	after: Dictionary,
	money_change: int,
	construction_change: int
) -> void:
	if not paused:
		_clear_construction_history()
		return

	construction_undo.append({
		"before": before.duplicate(),
		"after": after.duplicate(),
		"money_change": money_change,
		"construction_change": construction_change
	})

	if construction_undo.size() > MAX_CONSTRUCTION_HISTORY:
		construction_undo.pop_front()

	# A new action replaces any previously available redo path.
	construction_redo.clear()


func _clear_construction_history() -> void:
	construction_undo.clear()
	construction_redo.clear()

func _remove_track_with_history(cell: Vector2i) -> void:
	if not tracks.has(cell):
		return

	var before: Dictionary = {}
	var after: Dictionary = {}

	before[cell] = tracks[cell]
	after[cell] = null

	tracks.erase(cell)
	money += TRACK_REFUND

	_record_construction_change(
		before,
		after,
		TRACK_REFUND,
		0
	)

	_show_notice("Track removed. Refunded £%d." % TRACK_REFUND)
	_check_route()
	queue_redraw()

func _undo_construction() -> void:
	if not paused:
		_show_notice("Pause the game to undo construction.")
		return

	if is_dragging or construction_undo.is_empty():
		return

	var change: Dictionary = construction_undo.back()

	if not _apply_construction_history(change, true):
		return

	construction_undo.pop_back()
	construction_redo.append(change)

	_show_notice("Construction undone.")
	_update_history_controls()


func _redo_construction() -> void:
	if not paused:
		_show_notice("Pause the game to redo construction.")
		return

	if is_dragging or construction_redo.is_empty():
		return

	var change: Dictionary = construction_redo.back()

	if not _apply_construction_history(change, false):
		return

	construction_redo.pop_back()
	construction_undo.append(change)

	_show_notice("Construction redone.")
	_update_history_controls()


func _apply_construction_history(
	change: Dictionary,
	undo: bool
) -> bool:
	var multiplier: int = -1 if undo else 1
	var money_change: int = int(change["money_change"]) * multiplier
	var construction_change: int = (
		int(change["construction_change"]) * multiplier
	)

	# Some actions require money, such as rebuilding a removed track.
	if money_change < 0 and money + money_change < 0:
		_show_notice(
			"Insufficient funds. This action requires £%d."
			% (-money_change)
		)
		return false

	var target: Dictionary

	if undo:
		target = change["before"]
	else:
		target = change["after"]

	for cell in target:
		if target[cell] == null:
			tracks.erase(cell)
		else:
			tracks[cell] = target[cell]

	money += money_change
	total_construction_cost += construction_change

	_check_route()
	queue_redraw()

	return true

func _setup_history_controls() -> void:
	var controls := HBoxContainer.new()
	controls.name = "ConstructionHistory"
	$Interface.add_child(controls)

	controls.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_LEFT
	)
	controls.offset_left = 24.0
	controls.offset_right = 224.0
	controls.offset_top = -48.0
	controls.offset_bottom = -12.0
	controls.add_theme_constant_override("separation", 8)

	undo_button = Button.new()
	undo_button.text = "Undo"
	undo_button.focus_mode = Control.FOCUS_NONE
	undo_button.pressed.connect(_undo_construction)
	controls.add_child(undo_button)

	redo_button = Button.new()
	redo_button.text = "Redo"
	redo_button.focus_mode = Control.FOCUS_NONE
	redo_button.pressed.connect(_redo_construction)
	controls.add_child(redo_button)

	_update_history_controls()


func _update_history_controls() -> void:
	var unavailable: bool = not paused or is_dragging

	undo_button.disabled = unavailable or construction_undo.is_empty()
	redo_button.disabled = unavailable or construction_redo.is_empty()

	if not paused:
		undo_button.tooltip_text = "Pause before editing to enable undo."
		redo_button.tooltip_text = "Construction history clears when play resumes."
	else:
		undo_button.tooltip_text = "Undo the latest paused construction action."
		redo_button.tooltip_text = "Repeat the latest undone construction action."
