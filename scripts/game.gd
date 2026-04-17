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

@onready var _players_root: Node2D = $Players
@onready var _projectiles_root: Node2D = $Projectiles
@onready var _pickups_root: Node2D = Node2D.new()
@onready var _hazards_root: Node2D = Node2D.new()
@onready var _popups_root: CanvasLayer = CanvasLayer.new()
@onready var _hud: CanvasLayer = $HUD

func _ready() -> void:
	randomize()
	add_child(_pickups_root)
	add_child(_hazards_root)
	_popups_root.layer = 5
	add_child(_popups_root)
	_draw_arena()
	_build_hud()
	_roll_marquee()
	_start_round()

func _process(delta: float) -> void:
	_tick_marquee(delta)
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

	# Score line below marquee.
	var label := Label.new()
	label.name = "Score"
	label.position = Vector2(20, 30)
	label.add_theme_font_size_override("font_size", 18)
	_hud.add_child(label)

	# Round countdown (center top-right).
	var clock := Label.new()
	clock.name = "Clock"
	clock.position = Vector2(1080, 30)
	clock.add_theme_font_size_override("font_size", 18)
	clock.add_theme_color_override("font_color", Color("ffee00"))
	_hud.add_child(clock)

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
	var label: Label = _hud.get_node("Score")
	var parts: Array[String] = []
	for i in range(_players.size()):
		var p = _players[i]
		var s: int = _round_scores.get(p.device_id, 0)
		parts.append("P%d  lives:%d  wins:%d" % [i + 1, p.lives, s])
	label.text = "  |  ".join(parts)
	var clock: Label = _hud.get_node("Clock")
	clock.text = "11:59:%02d PM" % (int(_round_time * 2.0) % 60)

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
	_show_round_intro()

func _show_round_intro() -> void:
	_round_active = false
	var banner: Label = _hud.get_node("Banner")
	banner.visible = true
	banner.modulate = Color.WHITE
	banner.text = "CONNECTING...\n28800 bps"
	await get_tree().create_timer(0.9).timeout
	banner.text = "HANDSHAKE..."
	await get_tree().create_timer(0.7).timeout
	banner.text = "CONNECTED\n\nFIGHT!"
	banner.modulate = Color("66ff33")
	await get_tree().create_timer(0.9).timeout
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
	else:
		banner.text = "!!! SYSTEM HALTED !!!\nNO SURVIVORS\n\n( round: mutual destruction )"
		banner.modulate = Color("ff3344")
		_screen_flash(Color("ff2222"), 0.9)
		wait = 3.2
	await get_tree().create_timer(wait).timeout
	banner.visible = false

	var match_winner = null
	for p in _players:
		if _round_scores.get(p.device_id, 0) >= ROUNDS_TO_WIN:
			match_winner = p
			break
	if match_winner != null:
		_show_match_winner(match_winner)
		await get_tree().create_timer(4.0).timeout
		_round_scores.clear()
	_start_round()

func _show_match_winner(p) -> void:
	var banner: Label = _hud.get_node("Banner")
	banner.text = "P%d WINS\nY2K SURVIVED" % (p.player_index + 1)
	banner.modulate = p.color
	banner.visible = true
	await get_tree().create_timer(3.5).timeout
	banner.visible = false

# ---------- Spawners ----------

func _spawn_pickup() -> void:
	if _pickups_root.get_child_count() >= 3:
		return
	var p = PICKUP_SCENE.instantiate()
	p.kind = randi() % 3
	var r := arena_rect()
	p.position = Vector2(
		randf_range(r.position.x + 60, r.position.x + r.size.x - 60),
		randf_range(r.position.y + 60, r.position.y + r.size.y - 60))
	_pickups_root.add_child(p)

func _spawn_bsod() -> void:
	var b = BSOD_SCENE.instantiate()
	_hazards_root.add_child(b)
	b.configure(arena_rect(), -1 if randi() % 2 == 0 else 1)

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

func on_player_damaged(_p) -> void:
	_update_hud()

func on_player_died(p) -> void:
	_update_hud()
	_spawn_death_popup(p)

func on_pickup_collected(_p, _kind: int) -> void:
	pass

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
