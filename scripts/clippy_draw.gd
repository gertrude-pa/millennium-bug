extends Control

# Draws a stylized paperclip with two googly eyes.

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var col := Color("888888")
	# Three connected rounded arcs approximating a paperclip.
	var pts := PackedVector2Array([
		Vector2(30, 5), Vector2(10, 5), Vector2(10, 90), Vector2(30, 90),
		Vector2(30, 18), Vector2(18, 18), Vector2(18, 78), Vector2(26, 78),
		Vector2(26, 32), Vector2(22, 32),
	])
	for i in range(pts.size() - 1):
		draw_line(pts[i], pts[i + 1], col, 3.0)
	# Googly eyes.
	draw_circle(Vector2(16, 30), 4.5, Color.WHITE)
	draw_circle(Vector2(28, 30), 4.5, Color.WHITE)
	draw_circle(Vector2(17, 31), 2.0, Color.BLACK)
	draw_circle(Vector2(29, 31), 2.0, Color.BLACK)
