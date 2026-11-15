extends TextureRect

signal skin_changed(skin)

var skins = []
var selected = 3

func setup(player_skins, arena_skins):
	skins = player_skins + arena_skins
	choose(selected)

func choose(index):
	selected = wrapi(index, 0, skins.size())
	$Portrait.texture = selected_skin().texture
	skin_changed.emit(selected_skin())

func selected_skin():
	return skins[selected]

func _on_previous_pressed():
	choose(selected - 1)

func _on_next_pressed():
	choose(selected + 1)

func _unhandled_key_input(event):
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_left"):
		_on_previous_pressed()
	elif event.is_action_pressed("ui_right"):
		_on_next_pressed()
	else:
		return
	get_viewport().set_input_as_handled()
