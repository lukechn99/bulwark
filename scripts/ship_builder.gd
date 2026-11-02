class_name ShipBuilder
extends RefCounted
## Builds smooth, sculpted meshes for ships and hulls in code.
##
## The core tool is the loft: a series of cross-section rings joined into a
## skin, the way a boat hull is built from frames. Fuselages, wings, fins and
## capital-ship hulls are all lofts. Everything added is merged into one
## ArrayMesh with one surface per material, so a whole ship is a single draw
## per material.

## Flip if faces ever render inside-out (Godot treats clockwise as front).
const CLOCKWISE_FRONT := true

var collect_faces := false
var faces := PackedVector3Array()
var _parts := {}   # Material -> [verts, normals, tangents, uvs, indices]


# --- rings --------------------------------------------------------------------

## A superellipse ring: p = 2 is an ellipse, higher p is a rounded rectangle,
## p = 1 is a diamond. `right` and `up` set the ring's plane.
static func ring(center: Vector3, rx: float, ry: float, n := 16, p := 2.0,
		right := Vector3.RIGHT, up := Vector3.UP) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var e := 2.0 / p
	for i in n:
		var a := TAU * i / n
		var c := cos(a)
		var s := sin(a)
		var x := rx * signf(c) * pow(absf(c), e)
		var y := ry * signf(s) * pow(absf(s), e)
		pts.append(center + right * x + up * y)
	return pts


## A fuselage-style section across the Z axis at depth `z`.
static func zring(z: float, cy: float, rx: float, ry: float, p := 2.0, n := 16, cx := 0.0) -> PackedVector3Array:
	return ring(Vector3(cx, cy, z), rx, ry, n, p)


## A wing section at span position `x` (local X), chord along Z.
static func xring(x: float, cy: float, cz: float, half_chord: float, half_thick: float, n := 10, p := 3.0) -> PackedVector3Array:
	return ring(Vector3(x, cy, cz), half_chord, half_thick, n, p, Vector3.BACK, Vector3.UP)


## A fin section at height `y`, chord along Z, thickness along X.
static func yring(y: float, cx: float, cz: float, half_chord: float, half_thick: float, n := 10, p := 3.0) -> PackedVector3Array:
	return ring(Vector3(cx, y, cz), half_chord, half_thick, n, p, Vector3.BACK, Vector3.RIGHT)


# --- shapes -------------------------------------------------------------------

## Skin a list of rings (all the same point count). `edge_mats` maps a ring
## edge index (point i to i+1) to a different material, for stripes and trim.
func loft(rings: Array, mat: Material, smooth := true, cap_start := true, cap_end := true,
		edge_mats := {}, xform := Transform3D.IDENTITY) -> void:
	var n: int = (rings[0] as PackedVector3Array).size()
	var count := rings.size()
	# Work out which winding faces outward, from the first two rings.
	var c0 := _centroid(rings[0])
	var c1 := _centroid(rings[1])
	var a0: Vector3 = rings[0][0]
	var a1: Vector3 = rings[0][1]
	var outward_ccw := (a1 - a0).cross(c1 - c0).dot(a0 - c0) > 0.0
	var reverse := outward_ccw == CLOCKWISE_FRONT
	var tools := {}
	for r in count - 1:
		var ra: PackedVector3Array = rings[r]
		var rb: PackedVector3Array = rings[r + 1]
		for i in n:
			var j := (i + 1) % n
			var m: Material = edge_mats.get(i, mat)
			var st: SurfaceTool = tools.get(m)
			if not st:
				st = SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[m] = st
			var g := 0 if smooth else -1
			var u0 := float(i) / n
			var u1 := float(i + 1) / n
			var v0 := float(r) / count
			var v1 := float(r + 1) / count
			var quad := [[ra[i], Vector2(u0, v0)], [ra[j], Vector2(u1, v0)], [rb[i], Vector2(u0, v1)], [rb[j], Vector2(u1, v1)]]
			var tris := [[0, 2, 1], [1, 2, 3]] if reverse else [[0, 1, 2], [1, 3, 2]]
			for t in tris:
				for k in t:
					st.set_smooth_group(g)
					st.set_uv(quad[k][1])
					st.add_vertex(quad[k][0])
	if cap_start:
		_cap(tools, mat, rings[0], c0 - c1, not reverse)
	if cap_end:
		_cap(tools, mat, rings[count - 1], c1 - c0, reverse)
	for m in tools:
		var st: SurfaceTool = tools[m]
		st.generate_normals()
		st.generate_tangents()
		add_arrays(st.commit_to_arrays(), m, xform)


func _cap(tools: Dictionary, mat: Material, r: PackedVector3Array, _out: Vector3, reverse: bool) -> void:
	var st: SurfaceTool = tools.get(mat)
	if not st:
		st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools[mat] = st
	var c := _centroid(r)
	var n := r.size()
	for i in n:
		var j := (i + 1) % n
		var tri := [c, r[j], r[i]] if reverse else [c, r[i], r[j]]
		for p in tri:
			st.set_smooth_group(-1)
			st.set_uv(Vector2.ZERO)
			st.add_vertex(p)


static func _centroid(r: PackedVector3Array) -> Vector3:
	var c := Vector3.ZERO
	for p in r:
		c += p
	return c / r.size()


func box(size: Vector3, center: Vector3, mat: Material, rot := Vector3.ZERO) -> void:
	var m := BoxMesh.new()
	m.size = size
	add_arrays(m.get_mesh_arrays(), mat, Transform3D(Basis.from_euler(rot), center))


func sphere(radius: float, center: Vector3, mat: Material, scale := Vector3.ONE, rot := Vector3.ZERO, segs := 20) -> void:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = segs
	m.rings = segs / 2
	add_arrays(m.get_mesh_arrays(), mat, Transform3D(Basis.from_euler(rot).scaled(scale), center))


## A cylinder lying along `axis` (X, Y or Z), optionally tapered.
func tube(r_start: float, r_end: float, length: float, center: Vector3, mat: Material, axis := Vector3.FORWARD, sides := 16) -> void:
	var m := CylinderMesh.new()
	m.top_radius = r_end
	m.bottom_radius = r_start
	m.height = length
	m.radial_segments = sides
	m.rings = 1
	var basis := Basis.IDENTITY
	if axis.abs().is_equal_approx(Vector3.FORWARD):
		basis = Basis(Vector3.RIGHT, -PI / 2.0 if axis.z < 0 else PI / 2.0)
	elif axis.abs().is_equal_approx(Vector3.RIGHT):
		basis = Basis(Vector3.BACK, -PI / 2.0 if axis.x > 0 else PI / 2.0)
	add_arrays(m.get_mesh_arrays(), mat, Transform3D(basis, center))


# --- merging ------------------------------------------------------------------

func add_arrays(arrays: Array, mat: Material, xform := Transform3D.IDENTITY) -> void:
	if not _parts.has(mat):
		_parts[mat] = [PackedVector3Array(), PackedVector3Array(), PackedFloat32Array(), PackedVector2Array(), PackedInt32Array()]
	var part: Array = _parts[mat]
	var verts: PackedVector3Array = part[0]
	var norms: PackedVector3Array = part[1]
	var tans: PackedFloat32Array = part[2]
	var uvs: PackedVector2Array = part[3]
	var idx: PackedInt32Array = part[4]
	var base := verts.size()
	var src_v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var src_n = arrays[Mesh.ARRAY_NORMAL]
	var src_t = arrays[Mesh.ARRAY_TANGENT]
	var src_uv = arrays[Mesh.ARRAY_TEX_UV]
	var src_i = arrays[Mesh.ARRAY_INDEX]
	var nb := xform.basis.inverse().transposed()
	for k in src_v.size():
		verts.append(xform * src_v[k])
		norms.append((nb * (src_n[k] if src_n != null else Vector3.UP)).normalized())
		if src_t != null and (src_t as PackedFloat32Array).size() >= (k + 1) * 4:
			var t := (xform.basis * Vector3(src_t[k * 4], src_t[k * 4 + 1], src_t[k * 4 + 2])).normalized()
			tans.append_array(PackedFloat32Array([t.x, t.y, t.z, src_t[k * 4 + 3]]))
		else:
			tans.append_array(PackedFloat32Array([1.0, 0.0, 0.0, 1.0]))
		uvs.append(src_uv[k] if src_uv != null and (src_uv as PackedVector2Array).size() > k else Vector2.ZERO)
	var tri := PackedInt32Array()
	if src_i != null and (src_i as PackedInt32Array).size() > 0:
		tri = src_i
	else:
		for k in src_v.size():
			tri.append(k)
	for j in tri:
		idx.append(base + j)
	if collect_faces:
		for j in tri:
			faces.append(xform * src_v[j])
	_parts[mat] = [verts, norms, tans, uvs, idx]


func commit() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for mat in _parts:
		var part: Array = _parts[mat]
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = part[0]
		arr[Mesh.ARRAY_NORMAL] = part[1]
		arr[Mesh.ARRAY_TANGENT] = part[2]
		arr[Mesh.ARRAY_TEX_UV] = part[3]
		arr[Mesh.ARRAY_INDEX] = part[4]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
	return mesh


## Static collision matching everything added (needs collect_faces = true).
func collision_body() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Kit.WORLD_LAYER
	body.collision_mask = 0
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	return body
