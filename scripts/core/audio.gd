extends Node
## Music crossfading per region and a small pooled SFX player.

const NA := "res://assets/packs/ninja_adventure/audio/"

var music_volume := 0.7
var sfx_volume := 0.85
var muted := false
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _current_track := ""
var _pool: Array[AudioStreamPlayer] = []
var _pool_index := 0
var _streams: Dictionary = {}
var _ambient: AudioStreamPlayer
var _ambient_name := ""
var listener_pos := Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	_ambient = AudioStreamPlayer.new()
	for p in [_music_a, _music_b, _ambient]:
		p.volume_db = -80.0
		add_child(p)
	for i in range(10):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)


func _stream(path: String) -> AudioStream:
	if _streams.has(path):
		return _streams[path]
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path)
	_streams[path] = s
	return s


func play_music(track: String, fade := 1.6) -> void:
	if track == _current_track:
		return
	_current_track = track
	var stream := _stream(NA + "music/%s.ogg" % track)
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	var old := _music_a
	_music_a = _music_b
	_music_b = old
	_music_a.stream = stream
	_music_a.volume_db = -60.0
	_music_a.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_music_a, "volume_db", _db(music_volume) - 4.0, fade)
	tw.tween_property(_music_b, "volume_db", -80.0, fade)
	tw.chain().tween_callback(_music_b.stop)


func play_ambient(name: String) -> void:
	if name == _ambient_name:
		return
	_ambient_name = name
	if name == "":
		create_tween().tween_property(_ambient, "volume_db", -80.0, 1.5)
		return
	var s := _stream(NA + "sfx/%s.wav" % name)
	if s == null:
		return
	if s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = int(w.get_length() * w.mix_rate) - 1
	_ambient.stream = s
	_ambient.volume_db = -50.0
	_ambient.play()
	create_tween().tween_property(_ambient, "volume_db", _db(sfx_volume) - 16.0, 2.0)


func play(name: String, pitch_jitter := 0.08, volume := 0.0, at := Vector2.INF) -> void:
	if muted:
		return
	var path := NA + "sfx/%s.wav" % name
	if not ResourceLoader.exists(path):
		path = NA + "jingles/%s.wav" % name
	var s := _stream(path)
	if s == null:
		return
	var attenuation := 0.0
	if at != Vector2.INF:
		var d := at.distance_to(listener_pos)
		if d > 420.0:
			return
		attenuation = -d / 420.0 * 18.0
	var p := _pool[_pool_index]
	_pool_index = (_pool_index + 1) % _pool.size()
	p.stream = s
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.volume_db = _db(sfx_volume) + volume + attenuation
	p.play()


func apply_volumes() -> void:
	if _music_a.playing:
		_music_a.volume_db = _db(music_volume) - 4.0
	if _ambient.playing and _ambient_name != "":
		_ambient.volume_db = _db(sfx_volume) - 16.0


func stop_all() -> void:
	for p in [_music_a, _music_b, _ambient]:
		if is_instance_valid(p):
			p.stop()
			p.stream = null
	for p in _pool:
		if is_instance_valid(p):
			p.stop()
			p.stream = null
	_streams.clear()
	_current_track = ""
	_ambient_name = ""


func _db(v: float) -> float:
	if muted or v <= 0.001:
		return -80.0
	return linear_to_db(v)
