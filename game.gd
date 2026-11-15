extends Node2D

const CAT = preload("res://arena_cat.tscn")
const START_SIZE = Vector2(3200, 1800)
const START_ZOOM = 3.0
const START_RADIUS = 15.0
const SCORE_FILE = "user://high_score.cfg"

@onready var picker = $HUD/AvatarPicker
@onready var camera = $Camera2D
var arena = Rect2()
var player = null
var game_over = false
var high_score = 0
var npc_skins = []
var growth_progress = 0

func _ready():
	picker.skin_changed.connect(_on_skin_changed)
	picker.setup($Skins/PlayerSkins.get_children(), $Skins/ArenaSkins.get_children())
	load_high_score()
	set_arena(view().size)
	camera.force_update_scroll()
	get_viewport().size_changed.connect(_on_viewport_resized)
	var top = $PickerBarrier/Panel.polygon[0]
	for point in $PickerBarrier/Panel.polygon:
		if point.y < top.y:
			top = point
	var kitten = add_cat(1, top + Vector2.UP * 42)
	kitten.direction = Vector2.DOWN
	kitten.speed = 75.0
	for level in range(2, 9):
		spawn_random_cat(level, arena)

func load_high_score():
	var file = ConfigFile.new()
	if file.load(SCORE_FILE) == OK:
		high_score = file.get_value("game", "high_score", 0)
	$HUD/HighScore.text = "Best " + str(high_score)

func save_high_score():
	if player.score <= high_score:
		return
	var file = ConfigFile.new()
	file.load(SCORE_FILE)
	high_score = maxi(high_score, file.get_value("game", "high_score", 0))
	if player.score > high_score:
		file.set_value("game", "high_score", player.score)
		if file.save(SCORE_FILE) == OK:
			high_score = player.score
	$HUD/HighScore.text = "Best " + str(high_score)

func _unhandled_input(event):
	if player == null and event.is_action_pressed("start_game"):
		start_round()

func start_round():
	$HUD/BoostNotice.hide()
	$BoostNoticeTimer.stop()
	$Treats.clear()
	$BounceMeow.stop()
	$Meow.stop()
	for cat in $Cats.get_children():
		$Cats.remove_child(cat)
		cat.queue_free()
	game_over = false
	growth_progress = 0
	set_arena(START_SIZE)
	camera.position = Vector2.ZERO
	camera.zoom = Vector2.ONE * START_ZOOM
	camera.reset_physics_interpolation()
	picker.hide()
	$PickerBarrier.collision_layer = 0
	$Disks.place()
	player = add_cat(2, Vector2.ZERO, picker.selected_skin())
	player.score = 0
	add_cat(1, Vector2(72, 10))
	add_cat(1, Vector2(-76, -36))
	spawn_random_cat(randi_range(player.level, level_at_size(1.5)), view())
	for i in range(4):
		spawn_random_cat(randi_range(level_at_size(0.6), player.level - 1), arena)
		spawn_random_cat(random_cat_level(), arena, true)
	$Treats.fill_arena()
	$HUD/Title.hide()
	$HUD/Message.hide()
	$HUD/Score.text = "0"
	$HUD/Score.show()

func _on_skin_changed(skin):
	npc_skins = $Skins/ArenaSkins.get_children()
	npc_skins.erase(skin)
	for cat in $Cats.get_children():
		if cat != player and cat.skin == skin:
			cat.set_skin(npc_skins.pick_random())
			cat.set_level(cat.level)

func add_cat(level, spot, skin = null):
	var cat = CAT.instantiate()
	cat.game = self
	cat.position = spot
	cat.previous_spot = spot
	$Cats.add_child(cat)
	if skin == null:
		skin = npc_skins.pick_random()
	cat.set_skin(skin)
	cat.set_level(level)
	cat.score = level
	cat.reset_physics_interpolation()
	return cat

func eat(big_cat, small_cat):
	if game_over or big_cat.is_queued_for_deletion() or small_cat.is_queued_for_deletion():
		return
	big_cat.swallow_picture(small_cat.get_node("Sprite2D"))
	small_cat.hide()
	small_cat.queue_free()
	grow_cat(big_cat, small_cat.score)
	if small_cat == player:
		$HUD/BoostNotice.hide()
		$BoostNoticeTimer.stop()
		$BounceMeow.stop()
		$Meow.play()
		game_over = true
		player = null
		$HUD/Title.text = "You were eaten!"
		$HUD/Title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		$HUD/Title.show()
		$HUD/Message.text = "Press Space to replay"
		$HUD/Message.show()
	elif player == null and big_cat.level >= 15:
		big_cat.queue_free()

func show_speed_boost():
	$HUD/BoostNotice.show()
	$BoostNoticeTimer.start()

func grow_cat(cat, points):
	cat.score += points
	if cat != player:
		cat.set_level(cat.level + 1, true)
		return
	$HUD/Score.text = str(player.score)
	save_high_score()
	if player.level < 5:
		growth_progress += 3
		if growth_progress < 4:
			return
		growth_progress -= 4
	player.set_level(player.level + 1, true)
	var growth = player.radius / START_RADIUS
	set_arena(START_SIZE * growth)

func _physics_process(delta):
	if player == null:
		return
	var growth = player.radius / START_RADIUS
	var follow = minf(4.4 * delta, 1.0)
	var zoom = START_ZOOM / (1 + (growth - 1) * 0.8)
	camera.zoom = camera.zoom.lerp(Vector2.ONE * zoom, follow)
	var player_warped = false
	for cat in $Cats.get_children():
		if not cat.is_queued_for_deletion():
			var warped = $Disks.visit(cat)
			if cat == player:
				player_warped = warped
	if player_warped:
		camera.position = player.position
	else:
		camera.position = camera.position.lerp(player.position, follow)
	var edge = ((arena.size - view().size) / 2).max(Vector2.ZERO)
	camera.position = camera.position.clamp(-edge, edge)
	if player_warped:
		camera.reset_physics_interpolation()
		camera.force_update_scroll()

func level_at_size(fraction):
	var radius = player.radius * fraction
	return maxi(1, ceili((radius - 9) / 3))

func random_cat_level():
	var medium = level_at_size(1.5)
	if randf() < 0.15:
		return randi_range(medium + 1, level_at_size(3.0))
	return randi_range(level_at_size(0.6), medium)

func set_arena(size):
	arena = Rect2(-size / 2, size)
	var stars = (size / $Background.scale).ceil()
	$Background.region_rect = Rect2(-stars / 2, stars)
	$Walls/Left.position.x = arena.position.x
	$Walls/Right.position.x = arena.end.x
	$Walls/Top.position.y = arena.position.y
	$Walls/Bottom.position.y = arena.end.y

func _on_viewport_resized():
	if picker.visible:
		camera.force_update_scroll()
		set_arena(view().size)

func view():
	var size = get_viewport_rect().size / camera.zoom
	return Rect2(camera.position - size / 2, size)

func movement_scale():
	if player == null:
		return 1.0
	return START_ZOOM / camera.zoom.x

func has_room(spot, radius):
	for treat in $Treats.get_children():
		if spot.distance_to(treat.position) < radius + treat.texture.get_height() * treat.scale.y + 15:
			return false
	if $Disks.visible:
		for disk in $Disks.get_children():
			if disk.visible and spot.distance_to(disk.global_position) < radius + $Disks.clearance_radius(disk):
				return false
	if picker.visible:
		for barrier in $PickerBarrier.get_children():
			var points = barrier.polygon
			if Geometry2D.is_point_in_polygon(spot, points):
				return false
			for i in points.size():
				var edge = Geometry2D.get_closest_point_to_segment(spot, points[i - 1], points[i])
				if spot.distance_to(edge) <= radius * 1.42:
					return false
	for cat in $Cats.get_children():
		if spot.distance_to(cat.position) < radius + cat.radius + 15:
			return false
	return true

func spawn_random_cat(level, area, offscreen = false):
	var radius = 9 + 3 * level
	var space = area.intersection(arena).grow(-radius)
	var visible_area = view().grow(radius + 10)
	if not space.has_area():
		return null
	for attempt in range(30):
		var x = randf_range(space.position.x, space.end.x)
		var y = randf_range(space.position.y, space.end.y)
		var spot = Vector2(x, y)
		if offscreen and visible_area.has_point(spot):
			continue
		if has_room(spot, radius):
			var cat = add_cat(level, spot)
			if offscreen:
				cat.direction = spot.direction_to(visible_area.get_center())
			return cat
	return null

func _on_spawn_timer_timeout():
	if game_over:
		return
	if player == null:
		if $Cats.get_child_count() < 30:
			spawn_random_cat(randi_range(1, 8), arena)
		return

	$Treats.refill()
	var screen = view()
	var nearby = screen.grow(screen.size.y / 2)
	var smallest = level_at_size(0.6)
	var kittens = 0
	var far_away = []
	for cat in $Cats.get_children():
		if cat == player or cat.is_queued_for_deletion():
			continue
		if not nearby.grow(cat.radius).has_point(cat.position):
			far_away.append(cat)
		elif cat.level >= smallest and cat.level < player.level:
			kittens += 1

	var wanted = min(player.level + 2, 16)
	var entrance = screen.grow(screen.size.y / 5 + 40)
	for i in range(min(3, wanted - kittens)):
		var full = $Cats.get_child_count() >= 30 + wanted
		if full and far_away.is_empty():
			break
		var kitten = spawn_random_cat(randi_range(smallest, player.level - 1), entrance, true)
		if full and kitten != null:
			var old_cat = far_away.pop_back()
			$Cats.remove_child(old_cat)
			old_cat.queue_free()
	if $Cats.get_child_count() < 30 + wanted:
		spawn_random_cat(random_cat_level(), arena, true)
