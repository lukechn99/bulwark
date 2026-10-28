class_name Turret
extends Node3D
## A twin heavy cannon on the hull. Stand at its gunnery station and press USE
## to take the seat: the view moves to the gun, look input aims it, FIRE
## alternates barrels, and USE again climbs out.

const YAW_SPEED := 1.0
const FIRE_INTERVAL := 0.2
const BOLT_SPEED := 260.0

## Where the gunner stands to use this turret, in the turret's parent space.
var station := Vector3.ZERO
var manned := false
var _yaw_node: Node3D
var _pitch_node: Node3D
var _barrels: Array[Node3D] = []
var _camera: Camera3D
var _yaw := 0.0
var _pitch := 0.15
var _cooldown := 0.0
var _next_barrel := 0
var _recoil := [0.0, 0.0]
var _player_camera: Camera3D


static func make(pos: Vector3, yaw: float, station_pos: Vector3) -> Turret:
	var t := Turret.new()
	t.position = pos
	t._yaw = yaw
	t.station = station_pos
	return t


func _ready() -> void:
	# Fixed armoured base.
	Kit.cylinder(self, 3.4, 1.6, Vector3(0, 0.8, 0), Look.hull_dark, false, 20)
	Kit.cylinder(self, 3.5, 0.3, Vector3(0, 1.45, 0), Look.trim_red, false, 20)
	_yaw_node = Node3D.new()
	_yaw_node.position.y = 1.6
	add_child(_yaw_node)
	# Rotating housing.
	Kit.block(_yaw_node, Vector3(5.2, 2.4, 5.0), Vector3(0, 1.2, 0.4), Look.hull)
	Kit.block(_yaw_node, Vector3(5.4, 0.3, 5.2), Vector3(0, 2.45, 0.4), Look.hull_dark, false)
	Kit.block(_yaw_node, Vector3(1.6, 0.5, 0.1), Vector3(0, 1.6, -2.15), Look.screen_blue, false)
	_pitch_node = Node3D.new()
	_pitch_node.position = Vector3(0, 1.3, -1.6)
	_yaw_node.add_child(_pitch_node)
	Kit.block(_pitch_node, Vector3(3.0, 1.4, 1.6), Vector3.ZERO, Look.hull_dark, false)
	for side in [-1.0, 1.0]:
		var barrel := Node3D.new()
		barrel.position = Vector3(side * 0.9, 0.1, -0.8)
		_pitch_node.add_child(barrel)
		var tube := Kit.cylinder(barrel, 0.22, 6.0, Vector3(0, 0, -3.0), Look.metal, false, 12)
		tube.rotation.x = deg_to_rad(90)
		var tip := Kit.cylinder(barrel, 0.32, 0.8, Vector3(0, 0, -5.8), Look.hull_dark, false, 12)
		tip.rotation.x = deg_to_rad(90)
		_barrels.append(barrel)
	_camera = Camera3D.new()
	_camera.fov = 65.0
	_camera.far = 6000.0
	_camera.position = Vector3(0, 6.0, 12.0)
	_yaw_node.add_child(_camera)
	_apply()


func _apply() -> void:
	_yaw_node.rotation.y = _yaw
	_pitch_node.rotation.x = _pitch
	# Camera sits behind and above, tilted to look down the barrels' line.
	_camera.rotation.x = _pitch * 0.85 - 0.16


func add_look(x: float, y: float) -> void:
	_yaw -= x * YAW_SPEED
	_pitch = clampf(_pitch - y, -0.1, 1.2)
	_apply()


func _near_station() -> bool:
	var p := Zones.player as Node3D
	if not p:
		return false
	var s: Vector3 = (get_parent() as Node3D).to_global(station)
	return p.global_position.distance_to(s) < 1.6


func _process(delta: float) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	var player := Zones.player as Player
	var key := "[USE]" if Player.autoplay else "[E]"
	if not manned:
		var near := _near_station()
		if hud:
			hud.set_prompt(self, "%s  Man the turret" % key if near else "")
		if near and Input.is_action_just_pressed("interact") and player and not player.vehicle:
			_enter(player)
	else:
		if hud:
			hud.set_prompt(self, "%s  Leave the turret" % key)
		if Input.is_action_just_pressed("interact"):
			_exit(player)
			return
		_cooldown -= delta
		if Input.is_action_pressed("fire") and _cooldown <= 0.0:
			_cooldown = FIRE_INTERVAL
			_fire()
	for i in 2:
		_recoil[i] = move_toward(_recoil[i], 0.0, delta * 3.0)
		_barrels[i].position.z = -0.8 + _recoil[i]


func _enter(player: Player) -> void:
	manned = true
	player.vehicle = self
	_player_camera = player.camera()
	_camera.current = true


func _exit(player: Player) -> void:
	manned = false
	if player:
		player.vehicle = null
	if is_instance_valid(_player_camera):
		_player_camera.current = true


func _exit_tree() -> void:
	if manned:
		_exit(Zones.player as Player)


func _fire() -> void:
	var from := _camera.global_position
	var forward := -_camera.global_transform.basis.z
	var q := PhysicsRayQueryParameters3D.create(from, from + forward * 900.0, 0b101)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var target: Vector3 = hit.position if hit else from + forward * 900.0
	var barrel := _barrels[_next_barrel]
	var muzzle := barrel.to_global(Vector3(0, 0, -6.4))
	Bolt.fire(get_parent(), muzzle, (target - muzzle).normalized(), self, Look.bolt_blue, 40.0, BOLT_SPEED, 4.0)
	_recoil[_next_barrel] = 0.9
	_next_barrel = 1 - _next_barrel


## Credit the gunner for hits.
func on_hit_target(killed: bool) -> void:
	var p := Zones.player
	if p and p.has_method("on_hit_target"):
		p.on_hit_target(killed)
