extends Control

signal navigation_requested(world_position: Vector2)

var map_cells: Vector2i = Vector2i(80, 50)
var world_tile_size: float = 32.0

var track_data: Dictionary = {}
var facilities: Array[Dictionary] = []
var train_positions: Array[Vector2] = []

var camera_world_rect: Rect2 = Rect2()

var dragging: bool = false
var background_style := StyleBoxFlat.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE

	background_style.bg_color = Color("#111827")
	background_style.border_color = Color("#35445B")
	background_style.set_border_width_all(1)
	background_style.set_corner_radius_all(8)


func _map_rect() -> Rect2:
	var available := Vector2(
		maxf(size.x - 16.0, 1.0),
		maxf(size.y - 40.0, 1.0)
	)

	var scale_factor: float = minf(
		available.x / float(map_cells.x),
		available.y / float(map_cells.y)
	)

	var drawing_size: Vector2 = Vector2(map_cells) * scale_factor

	var drawing_position := Vector2(
		(size.x - drawing_size.x) / 2.0,
		32.0 + (available.y - drawing_size.y) / 2.0
	)

	return Rect2(drawing_position, drawing_size)


func _world_size() -> Vector2:
	return Vector2(map_cells) * world_tile_size


func _world_to_map(world_position: Vector2) -> Vector2:
	var area: Rect2 = _map_rect()
	return area.position + world_position / _world_size() * area.size


func _draw() -> void:
	draw_style_box(background_style, Rect2(Vector2.ZERO, size))

	draw_string(
		get_theme_default_font(),
		Vector2(12, 22),
		"Network map",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14,
		Color("#E8EEF6")
	)

	var area: Rect2 = _map_rect()
	var cell_size: Vector2 = area.size / Vector2(map_cells)

	draw_rect(area, Color("#172C27"))

	# Tracks.
	for cell in track_data:
		if cell.x < 0 or cell.x >= map_cells.x:
			continue

		if cell.y < 0 or cell.y >= map_cells.y:
			continue

		draw_rect(
			Rect2(
				area.position + Vector2(cell) * cell_size,
				cell_size
			),
			Color("#8C9BAD")
		)

	# Stations and industries.
	for facility in facilities:
		var cell: Vector2i = facility["cell"]
		var color: Color = facility["color"]

		var world_position: Vector2 = (
			Vector2(cell) + Vector2(0.5, 0.5)
		) * world_tile_size

		draw_rect(
			Rect2(
				_world_to_map(world_position) - Vector2(3, 3),
				Vector2(6, 6)
			),
			color
		)

	# Current camera view.
	var camera_rect := Rect2(
		_world_to_map(camera_world_rect.position),
		camera_world_rect.size / _world_size() * area.size
	)

	var clipped_camera: Rect2 = camera_rect.intersection(area)

	if clipped_camera.has_area():
		draw_rect(
			clipped_camera,
			Color(0.5, 0.75, 1.0, 0.12)
		)

		draw_rect(
			clipped_camera,
			Color("#D7E9FF"),
			false,
			1.0
		)

	# Trains: passenger first, freight second.
	var colors: Array[Color] = [
		Color("#FF655A"),
		Color("#56A4FF")
	]

	for index in range(train_positions.size()):
		var world_position: Vector2 = train_positions[index]

		if not Rect2(Vector2.ZERO, _world_size()).has_point(world_position):
			continue

		draw_circle(
			_world_to_map(world_position),
			2.5,
			colors[index % colors.size()]
		)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _map_rect().has_point(event.position):
					dragging = true
					_request_navigation(event.position)
			else:
				dragging = false

			accept_event()

	if event is InputEventMouseMotion and dragging:
		_request_navigation(event.position)
		accept_event()


func _request_navigation(local_position: Vector2) -> void:
	var area: Rect2 = _map_rect()

	var fraction: Vector2 = (
		local_position - area.position
	) / area.size

	fraction.x = clampf(fraction.x, 0.0, 1.0)
	fraction.y = clampf(fraction.y, 0.0, 1.0)

	navigation_requested.emit(fraction * _world_size())


func cancel_navigation() -> void:
	dragging = false
