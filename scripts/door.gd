class_name Door
extends Node3D
## A sliding blast door between two zones. It stays shut until the zone on the
## far side has streamed in, so the player never sees an empty void.
##
## Doors live outside the zones (in Main/Connectors) because each one belongs to
## two zones at once. Local X is the door's width; panels slide apart along it.

var zones: Array = []
var width := 3.0
var height := 3.2
var _open := 0.0
var _left: AnimatableBody3D
var _right: AnimatableBody3D
var _lamp: MeshInstance3D


static func make(pos: Vector3, yaw_degrees: float, between: Array, w := 3.0, h := 3.2) -> Door:
	var d := Door.new()
	d.position = pos
	d.rotation_degrees.y = yaw_degrees
	d.zones = between
	d.width = w
	d.height = h
	return d


func _ready() -> void:
	_left = _panel(-1.0)
	_right = _panel(1.0)
	# Header with a status lamp: red while locked or loading, blue when open.
	Kit.block(self, Vector3(width + 0.6, 0.35, 0.7), Vector3(0, height + 0.17, 0), Look.hull_dark, false)
	_lamp = Kit.strip(self, Vector3(width * 0.6, 0.08, 0.72), Vector3(0, height + 0.1, 0), Look.strip_red) as MeshInstance3D
	Zones.register_door(self)


func _panel(side: float) -> AnimatableBody3D:
	var body := AnimatableBody3D.new()
	body.sync_to_physics = false
	body.collision_layer = Kit.WORLD_LAYER
	body.collision_mask = 0
	add_child(body)
	var size := Vector3(width / 2.0, height, 0.3)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(side * width / 4.0, height / 2.0, 0)
	Kit.block(body, size, Vector3.ZERO, Look.hull, false)
	# Red chevron stripe and a light seam on the leading edge.
	Kit.block(body, Vector3(size.x * 0.9, 0.3, 0.34), Vector3(0, -0.2, 0), Look.trim_red, false)
	Kit.strip(body, Vector3(0.05, height * 0.8, 0.34), Vector3(-side * (size.x / 2.0 - 0.04), 0, 0), Look.strip_warm)
	return body


func _physics_process(delta: float) -> void:
	var p := Zones.player
	if not p:
		return
	var near := global_position.distance_to(p.global_position) < 4.5
	if near:
		for id in zones:
			Zones.request(id)
	var ready_to_open := zones.all(func(id): return Zones.is_loaded(id))
	var target := 1.0 if near and ready_to_open else 0.0
	_open = move_toward(_open, target, delta * 2.5)
	var slide := smoothstep(0.0, 1.0, _open) * (width / 2.0 - 0.1)
	_left.position.x = -width / 4.0 - slide
	_right.position.x = width / 4.0 + slide
	_lamp.material_override = Look.strip_blue if ready_to_open else Look.strip_red
