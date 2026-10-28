extends Node3D
## Command Bridge: a raised central walkway between two sunken crew pits,
## ending at a holotable before tall forward viewports.
##
## Built around its own origin, which sits at Main.BRIDGE_DECK (turned to face
## +X), far above the hangar deck: the only way here is the turbolift.
## Interior: x -10..10, z -34..6 (lift alcove to z 9), walkway y 0, pits y -1.8,
## ceiling y 6.

const PIT := -1.8
const TOP := 6.0
const FRONT := -34.0
const BACK := 6.0

var _holo: Node3D


func _ready() -> void:
	position = Vector3(0, 300, 0)
	rotation.y = deg_to_rad(-90)   # windows face +X, toward the planet
	Kit.begin(self)
	_shell()
	_walkway()
	_pits()
	_viewports()
	_holotable()
	_lift_alcove()
	Kit.end()
	_lights()
	var spawn := Marker3D.new()
	spawn.name = "Spawn"
	spawn.position = Vector3(0, 0.1, 3)
	add_child(spawn)


func _process(delta: float) -> void:
	if _holo:
		_holo.rotation.y += delta * 0.3


func _shell() -> void:
	var length := BACK - FRONT
	var cz := (BACK + FRONT) / 2.0
	Kit.block(self, Vector3(21.0, 0.4, length), Vector3(0, PIT - 0.2, cz), Look.floor_mat)
	Kit.block(self, Vector3(21.0, 0.4, length + 1.0), Vector3(0, TOP + 0.2, cz), Look.hull_dark)
	for side in [-1.0, 1.0]:
		Kit.block(self, Vector3(0.5, TOP - PIT, length), Vector3(side * 10.25, (TOP + PIT) / 2.0, cz), Look.hull)
		Kit.block(self, Vector3(0.3, 0.3, length), Vector3(side * 9.9, 1.2, cz), Look.trim_red, false)
		for i in 9:
			var z := FRONT + 2.0 + i * 4.4
			Kit.block(self, Vector3(0.8, TOP - PIT, 0.8), Vector3(side * 9.7, (TOP + PIT) / 2.0, z), Look.hull_dark)
			Kit.strip(self, Vector3(0.05, 2.0, 0.1), Vector3(side * 9.28, 3.2, z), Look.strip_warm)
			# Ceiling ribs rising toward the windows.
		for i in 8:
			var z := FRONT + 4.0 + i * 4.4
			Kit.block(self, Vector3(20.0, 0.5, 0.6), Vector3(0, TOP - 0.25, z), Look.hull_dark, false)
	Kit.strip(self, Vector3(2.0, 0.05, length - 4.0), Vector3(0, TOP - 0.03, cz), Look.strip_warm)
	# Back wall around the lift opening (x -1.5..1.5, y 0..3.2).
	Kit.block(self, Vector3(8.5, TOP - PIT, 0.5), Vector3(-5.75, (TOP + PIT) / 2.0, BACK + 0.25), Look.hull)
	Kit.block(self, Vector3(8.5, TOP - PIT, 0.5), Vector3(5.75, (TOP + PIT) / 2.0, BACK + 0.25), Look.hull)
	Kit.block(self, Vector3(3.0, TOP - 3.2, 0.5), Vector3(0, 3.2 + (TOP - 3.2) / 2.0, BACK + 0.25), Look.hull)
	Kit.block(self, Vector3(3.0, -PIT, 0.5), Vector3(0, PIT / 2.0, BACK + 0.25), Look.hull_dark)


func _walkway() -> void:
	# Central walkway from the lift to the command platform.
	var z0 := FRONT + 12.0   # -22
	Kit.block(self, Vector3(5.0, -PIT, BACK - z0), Vector3(0, PIT / 2.0, (BACK + z0) / 2.0), Look.floor_mat)
	Kit.block(self, Vector3(10.0, -PIT, 10.0), Vector3(0, PIT / 2.0, z0 - 5.0), Look.floor_mat)
	Kit.strip(self, Vector3(0.12, 0.02, BACK - z0), Vector3(-2.3, 0.01, (BACK + z0) / 2.0), Look.strip_blue)
	Kit.strip(self, Vector3(0.12, 0.02, BACK - z0), Vector3(2.3, 0.01, (BACK + z0) / 2.0), Look.strip_blue)
	for side in [-1.0, 1.0]:
		Kit.railing(self, Vector3(side * 2.5, 0, BACK - 1.0), Vector3(side * 2.5, 0, z0))
		Kit.railing(self, Vector3(side * 2.5, 0, z0), Vector3(side * 5.0, 0, z0))
		Kit.railing(self, Vector3(side * 5.0, 0, z0), Vector3(side * 5.0, 0, z0 - 9.0))
	# Steps down into each pit near the back.
	for side in [-1.0, 1.0]:
		for s in 3:
			var h := PIT + (s + 1) * (-PIT / 4.0)
			Kit.block(self, Vector3(1.2, 0.45, 1.6), Vector3(side * (6.0 - s * 1.2), h - 0.225, 3.6), Look.floor_mat)


func _pits() -> void:
	# Rows of crew stations facing the windows.
	for side in [-1.0, 1.0]:
		for row in 4:
			for col in 2:
				var x: float = side * (4.2 + col * 2.6)
				var z := -6.0 - row * 5.0
				Kit.console(self, Vector3(x, PIT, z), PI, Look.screen_blue if (row + col) % 2 == 0 else Look.screen_amber)
				Kit.block(self, Vector3(0.5, 0.5, 0.5), Vector3(x, PIT + 0.25, z + 1.0), Look.undersuit)   # seat
		Kit.strip(self, Vector3(0.06, 0.04, 30.0), Vector3(side * 2.62, -0.25, -12.0), Look.strip_blue)


func _viewports() -> void:
	# Tall forward windows: mullions, a sill and glass, with an invisible barrier.
	var bottom := PIT
	var height := TOP - PIT
	Kit.block(self, Vector3(20.0, 0.8, 1.2), Vector3(0, bottom + 0.4, FRONT + 0.6), Look.hull_dark)
	for i in 9:
		var x := -10.0 + i * 2.5
		Kit.block(self, Vector3(0.35, height, 0.6), Vector3(x, bottom + height / 2.0, FRONT), Look.hull_dark)
	Kit.block(self, Vector3(20.0, 0.4, 0.6), Vector3(0, 3.6, FRONT), Look.hull_dark, false)
	var glass := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(20.0, height)
	glass.mesh = quad
	glass.material_override = Look.glass
	glass.position = Vector3(0, bottom + height / 2.0, FRONT - 0.1)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glass)
	Kit.barrier(self, Vector3(20.0, height, 0.4), Vector3(0, bottom + height / 2.0, FRONT - 0.3))
	# Outer hull visible beyond the window: the ship's prow sloping away.
	Kit.block(self, Vector3(60.0, 2.0, 120.0), Vector3(0, PIT - 6.0, FRONT - 60.0), Look.hull, false, Vector3(deg_to_rad(-4), 0, 0))
	Kit.block(self, Vector3(4.0, 1.0, 110.0), Vector3(0, PIT - 4.6, FRONT - 60.0), Look.trim_red, false, Vector3(deg_to_rad(-4), 0, 0))


func _holotable() -> void:
	var c := Vector3(0, 0, FRONT + 6.0)
	Kit.cylinder(self, 1.6, 0.9, c + Vector3(0, 0.45, 0), Look.hull_dark)
	Kit.cylinder(self, 1.45, 0.05, c + Vector3(0, 0.92, 0), Look.screen_blue, false, 32)
	_holo = Node3D.new()
	_holo.position = c + Vector3(0, 1.9, 0)
	add_child(_holo)
	var globe := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.75
	sphere.height = 1.5
	sphere.radial_segments = 16
	sphere.rings = 8
	globe.mesh = sphere
	globe.material_override = Look.hologram
	globe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_holo.add_child(globe)
	for i in 3:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.95 + i * 0.12
		torus.outer_radius = 1.0 + i * 0.12
		ring.mesh = torus
		ring.material_override = Look.hologram
		ring.rotation = Vector3(deg_to_rad(20 + i * 25), deg_to_rad(i * 60), 0)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_holo.add_child(ring)
	var l := Kit.omni(self, c + Vector3(0, 1.8, 0), Color(0.4, 0.7, 1.0), 2.0, 7.0)
	l.shadow_enabled = false


func _lift_alcove() -> void:
	for side in [-1.0, 1.0]:
		Kit.block(self, Vector3(0.5, 4.0, 3.5), Vector3(side * 1.75, 2.0, BACK + 1.75), Look.hull_dark)
	Kit.block(self, Vector3(4.0, 0.4, 3.5), Vector3(0, -0.2, BACK + 1.75), Look.floor_mat)
	Kit.block(self, Vector3(4.0, 0.4, 3.5), Vector3(0, 4.2, BACK + 1.75), Look.hull_dark)
	Kit.block(self, Vector3(4.0, 4.0, 0.5), Vector3(0, 2.0, BACK + 3.75), Look.hull)
	Kit.strip(self, Vector3(2.2, 3.2, 0.06), Vector3(0, 1.8, BACK + 3.48), Look.screen_blue)
	Kit.omni(self, Vector3(0, 3.0, BACK + 1.5), Look.STRIP_BLUE, 1.5, 5.0)


func _lights() -> void:
	for z in [-26.0, -16.0, -6.0, 2.0]:
		Kit.omni(self, Vector3(0, TOP - 0.8, z), Color(1.0, 0.95, 0.88), 1.4, 10.0)
		for side in [-1.0, 1.0]:
			Kit.omni(self, Vector3(side * 6.5, 0.8, z), Color(0.45, 0.65, 1.0), 0.9, 6.0)
