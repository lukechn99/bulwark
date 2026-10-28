class_name Fx
extends RefCounted
## Short-lived effects: muzzle flashes, bolt impacts and explosions. Each is a
## glowing mesh plus a brief light, tweened and freed.


static func muzzle_flash(parent: Node, pos: Vector3, color: Color) -> void:
	_burst(parent, pos, color, 0.12, 0.25, 0.06, 1.5, 3.0)


static func impact(parent: Node, pos: Vector3, normal: Vector3, color: Color) -> void:
	_burst(parent, pos + normal * 0.05, color, 0.08, 0.35, 0.18, 2.0, 4.0)


static func explosion(parent: Node, pos: Vector3) -> void:
	_burst(parent, pos, Color(4.0, 1.6, 0.5), 0.3, 2.2, 0.55, 6.0, 12.0)
	_burst(parent, pos, Color(2.5, 2.2, 2.0), 0.2, 1.0, 0.25, 0.0, 0.0)


static func _burst(parent: Node, pos: Vector3, color: Color, r0: float, r1: float, time: float, light_energy: float, light_range: float) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = pos
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = color
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 12
	sphere.rings = 6
	mi.mesh = sphere
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3.ONE * r0 * 2.0
	root.add_child(mi)
	var tw := root.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * r1 * 2.0, time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mat, "albedo_color:a", 0.0, time)
	if light_energy > 0.0:
		var l := OmniLight3D.new()
		var peak := maxf(color.r, maxf(color.g, color.b))
		l.light_color = Color(color.r / peak, color.g / peak, color.b / peak)
		l.light_energy = light_energy
		l.omni_range = light_range
		root.add_child(l)
		tw.tween_property(l, "light_energy", 0.0, time)
	tw.chain().tween_callback(root.queue_free)
