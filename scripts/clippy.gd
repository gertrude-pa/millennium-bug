extends Control

# Clippy popup — purely cosmetic speech bubble that slides in from the side.
# "It looks like you're trying to survive Y2K..."

const QUIPS := [
	"It looks like you're\ntrying to survive Y2K.\nWould you like help?",
	"It looks like you're\nwriting a will.\nWant a template?",
	"I noticed you have\n(0) floppies left.\nConsider panicking.",
	"Hey! Your computer\nis 12 seconds from\nexploding. Neat!",
	"It looks like you're\nrunning from a\nBLUE SCREEN. Cute!",
	"Did you remember to\nrename all your files\nfrom '99 to '00?",
	"Y2K COMPLIANT: NO\nCONTINUE ANYWAY?",
]

var _life := 5.0
var _t := 0.0
var _from_left := true

func _ready() -> void:
	_from_left = randi() % 2 == 0
	anchor_right = 0.0
	anchor_bottom = 0.0
	size = Vector2(220, 140)
	position = Vector2(-240 if _from_left else 1280, randf_range(80, 500))
	set_process(true)

	# Yellow bubble background.
	var bg := ColorRect.new()
	bg.color = Color("fff9a8")
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var border := ColorRect.new()
	border.color = Color("000000")
	border.size = Vector2(220, 2)
	add_child(border)
	var border2 := ColorRect.new()
	border2.color = Color("000000")
	border2.size = Vector2(220, 2)
	border2.position = Vector2(0, 138)
	add_child(border2)

	# Clippy (crude paperclip of three arcs, fake with curves).
	var clip := Control.new()
	clip.size = Vector2(50, 110)
	clip.position = Vector2(4, 16)
	clip.set_script(preload("res://scripts/clippy_draw.gd"))
	add_child(clip)

	# Message.
	var msg := Label.new()
	msg.text = QUIPS[randi() % QUIPS.size()]
	msg.position = Vector2(60, 8)
	msg.size = Vector2(155, 100)
	msg.add_theme_font_size_override("font_size", 14)
	msg.add_theme_color_override("font_color", Color.BLACK)
	add_child(msg)

	# OK button (just label).
	var ok := Label.new()
	ok.text = "[ OK ]"
	ok.position = Vector2(160, 112)
	ok.add_theme_font_size_override("font_size", 12)
	ok.add_theme_color_override("font_color", Color.BLACK)
	add_child(ok)

func _process(delta: float) -> void:
	_t += delta
	# Slide in fast, hold, slide out.
	var target_x := 20.0 if _from_left else 1040.0
	var offscreen_x := -240.0 if _from_left else 1280.0
	if _t < 0.4:
		position.x = lerp(offscreen_x, target_x, _t / 0.4)
	elif _t < _life - 0.4:
		position.x = target_x
	elif _t < _life:
		position.x = lerp(target_x, offscreen_x, (_t - (_life - 0.4)) / 0.4)
	else:
		queue_free()
