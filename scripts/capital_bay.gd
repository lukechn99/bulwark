class_name CapitalBay
extends Node3D
## A hangar bay built into a capital ship, open to space behind a ray shield.
## Fly in slowly, press USE to land, then climb out and explore on foot.
##
## Friendly bays (sister ships) are lit blue-white; landing in one repairs your
## fighter. Enemy bays (dreadnoughts) are lit red and garrisoned: a squad of
## assault droids musters on the deck whenever you come near.
##
## Origin: the floor at the middle of the mouth. The bay runs back along -X.

const W := 56.0   # width, across Z
const H := 17.0
const D := 44.0   # depth, along -X

var enemy := false
var title := ""
var _squad := ""
var _garrisoned := false
var _rearm := 0.0
static var _count := 0


static func make(pos: Vector3, is_enemy: bool, label: String) -> CapitalBay:
	var b := CapitalBay.new()
	b.position = pos
	b.enemy = is_enemy
	b.title = label
	return b


func _ready() -> void:
	_count += 1
	_squad = "bay%d" % _count
	var shell: Material = Look.droid_shell if enemy else Look.hull
	var trim: Material = Look.droid_mark if enemy else Look.trim_red
	var glow: Material = Look.strip_red if enemy else Look.strip_blue
	Kit.begin(self)
	# Deck, overhead, back and side walls (solid, so they also read from outside).
	Kit.block(self, Vector3(D, 1.0, W), Vector3(-D / 2.0, -0.5, 0), Look.floor_mat)
	Kit.block(self, Vector3(D + 2.0, 2.0, W + 4.0), Vector3(-D / 2.0, -2.0, 0), shell)
	Kit.block(self, Vector3(D + 2.0, 2.0, W + 4.0), Vector3(-D / 2.0, H + 1.0, 0), shell)
	Kit.block(self, Vector3(2.0, H + 4.0, W + 4.0), Vector3(-D - 1.0, H / 2.0, 0), shell)
	for side in [-1.0, 1.0]:
		Kit.block(self, Vector3(D + 2.0, H + 4.0, 2.0), Vector3(-D / 2.0, H / 2.0, side * (W / 2.0 + 1.0)), shell)
		Kit.block(self, Vector3(D, 0.8, 0.2), Vector3(-D / 2.0, 3.0, side * (W / 2.0 - 0.1)), trim, false)
		Kit.block(self, Vector3(D, 3.0, 0.3), Vector3(-D / 2.0, 1.5, side * (W / 2.0 - 0.15)), Look.hull_dark, false)
		for i in 5:
			Kit.block(self, Vector3(1.2, H, 1.0), Vector3(-4.0 - i * 9.0, H / 2.0, side * (W / 2.0 - 0.5)), Look.hull_dark, false)
	# Overhead light bars, a lit back wall, and deck markings toward the mouth.
	for i in 4:
		Kit.strip(self, Vector3(2.0, 0.06, W - 8.0), Vector3(-6.0 - i * 10.0, H - 0.04, 0), Look.strip_warm)
	Kit.strip(self, Vector3(0.1, 4.0, W - 10.0), Vector3(-D + 0.06, H * 0.55, 0), Look.screen_amber if enemy else Look.screen_blue)
	for i in 8:
		Kit.strip(self, Vector3(2.0, 0.03, 0.4), Vector3(-3.0 - i * 5.0, 0.02, 0), glow)
	for side in [-1.0, 1.0]:
		Kit.strip(self, Vector3(0.4, 0.03, 0.4), Vector3(-D / 2.0, 0.02, side * 12.0), glow)
	# Mouth frame with glowing guide lights you can find from a distance.
	Kit.block(self, Vector3(2.0, 2.0, W + 4.0), Vector3(1.0, H + 1.0, 0), Look.hull_dark)
	Kit.block(self, Vector3(2.0, 1.0, W + 4.0), Vector3(1.0, -0.5, 0), Look.hull_dark)
	Kit.strip(self, Vector3(0.3, 0.3, W), Vector3(2.05, H, 0), glow)
	Kit.strip(self, Vector3(0.3, 0.3, W), Vector3(2.05, 0.1, 0), glow)
	for side in [-1.0, 1.0]:
		Kit.strip(self, Vector3(0.3, H, 0.3), Vector3(2.05, H / 2.0, side * W / 2.0), glow)
	Kit.end(30.0)
	var shield := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(W, H)
	shield.mesh = quad
	var mat := Look.shield
	if enemy:
		mat = Look.shield.duplicate() as StandardMaterial3D
		mat.albedo_color = Color(1.0, 0.35, 0.2, 0.14)
	shield.material_override = mat
	shield.position = Vector3(0.5, H / 2.0, 0)
	shield.rotation.y = deg_to_rad(90)
	shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shield)
	var sign := Label3D.new()
	sign.text = title
	sign.font_size = 96
	sign.pixel_size = 0.06
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.modulate = Color(1.0, 0.55, 0.4) if enemy else Color(0.6, 0.85, 1.0)
	sign.position = Vector3(6.0, H + 9.0, 0)
	sign.no_depth_test = false
	add_child(sign)
	var light_color := Color(1.0, 0.55, 0.45) if enemy else Color(0.88, 0.93, 1.0)
	for x in [-10.0, -32.0]:
		var l := Kit.omni(self, Vector3(x, H - 3.0, 0), light_color, 2.6, 34.0)
		l.shadow_enabled = false
	if not enemy:
		var bay := Node3D.new()
		bay.add_to_group("repair_bay")
		bay.set_meta("radius", 30.0)
		bay.position = Vector3(-D / 2.0, 1.0, 0)
		add_child(bay)


func _process(delta: float) -> void:
	if not enemy:
		return
	var p := Zones.player as Node3D
	if not p:
		return
	var d := p.global_position.distance_to(global_position)
	# Muster a squad when you come close; stand it down when you leave.
	if d < 450.0 and not _garrisoned:
		_rearm -= delta
		if _rearm <= 0.0:
			_garrisoned = true
			AssaultDroid.spawn_squad(self, Vector3(-30, 0.2, -6), 4, _squad, deg_to_rad(-90))
			AssaultDroid.spawn_squad(self, Vector3(-30, 0.2, 10), 3, _squad + "b", deg_to_rad(-90))
	elif d > 900.0 and _garrisoned:
		for c in get_children():
			if c is AssaultDroid:
				c.queue_free()
		_garrisoned = false
		_rearm = 0.0
	if _garrisoned and d < 450.0:
		var left := 0
		for c in get_children():
			if c is AssaultDroid and c.health > 0.0:
				left += 1
		if left == 0:
			# Cleared: reinforcements arrive a while after you leave and return.
			_rearm = 60.0
