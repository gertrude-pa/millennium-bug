extends Area2D

# Floppy disk projectile.
# Normal: 1 hit then gone. Piercing: passes through players, each only hit once,
# bounces forever off walls until lifetime runs out.

const SPEED := 720.0
const LIFETIME := 1.4

var direction: Vector2 = Vector2.RIGHT
var owner_id: int = -1
var color: Color = Color.WHITE
var piercing: bool = false

var _t := 0.0
var _hit_bodies: Array = []

@onready var _shape: CollisionShape2D = $Shape

func _ready() -> void:
	rotation = direction.angle()
	var s := RectangleShape2D.new()
	s.size = Vector2(14, 14)
	_shape.shape = s
	body_entered.connect(_on_body)
	queue_redraw()

func _physics_process(delta: float) -> void:
	_t += delta
	if _t > LIFETIME:
		queue_free()
		return
	global_position += direction * SPEED * delta
	var game := get_tree().current_scene
	if game and game.has_method("arena_rect"):
		var r: Rect2 = game.arena_rect()
		if global_position.x < r.position.x or global_position.x > r.position.x + r.size.x:
			direction.x = -direction.x
			rotation = direction.angle()
		if global_position.y < r.position.y or global_position.y > r.position.y + r.size.y:
			direction.y = -direction.y
			rotation = direction.angle()
	rotation += delta * 18.0 # Floppy spin around travel axis (cosmetic).
	queue_redraw()

func _draw() -> void:
	# 3.5" floppy silhouette.
	draw_rect(Rect2(Vector2(-7, -7), Vector2(14, 14)), Color("222222"), true)
	draw_rect(Rect2(Vector2(-5, -7), Vector2(10, 5)), Color("b0b0b0"), true)
	draw_rect(Rect2(Vector2(-3, -6), Vector2(6, 3)), Color("000000"), true)
	draw_rect(Rect2(Vector2(-4, 0), Vector2(8, 5)), color, true) # Label in player color.

func _on_body(body: Node) -> void:
	if not body.has_method("hit_by"):
		return
	if body in _hit_bodies:
		return
	body.hit_by(owner_id, direction)
	_hit_bodies.append(body)
	if not piercing:
		queue_free()
