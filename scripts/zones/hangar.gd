extends Node3D
## Hangar Bay 3: a tall bay open to space behind a ray shield, with parked
## fighters, crates for cover, wall catwalks and a control gallery above the
## blast door to the service corridor.
##
## Interior: x -22..22 (mouth at +22), z -28..28, floor y 0, ceiling y 18.

const X0 := -22.0
const X1 := 22.0
const ZW := 28.0
const H := 18.0


func _ready() -> void:
	Kit.begin(self)
	_shell()
	_mouth()
	_catwalks()
	_gallery()
	_props()
	Kit.end()
	_lights()
	for p in [Vector3(6, 1.8, 2), Vector3(14, 2.4, -10), Vector3(15, 1.8, 13), Vector3(0, 2.0, -20), Vector3(-2, 7.0 + 1.7, 26.5 - 1.3)]:
		SentryDrone.spawn(self, p)
	var spawn := Marker3D.new()
	spawn.name = "Spawn"
	spawn.position = Vector3(-17, 0.1, 6)
	spawn.rotation.y = deg_to_rad(-90)
	add_child(spawn)


func _shell() -> void:
	# Floor in tiles so each piece only receives the lights near it.
	var tx := 4
	var tz := 4
	var sx := (X1 + 1.0 - X0) / tx
	var sz := ZW * 2.0 / tz
	for i in tx:
		for j in tz:
			Kit.block(self, Vector3(sx, 0.4, sz), Vector3(X0 + sx * (i + 0.5), -0.2, -ZW + sz * (j + 0.5)), Look.floor_mat)
	# Floor markings: a guide line toward the mouth and pad outlines.
	for i in 14:
		Kit.strip(self, Vector3(1.2, 0.02, 0.18), Vector3(X0 + 3.0 + i * 3.0, 0.01, 0), Look.strip_blue)
	for pad in [Vector3(7, 0, -15), Vector3(7, 0, 15), Vector3(-9, 0, 15)]:
		_pad_outline(pad, 12.0)
	# Ceiling and cross beams.
	Kit.block(self, Vector3(X1 - X0 + 2.0, 0.5, ZW * 2.0 + 1.0), Vector3((X0 + X1) / 2.0 + 1.0, H + 0.25, 0), Look.hull_dark)
	for i in 7:
		var x := X0 + 3.0 + i * 6.5
		Kit.block(self, Vector3(1.0, 1.4, ZW * 2.0), Vector3(x, H - 0.7, 0), Look.hull_dark, false)
		Kit.strip(self, Vector3(1.6, 0.06, ZW * 1.6), Vector3(x + 3.25, H - 0.05, 0), Look.strip_warm)
	# Back wall with the door opening (z -1.5..1.5, y 0..3.2).
	var wx := X0 - 0.25
	Kit.block(self, Vector3(0.5, H, ZW - 1.5), Vector3(wx, H / 2.0, -(ZW + 1.5) / 2.0), Look.hull)
	Kit.block(self, Vector3(0.5, H, ZW - 1.5), Vector3(wx, H / 2.0, (ZW + 1.5) / 2.0), Look.hull)
	Kit.block(self, Vector3(0.5, H - 3.2, 3.0), Vector3(wx, 3.2 + (H - 3.2) / 2.0, 0), Look.hull)
	# Door surround: a heavy frame with red bands.
	for side in [-1.0, 1.0]:
		Kit.block(self, Vector3(0.6, 4.2, 0.8), Vector3(X0 + 0.1, 2.1, side * 1.9), Look.hull_dark)
		Kit.block(self, Vector3(0.64, 0.4, 0.84), Vector3(X0 + 0.1, 1.2, side * 1.9), Look.trim_red, false)
	Kit.block(self, Vector3(0.6, 0.8, 4.6), Vector3(X0 + 0.1, 3.6, 0), Look.hull_dark)
	# Side walls with ribs, a dark lower band and the red stripe.
	for side in [-1.0, 1.0]:
		var z: float = side * (ZW + 0.25)
		Kit.block(self, Vector3(X1 - X0 + 2.0, H, 0.5), Vector3((X0 + X1) / 2.0 + 1.0, H / 2.0, z), Look.hull)
		Kit.block(self, Vector3(X1 - X0, 3.0, 0.3), Vector3(0, 1.5, side * (ZW - 0.1)), Look.hull_dark)
		Kit.block(self, Vector3(X1 - X0, 0.35, 0.34), Vector3(0, 3.2, side * (ZW - 0.1)), Look.trim_red, false)
		for i in 7:
			var x := X0 + 3.0 + i * 6.5
			Kit.block(self, Vector3(1.0, H, 1.2), Vector3(x, H / 2.0, side * (ZW - 0.5)), Look.hull_dark)
			Kit.strip(self, Vector3(0.12, 3.0, 0.05), Vector3(x + 0.62, 5.0, side * (ZW - 0.5)), Look.strip_warm)
	# Back-wall ribs.
	for z in [-22.0, -15.0, -8.0, 8.0, 15.0, 22.0]:
		Kit.block(self, Vector3(1.2, H, 1.0), Vector3(X0 + 0.5, H / 2.0, z), Look.hull_dark)


func _pad_outline(c: Vector3, s: float) -> void:
	var t := 0.25
	Kit.block(self, Vector3(s, 0.02, t), c + Vector3(0, 0.01, -s / 2.0), Look.trim_red, false)
	Kit.block(self, Vector3(s, 0.02, t), c + Vector3(0, 0.01, s / 2.0), Look.trim_red, false)
	Kit.block(self, Vector3(t, 0.02, s), c + Vector3(-s / 2.0, 0.01, 0), Look.trim_red, false)
	Kit.block(self, Vector3(t, 0.02, s), c + Vector3(s / 2.0, 0.01, 0), Look.trim_red, false)


func _mouth() -> void:
	# A lip at the edge of the deck, a heavy frame, and the shimmering ray shield.
	Kit.block(self, Vector3(1.0, 0.6, ZW * 2.0), Vector3(X1 + 1.5, -0.1, 0), Look.hull_dark)
	Kit.strip(self, Vector3(0.1, 0.05, ZW * 2.0), Vector3(X1 + 1.0, 0.21, 0), Look.strip_blue)
	Kit.block(self, Vector3(2.0, 2.4, ZW * 2.0 + 2.0), Vector3(X1 + 1.0, H - 1.2, 0), Look.hull_dark)
	Kit.strip(self, Vector3(0.1, 0.12, ZW * 2.0), Vector3(X1 - 0.05, H - 2.45, 0), Look.strip_blue)
	for side in [-1.0, 1.0]:
		Kit.block(self, Vector3(2.0, H, 2.0), Vector3(X1 + 1.0, H / 2.0, side * (ZW - 1.0)), Look.hull_dark)
		Kit.block(self, Vector3(2.04, 0.5, 2.04), Vector3(X1 + 1.0, 3.2, side * (ZW - 1.0)), Look.trim_red, false)
	var shield := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(ZW * 2.0 - 4.0, H - 2.4)
	shield.mesh = quad
	shield.material_override = Look.shield
	shield.position = Vector3(X1 + 1.2, (H - 2.4) / 2.0, 0)
	shield.rotation.y = deg_to_rad(90)
	shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shield)
	Kit.barrier(self, Vector3(0.5, H, ZW * 2.0), Vector3(X1 + 1.5, H / 2.0, 0))


func _catwalks() -> void:
	var y := 7.0
	for side in [-1.0, 1.0]:
		var inner: float = side * (ZW - 2.6)
		Kit.block(self, Vector3(X1 - X0 - 1.0, 0.3, 2.6), Vector3(0, y - 0.15, side * (ZW - 1.3)), Look.hull_dark)
		Kit.strip(self, Vector3(X1 - X0 - 1.0, 0.04, 0.06), Vector3(0, y - 0.32, inner), Look.strip_blue)
		Kit.railing(self, Vector3(X0 + 0.6, y, inner), Vector3(X1 - 1.0, y, inner))
		for i in 7:
			var x := X0 + 3.0 + i * 6.5
			Kit.block(self, Vector3(0.3, 1.2, 2.2), Vector3(x, y - 0.9, side * (ZW - 1.4)), Look.hull_dark, false, Vector3(side * deg_to_rad(30), 0, 0))


func _gallery() -> void:
	# Control gallery above the door: a lit window band with consoles behind it.
	var x := X0 + 0.05
	Kit.block(self, Vector3(0.3, 0.4, 18.0), Vector3(x + 0.2, 8.0, 0), Look.hull_dark, false)
	Kit.block(self, Vector3(0.3, 0.4, 18.0), Vector3(x + 0.2, 11.0, 0), Look.hull_dark, false)
	Kit.strip(self, Vector3(0.05, 2.6, 17.6), Vector3(x, 9.5, 0), Look.screen_blue)
	for z in [-6.0, -2.0, 2.0, 6.0]:
		Kit.block(self, Vector3(0.32, 2.6, 0.3), Vector3(x + 0.2, 9.5, z), Look.hull_dark, false)
	Kit.strip(self, Vector3(0.06, 0.15, 18.0), Vector3(x + 0.35, 11.3, 0), Look.strip_red)


func _props() -> void:
	Kit.starfighter(self, Vector3(7, 0, -15), deg_to_rad(-90))
	Kit.starfighter(self, Vector3(7, 0, 15), deg_to_rad(-90))
	var serviced := Kit.starfighter(self, Vector3(-9, 0, 15), deg_to_rad(-60))
	serviced.position.y = 0.0
	# Fuel cells and crate stacks for cover.
	for c in [Vector3(-12, 0.6, 9), Vector3(-6, 0.6, 9.6), Vector3(-4.5, 0.6, -4), Vector3(2, 0.6, 6),
			Vector3(11, 0.6, -2), Vector3(16, 0.6, 5), Vector3(-14, 0.6, -10), Vector3(-6, 0.6, -18)]:
		Kit.crate(self, c, Vector3(1.4, 1.2, 1.4), randf() * 0.4)
	for c in [Vector3(-12, 1.8, 9), Vector3(-14, 1.8, -10)]:
		Kit.crate(self, c, Vector3(1.2, 1.2, 1.2), 0.3)
	Kit.crate(self, Vector3(-4.5, 0.75, -2.2), Vector3(2.8, 1.5, 1.2))
	for p in [Vector3(-17, 1.1, -20), Vector3(-15.5, 1.1, -20), Vector3(-17, 1.1, -22)]:
		var cell := Kit.cylinder(self, 0.6, 2.2, p, Look.hull)
		Kit.cylinder(cell, 0.62, 0.3, Vector3(0, 0.4, 0), Look.trim_red, false)
	# Wall consoles under the gallery.
	for z in [-10.0, 10.0]:
		Kit.console(self, Vector3(X0 + 0.8, 0, z), deg_to_rad(-90))


func _lights() -> void:
	for x in [-14.0, 0.0, 14.0]:
		for z in [-14.0, 14.0]:
			var s := Kit.spot(self, Vector3(x, H - 1.5, z), Color(1.0, 0.95, 0.86), 9.0, 30.0, 45.0)
			s.spot_angle_attenuation = 1.5
	Kit.omni(self, Vector3(X1 - 2.0, 6.0, 0), Look.STRIP_BLUE, 2.0, 22.0)
	# Wall wash so the panelling reads, not just the floor pools.
	for x in [-12.0, 2.0, 15.0]:
		for side in [-1.0, 1.0]:
			Kit.omni(self, Vector3(x, 11.0, side * (ZW - 5.0)), Color(0.9, 0.93, 1.0), 2.0, 16.0)
	Kit.omni(self, Vector3(X0 + 3.0, 4.0, 0), Color(1.0, 0.9, 0.8), 1.5, 10.0)
	Kit.omni(self, Vector3(X0 + 3.0, 9.5, 0), Color(0.4, 0.65, 1.0), 1.5, 12.0)
