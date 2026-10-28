class_name AssaultDroid
extends CharacterBody3D
## Enemy infantry: an original combat droid. Reverse-jointed legs, a wedge
## chest, a low hammerhead sensor bar with twin orange eyes, and a blaster built
## into its right forearm.
##
## Droids fight in squads. Each squad shares a volley clock, so its members
## fire together in bursts; between volleys they close to firing range and
## sidestep.

const SIGHT := 42.0
const PREFERRED_RANGE := 15.0
const WALK := 2.6
const GRAVITY := 19.0
const MAX_HEALTH := 25.0

## squad -> {"next": msec, "id": int}
static var _volleys: Dictionary = {}

var squad := "default"
var health := MAX_HEALTH
var _hips: Array[Node3D] = []
var _knees: Array[Node3D] = []
var _gun_arm: Node3D
var _muzzle: Node3D
var _stride := randf() * TAU
var _seen_volley := -1
var _shots_left := 0
var _shot_timer := 0.0
var _strafe := 1.0
var _alert := false
var _dead := false
var _home: Vector3


static func spawn(parent: Node3D, pos: Vector3, squad_name: String, yaw := 0.0) -> AssaultDroid:
	var d := AssaultDroid.new()
	d.squad = squad_name
	d.position = pos
	d.rotation.y = yaw
	parent.add_child(d)
	return d


## A squad of `count` droids in a loose wedge around `center`, facing `yaw`.
static func spawn_squad(parent: Node3D, center: Vector3, count: int, squad_name: String, yaw := 0.0) -> void:
	var offsets := [Vector3(0, 0, 0), Vector3(-1.6, 0, 1.4), Vector3(1.6, 0, 1.4), Vector3(-3.2, 0, 2.8), Vector3(3.2, 0, 2.8), Vector3(0, 0, 2.8)]
	var basis := Basis(Vector3.UP, yaw)
	for i in mini(count, offsets.size()):
		spawn(parent, center + basis * offsets[i], squad_name, yaw)


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	_home = global_position
	_strafe = 1.0 if randf() < 0.5 else -1.0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.9
	shape.shape = capsule
	shape.position.y = 0.95
	add_child(shape)
	_build()


func _part(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _box(x: float, y: float, z: float) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = Vector3(x, y, z)
	return m


func _cyl(r: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 10
	m.rings = 1
	return m


func _build() -> void:
	var body := Node3D.new()
	add_child(body)
	var shell := Look.droid_shell
	var dark := Look.hull_dark
	var mark := Look.droid_mark
	# Legs: thigh angles forward, shin angles back (reverse knee).
	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.16, 1.02, 0)
		body.add_child(hip)
		_part(hip, _box(0.12, 0.5, 0.14), Vector3(0, -0.22, -0.1), shell, Vector3(deg_to_rad(-25), 0, 0))
		var knee := Node3D.new()
		knee.position = Vector3(0, -0.44, -0.2)
		hip.add_child(knee)
		_part(knee, _cyl(0.07, 0.12), Vector3.ZERO, dark, Vector3(0, 0, deg_to_rad(90)))
		_part(knee, _box(0.1, 0.56, 0.1), Vector3(0, -0.26, 0.12), shell, Vector3(deg_to_rad(30), 0, 0))
		_part(knee, _box(0.16, 0.06, 0.3), Vector3(0, -0.55, 0.12), dark)   # foot
		_hips.append(hip)
		_knees.append(knee)
	# Pelvis, spine and the wedge chest.
	_part(body, _box(0.42, 0.14, 0.22), Vector3(0, 1.05, 0), dark)
	_part(body, _cyl(0.05, 0.3), Vector3(0, 1.2, 0.02), Look.metal)
	var chest := _part(body, PrismMesh.new(), Vector3(0, 1.5, -0.02), shell, Vector3(deg_to_rad(180), 0, 0))
	(chest.mesh as PrismMesh).size = Vector3(0.62, 0.48, 0.3)
	_part(body, _box(0.3, 0.08, 0.32), Vector3(0, 1.62, -0.02), mark)
	# Hammerhead sensor bar on a short neck.
	var head := Node3D.new()
	head.position = Vector3(0, 1.82, -0.02)
	body.add_child(head)
	_part(head, _cyl(0.05, 0.14), Vector3(0, -0.06, 0), Look.metal)
	_part(head, _box(0.62, 0.12, 0.18), Vector3(0, 0.04, 0), shell)
	_part(head, _box(0.66, 0.05, 0.14), Vector3(0, 0.12, 0.02), mark)
	for side in [-1.0, 1.0]:
		_part(head, SphereMesh.new(), Vector3(side * 0.22, 0.04, -0.1), Look.droid_eye).scale = Vector3.ONE * 0.09
	# Left arm hangs; right forearm is a blaster.
	_part(body, _box(0.09, 0.55, 0.09), Vector3(-0.36, 1.35, 0), shell, Vector3(0, 0, deg_to_rad(-8)))
	_gun_arm = Node3D.new()
	_gun_arm.position = Vector3(0.36, 1.58, 0)
	body.add_child(_gun_arm)
	_part(_gun_arm, _box(0.09, 0.32, 0.09), Vector3(0, -0.15, 0), shell)
	_part(_gun_arm, _box(0.12, 0.12, 0.5), Vector3(0, -0.3, -0.22), dark)
	_part(_gun_arm, _cyl(0.03, 0.2), Vector3(0, -0.28, -0.55), Look.metal, Vector3(deg_to_rad(90), 0, 0))
	_muzzle = Node3D.new()
	_muzzle.position = Vector3(0, -0.28, -0.68)
	_gun_arm.add_child(_muzzle)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	var player := Zones.player as Node3D
	var move := Vector3.ZERO
	_alert = false
	if player and Player.is_playing():
		var chest := player.global_position + Vector3(0, 1.2, 0)
		var eye := global_position + Vector3(0, 1.8, 0)
		var to_player := chest - eye
		var flat := Vector3(to_player.x, 0, to_player.z)
		if to_player.length() < SIGHT and _can_see(eye, chest):
			_alert = true
			rotation.y = lerp_angle(rotation.y, atan2(-flat.x, -flat.z), 1.0 - exp(-6.0 * delta))
			var dist := flat.length()
			var forward := flat.normalized()
			var right := forward.cross(Vector3.UP)
			if dist > PREFERRED_RANGE:
				move = forward
			elif dist < PREFERRED_RANGE * 0.6:
				move = -forward * 0.6
			move += right * _strafe * 0.5
			if randf() < delta * 0.35:
				_strafe = -_strafe
			_gun_arm.rotation.x = lerpf(_gun_arm.rotation.x, deg_to_rad(80), 0.2)
			_fight(delta, chest)
	if not _alert:
		_gun_arm.rotation.x = lerpf(_gun_arm.rotation.x, 0.0, 0.1)
	velocity.x = move_toward(velocity.x, move.x * WALK, 12.0 * delta)
	velocity.z = move_toward(velocity.z, move.z * WALK, 12.0 * delta)
	move_and_slide()
	if is_on_wall():
		_strafe = -_strafe
	# Stiff, mechanical gait.
	var speed := Vector2(velocity.x, velocity.z).length()
	_stride += delta * speed * 3.2
	var swing := sin(_stride) * clampf(speed / WALK, 0.0, 1.0) * 0.5
	_hips[0].rotation.x = swing
	_hips[1].rotation.x = -swing
	_knees[0].rotation.x = maxf(0.0, -swing) * 0.6
	_knees[1].rotation.x = maxf(0.0, swing) * 0.6


func _can_see(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, 0b011)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit and hit.collider is Player


func _fight(delta: float, target: Vector3) -> void:
	# Join the squad's next volley.
	var now := Time.get_ticks_msec()
	var v: Dictionary = _volleys.get(squad, {"next": now + 1200, "id": 0})
	if now >= v["next"]:
		v["next"] = now + randi_range(2000, 2800)
		v["id"] += 1
	_volleys[squad] = v
	if v["id"] != _seen_volley:
		_seen_volley = v["id"]
		_shots_left = 3
		_shot_timer = randf_range(0.0, 0.3)
	if _shots_left > 0:
		_shot_timer -= delta
		if _shot_timer <= 0.0:
			_shot_timer = 0.17
			_shots_left -= 1
			var from := _muzzle.global_position
			var spread := 0.045
			var dir := (target - from).normalized()
			dir = (dir + Vector3(randf_range(-spread, spread), randf_range(-spread, spread) * 0.6, randf_range(-spread, spread))).normalized()
			Bolt.fire(get_parent(), from, dir, self, Look.bolt_red, 6.0)


func take_damage(amount: float, _from: Vector3) -> bool:
	if _dead:
		return false
	health -= amount
	_strafe = -_strafe
	if health > 0.0:
		return false
	_dead = true
	collision_layer = 0
	Fx.impact(get_parent(), global_position + Vector3(0, 1.4, 0), Vector3.UP, Color(3.0, 1.4, 0.4))
	var tw := create_tween()
	tw.tween_property(self, "rotation:x", deg_to_rad(80), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_interval(4.0)
	tw.tween_callback(queue_free)
	return true
