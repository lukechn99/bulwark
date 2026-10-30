extends Node
## Streams the ship in zones. Only the zone the player is in, plus whatever is
## behind a door they are standing near, stays in memory; everything else is
## freed. This is what lets the whole interior be explorable in a browser.
##
## Zones share one world coordinate system, so a loaded neighbour lines up with
## the current zone exactly. Distant decks (the bridge) sit far away in space and
## are reached by turbolift, which hides the load behind a fade.

signal zone_changed(id: String, title: String)
signal streaming_changed(loading: Array)

const ZONES := {
	"hangar": {
		"title": "Hangar Bay 3",
		"scene": "res://scenes/zones/hangar.tscn",
		"bounds": AABB(Vector3(-22.5, -2, -30), Vector3(48, 24, 60)),
	},
	"corridor": {
		"title": "Port Service Corridor",
		"scene": "res://scenes/zones/corridor.tscn",
		"bounds": AABB(Vector3(-75, -1, -8), Vector3(52.5, 8, 16)),
	},
	"bridge": {
		"title": "Command Bridge",
		"scene": "res://scenes/zones/bridge.tscn",
		"bounds": AABB(Vector3(-12, 290, -14), Vector3(54, 24, 28)),
	},
	"flightdeck": {
		"title": "Dorsal Flight Deck",
		"scene": "res://scenes/zones/flightdeck.tscn",
		"bounds": AABB(Vector3(-90, 140, -30), Vector3(170, 60, 60)),
		"keep": ["space"],
	},
	"detention": {
		"title": "Detention Level",
		"scene": "res://scenes/zones/detention.tscn",
		"bounds": AABB(Vector3(-40, -160, -14), Vector3(70, 20, 28)),
	},
	# Everything outside the ship. Listed last: zone_at() checks in order, so
	# this only wins when the player is in no other zone.
	"space": {
		"title": "Open Space",
		"scene": "res://scenes/zones/space.tscn",
		"bounds": AABB(Vector3(-2600, -500, -2600), Vector3(5200, 1800, 5200)),
		"keep": ["flightdeck"],
	},
}

## How close the player must be to a door for the zone behind it to stay loaded.
const DOOR_HOLD_RADIUS := 14.0

var world: Node3D
var player: Node3D
var doors: Array[Node3D] = []
var loaded: Dictionary = {}    # id -> Node3D
var loading: Dictionary = {}   # id -> true
var pinned: Dictionary = {}    # ids held by a turbolift trip
var current := ""
var _tick := 0.0


func setup(world_root: Node3D, player_node: Node3D) -> void:
	world = world_root
	player = player_node


func register_door(door: Node3D) -> void:
	doors.append(door)


func is_loaded(id: String) -> bool:
	return loaded.has(id)


func zone_node(id: String) -> Node3D:
	return loaded.get(id)


func title(id: String) -> String:
	return ZONES[id]["title"] if ZONES.has(id) else ""


## Ask for a zone; it streams in over the next frames.
func request(id: String) -> void:
	if loaded.has(id) or loading.has(id) or not ZONES.has(id):
		return
	ResourceLoader.load_threaded_request(ZONES[id]["scene"], "PackedScene")
	loading[id] = true
	streaming_changed.emit(loading.keys())


## Load a zone right now (used at startup and behind turbolift fades).
func load_now(id: String) -> Node3D:
	request(id)
	while not loaded.has(id):
		_poll()
		if not loaded.has(id):
			await get_tree().process_frame
	return loaded[id]


func pin(id: String) -> void:
	pinned[id] = true
	request(id)


func unpin(id: String) -> void:
	pinned.erase(id)


func zone_at(p: Vector3) -> String:
	for id in ZONES:
		if (ZONES[id]["bounds"] as AABB).has_point(p):
			return id
	return ""


func spawn_point(id: String) -> Transform3D:
	var z := zone_node(id)
	if z and z.has_node("Spawn"):
		return (z.get_node("Spawn") as Node3D).global_transform
	return Transform3D(Basis(), Vector3(0, 1, 0))


func _process(delta: float) -> void:
	_poll()
	if not player:
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.25
	var here := zone_at(player.global_position)
	if here != "" and here != current:
		current = here
		zone_changed.emit(here, title(here))
	var keep := pinned.duplicate()
	if current != "":
		keep[current] = true
		for id in ZONES[current].get("keep", []):
			keep[id] = true
	for door in doors:
		if door.global_position.distance_to(player.global_position) < DOOR_HOLD_RADIUS:
			for id in door.zones:
				keep[id] = true
	for id in keep:
		request(id)
	for id in loaded.keys():
		if not keep.has(id):
			_unload(id)


func _poll() -> void:
	for id in loading.keys():
		var path: String = ZONES[id]["scene"]
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var scene := ResourceLoader.load_threaded_get(path) as PackedScene
			var node := scene.instantiate() as Node3D
			node.name = id.capitalize()
			world.add_child(node)
			loaded[id] = node
			loading.erase(id)
			streaming_changed.emit(loading.keys())
			print("[zones] loaded ", id)
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("Zone failed to load: %s" % id)
			loading.erase(id)
			streaming_changed.emit(loading.keys())


func _unload(id: String) -> void:
	var node: Node3D = loaded[id]
	loaded.erase(id)
	node.queue_free()
	print("[zones] unloaded ", id)
