extends Node3D
## Port Service Corridor: 40 m of ribbed corridor from the hangar's blast door
## to a turbolift lobby. Niches with consoles break up the run and give cover.
##
## Runs along -X from x = -22.5 (hangar wall) to x = -67 (lobby end wall).

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


func _lobby() -> void:
	var x0 := START - SEGMENTS * SEGMENT   # -62.5
	Kit.corridor_segment(self, x0, 4.5, 2.0, 4.0, false)
	var end := x0 - 4.5
	Kit.block(self, Vector3(0.5, 4.0, 5.0), Vector3(end - 0.25, 2.0, 0), Look.hull)
	# Lift shaft surround: a lit frame on the end wall and over the pad.
	Kit.strip(self, Vector3(0.06, 3.2, 2.2), Vector3(end + 0.02, 1.8, 0), Look.screen_blue)
	for side in [-1.0, 1.0]:
		Kit.block(self, Vector3(0.6, 4.0, 0.4), Vector3(end + 0.4, 2.0, side * 1.3), Look.hull_dark)
		Kit.strip(self, Vector3(0.05, 3.0, 0.05), Vector3(end + 0.72, 1.7, side * 1.1), Look.strip_blue)
	Kit.cylinder(self, 1.15, 0.12, Vector3(-64.5, 3.94, 0), Look.strip_blue, false)
	Kit.omni(self, Vector3(-64.5, 3.0, 0), Look.STRIP_BLUE, 1.8, 6.0)


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
