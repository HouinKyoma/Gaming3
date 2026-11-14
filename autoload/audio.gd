extends Node
## Autoload "Audio": sound effects, music, volume and fullscreen settings.
## Sounds are loaded by name from res://audio/sfx/<name>.wav and res://audio/music/<name>.wav,
## so replacing a sound = overwriting the file. A missing file is silently skipped.

const SFX_DIR := "res://audio/sfx/%s.wav"
const MUSIC_DIR := "res://audio/music/%s.wav"
const POOL_SIZE := 12

var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _music_name := ""
var _cache: Dictionary = {}          # path -> AudioStream (or null if missing)
var _last_played: Dictionary = {}    # name -> msec, to stop the same sound stacking


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Music")
	_ensure_bus("SFX")
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_music.finished.connect(_on_music_finished)

	Events.enemy_killed.connect(func(_d: EnemyData, _p: Vector2) -> void: play_sfx("enemy_die", 0.15))
	Events.boss_spawned.connect(_on_boss_spawned)
	Events.floor_started.connect(func(_i: int) -> void: play_sfx("stairs"))
	Events.floor_started.connect(func(_i: int) -> void: play_music("run_loop"))
	Events.player_died.connect(func(_k: String) -> void: play_sfx("death"))
	Events.room_cleared.connect(func(_c: Vector2i) -> void: play_sfx("door"))
	apply_settings()


## pitch_jitter: random pitch variation (0.1 = +/-10%) so repeated sounds don't grate.
func play_sfx(sound: String, pitch_jitter: float = 0.05, volume_db: float = 0.0) -> void:
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(sound, -1000)) < 35:
		return
	_last_played[sound] = now
	var stream := _load(SFX_DIR % sound)
	if stream == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = stream
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.volume_db = volume_db
	p.play()


func play_music(track: String) -> void:
	if track == _music_name and _music.playing:
		return
	_music_name = track
	var stream := _load(MUSIC_DIR % track)
	_music.stop()
	if stream:
		_music.stream = stream
		_music.play()


func stop_music() -> void:
	_music_name = ""
	_music.stop()


func _on_music_finished() -> void:
	if _music_name != "":
		_music.play()   # simple loop (works whatever the import loop setting is)


## Boss music per boss (FloorData.boss_id -> file in audio/music/). Unlisted bosses use boss_loop.
const BOSS_MUSIC := {
	"bone_shaman": "boss_theme",   # The Necromancer
	"warden": "boss_reaper",       # The Hollow Reaper
	"tyrant": "boss_theme",        # The Ashen Tyrant
}


func _on_boss_spawned(_boss_name: String, _max_hp: int) -> void:
	play_sfx("boss_roar", 0.0)
	var track := "boss_loop"
	if Run.floor_index >= 0 and Run.floor_index < Content.floors.size():
		var id := Content.floors[Run.floor_index].boss_id
		track = BOSS_MUSIC.get(id, "boss_loop")
	if _load(MUSIC_DIR % track) == null:
		track = "boss_loop"
	play_music(track)


func _load(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	_cache[path] = stream
	return stream


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


# --- Settings ------------------------------------------------------------------------

func apply_settings() -> void:
	var s: Dictionary = Save.data["settings"]
	_set_bus_volume("Music", float(s.get("music", 0.8)))
	_set_bus_volume("SFX", float(s.get("sfx", 1.0)))
	if not OS.has_feature("web"):
		var full := bool(s.get("fullscreen", false))
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if full else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)


func set_setting(key: String, value: Variant) -> void:
	var s: Dictionary = Save.data["settings"]
	s[key] = value
	apply_settings()


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.001)))
