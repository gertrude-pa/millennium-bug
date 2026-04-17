extends Node

# Procedural SFX. Registered as autoload "Sfx" in project.godot.
# All sounds are generated as short AudioStreamWAV samples at boot
# and played through a small pool of AudioStreamPlayers.

const MIX_RATE := 22050
const POOL_SIZE := 10

var _players: Array[AudioStreamPlayer] = []
var _next := 0

var throw_stream: AudioStreamWAV
var hit_stream: AudioStreamWAV
var death_stream: AudioStreamWAV
var pickup_cd_stream: AudioStreamWAV
var pickup_modem_stream: AudioStreamWAV
var pickup_floppy_stream: AudioStreamWAV
var pickup_heart_stream: AudioStreamWAV
var bsod_warn_stream: AudioStreamWAV
var bsod_spawn_stream: AudioStreamWAV
var round_start_stream: AudioStreamWAV
var round_end_stream: AudioStreamWAV
var match_win_stream: AudioStreamWAV
var title_boot_stream: AudioStreamWAV

func _ready() -> void:
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	throw_stream = _make_tone(520.0, 0.06, "square", 0.22, 2.5)
	hit_stream = _make_sequence([[900.0, 0.03], [500.0, 0.05], [200.0, 0.06]], "square", 0.32)
	death_stream = _make_sequence([[440.0, 0.08], [349.0, 0.08], [277.0, 0.08], [220.0, 0.22]], "square", 0.35)
	pickup_cd_stream = _make_sequence([[523.0, 0.05], [659.0, 0.05], [784.0, 0.1]], "square", 0.28)
	pickup_modem_stream = _make_sequence([[1200.0, 0.08], [2100.0, 0.1], [1800.0, 0.08], [2600.0, 0.1]], "sine", 0.28)
	pickup_floppy_stream = _make_sequence([[800.0, 0.04], [1000.0, 0.04], [1200.0, 0.08]], "square", 0.28)
	pickup_heart_stream = _make_sequence([[659.0, 0.05], [784.0, 0.05], [988.0, 0.05], [1319.0, 0.15]], "square", 0.32)
	bsod_warn_stream = _make_tone(180.0, 0.12, "square", 0.35, 0.8)
	bsod_spawn_stream = _make_sequence([[140.0, 0.06], [120.0, 0.08], [90.0, 0.1], [60.0, 0.2]], "saw", 0.4)
	round_start_stream = _make_sequence([[523.0, 0.07], [659.0, 0.07], [784.0, 0.07], [1046.0, 0.16]], "square", 0.3)
	round_end_stream = _make_sequence([[784.0, 0.08], [523.0, 0.08], [659.0, 0.08]], "square", 0.28)
	match_win_stream = _make_sequence([
		[523.0, 0.1], [659.0, 0.1], [784.0, 0.1], [1046.0, 0.1],
		[784.0, 0.08], [1046.0, 0.3]
	], "square", 0.32)
	title_boot_stream = _make_sequence([[440.0, 0.05], [660.0, 0.05], [880.0, 0.1]], "square", 0.25)

func _play(stream: AudioStreamWAV, pitch: float = 1.0) -> void:
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.pitch_scale = pitch
	p.play()

func _make_tone(freq: float, dur: float, waveform: String = "square", volume: float = 0.4, decay: float = 1.0) -> AudioStreamWAV:
	return _make_sequence([[freq, dur]], waveform, volume, decay)

func _make_sequence(notes: Array, waveform: String = "square", volume: float = 0.4, decay: float = 1.0) -> AudioStreamWAV:
	# notes: array of [freq: float, dur: float] pairs. freq <= 0 = noise.
	var total_dur := 0.0
	for n in notes:
		total_dur += n[1]
	var total_samples := int(MIX_RATE * total_dur)
	var buf := PackedByteArray()
	buf.resize(total_samples * 2)
	var i_off := 0
	for n in notes:
		var freq: float = n[0]
		var dur: float = n[1]
		var n_samp := int(MIX_RATE * dur)
		for j in range(n_samp):
			var t := float(j) / MIX_RATE
			var phase := t * freq
			var val := 0.0
			if freq <= 0.0:
				val = randf_range(-1.0, 1.0)
			else:
				match waveform:
					"square":
						val = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
					"saw":
						val = fmod(phase, 1.0) * 2.0 - 1.0
					"sine":
						val = sin(phase * TAU)
					_:
						val = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
			var env: float = pow(1.0 - float(j) / max(1.0, float(n_samp)), decay)
			# Short attack to avoid clicks.
			if j < 40:
				env *= float(j) / 40.0
			var s := int(clamp(val * volume * env, -1.0, 1.0) * 32767.0)
			buf.encode_s16((i_off + j) * 2, s)
		i_off += n_samp
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.data = buf
	stream.stereo = false
	return stream

# --- Public API -------------------------------------------------------

func play_throw() -> void: _play(throw_stream, randf_range(0.92, 1.08))
func play_hit() -> void: _play(hit_stream, randf_range(0.95, 1.1))
func play_death() -> void: _play(death_stream)
func play_pickup(kind: int) -> void:
	match kind:
		0: _play(pickup_cd_stream)
		1: _play(pickup_modem_stream)
		2: _play(pickup_floppy_stream)
		3: _play(pickup_heart_stream)
func play_bsod_warn() -> void: _play(bsod_warn_stream)
func play_bsod_spawn() -> void: _play(bsod_spawn_stream)
func play_round_start() -> void: _play(round_start_stream)
func play_round_end() -> void: _play(round_end_stream)
func play_match_win() -> void: _play(match_win_stream)
func play_title_boot() -> void: _play(title_boot_stream)
