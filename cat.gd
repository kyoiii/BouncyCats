extends RigidBody2D

const TEA_PINK = Color("#ffd1e2")
const TEA_BOOST = 1.35

@export var ring_distance_in_radii = 7.0
@export var player_speed = 428.0
@export var player_acceleration = 2450.0
@export var player_braking = 1050.0
@export var npc_braking = 140.0
var level = 1
var score = 0
var radius = 12.0
var direction = Vector2.RIGHT.rotated(randf() * TAU)
var speed = randf_range(47, 101)
var bounce_time = 0.0
var portal_exit_time = 0.0
var bounce_sound_cooldown = 0.0
var previous_spot = Vector2.ZERO
var exit_disk: Sprite2D
var game
var skin: Polygon2D
var ring_visible = false
var artwork_radius = 0.0
var skin_bounds = Rect2()
@onready var sprite = $Sprite2D
var growth_tween: Tween
var speed_factor = 1.0
var tea_time = 0.0

func drink_tea():
	tea_time += 7.0
	sprite.self_modulate = TEA_PINK

func tea_speed() -> float:
	return lerpf(1.0, TEA_BOOST, minf(tea_time, 1.0))

func spin():
	$AnimationPlayer.queue("lollipop")

func set_skin(new_skin):
	skin = new_skin
	sprite.texture = skin.texture
	$CollisionPolygon2D.polygon = skin.polygon
	$EatArea/CollisionPolygon2D.polygon = $CollisionPolygon2D.polygon

	artwork_radius = 0.0
	skin_bounds = Rect2(skin.polygon[0], Vector2.ZERO)
	for point in $CollisionPolygon2D.polygon:
		artwork_radius = maxf(artwork_radius, point.length())
		skin_bounds = skin_bounds.expand(point)

func _process(_delta):
	var player = game.player
	var nearby = false
	if player != null and self != player and level == player.level and not game.game_over:
		var reach = radius * ring_distance_in_radii
		if ring_visible:
			reach += radius * 0.4
		nearby = position.distance_to(player.position) <= reach
	if nearby != ring_visible:
		ring_visible = nearby
		queue_redraw()

func _draw():
	if ring_visible:
		var size = artwork_radius * $CollisionPolygon2D.scale.x + radius * 0.10
		draw_arc(Vector2.ZERO, size, 0, TAU, 80, skin.color, radius * 0.045, true)

func set_level(new_level, animate = false):
	queue_redraw()
	level = new_level
	radius = 9 + 3 * level
	speed_factor = 0.99 + 0.01 * minf(1.0, 15.0 / radius)
	var size = Vector2.ONE * (radius * 2) / sprite.texture.get_width()
	$CollisionPolygon2D.scale = size
	$EatArea.scale = size
	if growth_tween:
		growth_tween.kill()
	if animate:
		growth_tween = create_tween()
		growth_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		growth_tween.tween_property(sprite, "scale", size, 0.22)
	else:
		sprite.scale = size
	for other in get_parent().get_children():
		if other == self or other.is_queued_for_deletion():
			continue
		if level == other.level:
			remove_collision_exception_with(other)
			other.remove_collision_exception_with(self)
		else:
			add_collision_exception_with(other)
			other.add_collision_exception_with(self)

func swallow_picture(source: Sprite2D):
	var bite = Sprite2D.new()
	bite.texture = source.texture
	bite.texture_filter = source.texture_filter
	bite.self_modulate = source.self_modulate
	add_child(bite)
	move_child(bite, 0)
	bite.global_transform = source.global_transform
	bite.reset_physics_interpolation()
	var tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_parallel(true)
	tween.tween_property(bite, "position", Vector2.ZERO, 0.22)
	tween.tween_property(bite, "scale", Vector2.ZERO, 0.22)
	tween.chain().tween_callback(bite.queue_free)

func _exit_tree():
	for other in get_parent().get_children():
		if other != self:
			other.remove_collision_exception_with(self)

func emerge(spot: Vector2):
	var heading = linear_velocity.normalized()
	if heading == Vector2.ZERO:
		heading = spot.direction_to(Vector2.ZERO)
	position = spot
	reset_physics_interpolation()
	var travel_speed = player_speed if self == game.player else speed
	linear_velocity = heading * maxf(linear_velocity.length(), travel_speed * game.movement_scale() * speed_factor * tea_speed() * 0.7)
	portal_exit_time = 0.14

func _integrate_forces(state):
	if game.game_over or is_queued_for_deletion():
		state.linear_velocity = Vector2.ZERO
		return
	if portal_exit_time > 0.0:
		portal_exit_time -= state.step
		return
	if bounce_time > 0.0:
		bounce_time -= state.step
		if state.linear_velocity.length_squared() > 1.0:
			direction = state.linear_velocity.normalized()
		return

	var target: Vector2
	var movement_scale = game.movement_scale()
	var acceleration = 750.0
	var braking = npc_braking
	if self == game.player:
		acceleration = player_acceleration
		braking = player_braking
		var scale_factor = $CollisionPolygon2D.scale
		var bounds = game.arena.grow(-0.5)
		var goal = get_global_mouse_position().clamp(
			bounds.position - skin_bounds.position * scale_factor,
			bounds.end - skin_bounds.end * scale_factor)
		var to_mouse = goal - state.transform.origin
		var max_speed = player_speed * speed_factor * movement_scale
		target = (to_mouse * 3.5).limit_length(max_speed) * tea_speed()
	else:
		chase_smaller_cat()
		target = direction * speed * speed_factor * movement_scale * tea_speed()

	var velocity = state.linear_velocity
	if velocity.length() > target.length() or velocity.dot(target) < 0:
		acceleration = braking
	for i in state.get_contact_count():
		if state.get_contact_collider_object(i) is StaticBody2D:
			var normal = state.get_contact_local_normal(i)
			if target.dot(normal) < 0.0:
				target = target.slide(normal)
	state.linear_velocity = state.linear_velocity.move_toward(target, acceleration * movement_scale * state.step)

func _on_body_entered(body):
	if body == game.get_node("PickerBarrier"):
		bounce_time = 0.50
	else:
		bounce_time = maxf(bounce_time, 0.30)

	if self != game.player or game.game_over or is_queued_for_deletion() or body.is_queued_for_deletion():
		return
	var impact_speed = linear_velocity.length()
	if body is RigidBody2D:
		if body.level != level:
			return
		impact_speed = linear_velocity.distance_to(body.linear_velocity)
	if bounce_sound_cooldown <= 0.0 and impact_speed > 8.0:
		game.get_node("BounceMeow").play()
		bounce_sound_cooldown = 0.16

func _physics_process(delta):
	if tea_time > 0.0:
		tea_time = maxf(0.0, tea_time - delta)
		sprite.self_modulate = Color.WHITE.lerp(TEA_PINK, minf(1.0, tea_time))
	bounce_sound_cooldown = maxf(0.0, bounce_sound_cooldown - delta)
	if game.game_over or is_queued_for_deletion() or portal_exit_time > 0.0:
		return
	for other in $EatArea.get_overlapping_bodies():
		if not other.is_queued_for_deletion() and level > other.level and other.portal_exit_time <= 0.0:
			game.eat(self, other)
			if game.game_over or is_queued_for_deletion():
				return

func chase_smaller_cat():
	var closest = INF
	var prey = null
	for other in get_parent().get_children():
		if other.level < level and not other.is_queued_for_deletion():
			var distance = position.distance_squared_to(other.position)
			if distance > 0 and distance < closest:
				closest = distance
				prey = other
	if prey != null:
		direction = position.direction_to(prey.position)
