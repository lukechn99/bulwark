class_name Prisoner
extends CharacterBody3D
## A captured crew officer in a grey duty uniform. Waits in the cell until it
## opens, then follows the player, keeping a few metres back.

const SPEED := 4.6
const GRAVITY := 19.0

var follow := false
var _legs: Array[Node3D] = []
var _stride := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.75
	shape.shape = capsule
	shape.position.y = 0.875
	add_child(shape)
	var uniform := StandardMaterial3D.new()
	uniform.albedo_color = Color(0.42, 0.44, 0.47)
	uniform.roughness = 0.8
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.72, 0.55, 0.42)
	skin.roughness = 0.7
	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.11, 0.9, 0)
		add_child(hip)
		_capsule(hip, 0.08, 0.88, Vector3(0, -0.45, 0), uniform)
		_legs.append(hip)
		_capsule(self, 0.06, 0.62, Vector3(side * 0.27, 1.22, 0), uniform)
	_capsule(self, 0.2, 0.62, Vector3(0, 1.22, 0), uniform)
	var belt := Kit.block(self, Vector3(0.36, 0.06, 0.24), Vector3(0, 0.95, 0), Look.undersuit, false)
	belt.name = "Belt"
	Kit.block(self, Vector3(0.12, 0.06, 0.02), Vector3(-0.1, 1.42, -0.17), Look.trim_red, false)   # rank bar
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.26
	head.mesh = sphere
	head.material_override = skin
	head.position = Vector3(0, 1.66, 0)
	add_child(head)
	var cap := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.13
	cyl.bottom_radius = 0.135
	cyl.height = 0.08
	cap.mesh = cyl
	cap.material_override = uniform
	cap.position = Vector3(0, 1.77, 0)
	add_child(cap)


func _capsule(parent: Node3D, r: float, h: float, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 10
	m.rings = 2
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	var move := Vector3.ZERO
	var p := Zones.player as Node3D
	if follow and p:
		var to := p.global_position - global_position
		to.y = 0
		if to.length() > 3.0:
			move = to.normalized()
			rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-8.0 * delta))
		# Don't get left behind on a lift ride or a respawn.
		if to.length() > 30.0:
			global_position = p.global_position - to.normalized() * 2.5
	velocity.x = move.x * SPEED
	velocity.z = move.z * SPEED
	move_and_slide()
	var speed := Vector2(velocity.x, velocity.z).length()
	_stride += delta * speed * 2.4
	var swing := sin(_stride) * clampf(speed / SPEED, 0.0, 1.0) * 0.6
	_legs[0].rotation.x = swing
	_legs[1].rotation.x = -swing
