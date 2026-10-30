class_name Kit
extends RefCounted
## The modular kit: every wall, floor, rib, crate and console in the ship is built
## from these few functions, so swapping greybox boxes for authored meshes later
## means changing one function, not every zone.

const WORLD_LAYER := 1


static var _batch_root: Node3D = null
static var _pending: Array = []


## Start batching: static pieces built under `root` until end() are merged into
## a few meshes per material, grouped by floor cell. The Compatibility renderer
## draws each object once per light touching it, so hundreds of separate boxes
## would be far too slow in a browser.
static func begin(root: Node3D) -> void:
	_batch_root = root
	_pending = []


static func end(cell := 12.0) -> void:
	var root := _batch_root
	_batch_root = null
	var tools := {}
	var mats := {}
	var shadows := {}
	for e in _pending:
		var node: Node3D = e[0]
		var xf := _relative(node, root)
		var key := "%d|%d|%d|%s" % [e[2].get_instance_id(), floori(xf.origin.x / cell), floori(xf.origin.z / cell), e[3]]
		if not tools.has(key):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[key] = st
			mats[key] = e[2]
			shadows[key] = e[3]
		(tools[key] as SurfaceTool).append_from(e[1], 0, xf)
		if node.get_child_count() == 0:
			node.queue_free()
	for key in tools:
		var mi := MeshInstance3D.new()
		mi.mesh = (tools[key] as SurfaceTool).commit()
		mi.material_override = mats[key]
		if not shadows[key]:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	_pending = []


static func _relative(node: Node3D, root: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = node
	while cur and cur != root:
		xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


static func _batching(parent: Node) -> bool:
	if not _batch_root:
		return false
	var cur := parent
	while cur:
		if cur == _batch_root:
			return true
		cur = cur.get_parent()
	return false


## The visual half of a piece: deferred into the batch when batching, otherwise
## a MeshInstance3D (moving things such as doors, drones and the player).
static func _visual(parent: Node3D, mesh: Mesh, mat: Material, center: Vector3, rot: Vector3, shadow: bool) -> Node3D:
	if _batching(parent):
		var n := Node3D.new()
		n.position = center
		n.rotation = rot
		parent.add_child(n)
		_pending.append([n, mesh, mat, shadow])
		return n
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = center
	mi.rotation = rot
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _collider(owner: Node3D, shape_res: Shape3D) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = shape_res
	body.add_child(shape)
	owner.add_child(body)


## A box with collision. `center` is local to `parent`.
static func block(parent: Node3D, size: Vector3, center: Vector3, mat: Material, collide := true, rot := Vector3.ZERO, shadow := true) -> Node3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var n := _visual(parent, mesh, mat, center, rot, shadow)
	if collide:
		var box := BoxShape3D.new()
		box.size = size
		_collider(n, box)
	return n


## Glowing trim with no collision and no shadow.
static func strip(parent: Node3D, size: Vector3, center: Vector3, mat: Material) -> Node3D:
	return block(parent, size, center, mat, false, Vector3.ZERO, false)


static func cylinder(parent: Node3D, radius: float, height: float, center: Vector3, mat: Material, collide := true, sides := 24) -> Node3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	var n := _visual(parent, mesh, mat, center, Vector3.ZERO, true)
	if collide:
		var cyl := CylinderShape3D.new()
		cyl.radius = radius
		cyl.height = height
		_collider(n, cyl)
	return n


## An invisible wall.
## Layer 5: ray shields. People bump into them; ships fly through.
const SHIELD_LAYER := 16


static func barrier(parent: Node3D, size: Vector3, center: Vector3, layer := WORLD_LAYER) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = center
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)


static func omni(parent: Node3D, pos: Vector3, color: Color, energy: float, light_range: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	l.omni_attenuation = 1.4
	l.light_specular = 0.6
	parent.add_child(l)
	return l


static func spot(parent: Node3D, pos: Vector3, color: Color, energy: float, light_range: float, angle: float) -> SpotLight3D:
	var l := SpotLight3D.new()
	l.position = pos
	l.rotation_degrees = Vector3(-90, 0, 0)
	l.light_color = color
	l.light_energy = energy
	l.spot_range = light_range
	l.spot_angle = angle
	l.spot_attenuation = 0.8
	parent.add_child(l)
	return l


## One section of a ribbed corridor running along X from `x0` toward -X.
## Walls at z = ±half_width; the floor's top surface is at y = 0.
static func corridor_segment(parent: Node3D, x0: float, length: float, half_width := 2.0, height := 4.0, light := true) -> void:
	var cx := x0 - length / 2.0
	var w := half_width * 2.0
	# Shell: floor, centre grate, ceiling, walls.
	block(parent, Vector3(length, 0.3, w + 1.0), Vector3(cx, -0.15, 0), Look.floor_mat)
	strip(parent, Vector3(length, 0.02, 1.0), Vector3(cx, 0.005, 0), Look.grate)
	block(parent, Vector3(length, 0.3, w + 1.0), Vector3(cx, height + 0.15, 0), Look.hull_dark)
	for side in [-1.0, 1.0]:
		var z: float = side * (half_width + 0.25)
		block(parent, Vector3(length, height, 0.5), Vector3(cx, height / 2.0, z), Look.hull)
		# Lower dark band, red waist stripe and a recessed light line along the floor.
		block(parent, Vector3(length, 0.7, 0.1), Vector3(cx, 0.35, side * (half_width - 0.05)), Look.hull_dark, false)
		block(parent, Vector3(length, 0.16, 0.06), Vector3(cx, 1.15, side * (half_width - 0.03)), Look.trim_red, false)
		strip(parent, Vector3(length, 0.04, 0.04), Vector3(cx, 0.72, side * (half_width - 0.12)), Look.strip_blue)
		# Angled upper wall panels: the trapezoid profile of capital-ship corridors.
		block(parent, Vector3(length, 1.3, 0.3), Vector3(cx, height - 0.55, side * (half_width - 0.3)),
			Look.hull, false, Vector3(side * deg_to_rad(-35.0), 0, 0))
	# Ribs every 2 m: wall pilasters joined by a ceiling beam.
	var ribs := int(length / 2.0)
	for i in ribs:
		var x := x0 - 1.0 - i * 2.0
		for side in [-1.0, 1.0]:
			block(parent, Vector3(0.35, height, 0.35), Vector3(x, height / 2.0, side * (half_width - 0.12)), Look.hull_dark)
			strip(parent, Vector3(0.08, 1.6, 0.04), Vector3(x, 2.2, side * (half_width - 0.31)), Look.strip_warm)
		block(parent, Vector3(0.35, 0.35, w), Vector3(x, height - 0.2, 0), Look.hull_dark, false)
	# Ceiling light panel running the length of the segment.
	strip(parent, Vector3(length - 0.4, 0.05, 0.6), Vector3(cx, height - 0.03, 0), Look.strip_warm)
	if light:
		omni(parent, Vector3(cx, height - 0.6, 0), Color(1.0, 0.95, 0.88), 1.6, length * 0.9)


## A cargo crate with reinforced edges.
static func crate(parent: Node3D, center: Vector3, size := Vector3(1.4, 1.2, 1.4), yaw := 0.0) -> Node3D:
	var root := Node3D.new()
	root.position = center
	root.rotation.y = yaw
	parent.add_child(root)
	block(root, size, Vector3.ZERO, Look.hull_dark)
	for y in [-1.0, 1.0]:
		block(root, Vector3(size.x + 0.04, 0.12, size.z + 0.04), Vector3(0, y * (size.y / 2.0 - 0.06), 0), Look.metal, false)
	block(root, Vector3(size.x * 0.5, size.y * 0.3, size.z + 0.03), Vector3(0, 0, 0), Look.trim_red, false)
	return root


## A wall console with glowing screens. Faces +Z before rotation.
static func console(parent: Node3D, pos: Vector3, yaw: float, screen: Material = null) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	parent.add_child(root)
	var s := screen if screen else Look.screen_blue
	block(root, Vector3(1.6, 1.0, 0.7), Vector3(0, 0.5, 0), Look.hull_dark)
	block(root, Vector3(1.6, 0.1, 0.8), Vector3(0, 1.0, 0.05), Look.metal, false, Vector3(deg_to_rad(-20), 0, 0))
	var tilt := Vector3(deg_to_rad(-20), 0, 0)
	block(root, Vector3(0.6, 0.03, 0.35), Vector3(-0.35, 1.06, 0.05), s, false, tilt)
	block(root, Vector3(0.6, 0.03, 0.35), Vector3(0.38, 1.06, 0.05), Look.screen_amber, false, tilt)
	return root


## Railing between two points at floor height `from.y`.
static func railing(parent: Node3D, from: Vector3, to: Vector3) -> void:
	var mid := (from + to) / 2.0
	var length := from.distance_to(to)
	var yaw := atan2(-(to.z - from.z), to.x - from.x)
	block(parent, Vector3(length, 0.08, 0.08), mid + Vector3(0, 1.05, 0), Look.metal, false, Vector3(0, yaw, 0))
	block(parent, Vector3(length, 0.9, 0.04), mid + Vector3(0, 0.55, 0), Look.glass, true, Vector3(0, yaw, 0))
	var posts := maxi(2, int(length / 2.0) + 1)
	for i in posts:
		var p := from.lerp(to, float(i) / float(posts - 1))
		block(parent, Vector3(0.08, 1.1, 0.08), p + Vector3(0, 0.55, 0), Look.metal, false)


## An original light starfighter: a central fuselage pod with swept wings.
static func starfighter(parent: Node3D, pos: Vector3, yaw: float, accent: Material = null) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	parent.add_child(root)
	var a := accent if accent else Look.trim_red
	# Landing struts.
	for p in [Vector3(-1.2, 0.5, 1.2), Vector3(1.2, 0.5, 1.2), Vector3(0, 0.5, -2.0)]:
		block(root, Vector3(0.18, 1.0, 0.18), p, Look.metal, false)
	block(root, Vector3(2.0, 1.4, 6.0), Vector3(0, 1.8, 0), Look.hull)  # fuselage
	block(root, Vector3(1.4, 0.9, 2.2), Vector3(0, 1.7, -3.9), Look.hull, true, Vector3(deg_to_rad(8), 0, 0))  # nose
	block(root, Vector3(1.3, 0.55, 1.8), Vector3(0, 2.65, -1.2), Look.glass, false)  # canopy
	block(root, Vector3(1.32, 0.12, 1.84), Vector3(0, 2.95, -1.2), Look.hull_dark, false)
	for side in [-1.0, 1.0]:
		block(root, Vector3(4.2, 0.18, 3.0), Vector3(side * 2.9, 1.9, 1.0), Look.hull, true, Vector3(0, side * deg_to_rad(18), side * deg_to_rad(-6)))
		block(root, Vector3(2.4, 0.2, 0.5), Vector3(side * 3.3, 1.95, 0.0), a, false, Vector3(0, side * deg_to_rad(18), side * deg_to_rad(-6)))
		block(root, Vector3(0.25, 0.25, 2.2), Vector3(side * 4.8, 1.75, -0.4), Look.metal, false)  # wingtip cannon
	var engine := cylinder(root, 0.55, 0.3, Vector3(0, 1.8, 3.1), Look.engine_glow, false)
	engine.rotation.x = deg_to_rad(90)
	return root
