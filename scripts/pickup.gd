extends Area2D

# Pickup: CD-ROM (pierce) or MODEM (speed boost).

enum Kind { CD, MODEM, FLOPPY_STACK }

var kind: int = Kind.CD

var _t := 0.0

@onready var _shape: CollisionShape2D = $Shape
@onready var _label: Label = $Label

func _ready() -> void:
	var s := CircleShape2D.new()
	s.radius = 18.0
	_shape.shape = s
	body_entered.connect(_on_body)
	_label.add_theme_font_size_override("font_size", 11)
	_label.add_theme_color_override("font_color", Color("ffffff", 0.8))
	match kind:
		Kind.CD: _label.text = "CD-ROM"
		Kind.MODEM: _label.text = "56K"
		Kind.FLOPPY_STACK: _label.text = "3.5\""
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	rotation = _t * (2.0 if kind == Kind.CD else 0.0)
	scale = Vector2.ONE * (1.0 + sin(_t * 4.0) * 0.06)
	queue_redraw()

func _draw() -> void:
	match kind:
		Kind.CD:
			# Rainbow CD: concentric rings.
			for i in range(6):
				var r: float = 18.0 - i * 2.2
				var col := Color.from_hsv(fmod(_t * 0.3 + i * 0.13, 1.0), 0.6, 1.0)
				draw_circle(Vector2.ZERO, r, col)
			draw_circle(Vector2.ZERO, 4.0, Color("101020"))
		Kind.MODEM:
			draw_rect(Rect2(Vector2(-20, -12), Vector2(40, 24)), Color("204060"), true)
			draw_rect(Rect2(Vector2(-20, -12), Vector2(40, 24)), Color("66ccff"), false, 2.0)
			# Blinking LEDs.
			var on := int(_t * 6.0) % 2 == 0
			draw_circle(Vector2(-10, 0), 2.0, Color("ff2222") if on else Color("440000"))
			draw_circle(Vector2(0, 0), 2.0, Color("22ff22") if not on else Color("004400"))
			draw_circle(Vector2(10, 0), 2.0, Color("ffee00") if on else Color("444400"))
		Kind.FLOPPY_STACK:
			draw_rect(Rect2(Vector2(-16, -16), Vector2(32, 32)), Color("333333"), true)
			draw_rect(Rect2(Vector2(-10, -14), Vector2(20, 10)), Color("bbbbbb"), true)
			draw_rect(Rect2(Vector2(-8, -12), Vector2(16, 6)), Color("000000"), true)

func _on_body(body: Node) -> void:
	if not body.has_method("apply_pickup"):
		return
	body.apply_pickup(kind)
	queue_free()
