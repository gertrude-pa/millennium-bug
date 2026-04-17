extends Control

# A 24x24 floppy icon used as a life indicator in the HUD panel.
# break_it() animates destruction; restore() brings it back.

var _color: Color = Color.WHITE
var _broken := false
var _base_pos: Vector2
var _base_rotation := 0.0
var _base_scale: Vector2 = Vector2.ONE
var _base_modulate: Color = Color.WHITE
var _active_tween: Tween = null

func _ready() -> void:
	pivot_offset = Vector2(12, 12)
	_base_pos = position
	_base_rotation = rotation
	_base_scale = scale
	_base_modulate = modulate
	queue_redraw()

func set_color(c: Color) -> void:
	_color = c
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2(0, 0), Vector2(24, 24)), Color("2a2a2a"), true)
	draw_rect(Rect2(Vector2(0, 0), Vector2(24, 24)), Color("555555"), false, 1.0)
	draw_rect(Rect2(Vector2(4, 0), Vector2(16, 9)), Color("b0b0b0"), true)
	draw_rect(Rect2(Vector2(8, 1), Vector2(8, 6)), Color("000000"), true)
	draw_rect(Rect2(Vector2(4, 13), Vector2(16, 8)), _color, true)
	draw_rect(Rect2(Vector2(6, 15), Vector2(12, 1)), Color("222222"), true)
	draw_rect(Rect2(Vector2(6, 17), Vector2(10, 1)), Color("222222"), true)

func break_it() -> void:
	if _broken:
		return
	_broken = true
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	var tw: Tween = create_tween()
	_active_tween = tw
	tw.tween_property(self, "modulate", Color("ff3333"), 0.08)
	tw.parallel().tween_property(self, "scale", Vector2(1.35, 1.35), 0.08)
	tw.parallel().tween_property(self, "rotation", deg_to_rad(18), 0.08)
	tw.chain().tween_property(self, "rotation", deg_to_rad(-22), 0.08)
	tw.parallel().tween_property(self, "scale", Vector2(1.1, 1.1), 0.08)
	tw.chain().tween_property(self, "rotation", deg_to_rad(80), 0.5)
	tw.parallel().tween_property(self, "position:y", _base_pos.y + 28, 0.5)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.5)
	tw.parallel().tween_property(self, "scale", Vector2(0.4, 0.4), 0.5)

func restore() -> void:
	if not _broken:
		return
	_broken = false
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	# Snap to a "zoom-in from nothing" state, then grow into place.
	position = _base_pos
	rotation = _base_rotation
	modulate = Color(_base_modulate.r, _base_modulate.g, _base_modulate.b, 0.0)
	scale = Vector2(0.2, 0.2)
	var tw: Tween = create_tween()
	_active_tween = tw
	tw.tween_property(self, "modulate", _base_modulate, 0.25)
	tw.parallel().tween_property(self, "scale", Vector2(1.3, 1.3), 0.18)
	tw.chain().tween_property(self, "scale", _base_scale, 0.1)
