extends Node3D
## Open Space around the Bulwark, for fighter flight.
##
## - The frigate Steadfast holds station off the starboard bow. Land in its
##   lit side bay to repair your fighter.
## - An enemy corvette lurks above the port quarter: destroy its four reactor
##   pods while its flak guns and escort fighters defend it.
##
## Built in world coordinates (this zone's origin is the world origin).

const FRIGATE_AT := Vector3(420, 170, -420)
const CORVETTE_AT := Vector3(-200, 240, 720)
const ESCORTS := 3

var _corvette: Node3D
var _pods_left := 0
var _escort_timer := 3.0


func _ready() -> void:
	_bulwark_hull()
	Kit.begin(self)
	_frigate()
	Kit.end(60.0)
	_build_corvette()
	var spawn := Marker3D.new()
	spawn.name = "Spawn"
	spawn.position = Vector3(-62, 150.1, 0)
	spawn.rotation.y = deg_to_rad(-90)
	add_child(spawn)


## The outside of our own ship. The interior zones sit inside it.
func _bulwark_hull() -> void:
	var hull: Array = ShipModels.bulwark_hull()
	var mi := MeshInstance3D.new()
	mi.name = "BulwarkHull"
	mi.mesh = hull[0]
	# The keel would otherwise shade the hangar from the planet light.
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	add_child(_collider(hull[1]))


static func _collider(faces: PackedVector3Array) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Kit.WORLD_LAYER
	body.collision_mask = 0
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	return body


func _process(delta: float) -> void:
	if not is_instance_valid(_corvette):
		return
	var escorts := 0
	for c in get_children():
		if c is EnemyFighter:
			escorts += 1
	if escorts >= ESCORTS:
		return
	_escort_timer -= delta
	if _escort_timer <= 0.0:
		_escort_timer = 8.0
		var c := CORVETTE_AT
		var r := randf_range(110.0, 160.0)
		var path: Array[Vector3] = []
		for i in 6:
			var a := i * TAU / 6.0 + randf() * 0.3
			path.append(c + Vector3(cos(a) * r, randf_range(-30.0, 40.0), sin(a) * r))
		path.insert(3, Vector3(-62, 175, 0))   # one strafing pass at the flight deck per loop
		EnemyFighter.launch(self, path, 0)


# --- friendly frigate ---------------------------------------------------------

func _frigate() -> void:
	var f := Node3D.new()
	f.name = "Steadfast"
	f.position = FRIGATE_AT
	f.rotation.y = deg_to_rad(15)
	add_child(f)
	# Sculpted hull fore and aft of the bay (see ShipModels.frigate).
	var hull: Array = ShipModels.frigate()
	var mi := MeshInstance3D.new()
	mi.mesh = hull[0]
	f.add_child(mi)
	f.add_child(_collider(hull[1]))
	# The repair bay: a 44 x 12 x 30 room open to space on the -Z side.
	Kit.block(f, Vector3(44, 10, 32), Vector3(0, -5, 0), Look.hull)              # under the floor
	Kit.block(f, Vector3(44, 0.4, 30), Vector3(0, -0.2, 0), Look.floor_mat)      # floor
	Kit.block(f, Vector3(44, 8, 32), Vector3(0, 16, 0), Look.hull)               # roof
	Kit.block(f, Vector3(44, 12, 1), Vector3(0, 6, 15.5), Look.hull)             # back wall
	for x in [-22.5, 22.5]:
		Kit.block(f, Vector3(1, 12, 30), Vector3(x, 6, 0), Look.hull_dark)
	Kit.strip(f, Vector3(40, 0.1, 0.4), Vector3(0, 11.9, -14), Look.strip_blue)
	Kit.strip(f, Vector3(40, 0.05, 0.4), Vector3(0, 0.02, -14), Look.strip_blue)
	for x in [-12.0, 0.0, 12.0]:
		Kit.strip(f, Vector3(6, 0.04, 6), Vector3(x, 0.02, 2), Look.screen_blue)
		Kit.strip(f, Vector3(4, 0.08, 1.2), Vector3(x, 11.9, 2), Look.strip_warm)
	var sign := Label3D.new()
	sign.text = "REPAIR BAY"
	sign.font_size = 96
	sign.pixel_size = 0.04
	sign.modulate = Color(0.6, 0.85, 1.0)
	sign.position = f.position + f.basis * Vector3(0, 14, -16.2)
	sign.rotation.y = f.rotation.y + PI
	add_child(sign)
	var bay := Node3D.new()
	bay.add_to_group("repair_bay")
	bay.set_meta("radius", 26.0)
	f.add_child(bay)
	bay.position = Vector3(0, 1, 0)
	var light := Kit.omni(f, Vector3(0, 9, 0), Color(0.9, 0.95, 1.0), 2.5, 30.0)
	light.shadow_enabled = false


# --- enemy corvette -----------------------------------------------------------

func _build_corvette() -> void:
	_corvette = Node3D.new()
	_corvette.name = "Corvette"
	_corvette.position = CORVETTE_AT
	_corvette.rotation.y = deg_to_rad(-30)
	add_child(_corvette)
	var hull: Array = ShipModels.corvette()
	var mi := MeshInstance3D.new()
	mi.mesh = hull[0]
	_corvette.add_child(mi)
	_corvette.add_child(_collider(hull[1]))
	# Four reactor pods on pylons: the weak points.
	for spot in [Vector3(-20, 15, 0), Vector3(-20, -15, 0), Vector3(20, 0, 15), Vector3(20, 0, -15)]:
		var dir: Vector3 = spot.normalized() * Vector3(0, 1, 1)
		Kit.block(_corvette, Vector3(3, 3, 3) + dir.abs() * 9.0, Vector3(spot.x, 0, 0) + Vector3(0, spot.y, spot.z) * 0.5, Look.hull_dark)
		var pod := Pod.new()
		pod.position = spot
		pod.destroyed.connect(_on_pod_destroyed)
		_corvette.add_child(pod)
		_pods_left += 1
	# Flak guns along the spine.
	for spot in [Vector3(55, 5, 0), Vector3(-55, 5, 0), Vector3(0, -5, 0), Vector3(55, -5, 0)]:
		var gun := Flak.new()
		gun.position = spot
		_corvette.add_child(gun)
	var beacon := Kit.omni(_corvette, Vector3(0, 20, 0), Color(1.0, 0.45, 0.2), 3.0, 60.0)
	beacon.shadow_enabled = false


func _on_pod_destroyed() -> void:
	_pods_left -= 1
	var hud := get_tree().get_first_node_in_group("hud")
	if _pods_left > 0:
		if hud:
			hud.show_message("Reactor pod destroyed — %d left" % _pods_left)
			get_tree().create_timer(2.0).timeout.connect(func(): if is_instance_valid(hud): hud.show_message(""))
		return
	# Chain of explosions down the spine, then it's gone.
	for i in 8:
		if not is_instance_valid(_corvette):
			return
		Fx.explosion(self, _corvette.to_global(Vector3(randf_range(-75, 85), randf_range(-8, 8), randf_range(-12, 12))))
		await get_tree().create_timer(0.18).timeout
	if is_instance_valid(_corvette):
		_corvette.queue_free()
	var p := Zones.player as Player
	if p:
		p.kills += 5
	if hud:
		hud.show_message("Enemy corvette destroyed")
		get_tree().create_timer(3.0).timeout.connect(func(): if is_instance_valid(hud): hud.show_message(""))


## A glowing reactor pod. Shoot it until it bursts.
class Pod extends StaticBody3D:
	signal destroyed
	var health := 120.0
	var _mesh: MeshInstance3D

	func _ready() -> void:
		collision_layer = 4
		collision_mask = 0
		var shape := CollisionShape3D.new()
		var s := SphereShape3D.new()
		s.radius = 3.6
		shape.shape = s
		add_child(shape)
		_mesh = MeshInstance3D.new()
		var m := SphereMesh.new()
		m.radius = 3.2
		m.height = 6.4
		_mesh.mesh = m
		_mesh.material_override = Look.droid_eye
		add_child(_mesh)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.55, 0.2)
		l.light_energy = 2.0
		l.omni_range = 18.0
		add_child(l)

	func _process(_delta: float) -> void:
		_mesh.scale = Vector3.ONE * (1.0 + sin(Time.get_ticks_msec() / 200.0) * 0.06)

	func take_damage(amount: float, _from: Vector3) -> bool:
		if health <= 0.0:
			return false
		health -= amount
		if health > 0.0:
			return false
		Fx.explosion(get_parent(), global_position)
		destroyed.emit()
		queue_free()
		return true


## A flak gun that fires red bursts at the player's fighter when in range.
class Flak extends Node3D:
	const RANGE := 420.0
	var _cooldown := randf_range(0.5, 1.5)

	func _ready() -> void:
		Kit.cylinder(self, 1.6, 1.4, Vector3.ZERO, Look.hull_dark, false, 12)
		Kit.block(self, Vector3(0.5, 0.5, 4), Vector3(0, 0.9, -1.5), Look.metal, false)

	func _process(delta: float) -> void:
		var p := Zones.player as Node3D
		if not p or not Player.is_playing():
			return
		var to := p.global_position - global_position
		if to.length() > RANGE:
			return
		_cooldown -= delta
		if _cooldown > 0.0:
			return
		_cooldown = randf_range(0.5, 0.9)
		var spread := 0.05
		var dir := (to.normalized() + Vector3(randf_range(-spread, spread), randf_range(-spread, spread), randf_range(-spread, spread))).normalized()
		Bolt.fire(get_tree().current_scene, global_position + dir * 3.0, dir, null, Look.bolt_red, 6.0, 180.0, 2.0)
