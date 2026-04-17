extends Node2D

# Millennium Bug — main game. Round/match flow, spawners for pickups, BSOD,
# Clippy popups, death dialogs, news marquee.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const PICKUP_SCENE := preload("res://scenes/pickup.tscn")
const BSOD_SCENE := preload("res://scenes/bsod.tscn")
const CLIPPY_SCRIPT := preload("res://scripts/clippy.gd")

const ARENA_SIZE := Vector2(1280, 720)
const ARENA_PADDING := 80.0
const PLAYER_COLORS := [
	Color("00ffff"), # cyan
	Color("ff00aa"), # magenta
	Color("ffee00"), # yellow
	Color("66ff33"), # lime
]
const LIVES_PER_ROUND := 3
const ROUNDS_TO_WIN := 3

const MARQUEE_PHRASES := [
	"PREPARE FOR IMPACT",
	"BANKS TO FAIL AT MIDNIGHT",
	"STOCK UP ON CANNED GOODS",
	"BUY GOLD  BUY BEANIE BABIES",
	"MICROSOFT URGES CALM",
	"NAPSTER GOES LIVE",
	"PETS.COM IPO SOARS",
	"ALL YOUR BASE ARE BELONG TO US",
	"AOL OFFERS 1000 FREE HOURS",
	"ICQ: UH OH!",
	"YOU HAVE (1) NEW MESSAGE",
	"REMEMBER TO DEFRAG",
	"CLIPPY WANTS TO HELP",
	"TAMAGOTCHI NEEDS FEEDING",
	"WINAMP: IT REALLY WHIPS THE LLAMA'S",
	"FURBY SUPPLY CHAIN NORMAL",
	"DIAL-UP STILL GOING STRONG",
]

var _players: Array = []
var _round_scores: Dictionary = {}
var _round_active := false
var _round_time := 0.0
var _pickup_timer := 0.0
var _bsod_timer := 0.0
var _clippy_timer := 0.0
var _marquee_x := 1280.0
var _marquee_text := ""
var _shake_t := 0.0
var _shake_amp := 0.0
var _shake_dur := 0.0
var _player_panels: Array = []
var _camera: Camera2D
var _match_gen := 0
var _in_hitstop := false
var _bsod_warning_active := false

@onready var _players_root: Node2D = $Players
@onready var _projectiles_root: Node2D = $Projectiles
@onready var _pickups_root: Node2D = Node2D.new()
@onready var _hazards_root: Node2D = Node2D.new()
@onready var _obstacles_root: Node2D = Node2D.new()
@onready var _popups_root: CanvasLayer = CanvasLayer.new()
@onready var _hud: CanvasLayer = $HUD

func _ready() -> void:
	randomize()
	add_child(_pickups_root)
	add_child(_hazards_root)
	add_child(_obstacles_root)
	_popups_root.layer = 5
	add_child(_popups_root)
	_camera = Camera2D.new()
	_camera.enabled = true
	_camera.position = Vector2(ARENA_SIZE.x * 0.5, ARENA_SIZE.y * 0.5)
	add_child(_camera)
	_draw_arena()
	_build_hud()
	_roll_marquee()
	_start_round()

func _process(delta: float) -> void:
	_tick_marquee(delta)
	_tick_shake(delta)
	if not _round_active:
		return
	_round_time += delta
	_pickup_timer -= delta
	_bsod_timer -= delta
	_clippy_timer -= delta
	if _pickup_timer <= 0.0:
		_pickup_timer = randf_range(6.0, 10.0)
		_spawn_pickup()
	if _bsod_timer <= 0.0:
		_bsod_timer = randf_range(18.0, 28.0)
		_spawn_bsod()
	if _clippy_timer <= 0.0:
		_clippy_timer = randf_range(10.0, 16.0)
		_spawn_clippy()

	var alive := _players.filter(func(p): return p.lives > 0)
	if alive.size() <= 1 and _players.size() > 1:
		_end_round(alive[0] if alive.size() == 1 else null)

func spawn_projectile(node: Node2D) -> void:
	_projectiles_root.add_child(node)

func arena_rect() -> Rect2:
	return Rect2(ARENA_PADDING, ARENA_PADDING,
		ARENA_SIZE.x - ARENA_PADDING * 2,
		ARENA_SIZE.y - ARENA_PADDING * 2)

# ---------- Arena ----------

func _draw_arena() -> void:
	var bg := ColorRect.new()
	bg.color = Color("080018")
	bg.size = ARENA_SIZE
	$Arena.add_child(bg)

	var step := 40
	for x in range(0, int(ARENA_SIZE.x), step):
		var l := Line2D.new()
		l.add_point(Vector2(x, 0))
		l.add_point(Vector2(x, ARENA_SIZE.y))
		l.width = 1
		l.default_color = Color(0.15, 0.1, 0.35, 0.6)
		$Arena.add_child(l)
	for y in range(0, int(ARENA_SIZE.y), step):
		var l := Line2D.new()
		l.add_point(Vector2(0, y))
		l.add_point(Vector2(ARENA_SIZE.x, y))
		l.width = 1
		l.default_color = Color(0.15, 0.1, 0.35, 0.6)
		$Arena.add_child(l)

	var border := Line2D.new()
	border.closed = true
	var r := arena_rect()
	border.add_point(r.position)
	border.add_point(r.position + Vector2(r.size.x, 0))
	border.add_point(r.position + r.size)
	border.add_point(r.position + Vector2(0, r.size.y))
	border.width = 3
	border.default_color = Color("00ffcc")
	$Arena.add_child(border)

# ---------- HUD ----------

func _build_hud() -> void:
	# Top marquee band.
	var band := ColorRect.new()
	band.name = "MarqueeBand"
	band.color = Color("c0c0c0")
	band.position = Vector2(0, 0)
	band.size = Vector2(1280, 24)
	_hud.add_child(band)

	var marq := Label.new()
	marq.name = "Marquee"
	marq.position = Vector2(1280, 2)
	marq.add_theme_font_size_override("font_size", 16)
	marq.add_theme_color_override("font_color", Color.BLACK)
	_hud.add_child(marq)

	# Clock at far right of marquee band.
	var clock := Label.new()
	clock.name = "Clock"
	clock.position = Vector2(1130, 2)
	clock.add_theme_font_size_override("font_size", 16)
	clock.add_theme_color_override("font_color", Color.BLACK)
	_hud.add_child(clock)

	# Container for per-player panels, populated per round.
	var panels_root := Control.new()
	panels_root.name = "Panels"
	panels_root.position = Vector2(0, 28)
	panels_root.size = Vector2(1280, 62)
	panels_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(panels_root)

	# Persistent control hint at the bottom.
	var hint_bg := ColorRect.new()
	hint_bg.color = Color(0, 0, 0, 0.55)
	hint_bg.position = Vector2(0, 694)
	hint_bg.size = Vector2(1280, 26)
	_hud.add_child(hint_bg)
	var hint := Label.new()
	hint.name = "Hint"
	hint.text = "[ESC] main menu    [R] restart match    ( pad: BACK = menu, START = restart )"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color("ccff66", 0.9))
	hint.position = Vector2(0, 697)
	hint.size = Vector2(1280, 22)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(hint)

	# Banner (round intro / winner).
	var banner := Label.new()
	banner.name = "Banner"
	banner.anchor_left = 0.0
	banner.anchor_right = 1.0
	banner.anchor_top = 0.35
	banner.anchor_bottom = 0.55
	banner.add_theme_font_size_override("font_size", 44)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.visible = false
	_hud.add_child(banner)

func _update_hud() -> void:
	var clock: Label = _hud.get_node("Clock")
	clock.text = "11:59:%02d PM" % (int(_round_time * 2.0) % 60)
	# Wins label per panel.
	for i in range(_player_panels.size()):
		var panel: Dictionary = _player_panels[i]
		var p = _players[i]
		var wins: int = _round_scores.get(p.device_id, 0)
		panel["wins_label"].text = "WINS %d" % wins

func _build_player_panels() -> void:
	var panels_root: Control = _hud.get_node("Panels")
	for c in panels_root.get_children():
		c.queue_free()
	_player_panels.clear()

	var n := _players.size()
	if n == 0:
		return
	var margin := 20.0
	var gap := 12.0
	var panel_w := (1280.0 - margin * 2.0 - gap * (n - 1)) / n
	var panel_h := 56.0
	for i in range(n):
		var p = _players[i]
		var px := margin + i * (panel_w + gap)

		var panel := Control.new()
		panel.position = Vector2(px, 0)
		panel.size = Vector2(panel_w, panel_h)
		panels_root.add_child(panel)

		var bg := ColorRect.new()
		bg.color = Color(p.color.r, p.color.g, p.color.b, 0.12)
		bg.size = Vector2(panel_w, panel_h)
		panel.add_child(bg)

		# Color strip on the left.
		var strip := ColorRect.new()
		strip.color = p.color
		strip.size = Vector2(4, panel_h)
		panel.add_child(strip)

		var name_label := Label.new()
		name_label.text = "P%d" % (i + 1)
		name_label.add_theme_font_size_override("font_size", 20)
		name_label.add_theme_color_override("font_color", p.color)
		name_label.position = Vector2(12, 2)
		panel.add_child(name_label)

		var wins_label := Label.new()
		wins_label.text = "WINS 0"
		wins_label.add_theme_font_size_override("font_size", 14)
		wins_label.add_theme_color_override("font_color", Color.WHITE)
		wins_label.position = Vector2(panel_w - 64, 4)
		panel.add_child(wins_label)

		# Life icons.
		var life_icons: Array = []
		var icon_start_x := 44.0
		var icon_gap := 30.0
		for j in range(LIVES_PER_ROUND):
			var icon := Control.new()
			icon.size = Vector2(24, 24)
			icon.position = Vector2(icon_start_x + j * icon_gap, 26)
			icon.set_script(preload("res://scripts/life_icon.gd"))
			panel.add_child(icon)
			icon.set_color(p.color)
			life_icons.append(icon)

		# Offline overlay, hidden until KO.
		var offline := ColorRect.new()
		offline.color = Color(0, 0, 0, 0.55)
		offline.size = Vector2(panel_w, panel_h)
		offline.visible = false
		panel.add_child(offline)

		var offline_label := Label.new()
		offline_label.text = ">> OFFLINE <<"
		offline_label.add_theme_font_size_override("font_size", 22)
		offline_label.add_theme_color_override("font_color", Color("ff3344"))
		offline_label.size = Vector2(panel_w, panel_h)
		offline_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		offline_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		offline_label.visible = false
		panel.add_child(offline_label)

		_player_panels.append({
			"root": panel,
			"life_icons": life_icons,
			"wins_label": wins_label,
			"offline": offline,
			"offline_label": offline_label,
		})

func _flash_life_icon(player_idx: int, icon_idx: int) -> void:
	if player_idx >= _player_panels.size():
		return
	var icons: Array = _player_panels[player_idx]["life_icons"]
	if icon_idx < 0 or icon_idx >= icons.size():
		return
	var icon = icons[icon_idx]
	if not is_instance_valid(icon):
		return
	icon.break_it()

func _mark_panel_offline(player_idx: int) -> void:
	if player_idx >= _player_panels.size():
		return
	var panel: Dictionary = _player_panels[player_idx]
	var offline_rect: ColorRect = panel["offline"]
	var offline_label: Label = panel["offline_label"]
	offline_rect.visible = true
	offline_label.visible = true
	offline_label.modulate.a = 0.0
	var tw: Tween = offline_label.create_tween()
	tw.set_loops(3)
	tw.tween_property(offline_label, "modulate:a", 1.0, 0.18)
	tw.tween_property(offline_label, "modulate:a", 0.25, 0.18)
	var final_tw: Tween = offline_label.create_tween()
	final_tw.tween_interval(1.1)
	final_tw.tween_property(offline_label, "modulate:a", 1.0, 0.2)

func shake(amp: float, dur: float) -> void:
	if amp > _shake_amp * max(_shake_t, 0.001) / max(_shake_dur, 0.001):
		_shake_amp = amp
		_shake_dur = dur
		_shake_t = dur

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_to_title()
		elif event.keycode == KEY_R:
			_restart_match()
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_BACK:
			_to_title()
		elif event.button_index == JOY_BUTTON_START:
			_restart_match()

func _to_title() -> void:
	Engine.time_scale = 1.0
	_in_hitstop = false
	get_tree().change_scene_to_file("res://scenes/title.tscn")

func _restart_match() -> void:
	Engine.time_scale = 1.0
	_in_hitstop = false
	_match_gen += 1
	_round_scores.clear()
	_start_round()

func _tick_shake(delta: float) -> void:
	if _camera == null:
		return
	if _shake_t > 0.0:
		_shake_t -= delta
		var k: float = clamp(_shake_t / _shake_dur, 0.0, 1.0)
		_camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_amp * k
	else:
		_camera.offset = Vector2.ZERO

# ---------- Marquee ----------

func _roll_marquee() -> void:
	# Concatenate a few phrases with separators.
	var shuffled := MARQUEE_PHRASES.duplicate()
	shuffled.shuffle()
	_marquee_text = "  *  ".join(shuffled.slice(0, 6)) + "  *  "

func _tick_marquee(delta: float) -> void:
	var marq: Label = _hud.get_node("Marquee")
	_marquee_x -= 80.0 * delta
	marq.position.x = _marquee_x
	marq.text = _marquee_text
	if marq.get_minimum_size().x + _marquee_x < 0:
		_marquee_x = 1280.0
		_roll_marquee()

# ---------- Round flow ----------

func _start_round() -> void:
	for p in _players:
		if is_instance_valid(p):
			p.queue_free()
	_players.clear()
	for c in _projectiles_root.get_children():
		c.queue_free()
	for c in _pickups_root.get_children():
		c.queue_free()
	for c in _hazards_root.get_children():
		c.queue_free()
	for c in _obstacles_root.get_children():
		c.queue_free()
	_spawn_obstacles()

	var connected := Input.get_connected_joypads()
	if connected.is_empty():
		connected = [-1]
	for i in range(min(connected.size(), 4)):
		var device_id: int = connected[i]
		var p := PLAYER_SCENE.instantiate()
		p.device_id = device_id
		p.player_index = i
		p.color = PLAYER_COLORS[i]
		p.lives = LIVES_PER_ROUND
		p.position = _spawn_position(i)
		p.game = self
		_players_root.add_child(p)
		_players.append(p)
		if not _round_scores.has(device_id):
			_round_scores[device_id] = 0

	_round_time = 0.0
	_pickup_timer = 3.0
	_bsod_timer = 20.0
	_clippy_timer = 5.0
	_build_player_panels()
	_update_hud()
	_show_round_intro()

func _show_round_intro() -> void:
	var my_gen := _match_gen
	_round_active = false
	var banner: Label = _hud.get_node("Banner")
	banner.visible = true
	banner.modulate = Color.WHITE
	banner.text = "CONNECTING...\n28800 bps"
	await get_tree().create_timer(0.9).timeout
	if my_gen != _match_gen: return
	banner.text = "HANDSHAKE..."
	await get_tree().create_timer(0.7).timeout
	if my_gen != _match_gen: return
	banner.text = "CONNECTED\n\nFIGHT!"
	banner.modulate = Color("66ff33")
	Sfx.play_round_start()
	await get_tree().create_timer(0.9).timeout
	if my_gen != _match_gen: return
	banner.visible = false
	_round_active = true
	_update_hud()

func _spawn_position(i: int) -> Vector2:
	var r := arena_rect()
	match i:
		0: return r.position + Vector2(60, 60)
		1: return r.position + r.size - Vector2(60, 60)
		2: return r.position + Vector2(r.size.x - 60, 60)
		3: return r.position + Vector2(60, r.size.y - 60)
	return r.position + r.size * 0.5

func _end_round(winner) -> void:
	var my_gen := _match_gen
	_round_active = false
	if winner != null:
		_round_scores[winner.device_id] = _round_scores.get(winner.device_id, 0) + 1
	_update_hud()
	var banner: Label = _hud.get_node("Banner")
	banner.visible = true
	var wait := 2.0
	if winner != null:
		banner.text = "ROUND: P%d" % (winner.player_index + 1)
		banner.modulate = winner.color
		Sfx.play_round_end()
	else:
		banner.text = "!!! SYSTEM HALTED !!!\nNO SURVIVORS\n\n( round: mutual destruction )"
		banner.modulate = Color("ff3344")
		_screen_flash(Color("ff2222"), 0.9)
		wait = 3.2
	await get_tree().create_timer(wait).timeout
	if my_gen != _match_gen: return
	banner.visible = false

	var match_winner = null
	for p in _players:
		if _round_scores.get(p.device_id, 0) >= ROUNDS_TO_WIN:
			match_winner = p
			break
	if match_winner != null:
		_show_match_winner(match_winner)
		await get_tree().create_timer(4.0).timeout
		if my_gen != _match_gen: return
		_round_scores.clear()
	_start_round()

func _show_match_winner(p) -> void:
	var banner: Label = _hud.get_node("Banner")
	banner.text = "P%d WINS\nY2K SURVIVED" % (p.player_index + 1)
	banner.modulate = p.color
	banner.visible = true
	Sfx.play_match_win()
	await get_tree().create_timer(3.5).timeout
	banner.visible = false

# ---------- Spawners ----------

func _spawn_pickup() -> void:
	if _pickups_root.get_child_count() >= 3:
		return
	var p = PICKUP_SCENE.instantiate()
	# Weighted: CD 30%, MODEM 30%, FLOPPY_STACK 30%, HEART 10%.
	var roll := randf()
	if roll < 0.30:
		p.kind = 0
	elif roll < 0.60:
		p.kind = 1
	elif roll < 0.90:
		p.kind = 2
	else:
		p.kind = 3
	var r := arena_rect()
	p.position = Vector2(
		randf_range(r.position.x + 60, r.position.x + r.size.x - 60),
		randf_range(r.position.y + 60, r.position.y + r.size.y - 60))
	_pickups_root.add_child(p)

func _spawn_bsod() -> void:
	_warn_then_spawn_bsod()

func _warn_then_spawn_bsod() -> void:
	if _bsod_warning_active:
		return
	_bsod_warning_active = true
	var my_gen := _match_gen
	var warn := _make_bsod_warning()
	_popups_root.add_child(warn)
	for i in range(3):
		Sfx.play_bsod_warn()
		await get_tree().create_timer(0.35).timeout
		if my_gen != _match_gen:
			_bsod_warning_active = false
			if is_instance_valid(warn):
				warn.queue_free()
			return
	if is_instance_valid(warn):
		warn.queue_free()
	_bsod_warning_active = false
	var b = BSOD_SCENE.instantiate()
	_hazards_root.add_child(b)
	b.configure(arena_rect(), -1 if randi() % 2 == 0 else 1)
	Sfx.play_bsod_spawn()
	shake(6.0, 0.25)

func _make_bsod_warning() -> Control:
	var warn := Control.new()
	warn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warn.size = Vector2(ARENA_SIZE.x, ARENA_SIZE.y)
	var thickness := 22.0
	var red := Color("ff2233")
	for spec in [
		[0.0, 0.0, ARENA_SIZE.x, thickness],
		[0.0, ARENA_SIZE.y - thickness, ARENA_SIZE.x, thickness],
		[0.0, 0.0, thickness, ARENA_SIZE.y],
		[ARENA_SIZE.x - thickness, 0.0, thickness, ARENA_SIZE.y],
	]:
		var edge := ColorRect.new()
		edge.color = red
		edge.position = Vector2(spec[0], spec[1])
		edge.size = Vector2(spec[2], spec[3])
		warn.add_child(edge)
	var label := Label.new()
	label.text = "! ! !   BLUE SCREEN INCOMING   ! ! !"
	label.add_theme_font_size_override("font_size", 38)
	label.add_theme_color_override("font_color", Color("ffeeaa"))
	label.add_theme_color_override("font_shadow_color", Color("ff2233"))
	label.add_theme_constant_override("shadow_offset_x", 3)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.position = Vector2(0, 130)
	label.size = Vector2(ARENA_SIZE.x, 60)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn.add_child(label)
	warn.modulate.a = 0.0
	var tw: Tween = warn.create_tween()
	tw.set_loops(3)
	tw.tween_property(warn, "modulate:a", 1.0, 0.17)
	tw.tween_property(warn, "modulate:a", 0.1, 0.18)
	return warn

# ---------- Obstacles ----------

func _spawn_obstacles() -> void:
	var layouts := [
		# Four corners-ish rectangles.
		[[0.25, 0.35, 70.0, 60.0], [0.75, 0.35, 70.0, 60.0],
		 [0.25, 0.65, 70.0, 60.0], [0.75, 0.65, 70.0, 60.0]],
		# Cross: central bar + two pillars.
		[[0.5, 0.5, 160.0, 34.0], [0.5, 0.22, 34.0, 80.0], [0.5, 0.78, 34.0, 80.0]],
		# Two vertical walls splitting the arena into three lanes.
		[[0.33, 0.5, 34.0, 220.0], [0.67, 0.5, 34.0, 220.0]],
		# H-shape.
		[[0.3, 0.5, 34.0, 220.0], [0.7, 0.5, 34.0, 220.0], [0.5, 0.5, 120.0, 30.0]],
	]
	var layout: Array = layouts[randi() % layouts.size()]
	var r := arena_rect()
	for spec in layout:
		var obs := _make_obstacle(spec[2], spec[3])
		obs.position = Vector2(
			r.position.x + r.size.x * spec[0],
			r.position.y + r.size.y * spec[1])
		_obstacles_root.add_child(obs)

func _make_obstacle(w: float, h: float) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(w, h)
	shape.shape = rect_shape
	body.add_child(shape)
	# Beige PC tower body.
	var fill := ColorRect.new()
	fill.color = Color("c8c0a8")
	fill.size = Vector2(w, h)
	fill.position = Vector2(-w * 0.5, -h * 0.5)
	body.add_child(fill)
	# Dark border.
	var border_col := Color("3a2f22")
	var b_top := ColorRect.new()
	b_top.color = border_col
	b_top.size = Vector2(w, 2)
	b_top.position = Vector2(-w * 0.5, -h * 0.5)
	body.add_child(b_top)
	var b_bot := ColorRect.new()
	b_bot.color = border_col
	b_bot.size = Vector2(w, 2)
	b_bot.position = Vector2(-w * 0.5, h * 0.5 - 2)
	body.add_child(b_bot)
	var b_left := ColorRect.new()
	b_left.color = border_col
	b_left.size = Vector2(2, h)
	b_left.position = Vector2(-w * 0.5, -h * 0.5)
	body.add_child(b_left)
	var b_right := ColorRect.new()
	b_right.color = border_col
	b_right.size = Vector2(2, h)
	b_right.position = Vector2(w * 0.5 - 2, -h * 0.5)
	body.add_child(b_right)
	# Floppy slot.
	var slot_w: float = min(w * 0.6, 44.0)
	var slot := ColorRect.new()
	slot.color = Color("111111")
	slot.size = Vector2(slot_w, 3)
	slot.position = Vector2(-slot_w * 0.5, -h * 0.5 + 8)
	body.add_child(slot)
	# Green power LED.
	var led := ColorRect.new()
	led.color = Color("33ff33")
	led.size = Vector2(3, 3)
	led.position = Vector2(w * 0.5 - 10, -h * 0.5 + 8)
	body.add_child(led)
	# Cyan logo strip.
	var logo_w: float = min(w * 0.5, 40.0)
	var logo := ColorRect.new()
	logo.color = Color("00ccff")
	logo.size = Vector2(logo_w, 2)
	logo.position = Vector2(-logo_w * 0.5, 0)
	body.add_child(logo)
	# CD-ROM tray line.
	if h > 80:
		var tray := ColorRect.new()
		tray.color = Color("222222")
		tray.size = Vector2(w * 0.7, 2)
		tray.position = Vector2(-w * 0.35, h * 0.5 - 14)
		body.add_child(tray)
	return body

# ---------- Hitstop ----------

func hitstop(duration: float) -> void:
	if _in_hitstop:
		return
	_in_hitstop = true
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_in_hitstop = false

func _screen_flash(color: Color, duration: float) -> void:
	var flash := ColorRect.new()
	flash.color = color
	flash.anchor_right = 1.0
	flash.anchor_bottom = 1.0
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popups_root.add_child(flash)
	var tw := flash.create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, duration).from(0.9)
	tw.tween_callback(flash.queue_free)

func _spawn_clippy() -> void:
	var c := Control.new()
	c.set_script(CLIPPY_SCRIPT)
	_popups_root.add_child(c)

# ---------- Callbacks from player ----------

func on_player_damaged(p, idx_lost: int = -1) -> void:
	_update_hud()
	if idx_lost >= 0:
		_flash_life_icon(p.player_index, idx_lost)

func on_player_died(p) -> void:
	_update_hud()
	_mark_panel_offline(p.player_index)
	_spawn_death_popup(p)

func on_pickup_collected(_p, _kind: int) -> void:
	pass

func on_life_restored(p, icon_idx: int) -> void:
	_update_hud()
	if p.player_index < _player_panels.size():
		var icons: Array = _player_panels[p.player_index]["life_icons"]
		if icon_idx >= 0 and icon_idx < icons.size():
			var icon = icons[icon_idx]
			if is_instance_valid(icon):
				icon.restore()

func _spawn_death_popup(p) -> void:
	var win := Control.new()
	win.size = Vector2(360, 140)
	win.position = Vector2(randf_range(140, 780), randf_range(200, 440))
	_popups_root.add_child(win)

	var bg := ColorRect.new()
	bg.color = Color("c0c0c0")
	bg.size = Vector2(360, 140)
	win.add_child(bg)

	# Title bar.
	var title := ColorRect.new()
	title.color = Color("0a2487")
	title.size = Vector2(360, 20)
	win.add_child(title)
	var title_label := Label.new()
	title_label.text = "  PLAYER%d.EXE - Illegal Operation" % (p.player_index + 1)
	title_label.add_theme_font_size_override("font_size", 13)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.position = Vector2(2, 2)
	win.add_child(title_label)

	# Close X.
	var x := Label.new()
	x.text = "  X  "
	x.position = Vector2(332, 2)
	x.add_theme_font_size_override("font_size", 13)
	x.add_theme_color_override("font_color", Color.WHITE)
	win.add_child(x)

	# Body.
	var body := Label.new()
	body.text = "C:\\WINDOWS\\PLAYER%d.EXE has performed an\nillegal operation and has been shut down.\n\nIf the problem persists, contact Y2K support.\n(error 0xDEADBEEF)" % (p.player_index + 1)
	body.position = Vector2(14, 30)
	body.add_theme_font_size_override("font_size", 13)
	body.add_theme_color_override("font_color", Color.BLACK)
	win.add_child(body)

	# OK button.
	var ok_bg := ColorRect.new()
	ok_bg.color = Color("b0b0b0")
	ok_bg.position = Vector2(148, 108)
	ok_bg.size = Vector2(64, 22)
	win.add_child(ok_bg)
	var ok := Label.new()
	ok.text = "  OK  "
	ok.position = Vector2(156, 110)
	ok.add_theme_font_size_override("font_size", 13)
	ok.add_theme_color_override("font_color", Color.BLACK)
	win.add_child(ok)

	# Auto-dismiss after 2.2s.
	var tween := win.create_tween()
	tween.tween_interval(2.2)
	tween.tween_callback(win.queue_free)
