extends Node3D
## Port Service Corridor: 40 m of ribbed corridor from the hangar's blast door
## to a turbolift lobby. Niches with consoles break up the run and give cover.
##
## Runs along -X from x = -22.5 (hangar wall) to the lift hall (x -62.5..-74).

const START := -22.5
const SEGMENT := 8.0
const SEGMENTS := 5


func _ready() -> void:
	Kit.begin(self)
	for i in SEGMENTS:
		Kit.corridor_segment(self, START - i * SEGMENT, SEGMENT)
	_door_frame()
	_lobby()
	_dressing()
	Kit.end()
	SentryDrone.spawn(self, Vector3(-41, 1.8, 0.5))
	SentryDrone.spawn(self, Vector3(-56, 1.8, -0.5))
	var spawn := Marker3D.new()
	spawn.name = "Spawn"
	spawn.position = Vector3(-26, 0.1, 0)
	spawn.rotation.y = deg_to_rad(90)
	add_child(spawn)


func _door_frame() -> void:
	# Fill between the 4 m corridor and the 3 m x 3.2 m door.
	for side in [-1.0, 1.0]:
		Kit.block(self, Vector3(0.3, 4.0, 0.5), Vector3(START - 0.15, 2.0, side * 1.75), Look.hull_dark)
	Kit.block(self, Vector3(0.3, 0.8, 4.0), Vector3(START - 0.15, 3.6, 0), Look.hull_dark)
	Kit.strip(self, Vector3(0.05, 0.08, 3.0), Vector3(START - 0.32, 3.25, 0), Look.strip_warm)


## The lift hall: a taller room at the corridor's end with one turbolift per
## deck. Bridge straight ahead; flight deck to the left; detention to the right.
## Room: x -74..-62.5, z -7..7, ceiling 5.
func _lobby() -> void:
	var x0 := START - SEGMENTS * SEGMENT   # -62.5
	var x1 := -74.0
	var cx := (x0 + x1) / 2.0
	var w := x0 - x1
	var h := 5.0
	Kit.block(self, Vector3(w, 0.3, 14.5), Vector3(cx, -0.15, 0), Look.floor_mat)
	Kit.block(self, Vector3(w, 0.3, 14.5), Vector3(cx, h + 0.15, 0), Look.hull_dark)
	Kit.strip(self, Vector3(w - 2.0, 0.04, 1.2), Vector3(cx, h - 0.02, 0), Look.strip_warm)
	# Entry wall around the 4 m corridor mouth, end wall, side walls.
	for side in [-1.0, 1.0]:
		Kit.block(self, Vector3(0.5, h, 5.0), Vector3(x0 - 0.25, h / 2.0, side * 4.5), Look.hull)
	Kit.block(self, Vector3(0.5, h - 4.0, 4.0), Vector3(x0 - 0.25, 4.5, 0), Look.hull)
	Kit.block(self, Vector3(0.5, h, 14.5), Vector3(x1 - 0.25, h / 2.0, 0), Look.hull)
	for side in [-1.0, 1.0]:
		Kit.block(self, Vector3(w, h, 0.5), Vector3(cx, h / 2.0, side * 7.25), Look.hull)
		Kit.block(self, Vector3(w, 0.16, 0.06), Vector3(cx, 1.15, side * 6.98), Look.trim_red, false)
		Kit.block(self, Vector3(w, 0.7, 0.1), Vector3(cx, 0.35, side * 6.95), Look.hull_dark, false)
	# A floor ring and a round light in the middle of the hall.
	Kit.strip(self, Vector3(5.0, 0.02, 0.15), Vector3(cx, 0.01, 0), Look.strip_blue)
	Kit.strip(self, Vector3(0.15, 0.02, 5.0), Vector3(cx, 0.01, 0), Look.strip_blue)
	# Lift alcoves with lit frames and deck signs.
	_lift_frame(Vector3(x1, 0, 0), deg_to_rad(90), "COMMAND BRIDGE")
	_lift_frame(Vector3(-68.0, 0, -7.0), 0.0, "FLIGHT DECK")
	_lift_frame(Vector3(-68.0, 0, 7.0), PI, "DETENTION LEVEL")
	Kit.omni(self, Vector3(cx, 3.8, 0), Color(1.0, 0.95, 0.88), 1.8, 12.0)


## A lit frame on a wall. `at` is the wall surface, `yaw` turns the frame so
## its local -Z points into the wall (the same convention as Turbolift).
func _lift_frame(at: Vector3, yaw: float, sign_text: String) -> void:
	var f := Node3D.new()
	f.position = at
	f.rotation.y = yaw
	add_child(f)
	Kit.strip(f, Vector3(2.2, 3.2, 0.06), Vector3(0, 1.8, 0.02), Look.screen_blue)
	for side in [-1.0, 1.0]:
		Kit.block(f, Vector3(0.4, 4.0, 0.6), Vector3(side * 1.35, 2.0, 0.3), Look.hull_dark)
		Kit.strip(f, Vector3(0.05, 3.0, 0.05), Vector3(side * 1.12, 1.7, 0.62), Look.strip_blue)
	Kit.block(f, Vector3(3.1, 0.5, 0.6), Vector3(0, 4.25, 0.3), Look.hull_dark)
	var label := Label3D.new()
	label.text = sign_text
	label.font_size = 64
	label.pixel_size = 0.004
	label.modulate = Color(0.75, 0.9, 1.0)
	label.outline_size = 0
	label.position = Vector3(0, 4.25, 0.62)
	f.add_child(label)
	Kit.omni(f, Vector3(0, 3.0, 1.6), Look.STRIP_BLUE, 1.2, 5.0)


func _dressing() -> void:
	# Console niches on alternating sides and low crates to duck behind.
	Kit.console(self, Vector3(-31, 0, -1.55), 0.0)
	Kit.console(self, Vector3(-47, 0, 1.55), PI)
	Kit.crate(self, Vector3(-36, 0.5, 1.2), Vector3(1.0, 1.0, 1.0), 0.2)
	Kit.crate(self, Vector3(-44, 0.5, -1.2), Vector3(1.0, 1.0, 1.0), -0.1)
	Kit.crate(self, Vector3(-52, 0.5, 1.0), Vector3(1.4, 1.0, 1.0), 0.0)
	# Red warning lamps by the lobby.
	for side in [-1.0, 1.0]:
		Kit.strip(self, Vector3(0.3, 0.3, 0.05), Vector3(-61.5, 3.0, side * 1.86), Look.strip_red)
