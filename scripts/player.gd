class_name Player
extends CharacterBody3D
## Third-person trooper: over-the-shoulder spring-arm camera, run/sprint/jump,
## right mouse to aim down the shoulder, left mouse to fire. The body turns to
## face where the camera looks whenever you move or shoot, as in modern
## console shooters.

const WALK := 5.0
const SPRINT := 8.5
const AIM_WALK := 3.2
const ACCEL := 12.0
const AIR_ACCEL := 3.0
const JUMP := 6.5
const GRAVITY := 19.0
const MOUSE_SENS := 0.0025
const FIRE_INTERVAL := 0.15
const MAX_HEALTH := 100.0

## Set by the dev hooks in main.gd to play without a captured mouse.
static var autoplay := false

var health := MAX_HEALTH
var yaw := 0.0
var pitch := -0.1
var kills := 0

var _model: Node3D
var _legs: Array[Node3D] = []
var _arm_pivot: Node3D
var _muzzle: Node3D
var _pitch_node: Node3D
var _spring: SpringArm3D
var _camera: Camera3D
var _cooldown := 0.0
var _since_hit := 99.0
var _stride := 0.0
var _recoil := 0.0
var _dead := false


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.4
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	_build_model()
	_build_camera()


func _build_model() -> void:
	_model = Node3D.new()
	add_child(_model)
	var b := func(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> Node3D:
		return Kit.block(parent, size, pos, mat, false)
	# Legs pivot at the hip so they can swing.
	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.13, 0.92, 0)
		_model.add_child(hip)
		b.call(hip, Vector3(0.2, 0.9, 0.22), Vector3(0, -0.45, 0), Look.undersuit)
		b.call(hip, Vector3(0.22, 0.38, 0.25), Vector3(0, -0.25, -0.01), Look.armor)   # thigh plate
		b.call(hip, Vector3(0.21, 0.36, 0.24), Vector3(0, -0.68, -0.01), Look.armor)   # shin plate
		b.call(hip, Vector3(0.22, 0.12, 0.32), Vector3(0, -0.87, -0.05), Look.undersuit)  # boot
		_legs.append(hip)
	b.call(_model, Vector3(0.42, 0.18, 0.26), Vector3(0, 0.98, 0), Look.undersuit)      # belt
	b.call(_model, Vector3(0.46, 0.5, 0.28), Vector3(0, 1.3, 0), Look.armor)            # chest
	b.call(_model, Vector3(0.3, 0.16, 0.05), Vector3(0, 1.38, -0.15), Look.trim_red)     # chest marking
	b.call(_model, Vector3(0.36, 0.3, 0.14), Vector3(0, 1.25, 0.2), Look.hull_dark)      # backpack
	var head := Node3D.new()
	head.position = Vector3(0, 1.7, 0)
	_model.add_child(head)
	b.call(head, Vector3(0.3, 0.3, 0.32), Vector3.ZERO, Look.armor)                    # helmet
	b.call(head, Vector3(0.24, 0.08, 0.04), Vector3(0, 0.02, -0.16), Look.visor)        # visor slot
	b.call(head, Vector3(0.04, 0.12, 0.04), Vector3(0, -0.08, -0.16), Look.visor)       # breather
	b.call(head, Vector3(0.32, 0.05, 0.34), Vector3(0, 0.12, 0), Look.trim_red)         # crest stripe
	# Arms and blaster on one pivot that follows the camera pitch.
	_arm_pivot = Node3D.new()
	_arm_pivot.position = Vector3(0, 1.42, 0)
	_model.add_child(_arm_pivot)
	for side in [-1.0, 1.0]:
		b.call(_model, Vector3(0.16, 0.16, 0.2), Vector3(side * 0.31, 1.48, 0), Look.armor)  # pauldron
		b.call(_arm_pivot, Vector3(0.12, 0.12, 0.5), Vector3(side * 0.2, -0.08, -0.22), Look.undersuit)
	var gun := Node3D.new()
	gun.position = Vector3(0.05, -0.05, -0.45)
	_arm_pivot.add_child(gun)
	b.call(gun, Vector3(0.09, 0.14, 0.6), Vector3.ZERO, Look.hull_dark)
	b.call(gun, Vector3(0.05, 0.05, 0.25), Vector3(0, 0.03, -0.4), Look.metal)
	b.call(gun, Vector3(0.05, 0.08, 0.16), Vector3(0, 0.11, -0.04), Look.metal)      # scope
	_muzzle = Node3D.new()
	_muzzle.position = Vector3(0, 0.03, -0.55)
	gun.add_child(_muzzle)


func _build_camera() -> void:
	var yaw_node := Node3D.new()
	yaw_node.name = "CameraYaw"
	yaw_node.top_level = true
	add_child(yaw_node)
	_pitch_node = Node3D.new()
	yaw_node.add_child(_pitch_node)
	_spring = SpringArm3D.new()
	_spring.spring_length = 3.0
	_spring.margin = 0.2
	_spring.collision_mask = 1
	_spring.position = Vector3(0.75, 0.1, 0)
	var probe := SphereShape3D.new()
	probe.radius = 0.25
	_spring.shape = probe
	_spring.add_excluded_object(get_rid())
	_pitch_node.add_child(_spring)
	_camera = Camera3D.new()
	_camera.fov = 70.0
	_camera.far = 6000.0
	_camera.near = 0.08
	_spring.add_child(_camera)
	_camera.current = true


static func is_playing() -> bool:
	return autoplay or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func turn(amount: float) -> void:
	yaw += amount
	_model.rotation.y = yaw


func snap_camera() -> void:
	_update_camera_rig(1.0)


func camera() -> Camera3D:
	return _camera


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * MOUSE_SENS
		pitch = clampf(pitch - event.relative.y * MOUSE_SENS, -1.2, 1.1)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	var playing := is_playing()
	var aiming := playing and Input.is_action_pressed("aim")
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if playing else Vector2.ZERO
	var dir := (Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y)).normalized()
	var sprinting := Input.is_action_pressed("sprint") and input.y < 0 and not aiming
	var speed := AIM_WALK if aiming else (SPRINT if sprinting else WALK)
	var accel := ACCEL if is_on_floor() else AIR_ACCEL
	velocity.x = move_toward(velocity.x, dir.x * speed, accel * speed * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, accel * speed * delta)
	if is_on_floor():
		if playing and Input.is_action_just_pressed("jump"):
			velocity.y = JUMP
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()

	# Face the camera direction while moving, aiming or shooting.
	var firing := playing and Input.is_action_pressed("fire")
	if dir.length() > 0.1 or aiming or firing:
		_model.rotation.y = lerp_angle(_model.rotation.y, yaw, 1.0 - exp(-14.0 * delta))
	_arm_pivot.rotation.x = lerpf(_arm_pivot.rotation.x, pitch * 0.9 if (aiming or firing) else -0.35, 1.0 - exp(-12.0 * delta))

	# Leg swing.
	var ground_speed := Vector2(velocity.x, velocity.z).length()
	_stride += delta * ground_speed * 2.2
	var swing := sin(_stride) * clampf(ground_speed / SPRINT, 0.0, 1.0) * 0.8 if is_on_floor() else 0.3
	_legs[0].rotation.x = swing
	_legs[1].rotation.x = -swing

	# Weapon.
	_cooldown -= delta
	if firing and _cooldown <= 0.0:
		_cooldown = FIRE_INTERVAL
		_fire(aiming)

	# Health regenerates after a few seconds out of fire.
	_since_hit += delta
	if _since_hit > 4.0 and health < MAX_HEALTH:
		health = minf(MAX_HEALTH, health + 15.0 * delta)
	if global_position.y < -40.0 or (global_position.y > 200.0 and global_position.y < 260.0):
		_die()


func _process(delta: float) -> void:
	_update_camera_rig(1.0 - exp(-20.0 * delta))
	var aiming := is_playing() and Input.is_action_pressed("aim")
	_camera.fov = lerpf(_camera.fov, 48.0 if aiming else 70.0, 1.0 - exp(-10.0 * delta))
	_spring.spring_length = lerpf(_spring.spring_length, 1.7 if aiming else 3.0, 1.0 - exp(-10.0 * delta))
	_recoil = move_toward(_recoil, 0.0, delta * 0.25)


func _update_camera_rig(weight: float) -> void:
	var yaw_node := _pitch_node.get_parent() as Node3D
	yaw_node.global_position = yaw_node.global_position.lerp(global_position + Vector3(0, 1.6, 0), weight)
	yaw_node.rotation.y = yaw
	_pitch_node.rotation.x = pitch + _recoil


func _fire(aiming: bool) -> void:
	# Aim at whatever is under the crosshair, then shoot from the muzzle toward it.
	var from := _camera.global_position
	var forward := -_camera.global_transform.basis.z
	var query := PhysicsRayQueryParameters3D.create(from, from + forward * 400.0, 0b101)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var target: Vector3 = hit.position if hit else from + forward * 400.0
	var spread := 0.004 if aiming else 0.014
	var dir := (target - _muzzle.global_position).normalized()
	dir = (dir + Vector3(randf_range(-spread, spread), randf_range(-spread, spread), randf_range(-spread, spread))).normalized()
	Bolt.fire(get_parent(), _muzzle.global_position, dir, self, Look.bolt_blue, 20.0)
	_recoil += 0.012 if aiming else 0.02


func take_damage(amount: float, _from: Vector3) -> bool:
	if _dead:
		return false
	health -= amount
	_since_hit = 0.0
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.damage_flash()
	if health <= 0.0:
		_die()
		return true
	return false


func on_hit_target(killed: bool) -> void:
	if killed:
		kills += 1
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.hit_marker(killed)


func _die() -> void:
	if _dead:
		return
	_dead = true
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.show_message("Down — redeploying")
		await hud.fade(1.0, 0.6)
	var t := Zones.spawn_point(Zones.current if Zones.current != "" else "hangar")
	global_position = t.origin
	yaw = t.basis.get_euler().y
	_model.rotation.y = yaw
	velocity = Vector3.ZERO
	health = MAX_HEALTH
	snap_camera()
	await get_tree().create_timer(0.5).timeout
	_dead = false
	if hud:
		hud.show_message("")
		await hud.fade(0.0, 0.5)
