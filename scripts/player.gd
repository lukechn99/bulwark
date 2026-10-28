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
const SHOULDER := 0.75

## Set by the dev hooks in main.gd to play without a captured mouse.
static var autoplay := false

var health := MAX_HEALTH
var yaw := 0.0
var pitch := -0.1
var kills := 0
## A turret (or anything else) the player is operating; it gets look input.
var vehicle: Node = null

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
var _outside := 0.0


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


## An original armored trooper: rounded white plates over a black body glove,
## a domed helmet with a wraparound visor band and blue unit markings.
func _build_model() -> void:
	_model = Node3D.new()
	add_child(_model)
	var white := Look.armor
	var glove := Look.undersuit
	var stripe := Look.armor_stripe
	# Legs pivot at the hip so they can swing.
	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.12, 0.93, 0)
		_model.add_child(hip)
		_cap(hip, 0.085, 0.92, Vector3(0, -0.45, 0), glove)
		_cap(hip, 0.105, 0.42, Vector3(0, -0.2, -0.015), white)              # thigh plate
		_sph(hip, 0.075, Vector3(0, -0.47, -0.06), Look.hull_dark)           # knee pad
		_cap(hip, 0.095, 0.4, Vector3(0, -0.68, -0.005), white)              # shin plate
		_box(hip, Vector3(0.17, 0.11, 0.3), Vector3(0, -0.88, -0.04), white) # boot
		_box(hip, Vector3(0.18, 0.04, 0.31), Vector3(0, -0.93, -0.04), glove)
		if side < 0:
			_box(hip, Vector3(0.03, 0.22, 0.12), Vector3(-0.1, -0.2, -0.01), stripe)
		_legs.append(hip)
	# Belt and pouches, body glove torso, chest and abdomen plates.
	_cap(_model, 0.17, 0.34, Vector3(0, 1.0, 0), glove)
	_box(_model, Vector3(0.38, 0.08, 0.25), Vector3(0, 0.97, 0), Look.hull_dark)
	for x in [-0.14, 0.0, 0.14]:
		_box(_model, Vector3(0.08, 0.08, 0.05), Vector3(x, 0.97, -0.14), white)
	_cap(_model, 0.19, 0.5, Vector3(0, 1.32, 0), glove)
	_box(_model, Vector3(0.28, 0.15, 0.22), Vector3(0, 1.12, -0.02), white)
	var chest := _sph(_model, 0.23, Vector3(0, 1.38, -0.02), white)
	chest.scale = Vector3(1.0, 0.75, 0.62)
	_box(_model, Vector3(0.22, 0.04, 0.02), Vector3(0, 1.31, -0.165), stripe)
	_cap(_model, 0.13, 0.1, Vector3(0, 1.56, 0), glove)                   # collar
	_box(_model, Vector3(0.3, 0.32, 0.12), Vector3(0, 1.32, 0.2), Look.hull_dark)  # pack
	_cap(_model, 0.012, 0.35, Vector3(0.1, 1.6, 0.22), Look.metal)        # antenna
	# Helmet: dome, wraparound visor band, cheek guards, crest and side stripes.
	var head := Node3D.new()
	head.position = Vector3(0, 1.72, 0)
	_model.add_child(head)
	var dome := _sph(head, 0.15, Vector3(0, 0.02, 0.0), white)
	dome.scale = Vector3(1.0, 1.08, 1.12)
	var band := MeshInstance3D.new()
	var ring := CylinderMesh.new()
	ring.top_radius = 0.152
	ring.bottom_radius = 0.158
	ring.height = 0.05
	ring.radial_segments = 20
	ring.rings = 1
	band.mesh = ring
	band.material_override = Look.visor
	band.scale = Vector3(1.0, 1.0, 1.12)
	band.position = Vector3(0, 0.03, -0.004)
	head.add_child(band)
	_box(head, Vector3(0.22, 0.09, 0.08), Vector3(0, -0.09, -0.12), white)   # jaw guard
	_box(head, Vector3(0.14, 0.03, 0.02), Vector3(0, -0.07, -0.165), Look.hull_dark)
	_box(head, Vector3(0.025, 0.06, 0.24), Vector3(0, 0.16, 0.0), stripe)    # crest
	for side in [-1.0, 1.0]:
		var ear := _cyl(head, 0.045, 0.03, Vector3(side * 0.155, -0.02, 0.01), Look.hull_dark)
		ear.rotation.z = deg_to_rad(90)
	# Shoulder bells, one with the unit stripe.
	for side in [-1.0, 1.0]:
		var bell := _sph(_model, 0.11, Vector3(side * 0.29, 1.5, 0), white)
		bell.scale = Vector3(1.0, 0.8, 1.1)
		if side > 0:
			_box(_model, Vector3(0.04, 0.1, 0.18), Vector3(0.39, 1.48, 0), stripe)
	# Arms and rifle on one pivot that follows the camera pitch.
	_arm_pivot = Node3D.new()
	_arm_pivot.position = Vector3(0, 1.42, 0)
	_model.add_child(_arm_pivot)
	for side in [-1.0, 1.0]:
		var upper := _cap(_arm_pivot, 0.06, 0.34, Vector3(side * 0.26, -0.1, -0.06), glove)
		upper.rotation.x = deg_to_rad(50)
		var fore := _cap(_arm_pivot, 0.065, 0.32, Vector3(side * 0.16, -0.16, -0.3), white)
		fore.rotation = Vector3(deg_to_rad(90), 0, side * deg_to_rad(-30))
		_sph(_arm_pivot, 0.05, Vector3(side * 0.06, -0.13, -0.44), glove)    # hands
	var gun := Node3D.new()
	gun.position = Vector3(0.04, -0.07, -0.4)
	_arm_pivot.add_child(gun)
	_box(gun, Vector3(0.07, 0.12, 0.5), Vector3(0, 0, -0.05), Look.hull_dark)          # receiver
	_box(gun, Vector3(0.05, 0.1, 0.22), Vector3(0, -0.02, 0.3), Look.hull_dark)         # stock
	var shroud := _cyl(gun, 0.03, 0.34, Vector3(0, 0.02, -0.46), Look.metal)
	shroud.rotation.x = deg_to_rad(90)
	var scope := _cyl(gun, 0.025, 0.16, Vector3(0, 0.1, -0.06), Look.metal)
	scope.rotation.x = deg_to_rad(90)
	_box(gun, Vector3(0.04, 0.1, 0.05), Vector3(0, -0.1, -0.12), Look.hull_dark)        # magazine
	_muzzle = Node3D.new()
	_muzzle.position = Vector3(0, 0.02, -0.66)
	gun.add_child(_muzzle)


func _cap(parent: Node3D, r: float, h: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = maxf(h, r * 2.0)
	m.radial_segments = 12
	m.rings = 3
	return _mesh(parent, m, pos, mat)


func _sph(parent: Node3D, r: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 16
	m.rings = 8
	return _mesh(parent, m, pos, mat)


func _cyl(parent: Node3D, r: float, h: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 12
	m.rings = 1
	return _mesh(parent, m, pos, mat)


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _mesh(parent, m, pos, mat)


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


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
	_spring.position = Vector3(SHOULDER, 0.1, 0)
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
	if autoplay:
		return   # touch play: the on-screen controls drive the camera
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		add_look(event.relative.x * MOUSE_SENS, event.relative.y * MOUSE_SENS)


## Turn the camera; positive x looks right, positive y looks down.
func add_look(x: float, y: float) -> void:
	if vehicle:
		vehicle.add_look(x, y)
		return
	yaw -= x
	pitch = clampf(pitch - y, -1.2, 1.1)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if vehicle:
		velocity = Vector3.ZERO
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
	# Fell out of the ship: outside every zone for a moment.
	if Zones.zone_at(global_position) == "":
		_outside += delta
		if _outside > 1.5:
			_outside = 0.0
			_die()
	else:
		_outside = 0.0


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
	# Keep the shoulder offset inside walls: the spring arm only guards the
	# pull-back, so the sideways step from head to shoulder needs its own ray.
	var head := yaw_node.global_position
	var side := yaw_node.global_transform.basis.x
	var q := PhysicsRayQueryParameters3D.create(head, head + side * (SHOULDER + 0.3), 1)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var room := SHOULDER
	if hit:
		room = clampf(head.distance_to(hit.position) - 0.3, 0.0, SHOULDER)
	_spring.position.x = room


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
