extends Node2D

const MILK = preload("res://art/snacks/milk.png")
const ICING = preload("res://art/snacks/icing.png")
const STRAWBERRY = preload("res://art/snacks/strawberry.png")
const LOLLIPOP = preload("res://art/snacks/lollipop.png")
const BUBBLE_TEA = preload("res://art/snacks/cup.png")
const COMMON_FOODS = [MILK, ICING, STRAWBERRY]
const COUNT = 25

@onready var game = get_parent()

func clear():
	for treat in get_children():
		remove_child(treat)
		treat.queue_free()

func fill_arena():
	for food in COMMON_FOODS:
		spawn_treat(food, game.view())
	spawn_treat(random_food(), game.view())
	spawn_treat(random_food(), game.view())

	var half_size = game.arena.size / 2
	for row in range(2):
		for column in range(2):
			var corner = game.arena.position + Vector2(column, row) * half_size
			for food in COMMON_FOODS:
				spawn_treat(food, Rect2(corner, half_size))

	for i in range(COUNT - get_child_count()):
		spawn_treat(random_food(), game.arena)

func random_food():
	if randf() < 0.15:
		return [LOLLIPOP, BUBBLE_TEA].pick_random()
	return COMMON_FOODS.pick_random()

func spawn_treat(picture, area: Rect2) -> bool:
	var height = game.player.radius * randf_range(1.05, 1.3)
	var space = area.intersection(game.arena).grow(-height)
	if not space.has_area():
		return false
	for attempt in range(40):
		var x = randf_range(space.position.x, space.end.x)
		var y = randf_range(space.position.y, space.end.y)
		var spot = Vector2(x, y)
		if game.has_room(spot, height * 0.5):
			var treat = Sprite2D.new()
			treat.texture = picture
			treat.scale = Vector2.ONE * height / picture.get_height()
			treat.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			treat.position = spot
			add_child(treat)
			treat.reset_physics_interpolation()
			return true
	return false

func _physics_process(_delta):
	if game.player == null:
		return
	var cats = game.get_node("Cats").get_children()
	for treat in get_children():
		var treat_radius = treat.texture.get_height() * treat.scale.y * 0.35
		for cat in cats:
			if cat.is_queued_for_deletion():
				continue
			var reach = cat.radius * 0.85 + treat_radius
			if cat.position.distance_squared_to(treat.position) <= reach * reach:
				eat_treat(treat, cat)
				break

func eat_treat(treat, cat):
	if treat.texture == LOLLIPOP:
		cat.spin()
	elif treat.texture == BUBBLE_TEA:
		cat.drink_tea()
		if cat == game.player:
			game.show_speed_boost()
	cat.swallow_picture(treat)
	remove_child(treat)
	treat.queue_free()
	game.grow_cat(cat, 1)

func refill():
	var screen = game.view()
	var nearby = 0
	for treat in get_children():
		if screen.has_point(treat.position):
			nearby += 1
	if get_child_count() < COUNT:
		if nearby < 3:
			spawn_treat(random_food(), screen.grow(screen.size.y * 0.3))
		else:
			spawn_treat(random_food(), game.arena)
