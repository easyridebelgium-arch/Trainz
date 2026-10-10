extends ConfirmationDialog

const Services = preload("res://scripts/service_routes.gd")
var game: Node
var draft: Dictionary
var service_choice: OptionButton
var name_field: LineEdit
var stop_list: ItemList
var station_choice: OptionButton
var status: Label
var editing_controls: HBoxContainer
var add_button: Button
var remove_button: Button
var up_button: Button
var down_button: Button
var selected_service_key: String = "passenger"

func configure(owner_game: Node) -> void:
	game = owner_game
	title = "Routes"
	size = Vector2i(580, 510)
	ok_button_text = "Apply"
	dialog_hide_on_ok = false
	exclusive = true
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	service_choice = OptionButton.new()
	service_choice.add_item("Passenger service")
	service_choice.add_item("Freight service")
	box.add_child(service_choice)
	service_choice.item_selected.connect(_select_service)
	name_field = LineEdit.new()
	name_field.max_length = 40
	name_field.placeholder_text = "Route name"
	box.add_child(name_field)
	var heading := Label.new()
	heading.text = "Ordered stops — train returns through the list in reverse"
	box.add_child(heading)
	stop_list = ItemList.new()
	stop_list.custom_minimum_size.y = 140
	box.add_child(stop_list)
	editing_controls = HBoxContainer.new()
	box.add_child(editing_controls)
	station_choice = OptionButton.new()
	for key in Services.STATIONS:
		station_choice.add_item(Services.STATIONS[key]["name"])
		station_choice.set_item_metadata(station_choice.item_count - 1, key)
	editing_controls.add_child(station_choice)
	add_button = _button("Add", _add_stop)
	remove_button = _button("Remove", _remove_stop)
	up_button = _button("Up", _move_stop.bind(-1))
	down_button = _button("Down", _move_stop.bind(1))
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(530, 88)
	box.add_child(status)
	confirmed.connect(_apply)

func _button(title_text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = title_text
	button.pressed.connect(callback)
	editing_controls.add_child(button)
	return button

func open_editor() -> void:
	draft = game.services.duplicate(true)
	service_choice.select(0)
	selected_service_key = "passenger"
	_show_service()
	popup_centered()

func _key() -> String:
	return selected_service_key

func _capture_name(key: String) -> void:
	draft[key]["name"] = name_field.text.strip_edges()

func _select_service(index: int) -> void:
	_capture_name(_key())
	selected_service_key = "passenger" if index == 0 else "freight"
	_show_service()

func _show_service() -> void:
	name_field.text = draft[_key()]["name"]
	editing_controls.visible = _key() == "passenger"
	_refresh_stops()
	status.text = "Choose at least two different passenger stations. Applying a new stop order returns the train to the first stop and its passengers to their departure station. The game stays paused." if _key() == "passenger" else "Forest: load logs → Terminal: unload logs → return to Forest. Freight stops have fixed roles; you can rename this service."

func _refresh_stops(selected: int = -1) -> void:
	stop_list.clear()
	var stops: Array = draft[_key()]["stops"]
	for index in range(stops.size()):
		var key: String = stops[index]
		var stop_name: String = Services.STATIONS[key]["name"] if Services.STATIONS.has(key) else ("Forest — load logs" if key == "forest" else "Terminal — unload logs")
		stop_list.add_item("%d. %s" % [index + 1, stop_name])
	if selected >= 0 and selected < stops.size():
		stop_list.select(selected)

func _add_stop() -> void:
	var key: String = station_choice.get_selected_metadata()
	var stops: Array = draft["passenger"]["stops"]
	if stops.has(key):
		status.text = "That station is already on this route. Select it and use Up or Down."
		return
	stops.append(key)
	_refresh_stops(stops.size() - 1)

func _remove_stop() -> void:
	var selected: PackedInt32Array = stop_list.get_selected_items()
	if selected.is_empty():
		return
	var stops: Array = draft["passenger"]["stops"]
	if stops.size() <= 2:
		status.text = "Keep at least two stops. Add another station before removing one."
		return
	stops.remove_at(selected[0])
	_refresh_stops(mini(selected[0], stops.size() - 1))

func _move_stop(direction: int) -> void:
	var selected: PackedInt32Array = stop_list.get_selected_items()
	if selected.is_empty():
		return
	var stops: Array = draft["passenger"]["stops"]
	var index: int = selected[0]
	var target: int = index + direction
	if target < 0 or target >= stops.size():
		return
	var stop: String = stops[index]
	stops[index] = stops[target]
	stops[target] = stop
	_refresh_stops(target)

func _apply() -> void:
	_capture_name(_key())
	status.text = game.apply_service_routes(draft)
