class_name PilotFighter
extends CharacterBody3D
## A fighter the player can fly.
##
## Landed:  walk up and press USE (E) to climb in, JUMP (Space) to lift off.
## Flying:  look input (mouse or right-side swipes) pitches and turns,
##          forward/back (W/S or the joystick) sets throttle, left/right rolls,
##          Shift boosts, FIRE shoots the wingtip cannons.
##          USE over any deck, while slow and low, lands; USE again climbs out.
##
## Fighters live outside the zones (under Main/Connectors) so they survive
## flying from one zone to another.

enum State { LANDED, LIFTING, FLYING, LANDING }

const MIN_SPEED := 12.0
const MAX_SPEED := 70.0
const BOOST_SPEED := 115.0
const TURN_SENS := 1.25
const ROLL_RATE := 2.2
const FIRE_INTERVAL := 0.14
const MAX_HULL := 100.0
const LAND_RANGE := 16.0
const LAND_SPEED := 45.0
## The battle area: fighters are steered back if they stray this far.
const AREA_CENTER := Vector3(0, 150, 0)
const AREA_RADIUS := 2200.0

var state := State.LANDED
var hull := MAX_HULL
var throttle := 0.35
var speed := 0.0
var pad := -1
var _pilot: Player
var _model: Node3D
var _struts: Array[Node3D] = []
var _camera: Camera3D
var _player_camera: Camera3D
var _look := Vector2.ZERO
var _cooldown := 0.0
var _next_gun := 0
var _lift_target := 0.0
var _land_point := Vector3.ZERO
var _just_entered := false
var _warned := false


static func make(pos: Vector3, yaw: float, pad_index := -1) -> PilotFighter:
	var f := PilotFighter.new()
	f.position = pos
	f.rotation.y = yaw
	f.pad = pad_index
	return f


func _ready() -> void:
	add_to_group("pilotable")
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8.5, 1.4, 6.5)
	shape.shape = box
	shape.position = Vector3(0, 1.9, 0)
	add_child(shape)
	_model = Kit.starfighter(self, Vector3.ZERO, 0.0, Look.armor_stripe)
	# The kit model carries static collision for parked props; this fighter has
	# its own box, so drop those or it would crash into its own wings.
	for body in _model.find_children("*", "StaticBody3D", true, false):
		body.free()
	# Kit.starfighter puts the landing struts first; keep them so they retract.
	for i in 3:
		_struts.append(_model.get_child(i) as Node3D)
	_camera = Camera3D.new()
	_camera.fov = 72.0
	_camera.far = 8000.0
	_camera.near = 0.2
	_camera.top_level = true
	add_child(_camera)


func is_flying() -> bool:
	return state != State.LANDED


# --- boarding -----------------------------------------------------------------

func _near_cockpit(p: Node3D) -> bool:
	return p.global_position.distance_to(global_position) < 6.0 and absf(p.global_position.y - global_position.y) < 3.0


func _process(delta: float) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	var player := Zones.player as Player
	if not hud or not player:
		return
	var use := "[USE]" if Player.autoplay else "[E]"
	var jump := "[JUMP]" if Player.autoplay else "[Space]"
	if not _pilot:
		var near := state == State.LANDED and not player.vehicle and _near_cockpit(player)
		hud.set_prompt(self, "%s  Climb into the fighter" % use if near else "")
		if near and Input.is_action_just_pressed("interact"):
			_board(player)
		return
	_update_camera(delta)
	match state:
		State.LANDED:
			hud.set_prompt(self, "%s  Lift off      %s  Climb out" % [jump, use])
			if Input.is_action_just_pressed("jump"):
				_lift_off()
			elif Input.is_action_just_pressed("interact") and not _just_entered:
				_leave()
		State.FLYING:
			var can_land := _landing_spot() != Vector3.INF
			hud.set_prompt(self, "%s  Land" % use if can_land else "")
			if Input.is_action_just_pressed("interact") and not _just_entered:
				if can_land:
					_begin_landing()
				else:
					hud.show_message("Slow down and fly low over a deck to land")
					get_tree().create_timer(2.0).timeout.connect(func(): if is_instance_valid(hud): hud.show_message(""))
		_:
			hud.set_prompt(self, "")
	_just_entered = false


func _board(player: Player) -> void:
	_pilot = player
	_just_entered = true
	player.vehicle = self
	player.visible = false
	player.collision_layer = 0
	_player_camera = player.camera()
	_camera.global_transform = _chase_transform()
	_camera.current = true
	throttle = 0.35


func _leave() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.set_prompt(self, "")
	var p := _pilot
	_pilot = null
	if not p:
		return
	p.vehicle = null
	p.visible = true
	p.collision_layer = 2
	p.global_position = to_global(Vector3(-3.0, 0.3, 5.5))
	p.velocity = Vector3.ZERO
	if p.has_method("turn"):
		p.turn(rotation.y - p.yaw)
	p.snap_camera()
	if is_instance_valid(_player_camera):
		_player_camera.current = true


# --- flight -------------------------------------------------------------------

func add_look(x: float, y: float) -> void:
	_look += Vector2(x, y)


func _lift_off() -> void:
	state = State.LIFTING
	# Repulsors lift straight up, high enough to clear a trench deck.
	_lift_target = global_position.y + 20.0
	for s in _struts:
		s.visible = false


func _physics_process(delta: float) -> void:
	if _pilot:
		_pilot.global_position = global_position + Vector3(0, 1.0, 0)
	match state:
		State.LANDED:
			_look = Vector2.ZERO
		State.LIFTING:
			global_position.y = move_toward(global_position.y, _lift_target, 8.0 * delta)
			_steer(delta, 0.4)
			if global_position.y >= _lift_target - 0.05:
				state = State.FLYING
				speed = MIN_SPEED
			if Input.get_axis("move_back", "move_forward") > 0.5 and global_position.y > _lift_target - 14.0:
				state = State.FLYING   # throttle up to break off the climb early
				speed = MIN_SPEED
		State.FLYING:
			_fly(delta)
		State.LANDING:
			_land(delta)


func _steer(delta: float, scale: float) -> void:
	# Look input turns the nose; left/right on the stick rolls.
	var turn := _look * TURN_SENS * scale
	_look = Vector2.ZERO
	rotate_object_local(Vector3.UP, -turn.x)
	rotate_object_local(Vector3.RIGHT, -turn.y)
	var roll := Input.get_axis("move_right", "move_left")
	rotate_object_local(Vector3.FORWARD, -roll * ROLL_RATE * delta * scale)
	transform.basis = transform.basis.orthonormalized()


func _fly(delta: float) -> void:
	_steer(delta, 1.0)
	throttle = clampf(throttle + Input.get_axis("move_back", "move_forward") * 0.6 * delta, 0.0, 1.0)
	var boosting := Input.is_action_pressed("sprint")
	var target := BOOST_SPEED if boosting else lerpf(MIN_SPEED, MAX_SPEED, throttle)
	speed = move_toward(speed, target, 35.0 * delta)
	# Keep the fight in the battle area.
	var out := global_position - AREA_CENTER
	if out.length() > AREA_RADIUS:
		var home := -out.normalized()
		var fwd := -global_transform.basis.z
		look_at(global_position + fwd.slerp(home, clampf(0.8 * delta, 0.0, 1.0)), global_transform.basis.y)
		_message("Leaving the battle area — turning back" if not _warned else "")
		_warned = true
	elif _warned:
		_warned = false
		_message("")
	var col := move_and_collide(-global_transform.basis.z * speed * delta)
	if col:
		var impact := speed
		speed *= 0.25
		global_position += col.get_normal() * 1.5
		if impact > 20.0:
			take_damage(impact * 0.6, global_position)
	_cooldown -= delta
	if Input.is_action_pressed("fire") and _cooldown <= 0.0:
		_cooldown = FIRE_INTERVAL
		_fire()


func _fire() -> void:
	var side := -1.0 if _next_gun == 0 else 1.0
	_next_gun = 1 - _next_gun
	var muzzle := to_global(Vector3(side * 4.8, 1.75, -1.6))
	var dir := (aim_point() - muzzle).normalized()
	Bolt.fire(get_parent(), muzzle, dir, self, Look.bolt_blue, 15.0, 220.0, 2.0)


## Where the cannons converge; the HUD draws the crosshair here.
func aim_point() -> Vector3:
	return to_global(Vector3(0, 1.8, -160.0))


## The deck point below, if the fighter is slow and low enough to land.
func _landing_spot() -> Vector3:
	if speed > LAND_SPEED:
		return Vector3.INF
	var from := global_position + Vector3(0, 1.0, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * LAND_RANGE, 1)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit and (hit.normal as Vector3).y > 0.8:
		return hit.position
	return Vector3.INF


func _begin_landing() -> void:
	_land_point = _landing_spot()
	state = State.LANDING
	speed = 0.0


func _land(delta: float) -> void:
	# Level the wings, keep the heading, and settle onto the deck.
	var fwd := -global_transform.basis.z
	var yaw := atan2(-fwd.x, -fwd.z)
	var level := Basis(Vector3.UP, yaw)
	transform.basis = transform.basis.slerp(level, clampf(4.0 * delta, 0.0, 1.0)).orthonormalized()
	global_position.x = move_toward(global_position.x, _land_point.x, 6.0 * delta)
	global_position.z = move_toward(global_position.z, _land_point.z, 6.0 * delta)
	global_position.y = move_toward(global_position.y, _land_point.y, 4.0 * delta)
	if global_position.distance_to(_land_point) < 0.05:
		transform.basis = level
		global_position = _land_point
		state = State.LANDED
		for s in _struts:
			s.visible = true
		_docked_check()


## Landing inside a friendly repair bay restores the hull.
func _docked_check() -> void:
	for bay in get_tree().get_nodes_in_group("repair_bay"):
		if (bay as Node3D).global_position.distance_to(global_position) < float(bay.get_meta("radius", 20.0)):
			hull = MAX_HULL
			_message("Docked — hull repaired")
			get_tree().create_timer(2.5).timeout.connect(func(): _message(""))
			return


func _chase_transform() -> Transform3D:
	var t := global_transform
	t.origin = to_global(Vector3(0, 5.0, 17.0))
	return t.looking_at(to_global(Vector3(0, 2.5, -20.0)), global_transform.basis.y)


func _update_camera(delta: float) -> void:
	var target := _chase_transform()
	var w := 1.0 - exp(-9.0 * delta)
	_camera.global_position = _camera.global_position.lerp(target.origin, w)
	_camera.global_transform.basis = _camera.global_transform.basis.slerp(target.basis, 1.0 - exp(-7.0 * delta)).orthonormalized()
	_camera.fov = lerpf(_camera.fov, 72.0 + (speed / BOOST_SPEED) * 14.0, w)


func _message(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.show_message(text)


# --- damage -------------------------------------------------------------------

func take_damage(amount: float, _from: Vector3) -> bool:
	if hull <= 0.0:
		return false
	hull -= amount
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and _pilot:
		hud.damage_flash()
	if hull > 0.0:
		return false
	Fx.explosion(get_parent(), global_position + Vector3(0, 1.8, 0))
	Fx.explosion(get_parent(), to_global(Vector3(3, 1.8, 0)))
	var p := _pilot
	if p:
		_leave()
		p.call("_die")
	queue_free()
	return true


func on_hit_target(killed: bool) -> void:
	if _pilot:
		_pilot.on_hit_target(killed)


func _exit_tree() -> void:
	var hud := get_tree().get_first_node_in_group("hud") if is_inside_tree() else null
	if hud:
		hud.set_prompt(self, "")
