class_name EntityVisual
extends Node2D
## The ONLY script that touches sprites. Gameplay code calls play(), face(), flash() and blink(),
## and never touches textures or frames.
##
## Animations are built at runtime from PNG strips listed in ArtSpec
## (res://art/<folder>/<art_key>_<animation>.png). Replacing art = overwriting a PNG.

const IDLE := &"idle"
const WALK := &"walk"
const ATTACK := &"attack"
const WINDUP := &"windup"
const DASH := &"dash"
const HURT := &"hurt"
const DEATH := &"death"
const SUMMON := &"summon"
const SPIN := &"spin"
const OPEN := &"open"
const CLOSED := &"closed"
const FULL := &"full"
const EMPTY := &"empty"

const FLASH_SHADER := preload("res://scenes/components/hit_flash.gdshader")

static var _frames_cache: Dictionary = {}

## Key into ArtSpec.SPRITES, e.g. "player" or "crawler".
@export var art_key: String = ""
## True for characters: the bottom of the frame sits on the node's origin (their feet).
@export var feet_origin: bool = true
@export var start_animation: StringName = &"idle"

var sprite: AnimatedSprite2D

var _material: ShaderMaterial
var _flash_left := 0.0
var _blink_left := 0.0


func _ready() -> void:
	sprite = AnimatedSprite2D.new()
	sprite.name = "Sprite"
	add_child(sprite)
	sprite.sprite_frames = EntityVisual.get_frames(art_key)
	if feet_origin:
		var frame_size := ArtSpec.frame_size(art_key)
		sprite.offset = Vector2(0.0, -frame_size.y / 2.0 + 1.0)
	_material = ShaderMaterial.new()
	_material.shader = FLASH_SHADER
	sprite.material = _material
	play(start_animation)


func _process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_material.set_shader_parameter("flash", 0.0)
	if _blink_left > 0.0:
		_blink_left -= delta
		var hidden_phase := int(_blink_left * 20.0) % 2 == 0
		modulate.a = 0.35 if hidden_phase and _blink_left > 0.0 else 1.0
	elif modulate.a < 1.0:
		modulate.a = 1.0


## Plays an animation. Missing animations fall back to "idle", so missing art never crashes.
func play(anim: StringName) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var frames := sprite.sprite_frames
	var chosen := anim
	if not frames.has_animation(chosen):
		if frames.has_animation(IDLE):
			chosen = IDLE
		else:
			var names := frames.get_animation_names()
			if names.is_empty():
				return
			chosen = StringName(names[0])
	if sprite.animation != chosen:
		sprite.play(chosen)
	elif not sprite.is_playing() and frames.get_animation_loop(chosen):
		sprite.play(chosen)


func has_animation(anim: StringName) -> bool:
	return sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim)


## Length of an animation in seconds (0 if missing).
func animation_length(anim: StringName) -> float:
	if not has_animation(anim):
		return 0.0
	var frames := sprite.sprite_frames
	var fps := frames.get_animation_speed(anim)
	return frames.get_frame_count(anim) / fps if fps > 0.0 else 0.0


## Mirrors the sprite: art is drawn facing right.
func face(dir_x: float) -> void:
	if sprite == null:
		return
	if dir_x < -0.01:
		sprite.flip_h = true
	elif dir_x > 0.01:
		sprite.flip_h = false


## Solid white flash (hit feedback).
func flash(duration: float = 0.08) -> void:
	if _material == null:
		return
	_flash_left = duration
	_material.set_shader_parameter("flash", 1.0)


## Flicker for invulnerability frames.
func blink(duration: float) -> void:
	_blink_left = duration


# --- Frame building ----------------------------------------------------------------

static func get_frames(key: String) -> SpriteFrames:
	if _frames_cache.has(key):
		return _frames_cache[key]
	var frames := SpriteFrames.new()
	var spec := ArtSpec.get_spec(key)
	if spec.is_empty():
		push_warning("EntityVisual: no ArtSpec entry for '%s'" % key)
		_frames_cache[key] = frames
		return frames

	var size: Vector2i = spec["size"]
	var anims: Dictionary = spec["anims"]
	for anim_name in anims:
		var path := "res://art/%s/%s_%s.png" % [spec["folder"], key, anim_name]
		if not ResourceLoader.exists(path):
			push_warning("EntityVisual: missing art %s" % path)
			continue
		var tex := load(path) as Texture2D
		if tex == null:
			continue
		var settings: Array = anims[anim_name]
		var count := maxi(1, floori(float(tex.get_width()) / size.x))
		var height := mini(size.y, tex.get_height())
		var anim := StringName(anim_name)
		if not frames.has_animation(anim):
			frames.add_animation(anim)
		frames.set_animation_speed(anim, float(settings[0]))
		frames.set_animation_loop(anim, bool(settings[1]))
		for i in count:
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(i * size.x, 0, size.x, height)
			frames.add_frame(anim, atlas)

	if frames.has_animation(&"default") and frames.get_animation_names().size() > 1:
		frames.remove_animation(&"default")
	_frames_cache[key] = frames
	return frames
