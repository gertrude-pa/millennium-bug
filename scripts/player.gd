extends CharacterBody2D

# Player — twin-stick Xbox pad + keyboard fallback on device -1.
# Draws as a tiny CRT monitor; flashes white on hit, shatters on final death.

const BASE_SPEED := 340.0
const ACCEL := 2200.0
const FRICTION := 1800.0
const PROJECTILE_SCENE := preload("res://scenes/floppy.tscn")
const HIT_INVULN := 0.6
const HIT_FLASH_DURATION := 0.18
const KNOCKBACK_IMPULSE := 620.0
const DEAD_ZONE := 0.22
const PICKUP_DURATION_SPEED := 6.0
const PICKUP_SPEED_MULT := 1.6
const PICKUP_PIERCE_SHOTS := 4
const PICKUP_SPREAD_SHOTS := 12

var device_id: int = 0
var player_index: int = 0
var color: Color = Color.WHITE
var lives: int = 3
var game: Node2D

var _aim: Vector2 = Vector2.RIGHT
var _invuln_t := 0.0
var _flash_t := 0.0
var _speed_boost_t := 0.0
var _pierce_ammo := 0
var _spread_ammo := 0

@onready var _aim_line: Line2D = $Aim
@onready var _shape: CollisionShape2D = $Shape
@onready var _cooldown: Timer = $Cooldown

func _ready() -> void:
	_aim_line.default_color = Color(color.r, color.g, color.b, 0.45)
	var s := RectangleShape2D.new()
	s.size = Vector2(28, 28)
	_shape.shape = s
	queue_redraw()

func _physics_process(delta: float) -> void:
	if lives <= 0:
		return
	_invuln_t = max(0.0, _invuln_t - delta)
	_flash_t = max(0.0, _flash_t - delta)
	_speed_boost_t = max(0.0, _speed_boost_t - delta)
	queue_redraw()

	var move := _read_move()
	var aim := _read_aim()
	if aim.length() > DEAD_ZONE:
		_aim = aim.normalized()
	elif move.length() > DEAD_ZONE:
		_aim = move.normalized()
	_aim_line.rotation = _aim.angle()

	var speed := BASE_SPEED * (PICKUP_SPEED_MULT if _speed_boost_t > 0.0 else 1.0)
	var target := move * speed
	velocity = velocity.move_toward(target, (ACCEL if move.length() > 0 else FRICTION) * delta)
	move_and_slide()
	_clamp_to_arena()

	if _shoot_pressed() and _cooldown.is_stopped():
		_shoot()
		_cooldown.start()

func _draw() -> void:
	var alpha := 0.55 if _invuln_t > 0.0 and int(_invuln_t * 20) % 2 == 0 else 1.0
	var flashing := _flash_t > 0.0
	# CRT monitor body.
	var body_col := Color("d8d2b8", alpha)
	draw_rect(Rect2(Vector2(-16, -16), Vector2(32, 32)), body_col, true)
	draw_rect(Rect2(Vector2(-16, -16), Vector2(32, 32)), Color("404040", alpha), false, 1.5)
	# Screen (player color, or white when flashing).
	var sc_base := Color.WHITE if flashing else color
	var sc := Color(sc_base.r, sc_base.g, sc_base.b, alpha)
	draw_rect(Rect2(Vector2(-11, -12), Vector2(22, 18)), sc, true)
	# Face: two dot eyes + mouth. Flip to a grimace when flashing.
	var face_col := Color(0, 0, 0, alpha)
	draw_rect(Rect2(Vector2(-7, -7), Vector2(2, 2)), face_col, true)
	draw_rect(Rect2(Vector2(5, -7), Vector2(2, 2)), face_col, true)
	if flashing:
		# Open-mouth "oh no" — square.
		draw_rect(Rect2(Vector2(-3, -2), Vector2(6, 5)), face_col, true)
	else:
		draw_rect(Rect2(Vector2(-4, -2), Vector2(8, 2)), face_col, true)
	# Power LED.
	var led := Color("33ff33", alpha) if int(Engine.get_frames_drawn() * 0.1) % 2 == 0 else Color("115511", alpha)
	draw_rect(Rect2(Vector2(10, 10), Vector2(2, 2)), led, true)
	# Speed boost ring.
	if _speed_boost_t > 0.0:
		draw_arc(Vector2.ZERO, 22, 0, TAU, 24, Color("66ccff", 0.8), 2.0)
	# Pierce ring.
	if _pierce_ammo > 0:
		draw_arc(Vector2.ZERO, 25, 0, TAU, 24, Color("ff00ff", 0.7), 2.0)
	# Hit-flash outer burst.
	if flashing:
		var r := 28.0 + (1.0 - _flash_t / HIT_FLASH_DURATION) * 20.0
		draw_arc(Vector2.ZERO, r, 0, TAU, 32, Color(1, 1, 1, _flash_t / HIT_FLASH_DURATION), 3.0)

func _read_move() -> Vector2:
	if device_id == -1:
		var v := Vector2(
			int(Input.is_key_pressed(KEY_D)) - int(Input.is_key_pressed(KEY_A)),
			int(Input.is_key_pressed(KEY_S)) - int(Input.is_key_pressed(KEY_W)))
		return v.limit_length(1.0)
	var raw := Vector2(
		Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(device_id, JOY_AXIS_LEFT_Y))
	return raw if raw.length() > DEAD_ZONE else Vector2.ZERO

func _read_aim() -> Vector2:
	if device_id == -1:
		var mouse := get_global_mouse_position() - global_position
		return mouse.normalized() if mouse.length() > 1.0 else Vector2.ZERO
	return Vector2(
		Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_Y))

func _shoot_pressed() -> bool:
	if device_id == -1:
		return Input.is_key_pressed(KEY_SPACE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if Input.is_joy_button_pressed(device_id, JOY_BUTTON_A):
		return true
	return Input.get_joy_axis(device_id, JOY_AXIS_TRIGGER_RIGHT) > 0.5

func _shoot() -> void:
	var piercing := _pierce_ammo > 0
	if piercing:
		_pierce_ammo -= 1
	if _spread_ammo > 0:
		_spread_ammo -= 1
		for angle in [-0.22, 0.0, 0.22]:
			var dir := _aim.rotated(angle)
			_spawn_floppy(dir, piercing)
	else:
		_spawn_floppy(_aim, piercing)

func _spawn_floppy(dir: Vector2, piercing: bool) -> void:
	var proj := PROJECTILE_SCENE.instantiate()
	proj.global_position = global_position + dir * 24.0
	proj.direction = dir
	proj.owner_id = player_index
	proj.color = color
	proj.piercing = piercing
	game.spawn_projectile(proj)

func _clamp_to_arena() -> void:
	var r: Rect2 = game.arena_rect()
	global_position.x = clamp(global_position.x, r.position.x + 16, r.position.x + r.size.x - 16)
	global_position.y = clamp(global_position.y, r.position.y + 16, r.position.y + r.size.y - 16)

func hit_by(owner_id: int, hit_dir: Vector2 = Vector2.ZERO) -> void:
	if lives <= 0 or _invuln_t > 0.0 or owner_id == player_index:
		return
	_take_damage(hit_dir)

func kill() -> void:
	if lives <= 0 or _invuln_t > 0.0:
		return
	_take_damage(Vector2.ZERO)

func _take_damage(hit_dir: Vector2) -> void:
	var idx_lost := lives - 1
	lives -= 1
	_invuln_t = HIT_INVULN
	_flash_t = HIT_FLASH_DURATION
	if hit_dir.length() > 0.01:
		velocity += hit_dir.normalized() * KNOCKBACK_IMPULSE
	if lives <= 0:
		_die()
	else:
		if game.has_method("shake"):
			game.shake(4.0, 0.15)
	if game.has_method("on_player_damaged"):
		game.on_player_damaged(self, idx_lost)

func _die() -> void:
	_spawn_shatter()
	visible = false
	set_physics_process(false)
	$Shape.set_deferred("disabled", true)
	if game.has_method("shake"):
		game.shake(10.0, 0.35)
	if game.has_method("on_player_died"):
		game.on_player_died(self)

func _spawn_shatter() -> void:
	# Build a container of shards in world space. Lives inside `game`.
	var container := Node2D.new()
	container.global_position = global_position
	game.add_child(container)
	for i in range(14):
		var shard := ColorRect.new()
		var tint_pick := randi() % 3
		var tint: Color = color
		match tint_pick:
			0: tint = color
			1: tint = Color("d8d2b8") # monitor beige
			2: tint = Color("ffffff")
		shard.color = tint
		var sz := randf_range(3.0, 7.0)
		shard.size = Vector2(sz, sz)
		shard.position = Vector2(-sz * 0.5, -sz * 0.5)
		container.add_child(shard)
		var angle := randf() * TAU
		var dist := randf_range(60.0, 160.0)
		var target := Vector2.from_angle(angle) * dist
		var tw := shard.create_tween()
		tw.parallel().tween_property(shard, "position", target, randf_range(0.7, 1.1))
		tw.parallel().tween_property(shard, "modulate:a", 0.0, 0.9).set_delay(0.2)
	# Add a quick "!" burst ring.
	var ring := _make_ring(color)
	container.add_child(ring)
	var tree_timer := get_tree().create_timer(1.4)
	tree_timer.timeout.connect(container.queue_free)

func _make_ring(c: Color) -> Node2D:
	var ring := Node2D.new()
	ring.set_script(GDScript.new())
	# Cheap: one ring control with _draw... simpler to just spawn 8 lines in tween.
	for i in range(12):
		var line := Line2D.new()
		var angle := TAU * i / 12.0
		var inner := Vector2.from_angle(angle) * 12.0
		var outer := Vector2.from_angle(angle) * 32.0
		line.add_point(inner)
		line.add_point(outer)
		line.width = 3.0
		line.default_color = Color(c.r, c.g, c.b, 1.0)
		ring.add_child(line)
		var tw := line.create_tween()
		tw.parallel().tween_property(line, "points", PackedVector2Array([outer * 1.6, outer * 2.6]), 0.45)
		tw.parallel().tween_property(line, "modulate:a", 0.0, 0.45)
	return ring

func apply_pickup(kind: int) -> void:
	match kind:
		0: _pierce_ammo = PICKUP_PIERCE_SHOTS
		1: _speed_boost_t = PICKUP_DURATION_SPEED
		2: _spread_ammo = PICKUP_SPREAD_SHOTS
		3:
			if lives > 0 and lives < 3:
				var restore_idx := lives
				lives += 1
				if game.has_method("on_life_restored"):
					game.on_life_restored(self, restore_idx)
	if game.has_method("on_pickup_collected"):
		game.on_pickup_collected(self, kind)
