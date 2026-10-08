extends Node2D

const TILE_SIZE: int = 32
const GRID_COLOR: Color = Color(0.18, 0.23, 0.25, 1.0)


func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	queue_redraw()
	print("Trainz started successfully.")


func _on_viewport_size_changed() -> void:
	queue_redraw()


func _draw() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var columns: int = int(ceil(viewport_size.x / TILE_SIZE))
	var rows: int = int(ceil(viewport_size.y / TILE_SIZE))

	for column in range(columns + 1):
		var x: float = float(column * TILE_SIZE)
		draw_line(
			Vector2(x, 0.0),
			Vector2(x, viewport_size.y),
			GRID_COLOR
		)

	for row in range(rows + 1):
		var y: float = float(row * TILE_SIZE)
		draw_line(
			Vector2(0.0, y),
			Vector2(viewport_size.x, y),
			GRID_COLOR
		)