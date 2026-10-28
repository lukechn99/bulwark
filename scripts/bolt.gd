class_name Bolt
extends Node3D
## A blaster bolt: a bright streak that sweeps a ray each physics frame, so fast
## bolts never tunnel through thin walls.

const SPEED := 85.0
const LIFETIME := 2.5

var velocity := Vector3.ZERO
var shooter: Node3D
var damage := 10.0
var color := Color.WHITE
var _age := 0.0
var _exclude: Array[RID] = []


static func fire(parent: Node, from: Vector3, dir: Vector3, by: Node3D, mat: StandardMaterial3D, dmg: float) -> Bolt:
	var b := Bolt.new()
	b.shooter = by
	b.damage = dmg
	b.velocity = dir * SPEED
	b.color = mat.albedo_color
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.035
	capsule.height = 1.1
	capsule.radial_segments = 6
	capsule.rings = 2
	mesh.mesh = capsule
	mesh.material_override = mat
	mesh.rotation.x = deg_to_rad(90)   # capsule is Y-up; lay it along -Z
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.add_child(mesh)
	parent.add_child(b)
	b.global_position = from
	b.look_at(from + dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT)
	if by is CollisionObject3D:
		b._exclude.append((by as CollisionObject3D).get_rid())
	Fx.muzzle_flash(parent, from, b.color)
	return b


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > LIFETIME:
		queue_free()
		return
	var from := global_position
	var to := from + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to, 0b111)
	query.exclude = _exclude
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		var target: Object = hit.collider
		# Kit pieces put collision on a child body; damageable things are the body itself.
		if target and target.has_method("take_damage"):
			var killed: bool = target.take_damage(damage, from)
			if is_instance_valid(shooter) and shooter.has_method("on_hit_target"):
				shooter.on_hit_target(killed)
		Fx.impact(get_parent(), hit.position, hit.normal, color)
		queue_free()
		return
	global_position = to
