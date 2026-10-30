extends Node3D
## Dorsal Flight Deck: a long trench cut into the top of the hull, open to
## space under a ray shield. Fighters launch straight up out of it. Heavy
## turrets sit on the hull either side, crewed from gunnery stations set into
## the trench walls, and the command tower rises behind the aft wall.
##
## Built around its own origin (Main.FLIGHT_DECK). Trench: x -70..70,
## z -18..18, deck y 0, hull top y 16. The ship's bow points +X.

const X0 := -70.0
const X1 := 70.0
const ZW := 18.0
const H := 16.0
const FIGHTERS := 3

var _respawn := 4.0


func _ready() -> void:
	position = Vector3(0, 150, 0)
	Kit.begin(self)
	_trench()
	_hull()
	_tower()
	_props()
	_stations()
	Kit.end(20.0)
	_lights()
	for side in [-1.0, 1.0]:
		add_child(Turret.make(Vector3(-40, H, side * 28.0), deg_to_rad(-90), Vector3(-40, 0, side * (ZW - 1.4))))
		add_child(Turret.make(Vector3(15, H, side * 28.0), deg_to_rad(-90), Vector3(9999, 0, 0)))
	AssaultDroid.spawn_squad(self, Vector3(42, 0.1, 0), 4, "deck", deg_to_rad(90))
	var spawn := Marker3D.new()
	spawn.name = "Spawn"
	spawn.position = Vector3(-62, 0.1, 0)
	spawn.rotation.y = deg_to_rad(-90)
	add_child(spawn)


func _process(delta: float) -> void:
	# Keep a flight of enemy fighters making runs at the deck.
	var count := 0
	for c in get_children():
		if c is EnemyFighter:
			count += 1
	if count >= FIGHTERS:
		return
	_respawn -= delta
	if _respawn <= 0.0:
		_respawn = 5.0
		_launch_fighter()


func _launch_fighter() -> void:
	var lane := randf_range(-8.0, 8.0)
	var s := 1.0 if randf() < 0.5 else -1.0
	var path: Array[Vector3] = [
		Vector3(480, 80, lane * 6.0),
		Vector3(120, 30, lane),
		Vector3(-20, 24, lane),
		Vector3(-170, 70, lane * 2.0),
		Vector3(-160, 150, s * 260.0),
		Vector3(260, 170, s * 320.0),
	]
	EnemyFighter.launch(self, path, 0)


func _trench() -> void:
	# Deck tiles, guide lines and launch circles.
	for i in 7:
		for j in 2:
			Kit.block(self, Vector3(20, 0.4, ZW), Vector3(X0 + 10 + i * 20, -0.2, -ZW / 2.0 + j * ZW), Look.floor_mat)
	for i in 34:
		Kit.strip(self, Vector3(2.0, 0.02, 0.2), Vector3(X0 + 3 + i * 4.0, 0.01, 0), Look.strip_blue)
	for x in [-30.0, 0.0, 30.0]:
		for side in [-1.0, 1.0]:
			_ring(Vector3(x, 0.01, side * 10.0), 5.5)
	# Trench walls: dark lower band, red stripe, ribs, and a catwalk halfway up.
	for side in [-1.0, 1.0]:
		var z: float = side * (ZW + 0.5)
		Kit.block(self, Vector3(X1 - X0 + 1.0, H, 1.0), Vector3(0, H / 2.0, z), Look.hull)
		Kit.block(self, Vector3(X1 - X0, 3.0, 0.3), Vector3(0, 1.5, side * (ZW - 0.1)), Look.hull_dark)
		Kit.block(self, Vector3(X1 - X0, 0.35, 0.34), Vector3(0, 3.2, side * (ZW - 0.1)), Look.trim_red, false)
		Kit.block(self, Vector3(X1 - X0, 0.3, 2.2), Vector3(0, 8.0, side * (ZW - 1.1)), Look.hull_dark)
		Kit.strip(self, Vector3(X1 - X0, 0.05, 0.06), Vector3(0, 7.84, side * (ZW - 2.2)), Look.strip_blue)
		Kit.railing(self, Vector3(X0 + 0.5, 8.15, side * (ZW - 2.2)), Vector3(X1 - 0.5, 8.15, side * (ZW - 2.2)))
		for i in 15:
			var x := X0 + 2.0 + i * 9.7
			Kit.block(self, Vector3(1.2, H, 1.0), Vector3(x, H / 2.0, side * (ZW - 0.3)), Look.hull_dark)
			Kit.strip(self, Vector3(0.1, 3.0, 0.06), Vector3(x + 0.66, 5.0, side * (ZW - 0.3)), Look.strip_warm)
		# Lip along the top edge.
		Kit.block(self, Vector3(X1 - X0 + 2.0, 0.8, 1.6), Vector3(0, H + 0.1, side * (ZW + 0.2)), Look.hull_dark)
	# End walls: the aft wall holds the lift, the bow wall is a sealed blast door.
	Kit.block(self, Vector3(1.0, H, ZW * 2.0 + 2.0), Vector3(X0 - 0.5, H / 2.0, 0), Look.hull)
	Kit.block(self, Vector3(1.0, H, ZW * 2.0 + 2.0), Vector3(X1 + 0.5, H / 2.0, 0), Look.hull)
	for i in 4:
		Kit.block(self, Vector3(0.4, H - 2.0, 7.0), Vector3(X1 - 0.1, (H - 2.0) / 2.0, -10.5 + i * 7.0), Look.hull_dark)
		Kit.block(self, Vector3(0.44, 0.6, 7.0), Vector3(X1 - 0.12, 4.0, -10.5 + i * 7.0), Look.trim_red, false)
	_lift_frame()
	# The ray shield overhead, and an invisible lid so nobody leaves through it.
	var shield := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(X1 - X0, ZW * 2.0)
	shield.mesh = quad
	shield.material_override = Look.shield
	shield.rotation.x = deg_to_rad(-90)
	shield.position = Vector3(0, H + 0.3, 0)
	shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shield)
	Kit.barrier(self, Vector3(X1 - X0, 1.0, ZW * 2.0), Vector3(0, H + 1.0, 0), Kit.SHIELD_LAYER)


func _ring(c: Vector3, r: float) -> void:
	for i in 12:
		var a := i * TAU / 12.0
		Kit.block(self, Vector3(r * 0.5, 0.02, 0.2), c + Vector3(cos(a) * r, 0, sin(a) * r), Look.trim_red, false, Vector3(0, -a + PI / 2.0, 0))


func _lift_frame() -> void:
	var f := Node3D.new()
	f.position = Vector3(X0, 0, 0)
	f.rotation.y = deg_to_rad(90)
	add_child(f)
	Kit.strip(f, Vector3(2.2, 3.2, 0.06), Vector3(0, 1.8, 0.02), Look.screen_blue)
	for side in [-1.0, 1.0]:
		Kit.block(f, Vector3(0.4, 4.0, 0.6), Vector3(side * 1.35, 2.0, 0.3), Look.hull_dark)
	Kit.block(f, Vector3(3.1, 0.5, 0.6), Vector3(0, 4.25, 0.3), Look.hull_dark)


## The hull around the trench, seen from the deck and from the turrets.
func _hull() -> void:
	for side in [-1.0, 1.0]:
		# Flat shoulders either side of the trench, then a long downward slope.
		Kit.block(self, Vector3(205, 2.0, 50), Vector3(-15, H - 1.0, side * (ZW + 25.0)), Look.hull)
		Kit.block(self, Vector3(205, 0.3, 1.2), Vector3(-15, H + 0.05, side * (ZW + 49.0)), Look.trim_red, false)
		Kit.block(self, Vector3(205, 2.0, 46), Vector3(-15, H - 9.0, side * (ZW + 71.0)), Look.hull, false, Vector3(side * deg_to_rad(20), 0, 0))
		# Panel lines and vents along the shoulders.
		for i in 9:
			Kit.block(self, Vector3(14, 0.4, 4), Vector3(-100 + i * 22.0, H + 0.1, side * (ZW + 38.0)), Look.hull_dark, false)
	# The bow: a long wedge narrowing to a point.
	var bow := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(186, 240, 4)
	bow.mesh = prism
	bow.material_override = Look.hull
	bow.rotation_degrees = Vector3(-90, -90, 0)
	bow.position = Vector3(87 + 120, H - 2.0, 0)
	add_child(bow)
	var keel := MeshInstance3D.new()
	var keel_prism := PrismMesh.new()
	keel_prism.size = Vector3(12, 230, 3)
	keel.mesh = keel_prism
	keel.material_override = Look.trim_red
	keel.rotation_degrees = Vector3(-90, -90, 0)
	keel.position = Vector3(87 + 115, H + 0.6, 0)
	add_child(keel)
	# Aft section under the tower.
	Kit.block(self, Vector3(50, 2.0, 2.0 * ZW + 4.0), Vector3(-96, H - 1.0, 0), Look.hull)


func _tower() -> void:
	# Stepped command tower behind the aft wall, with a lit bridge band near the top.
	Kit.block(self, Vector3(30, 16, 26), Vector3(-100, H + 8, 0), Look.hull)
	Kit.block(self, Vector3(24, 14, 20), Vector3(-102, H + 23, 0), Look.hull)
	Kit.block(self, Vector3(34, 7, 30), Vector3(-100, H + 33.5, 0), Look.hull)
	Kit.strip(self, Vector3(0.2, 1.4, 26), Vector3(-82.9, H + 33.5, 0), Look.screen_blue)
	Kit.block(self, Vector3(34.4, 0.6, 30.4), Vector3(-100, H + 31.0, 0), Look.trim_red, false)
	Kit.block(self, Vector3(18, 3, 16), Vector3(-103, H + 38.5, 0), Look.hull_dark)
	Kit.cylinder(self, 0.4, 14, Vector3(-106, H + 47, 4), Look.metal, false, 8)
	Kit.cylinder(self, 0.3, 9, Vector3(-100, H + 44.5, -5), Look.metal, false, 8)
	for side in [-1.0, 1.0]:
		Kit.block(self, Vector3(20, 10, 4), Vector3(-98, H + 5, side * 15.0), Look.hull_dark)
	Kit.strip(self, Vector3(0.6, 0.6, 0.6), Vector3(-106, H + 54.2, 4), Look.strip_red)


func _props() -> void:
	for i in range(1, 5):   # pad 0 holds the flyable fighters (Main)
		for side in [-1.0, 1.0]:
			Kit.starfighter(self, Vector3(-48 + i * 22.0, 0, side * 10.0), deg_to_rad(-90))
	for c in [Vector3(-60, 0.6, 14), Vector3(-58.4, 0.6, 14.3), Vector3(-25, 0.6, -14), Vector3(5, 0.6, 14.5),
			Vector3(28, 0.6, -14.2), Vector3(55, 0.6, 13.8), Vector3(57, 0.6, -14)]:
		Kit.crate(self, c, Vector3(1.4, 1.2, 1.4), randf() * 0.3)
	for c in [Vector3(-12, 0.75, 3.5), Vector3(18, 0.75, -3.5)]:
		Kit.crate(self, c, Vector3(2.8, 1.5, 1.2))


func _stations() -> void:
	# A gunnery alcove in each wall below the manned turrets.
	for side in [-1.0, 1.0]:
		var z: float = side * (ZW - 0.6)
		Kit.console(self, Vector3(-40, 0, z), PI if side > 0 else 0.0, Look.screen_amber)
		Kit.strip(self, Vector3(1.6, 0.03, 1.6), Vector3(-40, 0.02, side * (ZW - 1.4)), Look.strip_blue)
		Kit.strip(self, Vector3(3.0, 0.4, 0.06), Vector3(-40, 3.8, side * (ZW - 0.42)), Look.strip_red)


func _lights() -> void:
	for x in [-50.0, -15.0, 20.0, 55.0]:
		for side in [-1.0, 1.0]:
			var s := Kit.spot(self, Vector3(x, H - 1.0, side * (ZW - 1.5)), Color(1.0, 0.95, 0.86), 7.0, 26.0, 50.0)
			s.rotation_degrees = Vector3(-70, 180 if side < 0 else 0, 0)
	Kit.omni(self, Vector3(X0 + 4.0, 4.0, 0), Look.STRIP_BLUE, 1.5, 10.0)
	for side in [-1.0, 1.0]:
		Kit.omni(self, Vector3(-40, 3.0, side * (ZW - 2.5)), Color(1.0, 0.6, 0.3), 1.2, 6.0)
