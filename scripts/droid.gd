class_name SentryDrone
extends CharacterBody3D
## An original hovering sentry drone. It scans while idle; when it sees the
## player it turns, drifts sideways and fires short bursts.

const SIGHT := 34.0
const HOVER := 1.7
const MAX_HEALTH := 40.0

var health := MAX_HEALTH
var _home: Vector3
var _t := 0.0
var _burst_left := 0
var _cooldown := 1.5
var _strafe := 1.0
var _body: Node3D
var _eye_light: OmniLight3D
var _eye: MeshInstance3D
var _flash := 0.0
var _alert := false


static func spawn(parent: Node3D, pos: Vector3) -> SentryDrone:
	var d := SentryDrone.new()
	d.position = pos
	parent.add_child(d)
	return d


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	_home = global_position
	_t = randf() * TAU
	_strafe = 1.0 if randf() < 0.5 else -1.0
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.55
	shape.shape = sphere
	add_child(shape)
	_body = Node3D.new()
	add_child(_body)
	var shell := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.45
	sm.height = 0.9
	shell.mesh = sm
	shell.material_override = Look.drone_shell
	_body.add_child(shell)
	var band := Kit.cylinder(_body, 0.5, 0.14, Vector3.ZERO, Look.metal, false)
	band.scale = Vector3(1, 1, 1)
	_eye = MeshInstance3D.new()
	var em := SphereMesh.new()
	em.radius = 0.11
	em.height = 0.22
	_eye.mesh = em
	_eye.material_override = Look.drone_eye
	_eye.position = Vector3(0, 0.08, -0.42)
	_body.add_child(_eye)
	Kit.block(_body, Vector3(0.22, 0.04, 0.06), Vector3(0, 0.2, -0.38), Look.hull_dark, false)
	for side in [-1.0, 1.0]:
		Kit.block(_body, Vector3(0.14, 0.16, 0.5), Vector3(side * 0.55, -0.05, -0.05), Look.hull_dark, false)
		Kit.block(_body, Vector3(0.05, 0.05, 0.3), Vector3(side * 0.55, -0.05, -0.42), Look.metal, false)
		Kit.block(_body, Vector3(0.03, 0.4, 0.03), Vector3(side * 0.14, 0.55, 0.12), Look.metal, false)
	Kit.cylinder(_body, 0.18, 0.06, Vector3(0, -0.45, 0), Look.strip_red, false)
	_eye_light = OmniLight3D.new()
	_eye_light.light_color = Color(1.0, 0.25, 0.15)
	_eye_light.light_energy = 0.8
	_eye_light.omni_range = 3.0
	_eye_light.position = Vector3(0, 0, -0.6)
	_body.add_child(_eye_light)


func _physics_process(delta: float) -> void:
	_t += delta
	var player := Zones.player as Node3D
	var desired := Vector3.ZERO
	_alert = false
	if player:
		var chest := player.global_position + Vector3(0, 1.2, 0)
		var to_player := chest - global_position
		if Player.is_playing() and to_player.length() < SIGHT and _can_see(chest):
			_alert = true
			var yaw := atan2(-to_player.x, -to_player.z)
			rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-6.0 * delta))
			var right := global_transform.basis.x
			desired = right * _strafe * 1.6
			if randf() < delta * 0.4:
				_strafe = -_strafe
			_shoot(delta, chest)
	if not _alert:
		rotation.y += delta * 0.5
		desired = (_home - global_position) * Vector3(1, 0, 1)
	# Hover at a bobbing height above home.
	var target_y := _home.y + sin(_t * 1.7) * 0.2
	desired.y = (target_y - global_position.y) * 3.0
	velocity = velocity.lerp(desired, 1.0 - exp(-3.0 * delta))
	move_and_slide()
	if is_on_wall():
		_strafe = -_strafe
	_body.rotation.z = lerpf(_body.rotation.z, -velocity.dot(global_transform.basis.x) * 0.12, 0.1)
	_flash = maxf(0.0, _flash - delta * 6.0)
	_eye_light.light_energy = (1.8 if _alert else 0.8) + _flash * 4.0


func _can_see(point: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position, point, 0b011)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit and hit.collider is Player


func _shoot(delta: float, at: Vector3) -> void:
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var muzzle := _eye.global_position - global_transform.basis.z * 0.2
	var spread := 0.05
	var dir := (at - muzzle).normalized()
	dir = (dir + Vector3(randf_range(-spread, spread), randf_range(-spread, spread) * 0.5, randf_range(-spread, spread))).normalized()
	Bolt.fire(get_parent(), muzzle, dir, self, Look.bolt_red, 7.0)
	_flash = 1.0
	if _burst_left <= 0:
		_burst_left = 2
		_cooldown = randf_range(1.4, 2.2)
	else:
		_burst_left -= 1
		_cooldown = 0.16


func take_damage(amount: float, _from: Vector3) -> bool:
	if health <= 0.0:
		return false
	health -= amount
	_flash = 1.5
	_strafe = -_strafe
	if health <= 0.0:
		Fx.explosion(get_parent(), global_position)
		queue_free()
		return true
	return false
