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
	collision_mask = 1 | Kit.SHIELD_LAYER
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


## An original armored trooper: segmented white plates over a black body
## glove, blue unit markings, and a helmet with a flared dome, a brow ridge,
## two angled eye lenses and a breather slit.
func _build_model() -> void:
	_model = Node3D.new()
	add_child(_model)
	var white := Look.armor
	var glove := Look.undersuit
	var stripe := Look.armor_stripe
	var dark := Look.visor
	# Legs pivot at the hip so they can swing.
	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.12, 0.93, 0)
		_model.add_child(hip)
		var b := ShipBuilder.new()
		_tube_y(b, [[-0.02, 0.075, 0.08], [-0.9, 0.065, 0.07]], glove)
		_tube_y(b, [[-0.03, 0.1, 0.112], [-0.2, 0.108, 0.118], [-0.4, 0.086, 0.096]], white)   # thigh plate
		b.sphere(0.07, Vector3(0, -0.46, -0.05), Look.hull_dark, Vector3(1, 0.9, 0.8))       # knee
		_tube_y(b, [[-0.5, 0.08, 0.088], [-0.6, 0.094, 0.104], [-0.8, 0.074, 0.084]], white)   # shin
		var boot := []
		for r in [[0.09, 0.075, 0.055], [-0.03, 0.085, 0.07], [-0.15, 0.075, 0.055], [-0.21, 0.04, 0.035]]:
			boot.append(ShipBuilder.ring(Vector3(0, -0.865, r[0] - 0.02), r[1], r[2], 14, 2.6))
		b.loft(boot, white)
		b.box(Vector3(0.16, 0.025, 0.3), Vector3(0, -0.925, -0.05), Look.hull_dark)
		if side < 0:
			b.sphere(0.5, Vector3(-0.1, -0.2, -0.01), stripe, Vector3(0.025, 0.24, 0.12))
		_add(hip, b)
		_legs.append(hip)
	# Torso: body glove, belt, abdominal plates, chest and back plate, collar, pack.
	var t := ShipBuilder.new()
	_tube_y(t, [[0.88, 0.15, 0.11], [1.62, 0.17, 0.12]], glove)
	_tube_y(t, [[0.94, 0.19, 0.135], [1.03, 0.19, 0.135]], white)                          # belt
	t.box(Vector3(0.09, 0.07, 0.03), Vector3(0, 0.985, -0.14), Look.hull_dark)              # buckle
	for x in [-0.15, -0.09, 0.09, 0.15]:
		t.sphere(0.5, Vector3(x, 0.98, -0.12 + absf(x) * 0.25), Look.hull_dark, Vector3(0.05, 0.06, 0.04))
	_tube_y(t, [[1.07, 0.165, 0.12], [1.15, 0.17, 0.125]], white)                          # abdomen plates
	_tube_y(t, [[1.17, 0.175, 0.128], [1.25, 0.18, 0.13]], white)
	_tube_y(t, [[1.27, 0.18, 0.125], [1.38, 0.225, 0.14], [1.5, 0.24, 0.145], [1.6, 0.17, 0.11]], white)  # chest
	t.sphere(0.5, Vector3(0, 1.43, -0.142), stripe, Vector3(0.16, 0.035, 0.02))            # chest marking
	_tube_y(t, [[1.6, 0.11, 0.09], [1.66, 0.09, 0.075]], glove)                            # collar
	var pack := []
	for r in [[1.18, 0.12, 0.05], [1.3, 0.15, 0.07], [1.48, 0.14, 0.065], [1.54, 0.1, 0.04]]:
		pack.append(ShipBuilder.ring(Vector3(0, r[0], 0.2), r[1], r[2], 14, 3.0, Vector3.RIGHT, Vector3.BACK))
	t.loft(pack, Look.ship_grey)
	t.tube(0.012, 0.012, 0.32, Vector3(0.1, 1.68, 0.22), Look.metal, Vector3.UP, 6)
	for side in [-1.0, 1.0]:
		t.sphere(0.13, Vector3(side * 0.28, 1.53, 0), white, Vector3(1.0, 0.72, 1.05))        # shoulder bells
	t.sphere(0.135, Vector3(0.285, 1.535, 0), stripe, Vector3(0.6, 0.55, 1.07))             # unit marking
	_add(_model, t)
	# Helmet.
	var head := Node3D.new()
	head.position = Vector3(0, 1.72, 0)
	_model.add_child(head)
	var h := ShipBuilder.new()
	var dome := []
	for r in [[-0.135, 0.168, 0.185], [-0.095, 0.15, 0.168], [0.0, 0.152, 0.172], [0.07, 0.143, 0.163],
			[0.12, 0.116, 0.132], [0.155, 0.07, 0.08], [0.172, 0.02, 0.02]]:
		dome.append(ShipBuilder.ring(Vector3(0, r[0], 0), r[1], r[2], 20, 2.2, Vector3.RIGHT, Vector3.BACK))
	h.loft(dome, white)
	h.sphere(0.5, Vector3(0, 0.055, -0.162), white, Vector3(0.25, 0.035, 0.05))             # brow ridge
	for side in [-1.0, 1.0]:
		h.sphere(0.05, Vector3(side * 0.058, 0.012, -0.163), dark, Vector3(1.15, 0.62, 0.45), Vector3(0, 0, side * 0.28))  # eye lenses
		h.sphere(0.5, Vector3(side * 0.105, -0.085, -0.125), white, Vector3(0.07, 0.09, 0.1))  # cheek guards
		h.box(Vector3(0.018, 0.04, 0.012), Vector3(side * 0.045, -0.085, -0.168), dark, Vector3(0, 0, side * 0.3))  # breather grilles
		h.tube(0.042, 0.042, 0.03, Vector3(side * 0.155, -0.02, 0.01), Look.hull_dark, Vector3.RIGHT, 12)  # ear caps
	h.box(Vector3(0.022, 0.07, 0.014), Vector3(0, -0.07, -0.172), dark)                     # breather slit
	h.sphere(0.5, Vector3(0, 0.06, 0.0), stripe, Vector3(0.03, 0.23, 0.35))                 # crest
	_add(head, h)
	# Arms and rifle on one pivot that follows the camera pitch.
	_arm_pivot = Node3D.new()
	_arm_pivot.position = Vector3(0, 1.42, 0)
	_model.add_child(_arm_pivot)
	var a := ShipBuilder.new()
	for side in [-1.0, 1.0]:
		var upper := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(50)), Vector3(side * 0.26, -0.1, -0.06))
		var arm := ShipBuilder.new()
		_tube_y(arm, [[0.18, 0.055, 0.055], [-0.18, 0.05, 0.05]], glove)
		_tube_y(arm, [[0.12, 0.07, 0.07], [-0.08, 0.064, 0.064]], white)                     # upper arm plate
		a.merge(arm, upper)
		var fore := Transform3D(Basis.from_euler(Vector3(deg_to_rad(90), 0, side * deg_to_rad(-30))), Vector3(side * 0.16, -0.16, -0.3))
		var gauntlet := ShipBuilder.new()
		_tube_y(gauntlet, [[0.16, 0.06, 0.06], [0.0, 0.07, 0.068], [-0.16, 0.055, 0.05]], white)
		a.merge(gauntlet, fore)
		a.sphere(0.05, Vector3(side * 0.06, -0.13, -0.44), glove)                            # hands
	_add(_arm_pivot, a)
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


## A vertical rounded tube through rings of [y, half width, half depth].
func _tube_y(b: ShipBuilder, rings_spec: Array, mat: Material) -> void:
	var rings := []
	for r in rings_spec:
		rings.append(ShipBuilder.ring(Vector3(0, r[0], 0), r[1], r[2], 16, 2.4, Vector3.RIGHT, Vector3.BACK))
	b.loft(rings, mat)


func _add(parent: Node3D, b: ShipBuilder) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit()
	parent.add_child(mi)


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
