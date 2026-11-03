extends Node3D
## The planet surface: a green basin ringed by mountains, with a forward
## outpost (landing pad, domes, a comms mast and a supply shed) held by
## enemy droids. You arrive by flying into the planet's atmosphere and leave by
## climbing back out of it.
##
## Built around its own origin, which sits at Zones.PLANET_ORIGIN. The outpost
## is at the centre; the terrain spans ±SIZE/2.

const SIZE := 3200.0
const GRID := 128
const PAD_RADIUS := 42.0

var _noise := FastNoiseLite.new()
var _ridges := FastNoiseLite.new()


func _ready() -> void:
	position = Zones.PLANET_ORIGIN
	_noise.seed = 21
	_noise.frequency = 0.0011
	_noise.fractal_octaves = 5
	_ridges.seed = 5
	_ridges.frequency = 0.0006
	_ridges.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_ridges.fractal_octaves = 3
	_terrain()
	_trees()
	Kit.begin(self)
	_outpost()
	Kit.end(40.0)
	AssaultDroid.spawn_squad(self, Vector3(70, height(70, 40) + 0.2, 40), 4, "outpost-a", deg_to_rad(-120))
	AssaultDroid.spawn_squad(self, Vector3(-60, height(-60, 70) + 0.2, 70), 3, "outpost-b", deg_to_rad(150))
	SentryDrone.spawn(self, Vector3(10, 14, 80))
	SentryDrone.spawn(self, Vector3(-80, 12, -30))
	var spawn := Marker3D.new()
	spawn.name = "Spawn"
	spawn.position = Vector3(0, 1.1, 30)
	add_child(spawn)


## Ground height at (x, z), local metres. Flat at the outpost, rolling hills
## across the basin, mountains around the rim.
func height(x: float, z: float) -> float:
	var r := Vector2(x, z).length()
	var h := _noise.get_noise_2d(x, z) * 70.0 + 20.0
	h += maxf(0.0, _ridges.get_noise_2d(x, z)) * 220.0 * smoothstep(300.0, 900.0, r)
	h += smoothstep(900.0, 1550.0, r) * 420.0
	# Level the outpost site and blend out to the hills.
	return lerpf(0.0, h, smoothstep(PAD_RADIUS + 70.0, PAD_RADIUS + 260.0, r))


func _terrain() -> void:
	var step := SIZE / GRID
	var half := SIZE / 2.0
	var heights := PackedFloat32Array()
	heights.resize((GRID + 1) * (GRID + 1))
	for j in GRID + 1:
		for i in GRID + 1:
			heights[j * (GRID + 1) + i] = height(-half + i * step, -half + j * step)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	var P := func(i: int, j: int) -> Vector3:
		return Vector3(-half + i * step, heights[j * (GRID + 1) + i], -half + j * step)
	for j in GRID:
		for i in GRID:
			var a: Vector3 = P.call(i, j)
			var b: Vector3 = P.call(i + 1, j)
			var c: Vector3 = P.call(i, j + 1)
			var d: Vector3 = P.call(i + 1, j + 1)
			for v in [a, b, c, b, d, c]:
				st.set_color(_ground_color(v))
				st.set_uv(Vector2(v.x, v.z) * 0.02)
				st.add_vertex(v)
				faces.append(v)
	st.generate_normals()
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = Look.terrain
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	add_child(ShipBuilder.body_from_faces(faces))


func _ground_color(v: Vector3) -> Color:
	var grass := Color(0.32, 0.46, 0.2)
	var dry := Color(0.55, 0.52, 0.32)
	var rock := Color(0.45, 0.42, 0.38)
	var snow := Color(0.92, 0.93, 0.96)
	var c := grass.lerp(dry, clampf(_noise.get_noise_2d(v.z, v.x) * 1.5 + 0.3, 0.0, 1.0) * 0.6)
	c = c.lerp(rock, smoothstep(120.0, 260.0, v.y))
	return c.lerp(snow, smoothstep(430.0, 540.0, v.y))


## Low-poly pines scattered over the grassland, drawn in one batch.
func _trees() -> void:
	var b := ShipBuilder.new()
	b.tube(0.5, 0.35, 4.0, Vector3(0, 2.0, 0), Look.tree_bark, Vector3.UP, 6)
	for k in 3:
		var y := 4.0 + k * 3.2
		b.tube(3.6 - k * 0.9, 0.2, 5.0, Vector3(0, y + 2.0, 0), Look.tree_leaves, Vector3.UP, 7)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = b.commit()
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	var spots: Array[Transform3D] = []
	for n in 6000:
		if spots.size() >= 900:
			break
		var x := rng.randf_range(-1400.0, 1400.0)
		var z := rng.randf_range(-1400.0, 1400.0)
		if Vector2(x, z).length() < PAD_RADIUS + 120.0:
			continue
		var h := height(x, z)
		if h > 170.0:
			continue
		var s := rng.randf_range(0.8, 1.6)
		spots.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(x, h - 0.3, z)))
	mm.instance_count = spots.size()
	for k in spots.size():
		mm.set_instance_transform(k, spots[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _outpost() -> void:
	# Landing pad: a raised disc with a lit ring and guide lines.
	Kit.cylinder(self, PAD_RADIUS, 1.0, Vector3(0, 0.5, 0), Look.floor_mat, true, 48)
	Kit.cylinder(self, PAD_RADIUS + 1.0, 0.6, Vector3(0, 0.3, 0), Look.hull_dark, false, 48)
	for k in 24:
		var a := k * TAU / 24.0
		Kit.strip(self, Vector3(3.0, 0.05, 0.4), Vector3(cos(a), 0, sin(a)) * (PAD_RADIUS - 2.0) + Vector3(0, 1.02, 0), Look.strip_blue)
	for x in [-14.0, 14.0]:
		Kit.strip(self, Vector3(0.4, 0.04, 50.0), Vector3(x, 1.02, 0), Look.trim_red)
	# Domed habitats with lit doors.
	for d in [[Vector3(75, 0, 10), 14.0], [Vector3(60, 0, -45), 10.0], [Vector3(-70, 0, -20), 12.0]]:
		var c: Vector3 = d[0]
		var r: float = d[1]
		c.y = height(c.x, c.z)
		Kit.cylinder(self, r, 3.0, c + Vector3(0, 1.5, 0), Look.hull_dark, true, 32)
		var dome := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = r
		sm.height = r * 1.4
		sm.is_hemisphere = true
		sm.radial_segments = 32
		sm.rings = 12
		dome.mesh = sm
		dome.material_override = Look.ship_white
		dome.position = c + Vector3(0, 3.0, 0)
		add_child(dome)
		Kit.barrier(self, Vector3(r * 1.5, r * 0.6, r * 1.5), c + Vector3(0, 3.0 + r * 0.3, 0))
		var to_pad := -Vector3(c.x, 0, c.z).normalized()
		Kit.strip(self, Vector3(3.0, 2.6, 0.2), c + to_pad * (r + 0.05) + Vector3(0, 1.4, 0), Look.screen_blue)
		Kit.strip(self, Vector3(r * 2.04, 0.3, r * 2.04), c + Vector3(0, 3.0, 0), Look.trim_red)
	# Comms mast with a dish.
	var m := Vector3(-35, height(-35, 75), 75)
	Kit.cylinder(self, 1.2, 40.0, m + Vector3(0, 20, 0), Look.metal, true, 10)
	Kit.cylinder(self, 4.0, 1.0, m + Vector3(0, 40.5, 0), Look.hull_dark, false, 16)
	Kit.strip(self, Vector3(1.2, 1.2, 1.2), m + Vector3(0, 41.6, 0), Look.strip_red)
	var dish := Kit.cylinder(self, 6.0, 0.6, m + Vector3(2, 34, 0), Look.ship_white, false, 24)
	dish.rotation = Vector3(0, 0, deg_to_rad(60))
	# A supply shed open to the pad, with crates.
	var s := Vector3(0, 0, -78)
	Kit.block(self, Vector3(34, 1.0, 22), s + Vector3(0, -0.5, 0), Look.floor_mat)
	Kit.block(self, Vector3(34, 12, 1.0), s + Vector3(0, 6, -11), Look.hull)
	for x in [-17.0, 17.0]:
		Kit.block(self, Vector3(1.0, 12, 22), s + Vector3(x, 6, 0), Look.hull)
	Kit.block(self, Vector3(36, 1.2, 24), s + Vector3(0, 12.6, 0), Look.hull_dark)
	Kit.block(self, Vector3(36.2, 0.5, 0.6), s + Vector3(0, 12.0, 11.6), Look.trim_red, false)
	for c in [Vector3(-10, 0.6, -6), Vector3(-8.4, 0.6, -6.2), Vector3(9, 0.6, -5), Vector3(9, 1.8, -5), Vector3(4, 0.6, 3)]:
		Kit.crate(self, s + c, Vector3(1.4, 1.2, 1.4), randf() * 0.4)
	# Barricades around the pad edge.
	for k in 8:
		var a := k * TAU / 8.0 + 0.2
		var p := Vector3(cos(a), 0, sin(a)) * (PAD_RADIUS + 14.0)
		Kit.block(self, Vector3(6.0, 1.4, 1.0), p + Vector3(0, 0.7, 0), Look.hull_dark, true, Vector3(0, -a + PI / 2.0, 0))
