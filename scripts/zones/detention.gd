extends Node3D
## Detention Level: a guard station by the lift, then a long cell block with
## energy-field doors. A squad of droids holds the block; the guard console
## drops every field, and the prisoner inside follows you out.
##
## Built around its own origin (Main.DETENTION_DECK). Guard room x -38..-24,
## z -8..8; cell hall x -24..28, z -3..3; cells reach z ±7.

const CELL := 6.0
const CELLS := 8
const HALL_X0 := -24.0
const HALL_X1 := 28.0
const PRISONER_CELL := 5

var _fields: Array[Node3D] = []
var _released := false
var _rescued := false
var _prisoner: Prisoner


func _ready() -> void:
	position = Vector3(0, -150, 0)
	Kit.begin(self)
	_guard_room()
	_hall()
	Kit.end()
	_cells_fields()
	_lights()
	_prisoner = Prisoner.new()
	_prisoner.position = Vector3(HALL_X0 + 2.0 + PRISONER_CELL * CELL + CELL / 2.0, 0.1, 5.4)
	_prisoner.rotation.y = 0.0
	add_child(_prisoner)
	AssaultDroid.spawn_squad(self, Vector3(4, 0.1, 0), 3, "cells", deg_to_rad(90))
	AssaultDroid.spawn_squad(self, Vector3(22, 0.1, 0), 2, "cells-far", deg_to_rad(90))
	var spawn := Marker3D.new()
	spawn.name = "Spawn"
	spawn.position = Vector3(-31, 0.1, 0)
	spawn.rotation.y = deg_to_rad(-90)
	add_child(spawn)


func _guard_room() -> void:
	var x0 := -38.0
	var x1 := HALL_X0
	var cx := (x0 + x1) / 2.0
	var h := 4.5
	Kit.block(self, Vector3(x1 - x0, 0.3, 16.5), Vector3(cx, -0.15, 0), Look.floor_mat)
	Kit.block(self, Vector3(x1 - x0, 0.3, 16.5), Vector3(cx, h + 0.15, 0), Look.hull_dark)
	Kit.block(self, Vector3(0.5, h, 16.5), Vector3(x0 - 0.25, h / 2.0, 0), Look.hull)
	for side in [-1.0, 1.0]:
		Kit.block(self, Vector3(x1 - x0, h, 0.5), Vector3(cx, h / 2.0, side * 8.25), Look.hull)
		Kit.block(self, Vector3(x1 - x0, 0.16, 0.06), Vector3(cx, 1.15, side * 7.98), Look.trim_red, false)
		# Wall either side of the 6 m opening into the cell hall.
		Kit.block(self, Vector3(0.5, h, 5.0), Vector3(x1 + 0.25, h / 2.0, side * 5.5), Look.hull)
	Kit.block(self, Vector3(0.5, h - 4.0, 6.0), Vector3(x1 + 0.25, 4.25, 0), Look.hull)
	Kit.strip(self, Vector3(x1 - x0 - 2.0, 0.04, 1.0), Vector3(cx, h - 0.02, 0), Look.strip_warm)
	# The guard desk: a curved bank of consoles facing the cell block door.
	for i in 3:
		Kit.console(self, Vector3(-29.5, 0, -2.0 + i * 2.0), deg_to_rad(-90), Look.screen_amber if i == 1 else Look.screen_blue)
	Kit.strip(self, Vector3(2.5, 0.03, 2.0), Vector3(-27.6, 0.02, 0), Look.strip_red)
	# Lift frame on the aft wall.
	var f := Node3D.new()
	f.position = Vector3(x0, 0, 0)
	f.rotation.y = deg_to_rad(90)
	add_child(f)
	Kit.strip(f, Vector3(2.2, 3.2, 0.06), Vector3(0, 1.8, 0.02), Look.screen_blue)
	for side in [-1.0, 1.0]:
		Kit.block(f, Vector3(0.4, 4.0, 0.6), Vector3(side * 1.35, 2.0, 0.3), Look.hull_dark)
	# Weapon racks and lockers.
	for z in [-6.8, 6.8]:
		for x in [-36.0, -33.5]:
			Kit.block(self, Vector3(1.8, 2.4, 0.6), Vector3(x, 1.2, z), Look.hull_dark)
			Kit.strip(self, Vector3(1.4, 0.06, 0.62), Vector3(x, 2.0, z), Look.strip_blue)


func _hall() -> void:
	var cx := (HALL_X0 + HALL_X1) / 2.0
	var length := HALL_X1 - HALL_X0
	var h := 4.0
	Kit.block(self, Vector3(length, 0.3, 15.0), Vector3(cx, -0.15, 0), Look.floor_mat)
	Kit.strip(self, Vector3(length, 0.02, 1.2), Vector3(cx, 0.005, 0), Look.grate)
	Kit.block(self, Vector3(length, 0.3, 15.0), Vector3(cx, h + 0.15, 0), Look.hull_dark)
	Kit.block(self, Vector3(0.5, h, 15.0), Vector3(HALL_X1 + 0.25, h / 2.0, 0), Look.hull)
	for side in [-1.0, 1.0]:
		Kit.block(self, Vector3(length, h, 0.5), Vector3(cx, h / 2.0, side * 7.25), Look.hull_dark)
		# Cell dividers, door pillars with red lamps, and a bunk in each cell.
		for i in CELLS + 1:
			var x := HALL_X0 + 2.0 + i * CELL
			Kit.block(self, Vector3(0.4, h, 4.0), Vector3(x, h / 2.0, side * 5.0), Look.hull)
			Kit.block(self, Vector3(0.7, h, 0.6), Vector3(x, h / 2.0, side * 3.1), Look.hull_dark)
			Kit.strip(self, Vector3(0.1, 2.6, 0.62), Vector3(x, 1.6, side * 3.1), Look.strip_red)
		for i in CELLS:
			var x := HALL_X0 + 2.0 + i * CELL + CELL / 2.0
			Kit.block(self, Vector3(3.0, 0.5, 1.0), Vector3(x, 0.45, side * 6.4), Look.hull_dark)
			Kit.strip(self, Vector3(2.0, 0.06, 0.06), Vector3(x, 3.6, side * 6.9), Look.strip_blue)
		# Lintel above the cell doors.
		Kit.block(self, Vector3(length, 0.8, 0.6), Vector3(cx, h - 0.4, side * 3.1), Look.hull_dark)
	Kit.strip(self, Vector3(length - 1.0, 0.04, 0.4), Vector3(cx, h - 0.02, 0), Look.strip_warm)
	# Low barricades in the hall for cover.
	for p in [Vector3(-12, 0.5, 1.4), Vector3(0, 0.5, -1.4), Vector3(13, 0.5, 1.2)]:
		Kit.crate(self, p, Vector3(1.6, 1.0, 0.8))


func _cells_fields() -> void:
	for side in [-1.0, 1.0]:
		for i in CELLS:
			var x := HALL_X0 + 2.0 + i * CELL + CELL / 2.0
			var field := Node3D.new()
			field.position = Vector3(x, 0, side * 3.1)
			add_child(field)
			var quad := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(CELL - 0.7, 3.2)
			quad.mesh = q
			quad.material_override = Look.energy_field
			quad.position.y = 1.6
			quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			field.add_child(quad)
			Kit.barrier(field, Vector3(CELL - 0.7, 3.2, 0.3), Vector3(0, 1.6, 0))
			_fields.append(field)


func _lights() -> void:
	Kit.omni(self, Vector3(-31, 3.6, 0), Color(1.0, 0.95, 0.88), 1.6, 12.0)
	for i in 4:
		Kit.omni(self, Vector3(HALL_X0 + 6.0 + i * 13.0, 3.4, 0), Color(1.0, 0.8, 0.75), 1.3, 11.0)
	Kit.omni(self, Vector3(-27.6, 1.5, 0), Color(1.0, 0.6, 0.3), 0.8, 4.0)


func _process(_delta: float) -> void:
	var p := Zones.player as Node3D
	var hud := get_tree().get_first_node_in_group("hud")
	if not p or not hud:
		return
	var near := not _released and p.global_position.distance_to(to_global(Vector3(-27.6, 0, 0))) < 1.8
	var key := "[USE]" if Player.autoplay else "[E]"
	hud.set_prompt(self, "%s  Release the cell block" % key if near else "")
	if near and Input.is_action_just_pressed("interact"):
		_release(hud)
	# The rescue completes when the prisoner reaches the lift.
	if _released and not _rescued and is_instance_valid(_prisoner):
		if _prisoner.position.distance_to(Vector3(-34.5, 0.1, 0)) < 3.0:
			_rescued = true
			_prisoner.follow = false
			var tw := _prisoner.create_tween()
			tw.tween_property(_prisoner, "scale", Vector3(1, 0.01, 1), 0.6)
			tw.tween_callback(_prisoner.queue_free)
			hud.show_message("Prisoner rescued")
			await get_tree().create_timer(3.0).timeout
			if is_instance_valid(hud):
				hud.show_message("")


func _release(hud: Node) -> void:
	_released = true
	hud.set_prompt(self, "")
	for f in _fields:
		var quad := f.get_child(0) as MeshInstance3D
		var tw := f.create_tween()
		tw.tween_property(quad, "scale:y", 0.0, 0.4)
		tw.tween_callback(f.queue_free)
	_prisoner.follow = true
	hud.show_message("Cell block open — get the prisoner to the lift")
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(hud):
		hud.show_message("")


func _exit_tree() -> void:
	var hud := get_tree().get_first_node_in_group("hud") if is_inside_tree() else null
	if hud:
		hud.set_prompt(self, "")
