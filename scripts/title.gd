extends Control

# Title screen. Any key or any pad button boots into the game.
# Built entirely in code: ASCII-ish title, blinking prompt, fake Win98 taskbar,
# floating clip-art nodes, countdown clock.

const CLIP_ART_GLYPHS := [
	"@", "#", "$", "%", "&", "*", "+", "~", "=", "?", "!", ">", "<",
]
const BOOT_TIPS := [
	"TIP: save early, save often.",
	"TIP: do not open attachments from strangers.",
	"TIP: defragment your heart.",
	"TIP: back up to ZIP disks.",
	"TIP: the cake is a lie.",
	"TIP: you have (1) new message. ICQ uh-oh!",
	"TIP: press CTRL+ALT+DEL if the world ends.",
]

var _t := 0.0
var _tip_idx := 0
var _tip_timer := 0.0
var _clip_nodes: Array = []

func _ready() -> void:
	randomize()
	_build()
	set_process(true)
	set_process_input(true)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_boot()
	elif event is InputEventJoypadButton and event.pressed:
		_boot()
	elif event is InputEventMouseButton and event.pressed:
		_boot()

func _boot() -> void:
	set_process_input(false)
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _process(delta: float) -> void:
	_t += delta
	_tip_timer += delta
	var prompt: Label = get_node("Prompt")
	prompt.visible = fmod(_t, 1.0) < 0.6
	var clock: Label = get_node("Taskbar/Clock")
	# Fake seconds crawl from 11:59:00 toward 11:59:59 on loop
	var sec := int(_t * 2.0) % 60
	clock.text = "11:59:%02d PM  12/31/1999" % sec
	for i in range(_clip_nodes.size()):
		var n: Label = _clip_nodes[i]
		var spd: float = float(n.get_meta("spd"))
		var drift: float = float(n.get_meta("drift"))
		n.position.y += spd * delta
		n.position.x += sin((_t + i) * drift) * 30.0 * delta
		if n.position.y > 760:
			n.position.y = -40
			n.position.x = randf_range(20, 1240)
	if _tip_timer > 3.5:
		_tip_timer = 0.0
		_tip_idx = (_tip_idx + 1) % BOOT_TIPS.size()
		var tip: Label = get_node("Tip")
		tip.text = BOOT_TIPS[_tip_idx]

func _build() -> void:
	# Dark purple-black background.
	var bg := ColorRect.new()
	bg.color = Color("05001a")
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Floating clip-art symbols.
	for i in range(28):
		var g := Label.new()
		g.text = CLIP_ART_GLYPHS[randi() % CLIP_ART_GLYPHS.size()]
		g.position = Vector2(randf_range(20, 1240), randf_range(-40, 720))
		g.add_theme_font_size_override("font_size", randi_range(18, 40))
		g.modulate = Color.from_hsv(randf(), 0.7, 1.0, 0.55)
		g.set_meta("spd", randf_range(18, 55))
		g.set_meta("drift", randf_range(0.5, 2.0))
		add_child(g)
		_clip_nodes.append(g)

	# Title.
	var title := Label.new()
	title.name = "TitleText"
	title.text = "MILLENNIUM  BUG"
	title.add_theme_font_size_override("font_size", 96)
	title.add_theme_color_override("font_color", Color("00ffcc"))
	title.add_theme_color_override("font_shadow_color", Color("ff00aa"))
	title.add_theme_constant_override("shadow_offset_x", 6)
	title.add_theme_constant_override("shadow_offset_y", 6)
	title.position = Vector2(0, 140)
	title.size = Vector2(1280, 120)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	# Subtitle.
	var sub := Label.new()
	sub.text = ">> Y2K // A REAL EMERGENCY <<"
	sub.add_theme_font_size_override("font_size", 28)
	sub.add_theme_color_override("font_color", Color("ffee00"))
	sub.position = Vector2(0, 250)
	sub.size = Vector2(1280, 40)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)

	# Marquee-style credits line.
	var credits := Label.new()
	credits.text = "4-PLAYER LOCAL  *  XBOX PADS OR WASD  *  BEST WITH SURGE PROTECTOR"
	credits.add_theme_font_size_override("font_size", 18)
	credits.add_theme_color_override("font_color", Color("66ff33"))
	credits.position = Vector2(0, 300)
	credits.size = Vector2(1280, 28)
	credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(credits)

	# Blinking prompt.
	var prompt := Label.new()
	prompt.name = "Prompt"
	prompt.text = "- PRESS ANY KEY TO BOOT -"
	prompt.add_theme_font_size_override("font_size", 36)
	prompt.add_theme_color_override("font_color", Color("ff00aa"))
	prompt.position = Vector2(0, 420)
	prompt.size = Vector2(1280, 50)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(prompt)

	# Rotating tip line.
	var tip := Label.new()
	tip.name = "Tip"
	tip.text = BOOT_TIPS[0]
	tip.add_theme_font_size_override("font_size", 18)
	tip.add_theme_color_override("font_color", Color("ffffff", 0.7))
	tip.position = Vector2(0, 500)
	tip.size = Vector2(1280, 28)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(tip)

	# Controls cheat-sheet.
	var ctl := Label.new()
	ctl.text = "XBOX: LSTICK move * RSTICK aim * A/RT throw floppy\n" + \
			   "KEYBOARD (P1): WASD move * MOUSE aim * SPACE throw"
	ctl.add_theme_font_size_override("font_size", 16)
	ctl.add_theme_color_override("font_color", Color("66ccff"))
	ctl.position = Vector2(0, 560)
	ctl.size = Vector2(1280, 60)
	ctl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(ctl)

	# Fake Win98 taskbar.
	var taskbar := ColorRect.new()
	taskbar.name = "Taskbar"
	taskbar.color = Color("c0c0c0")
	taskbar.position = Vector2(0, 692)
	taskbar.size = Vector2(1280, 28)
	add_child(taskbar)

	var start := Label.new()
	start.text = "  Start  "
	start.position = Vector2(6, 4)
	start.add_theme_font_size_override("font_size", 16)
	start.add_theme_color_override("font_color", Color.BLACK)
	var start_bg := ColorRect.new()
	start_bg.color = Color("b0b0b0")
	start_bg.position = Vector2(4, 2)
	start_bg.size = Vector2(70, 24)
	taskbar.add_child(start_bg)
	taskbar.add_child(start)

	var clock := Label.new()
	clock.name = "Clock"
	clock.text = "11:59:00 PM  12/31/1999"
	clock.position = Vector2(1030, 5)
	clock.add_theme_font_size_override("font_size", 16)
	clock.add_theme_color_override("font_color", Color.BLACK)
	taskbar.add_child(clock)
