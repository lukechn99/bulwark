extends Node
## Art direction in one place: the shared materials, procedural textures, sky and input map.
##
## The look aims at the cinematic Republic-era interiors of modern Star Wars games
## (light grey panelling, deep red trim, bright strip lights, glossy dark floors)
## but every texture here is generated at startup, so nothing is borrowed.

const HULL := Color(0.70, 0.71, 0.73)
const HULL_DARK := Color(0.23, 0.24, 0.26)
const FLOOR := Color(0.30, 0.31, 0.33)
const TRIM_RED := Color(0.52, 0.07, 0.06)
const STRIP_WARM := Color(1.0, 0.93, 0.80)
const STRIP_BLUE := Color(0.45, 0.72, 1.0)

var hull: StandardMaterial3D
var hull_dark: StandardMaterial3D
var floor_mat: StandardMaterial3D
var grate: StandardMaterial3D
var trim_red: StandardMaterial3D
var metal: StandardMaterial3D
var strip_warm: StandardMaterial3D
var strip_blue: StandardMaterial3D
var strip_red: StandardMaterial3D
var screen_blue: StandardMaterial3D
var screen_amber: StandardMaterial3D
var glass: StandardMaterial3D
var shield: StandardMaterial3D
var hologram: StandardMaterial3D
var armor: StandardMaterial3D
var undersuit: StandardMaterial3D
var visor: StandardMaterial3D
var drone_shell: StandardMaterial3D
var drone_eye: StandardMaterial3D
var bolt_blue: StandardMaterial3D
var bolt_red: StandardMaterial3D
var planet: StandardMaterial3D
var engine_glow: StandardMaterial3D
var star_sky: Sky


func _ready() -> void:
	_setup_input()
	var panels := _panel_textures(512, 4, 0.06, 42)
	var tiles := _panel_textures(512, 2, 0.04, 7)
	hull = _lit(HULL, 0.5, 0.15, panels, 0.25)
	hull_dark = _lit(HULL_DARK, 0.45, 0.35, panels, 0.25)
	floor_mat = _lit(FLOOR, 0.28, 0.4, tiles, 0.2)
	grate = _lit(Color(0.12, 0.12, 0.13), 0.6, 0.6, _grate_texture(), 0.5)
	trim_red = _lit(TRIM_RED, 0.35, 0.1, [], 1.0)
	metal = _lit(Color(0.42, 0.43, 0.45), 0.3, 0.8, [], 1.0)
	strip_warm = _glow(STRIP_WARM, 3.0)
	strip_blue = _glow(STRIP_BLUE, 3.5)
	strip_red = _glow(Color(1.0, 0.18, 0.12), 3.0)
	screen_blue = _glow(Color(0.25, 0.55, 1.0), 1.6)
	screen_amber = _glow(Color(1.0, 0.6, 0.2), 1.4)
	glass = _clear(Color(0.55, 0.75, 1.0, 0.12))
	shield = _clear(Color(0.35, 0.65, 1.0, 0.16), true)
	hologram = _clear(Color(0.35, 0.75, 1.0, 0.45), true)
	armor = _lit(Color(0.88, 0.88, 0.86), 0.35, 0.05, [], 1.0)
	undersuit = _lit(Color(0.09, 0.09, 0.1), 0.8, 0.0, [], 1.0)
	visor = _lit(Color(0.02, 0.02, 0.03), 0.08, 0.9, [], 1.0)
	drone_shell = _lit(Color(0.33, 0.30, 0.27), 0.4, 0.7, panels, 0.6)
	drone_eye = _glow(Color(1.0, 0.15, 0.1), 6.0)
	bolt_blue = _glow(Color(0.35, 0.65, 1.0), 9.0)
	bolt_red = _glow(Color(1.0, 0.2, 0.12), 9.0)
	planet = _planet_material()
	engine_glow = _glow(Color(0.5, 0.75, 1.0), 6.0)
	star_sky = _starfield()


# --- input --------------------------------------------------------------------

func _setup_input() -> void:
	_bind_keys("move_forward", [KEY_W, KEY_UP])
	_bind_keys("move_back", [KEY_S, KEY_DOWN])
	_bind_keys("move_left", [KEY_A, KEY_LEFT])
	_bind_keys("move_right", [KEY_D, KEY_RIGHT])
	_bind_keys("sprint", [KEY_SHIFT])
	_bind_keys("jump", [KEY_SPACE])
	_bind_keys("interact", [KEY_E])
	_bind_keys("pause", [KEY_ESCAPE])
	_bind_keys("fullscreen", [KEY_F])
	_bind_mouse("fire", MOUSE_BUTTON_LEFT)
	_bind_mouse("aim", MOUSE_BUTTON_RIGHT)


func _bind_keys(action: StringName, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _bind_mouse(action: StringName, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


# --- materials ----------------------------------------------------------------

func _lit(color: Color, roughness: float, metallic: float, tex: Array, scale: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	m.metallic_specular = 0.6
	if tex.size() == 2:
		m.albedo_texture = tex[0]
		m.normal_enabled = true
		m.normal_texture = tex[1]
		m.normal_scale = 0.8
		# World-space triplanar mapping: every box in the kit gets panel lines at
		# the same scale, without UV work.
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE * scale
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color * energy
	m.albedo_color.a = 1.0
	return m


func _clear(color: Color, additive := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = color
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m


func _planet_material() -> StandardMaterial3D:
	var noise := FastNoiseLite.new()
	noise.seed = 3
	noise.frequency = 0.004
	noise.fractal_octaves = 5
	var tex := NoiseTexture2D.new()
	tex.width = 1024
	tex.height = 512
	tex.seamless = true
	tex.noise = noise
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.45, 0.5, 0.62, 1.0])
	ramp.colors = PackedColorArray([
		Color(0.04, 0.12, 0.30), Color(0.08, 0.25, 0.48), Color(0.62, 0.55, 0.40),
		Color(0.32, 0.40, 0.22), Color(0.92, 0.92, 0.95)])
	tex.color_ramp = ramp
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = 0.9
	m.rim_enabled = true
	m.rim = 0.8
	m.rim_tint = 0.2
	return m


# --- procedural textures ------------------------------------------------------

## Returns [albedo, normal]: an irregular grid of panels with dark seams, vents and
## bolts. `divisions` is how many large panels span the texture.
func _panel_textures(size: int, divisions: int, variation: float, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var albedo := Image.create(size, size, false, Image.FORMAT_RGB8)
	var bump := Image.create(size, size, false, Image.FORMAT_L8)
	albedo.fill(Color(0.8, 0.8, 0.8))
	bump.fill(Color(0.6, 0.6, 0.6))
	var cell := size / divisions
	for gy in divisions:
		for gx in divisions:
			_panel_split(albedo, bump, Rect2i(gx * cell, gy * cell, cell, cell), 2, rng, variation)
	var normal := bump.duplicate() as Image
	normal.convert(Image.FORMAT_RGBA8)
	normal.bump_map_to_normal_map(6.0)
	albedo.generate_mipmaps()
	normal.generate_mipmaps()
	return [ImageTexture.create_from_image(albedo), ImageTexture.create_from_image(normal)]


func _panel_split(albedo: Image, bump: Image, r: Rect2i, depth: int, rng: RandomNumberGenerator, variation: float) -> void:
	if depth > 0 and r.size.x > 48 and rng.randf() < 0.7:
		if rng.randf() < 0.5:
			var cut := int(r.size.x * rng.randf_range(0.3, 0.7))
			_panel_split(albedo, bump, Rect2i(r.position, Vector2i(cut, r.size.y)), depth - 1, rng, variation)
			_panel_split(albedo, bump, Rect2i(r.position + Vector2i(cut, 0), Vector2i(r.size.x - cut, r.size.y)), depth - 1, rng, variation)
		else:
			var cut := int(r.size.y * rng.randf_range(0.3, 0.7))
			_panel_split(albedo, bump, Rect2i(r.position, Vector2i(r.size.x, cut)), depth - 1, rng, variation)
			_panel_split(albedo, bump, Rect2i(r.position + Vector2i(0, cut), Vector2i(r.size.x, r.size.y - cut)), depth - 1, rng, variation)
		return
	var tone := 0.8 + rng.randf_range(-variation, variation)
	var inner := r.grow(-2)
	albedo.fill_rect(r, Color(0.42, 0.42, 0.43))
	bump.fill_rect(r, Color(0.2, 0.2, 0.2))
	albedo.fill_rect(inner, Color(tone, tone, tone))
	bump.fill_rect(inner, Color(0.6, 0.6, 0.6))
	var roll := rng.randf()
	if roll < 0.18 and inner.size.x > 40 and inner.size.y > 40:
		# A vent: a block of horizontal slots.
		var v := Rect2i(inner.position + inner.size / 4, inner.size / 2)
		for y in range(v.position.y, v.end.y, 6):
			albedo.fill_rect(Rect2i(v.position.x, y, v.size.x, 3), Color(0.3, 0.3, 0.31))
			bump.fill_rect(Rect2i(v.position.x, y, v.size.x, 3), Color(0.25, 0.25, 0.25))
	elif roll < 0.35 and inner.size.x > 24 and inner.size.y > 24:
		# An inset hatch.
		var h := inner.grow(-6)
		albedo.fill_rect(h, Color(tone - 0.05, tone - 0.05, tone - 0.05))
		bump.fill_rect(h, Color(0.48, 0.48, 0.48))
	# Bolts in the corners.
	for c in [inner.position + Vector2i(4, 4), Vector2i(inner.end.x - 7, inner.position.y + 4),
			Vector2i(inner.position.x + 4, inner.end.y - 7), inner.end - Vector2i(7, 7)]:
		albedo.fill_rect(Rect2i(c, Vector2i(3, 3)), Color(0.55, 0.55, 0.56))
		bump.fill_rect(Rect2i(c, Vector2i(3, 3)), Color(0.75, 0.75, 0.75))


func _grate_texture() -> Array:
	var size := 128
	var albedo := Image.create(size, size, false, Image.FORMAT_RGB8)
	var bump := Image.create(size, size, false, Image.FORMAT_L8)
	albedo.fill(Color(0.15, 0.15, 0.16))
	bump.fill(Color(0.1, 0.1, 0.1))
	for y in range(0, size, 16):
		for x in range(0, size, 16):
			albedo.fill_rect(Rect2i(x + 2, y + 2, 12, 12), Color(0.55, 0.55, 0.57))
			bump.fill_rect(Rect2i(x + 2, y + 2, 12, 12), Color(0.7, 0.7, 0.7))
	var normal := bump.duplicate() as Image
	normal.convert(Image.FORMAT_RGBA8)
	normal.bump_map_to_normal_map(4.0)
	albedo.generate_mipmaps()
	normal.generate_mipmaps()
	return [ImageTexture.create_from_image(albedo), ImageTexture.create_from_image(normal)]


## An equirectangular starfield with a faint band of nebula.
func _starfield() -> Sky:
	var w := 2048
	var h := 1024
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	img.fill(Color(0.004, 0.006, 0.012))
	var noise := FastNoiseLite.new()
	noise.seed = 11
	noise.frequency = 0.006
	noise.fractal_octaves = 4
	var nebula := noise.get_image(w / 8, h / 8)
	for y in h / 8:
		var band := exp(-pow((y - h / 16.0 - 18.0) / 22.0, 2.0))
		for x in w / 8:
			var n := clampf(nebula.get_pixel(x, y).r * 1.6 - 0.45, 0.0, 1.0) * band
			if n > 0.01:
				img.fill_rect(Rect2i(x * 8, y * 8, 8, 8), Color(0.02 + n * 0.10, 0.015 + n * 0.05, 0.04 + n * 0.16))
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in 4200:
		var x := rng.randi_range(0, w - 2)
		var y := rng.randi_range(0, h - 2)
		var b := pow(rng.randf(), 4.0) * 0.9 + 0.1
		var tint := Color(b, b, b).lerp(Color(b * 0.7, b * 0.85, b), rng.randf())
		img.set_pixel(x, y, tint)
		if b > 0.75:
			img.fill_rect(Rect2i(x, y, 2, 2), tint)
	var tex := ImageTexture.create_from_image(img)
	var mat := PanoramaSkyMaterial.new()
	mat.panorama = tex
	mat.energy_multiplier = 1.0
	var sky := Sky.new()
	sky.sky_material = mat
	return sky
