extends Area2D

# BSOD hazard: vertical bar sweeps across the arena. Touching = instant kill.

const WIDTH := 180.0
const SPEED := 160.0

var direction: int = 1 # 1 = left to right, -1 = right to left
var _arena_rect: Rect2

@onready var _shape: CollisionShape2D = $Shape
@onready var _label: Label = $Label

func _ready() -> void:
	var s := RectangleShape2D.new()
	s.size = Vector2(WIDTH, 720.0)
	_shape.shape = s
	body_entered.connect(_on_body)
	_label.text = "*** STOP ***\n0x0000Y2K\n\nTHE MILLENNIUM\nHAS BUGGED.\n\nPRESS ANY KEY\nTO CONTINUE."
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", Color.WHITE)

func configure(arena_rect: Rect2, dir: int) -> void:
	_arena_rect = arena_rect
	direction = dir
	global_position = Vector2(
		_arena_rect.position.x - WIDTH * 0.5 if dir > 0 else _arena_rect.position.x + _arena_rect.size.x + WIDTH * 0.5,
		_arena_rect.position.y + _arena_rect.size.y * 0.5)

func _physics_process(delta: float) -> void:
	global_position.x += direction * SPEED * delta
	var end_x: float = _arena_rect.position.x + _arena_rect.size.x + WIDTH
	var start_x: float = _arena_rect.position.x - WIDTH
	if (direction > 0 and global_position.x > end_x) or (direction < 0 and global_position.x < start_x):
		queue_free()
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2(-WIDTH * 0.5, -360), Vector2(WIDTH, 720)), Color("1844b0"), true)
	draw_rect(Rect2(Vector2(-WIDTH * 0.5, -360), Vector2(WIDTH, 720)), Color("ffffff"), false, 2.0)

func _on_body(body: Node) -> void:
	if body.has_method("kill"):
		body.kill()
