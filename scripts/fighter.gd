class_name EnemyFighter
extends CharacterBody3D
## An original enemy starfighter: a slim fuselage with a red sensor eye and two
## forward-swept blade wings. It loops around the ship and makes strafing runs
## down the flight deck, firing at the player.
##
## Flies on a loop of waypoints in its parent's space (the flight deck zone).

const SPEED := 58.0
const TURN := 1.5
const MAX_HEALTH := 30.0

var waypoints: Array[Vector3] = []
var health := MAX_HEALTH
var _next := 0
var _cooldown := 0.0
var _model: Node3D
var _bank := 0.0


static func launch(parent: Node3D, path: Array[Vector3], start_index := 0) -> EnemyFighter:
	var f := EnemyFighter.new()
	f.waypoints = path
	f._next = (start_index + 1) % path.size()
	f.position = path[start_index]
	parent.add_child(f)
	f.look_at(f.global_position + (parent.to_global(path[f._next]) - f.global_position), Vector3.UP)
	return f


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 3.2
	shape.shape = sphere
	add_child(shape)
	_model = Node3D.new()
	add_child(_model)
	Kit.block(_model, Vector3(1.4, 1.1, 6.0), Vector3(0, 0, 0), Look.droid_shell, false)
	Kit.block(_model, Vector3(1.0, 0.8, 1.6), Vector3(0, 0.1, -3.4), Look.hull_dark, false)
	var eye := Kit.cylinder(_model, 0.35, 0.2, Vector3(0, 0.1, -4.25), Look.strip_red, false, 12)
	eye.rotation.x = deg_to_rad(90)
	for side in [-1.0, 1.0]:
		# Swept blade wing with a bent tip and a cannon.
		Kit.block(_model, Vector3(4.6, 0.16, 1.6), Vector3(side * 2.8, 0, 0.6), Look.droid_shell, false, Vector3(0, side * deg_to_rad(-28), 0))
		Kit.block(_model, Vector3(0.16, 1.8, 1.2), Vector3(side * 5.0, -0.7, -0.6), Look.droid_shell, false, Vector3(0, 0, side * deg_to_rad(15)))
		Kit.block(_model, Vector3(2.0, 0.18, 0.3), Vector3(side * 2.6, 0.02, 0.0), Look.droid_mark, false, Vector3(0, side * deg_to_rad(-28), 0))
		Kit.block(_model, Vector3(0.2, 0.2, 2.2), Vector3(side * 1.1, -0.35, -2.4), Look.metal, false)
	var glow := Kit.cylinder(_model, 0.45, 0.2, Vector3(0, 0, 3.05), Look.strip_red, false, 12)
	glow.rotation.x = deg_to_rad(90)


func _physics_process(delta: float) -> void:
	var parent := get_parent() as Node3D
	var target := parent.to_global(waypoints[_next])
	var to_target := target - global_position
	if to_target.length() < 18.0:
		_next = (_next + 1) % waypoints.size()
	var forward := -global_transform.basis.z
	var desired := to_target.normalized()
	var new_forward := forward.slerp(desired, clampf(TURN * delta, 0.0, 1.0)).normalized()
	# Bank into turns.
	var turn_amount := forward.cross(new_forward).y
	_bank = lerpf(_bank, clampf(turn_amount * 40.0, -1.0, 1.0), 0.1)
	global_position += new_forward * SPEED * delta
	look_at(global_position + new_forward, Vector3.UP)
	_model.rotation.z = _bank
	_shoot(delta, new_forward)


func _shoot(delta: float, forward: Vector3) -> void:
	_cooldown -= delta
	var p := Zones.player as Node3D
	if not p or _cooldown > 0.0 or not Player.is_playing():
		return
	var aim := p.global_position + Vector3(0, 1.2, 0) - global_position
	if aim.length() < 110.0 and forward.dot(aim.normalized()) > 0.93:
		_cooldown = 0.22
		var dir := (aim.normalized() + Vector3(randf_range(-0.03, 0.03), randf_range(-0.03, 0.03), randf_range(-0.03, 0.03))).normalized()
		for side in [-1.0, 1.0]:
			Bolt.fire(get_parent(), to_global(Vector3(side * 1.1, -0.35, -3.6)), dir, self, Look.bolt_red, 5.0, 150.0, 1.6)


func take_damage(amount: float, _from: Vector3) -> bool:
	if health <= 0.0:
		return false
	health -= amount
	if health > 0.0:
		return false
	Fx.explosion(get_parent(), global_position)
	Fx.explosion(get_parent(), global_position + global_transform.basis.x * 3.0)
	queue_free()
	return true
