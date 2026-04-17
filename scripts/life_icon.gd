extends Control

# A 24x24 floppy icon used as a life indicator in the HUD panel.
# Call break_it() to animate its destruction.

var _color: Color = Color.WHITE
var _broken := false

func _ready() -> void:
	pivot_offset = Vector2(12, 12)
	queue_redraw()

func set_color(c: Color) -> void:
	_color = c
	queue_redraw()

func _draw() -> void:
	# Floppy body.
	draw_rect(Rect2(Vector2(0, 0), Vector2(24, 24)), Color("2a2a2a"), true)
	draw_rect(Rect2(Vector2(0, 0), Vector2(24, 24)), Color("555555"), false, 1.0)
	# Metal shutter.
	draw_rect(Rect2(Vector2(4, 0), Vector2(16, 9)), Color("b0b0b0"), true)
	draw_rect(Rect2(Vector2(8, 1), Vector2(8, 6)), Color("000000"), true)
	# Label strip (tinted to player color).
	draw_rect(Rect2(Vector2(4, 13), Vector2(16, 8)), _color, true)
	# Label lines.
	draw_rect(Rect2(Vector2(6, 15), Vector2(12, 1)), Color("222222"), true)
	draw_rect(Rect2(Vector2(6, 17), Vector2(10, 1)), Color("222222"), true)

func break_it() -> void:
	if _broken:
		return
	_broken = true
	# Phase 1: shake + pop to red.
	var p1 := create_tween().set_parallel()
	p1.tween_property(self, "modulate", Color("ff3333"), 0.08)
	p1.tween_property(self, "scale", Vector2(1.35, 1.35), 0.08)
	p1.tween_property(self, "rotation", deg_to_rad(18), 0.08)
	# Phase 2: counter-shake.
	await p1.finished
	var p2 := create_tween().set_parallel()
	p2.tween_property(self, "rotation", deg_to_rad(-22), 0.08)
	p2.tween_property(self, "scale", Vector2(1.1, 1.1), 0.08)
	# Phase 3: fall / fade.
	await p2.finished
	var p3 := create_tween().set_parallel()
	p3.tween_property(self, "rotation", deg_to_rad(80), 0.5)
	p3.tween_property(self, "position:y", position.y + 28, 0.5)
	p3.tween_property(self, "modulate:a", 0.0, 0.5)
	p3.tween_property(self, "scale", Vector2(0.4, 0.4), 0.5)
