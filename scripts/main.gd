extends Node2D

const TILE_SIZE: int = 32

# Reserve the top three rows for the interface.
const BUILD_START_ROW: int = 3

const GRID_COLOR: Color = Color(0.18, 0.23, 0.25)
const SLEEPER_COLOR: Color = Color(0.43, 0.29, 0.17)
const RAIL_COLOR: Color = Color(0.78, 0.82, 0.85)
const PREVIEW_COLOR: Color = Color(0.35, 0.9, 0.55, 0.8)

# Each grid coordinate stores whether its track is vertical.
var tracks: Dictionary = {}
var placing_vertical: bool = false
var hovered_cell: Vector2i = Vector2i(-1, -1)

@onready var instructions: Label = $Interface/Instructions


func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_update_instructions()
	queue_redraw()


func _process(_delta: float) -> void:
	var cell: Vector2i = _mouse_to_cell()

	if cell != hovered_cell:
		hovered_cell = cell
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_R:
			placing_vertical = not placing_vertical
			_update_instructions()
			queue_redraw()

	if event is InputEventMouseButton:
		if not event.pressed:
			return

		var cell: Vector2i = _mouse_to_cell()

		if not _can_build_at(cell):
			return

		match event.button_index:
			MOUSE_BUTTON_LEFT:
				# Preserve an existing tile until the player removes it.
				if not tracks.has(cell):
					tracks[cell] = placing_vertical
					queue_redraw()

			MOUSE_BUTTON_RIGHT:
				if tracks.erase(cell):
					queue_redraw()


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

	instructions.text = (
		"Left-click: build | Right-click: remove | R: rotate | Direction: "
		+ direction
	)


func _on_viewport_size_changed() -> void:
	queue_redraw()


func _draw() -> void:
	_draw_grid()

	for cell in tracks:
		_draw_track(cell, tracks[cell], false)

	if _can_build_at(hovered_cell) and not tracks.has(hovered_cell):
		_draw_track(hovered_cell, placing_vertical, true)


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

	# Draw the wooden sleepers beneath the rails.
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

	# Draw the two rails.
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
