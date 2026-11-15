extends Node2D

func place():
	var side = [-1, 1].pick_random()
	$First.position = Vector2(side * randf_range(245, 280), randf_range(-85, 85))
	$Second.position = Vector2(-side * randf_range(440, 775), randf_range(-310, 310))
	for disk in get_children():
		disk.show()
		disk.rotation = randf() * TAU
		disk.reset_physics_interpolation()
	show()

func clearance_radius(disk: Sprite2D) -> float:
	return disk.texture.get_height() * disk.scale.y * 0.5 + 20.0

func core_radius(disk: Sprite2D) -> float:
	return disk.texture.get_width() * disk.scale.x * 0.21

func _physics_process(delta):
	if visible:
		for disk in get_children():
			disk.rotate(0.85 * delta)

func visit(cat) -> bool:
	var start = cat.previous_spot
	var spot = cat.position
	cat.previous_spot = spot
	for disk in get_children():
		if not disk.visible:
			continue
		var can_eat = cat.radius >= disk.texture.get_width() * disk.scale.x * 0.5
		if disk == cat.exit_disk and not can_eat:
			if spot.distance_to(disk.position) > core_radius(disk) + 8:
				cat.exit_disk = null
			continue
		var nearest = spot
		if start != spot:
			nearest = Geometry2D.get_closest_point_to_segment(disk.position, start, spot)
		var reach = cat.radius if can_eat else core_radius(disk)
		if nearest.distance_to(disk.position) > reach:
			continue
		if can_eat:
			cat.swallow_picture(disk)
			disk.hide()
			get_parent().grow_cat(cat, 10)
			return false
		var partner = $Second if disk == $First else $First
		if partner.visible:
			cat.exit_disk = partner
			cat.previous_spot = partner.position
			cat.emerge(partner.position)
			return true
	return false
