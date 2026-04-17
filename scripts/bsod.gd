extends Area2D

# BSOD hazard: vertical bar sweeps across the arena with a random-height
# safe gap so players can dodge through. Touching the blue = -1 life.

const WIDTH := 180.0
const SPEED := 160.0
const GAP_HEIGHT := 140.0
const FULL_HEIGHT := 720.0

var direction: int = 1
var _arena_rect: Rect2
var _gap_y: float = 360.0 # Center of the safe gap in local space (y=0 at node).

@onready var _shape_top: CollisionShape2D = $ShapeTop
@onready var _shape_bot: CollisionShape2D = $ShapeBot
@onready var _label: Label = $Label

func _ready() -> void:
	body_entered.connect(_on_body)
	_label.text = "*** STOP ***\n0x0000Y2K\n\nTHE MILLENNIUM\nHAS BUGGED.\n\nPRESS ANY KEY\nTO CONTINUE."
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", Color.WHITE)

func configure(arena_rect: Rect2, dir: int) -> void:
	_arena_rect = arena_rect
	direction = dir
	# Pick a gap center within the arena, keeping the gap fully inside.
	var min_y := _arena_rect.position.y + GAP_HEIGHT * 0.5 + 10.0
	var max_y := _arena_rect.position.y + _arena_rect.size.y - GAP_HEIGHT * 0.5 - 10.0
	var gap_center_world := randf_range(min_y, max_y)
	# Node y sits at arena vertical center; convert world y → local.
	var node_y := _arena_rect.position.y + _arena_rect.size.y * 0.5
	_gap_y = gap_center_world - node_y
	global_position = Vector2(
		_arena_rect.position.x - WIDTH * 0.5 if dir > 0 else _arena_rect.position.x + _arena_rect.size.x + WIDTH * 0.5,
		node_y)
	_apply_shapes()
	_label.position = Vector2(_label.position.x, _gap_y - 300.0)

func _apply_shapes() -> void:
	# Top piece: from -FULL_HEIGHT*0.5 to (_gap_y - GAP_HEIGHT*0.5).
	var top_top := -FULL_HEIGHT * 0.5
	var top_bottom := _gap_y - GAP_HEIGHT * 0.5
	var top_h: float = max(0.0, top_bottom - top_top)
	var top_s := RectangleShape2D.new()
	top_s.size = Vector2(WIDTH, top_h)
	_shape_top.shape = top_s
	_shape_top.position = Vector2(0, top_top + top_h * 0.5)

	var bot_top := _gap_y + GAP_HEIGHT * 0.5
	var bot_bottom := FULL_HEIGHT * 0.5
	var bot_h: float = max(0.0, bot_bottom - bot_top)
	var bot_s := RectangleShape2D.new()
	bot_s.size = Vector2(WIDTH, bot_h)
	_shape_bot.shape = bot_s
	_shape_bot.position = Vector2(0, bot_top + bot_h * 0.5)

func _physics_process(delta: float) -> void:
	global_position.x += direction * SPEED * delta
	var end_x: float = _arena_rect.position.x + _arena_rect.size.x + WIDTH
	var start_x: float = _arena_rect.position.x - WIDTH
	if (direction > 0 and global_position.x > end_x) or (direction < 0 and global_position.x < start_x):
		queue_free()
	queue_redraw()

func _draw() -> void:
	var w := WIDTH
	var half_h := FULL_HEIGHT * 0.5
	var top_y := -half_h
	var top_h: float = _gap_y - GAP_HEIGHT * 0.5 - top_y
	if top_h > 0.0:
		draw_rect(Rect2(Vector2(-w * 0.5, top_y), Vector2(w, top_h)), Color("1844b0"), true)
		draw_rect(Rect2(Vector2(-w * 0.5, top_y), Vector2(w, top_h)), Color("ffffff"), false, 2.0)
	var bot_y := _gap_y + GAP_HEIGHT * 0.5
	var bot_h: float = half_h - bot_y
	if bot_h > 0.0:
		draw_rect(Rect2(Vector2(-w * 0.5, bot_y), Vector2(w, bot_h)), Color("1844b0"), true)
		draw_rect(Rect2(Vector2(-w * 0.5, bot_y), Vector2(w, bot_h)), Color("ffffff"), false, 2.0)
	# Gap marker: dashed cyan outline + arrow hint.
	_draw_dashed_gap(w)
	var hint := "-- SAFE --"
	var font := ThemeDB.fallback_font
	var size := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
	draw_string(font, Vector2(-size.x * 0.5, _gap_y + 5), hint,
		HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color("00ffcc"))

func _draw_dashed_gap(w: float) -> void:
	var col := Color("00ffcc")
	var top_y := _gap_y - GAP_HEIGHT * 0.5
	var bot_y := _gap_y + GAP_HEIGHT * 0.5
	var dash := 10.0
	var step := 18.0
	var x := -w * 0.5
	while x < w * 0.5:
		draw_line(Vector2(x, top_y), Vector2(x + dash, top_y), col, 2.0)
		draw_line(Vector2(x, bot_y), Vector2(x + dash, bot_y), col, 2.0)
		x += step

func _on_body(body: Node) -> void:
	if body.has_method("kill"):
		body.kill()
