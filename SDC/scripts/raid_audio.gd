extends Node
## Original procedural prototype audio; no external sound recording or network.
const RATE: int = 22050
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _cursor: int = 0

func _ready() -> void:
	for index in range(10):
		var player := AudioStreamPlayer.new()
		player.max_polyphony = 1
		player.bus = "SFX"
		player.volume_db = -12.0
		add_child(player)
		_players.append(player)
	_streams["shot"] = _synthesize(0.16, 95, 0.72, 19.0, 482)
	_streams["heavy"] = _synthesize(0.24, 62, 0.82, 13.0, 991)
	_streams["suppressed"] = _synthesize(0.11, 170, 0.24, 27.0, 829)
	_streams["reload"] = _synthesize(0.13, 680, 0.45, 35.0, 734)
	_streams["search"] = _synthesize(0.17, 440, 0.10, 19.0, 534)
	_streams["heal"] = _synthesize(0.22, 760, 0.02, 15.0, 841)
	_streams["extract"] = _synthesize(0.42, 620, 0.015, 7.0, 541)
	_streams["hit"] = _synthesize(0.09, 120, 0.22, 35.0, 326)
	_streams["death"] = _synthesize(0.44, 75, 0.06, 7.0, 237)

func _synthesize(duration: float, frequency: float, noise_mix: float, decay: float, seed_value: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var count: int = roundi(duration * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var smoothed: float = 0.0
	for index in range(count):
		var t: float = float(index) / RATE
		smoothed = smoothed * 0.42 + rng.randf_range(-1.0, 1.0) * 0.58
		var tone: float = sin(TAU * frequency * t * (1.0 - t * 0.65))
		var envelope: float = exp(-decay * t) * minf(1.0, t / 0.001)
		var sample: float = (smoothed * noise_mix + tone * (1.0 - noise_mix) * 0.52) * envelope
		data.encode_s16(index * 2, roundi(clampf(sample, -1.0, 1.0) * 24000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream

func play_shot(category: String, suppressed: bool = false, enemy: bool = false) -> void:
	var key: String = "suppressed" if suppressed else ("heavy" if category in ["sniper", "shotgun", "machine_gun"] else "shot")
	_play(key, -19.0 if enemy else (-17.0 if suppressed else -10.0), 1.12 if category in ["pistol", "smg"] else 1.0)

func play_event(kind: String) -> void:
	_play(kind, -12.0, 1.0)

func _play(key: String, volume: float, pitch: float) -> void:
	if _players.is_empty() or not _streams.has(key): return
	var player: AudioStreamPlayer = _players[_cursor]
	_cursor = (_cursor + 1) % _players.size()
	player.stream = _streams[key]
	player.volume_db = volume
	player.pitch_scale = pitch
	player.play()

func _exit_tree() -> void:
	for player: AudioStreamPlayer in _players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	_streams.clear()
	_players.clear()
