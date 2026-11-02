extends Node3D
## Boots the game: environment and backdrop, the connectors between zones,
## the player and HUD, then streams in the first zone.

const BRIDGE_DECK := Vector3(0, 300, 0)
const PLANET_OFFSET := Vector3(3000, -400, 300)
const FLIGHT_DECK := Vector3(0, 150, 0)
const DETENTION_DECK := Vector3(0, -150, 0)

var world: Node3D
var _planet: Node3D
var player: Player


func _ready() -> void:
	_environment()
	_backdrop()
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	player = Player.new()
	player.name = "Player"
	world.add_child(player)
	Zones.setup(world, player)
	_connectors()
	var hud := preload("res://scripts/hud.gd").new()
	hud.name = "HUD"
	add_child(hud)
	var dev := dev_options()
	var first: String = dev.get("spawn", "hangar")
	if not Zones.ZONES.has(first):
		first = "hangar"
	# The first zone loads before the player is placed in it.
	player.process_mode = Node.PROCESS_MODE_DISABLED
	await Zones.load_now(first)
	var spawn := Zones.spawn_point(first)
	player.global_position = spawn.origin
	player.turn(spawn.basis.get_euler().y)
	if dev.has("pose"):
		var v: PackedFloat64Array = str(dev["pose"]).split_floats(",")
		player.global_position = Vector3(v[0], v[1], v[2])
		player.turn(deg_to_rad(v[3]) - player.yaw)
		player.pitch = deg_to_rad(v[4]) if v.size() > 4 else 0.0
	if dev.has("camyaw"):
		player.yaw += deg_to_rad(float(dev["camyaw"]))   # orbit the camera, not the body
	player.snap_camera()
	player.process_mode = Node.PROCESS_MODE_INHERIT
	if dev.has("autoplay") or dev.has("hold"):
		Player.autoplay = true
	if dev.has("hold"):
		for action in str(dev["hold"]).split(","):
			Input.action_press(action)
	if dev.has("fly") or dev.has("flypose"):
		await get_tree().process_frame
		var ship: PilotFighter = null
		for f in get_tree().get_nodes_in_group("pilotable"):
			if not ship or f.global_position.distance_to(player.global_position) < ship.global_position.distance_to(player.global_position):
				ship = f
		ship._board(player)
		ship._lift_off()
		if dev.has("flypose"):
			var v: PackedFloat64Array = str(dev["flypose"]).split_floats(",")
			ship.global_position = Vector3(v[0], v[1], v[2])
			ship.rotation = Vector3(deg_to_rad(v[4]) if v.size() > 4 else 0.0, deg_to_rad(v[3]), 0)
			ship.state = PilotFighter.State.FLYING
			ship.speed = 40.0
			ship._camera.global_transform = ship._chase_transform()
			if dev.has("land"):
				await get_tree().create_timer(1.0).timeout
				var ev := InputEventAction.new()
				ev.action = "interact"
				ev.pressed = true
				Input.parse_input_event(ev)
	if dev.has("touchdemo"):
		_touch_demo()
	if dev.has("nohud"):
		hud.visible = false
		player.visible = dev.has("showplayer")
	if dev.has("shot"):
		await get_tree().create_timer(float(dev.get("wait", "2.5"))).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(str(dev["shot"]))
		print("[dev] saved ", dev["shot"])
		get_tree().quit()


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Look.star_sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.47, 0.56)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 1.0
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.set_glow_level(1, 1.0)
	env.set_glow_level(3, 1.0)
	env.set_glow_level(5, 0.6)
	env.fog_enabled = true
	env.fog_light_color = Color(0.16, 0.2, 0.28)
	env.fog_density = 0.0008
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# Light from the planet below the hangar mouth: cool, low and from +X.
	var sun := DirectionalLight3D.new()
	sun.add_to_group("sun")
	sun.rotation_degrees = Vector3(-28, 100, 0)
	sun.light_color = Color(0.82, 0.88, 1.0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 90.0
	sun.shadow_bias = 0.05
	add_child(sun)


## Things outside the ship: a planet and distant cruisers of the same fleet.
func _backdrop() -> void:
	# The planet and its atmosphere ride along with the camera, like the sky:
	# always on the horizon, never reachable, so you can't fly into it.
	_planet = Node3D.new()
	_planet.name = "Planet"
	add_child(_planet)
	var planet := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1400.0
	sphere.height = 2800.0
	sphere.radial_segments = 96
	sphere.rings = 48
	planet.mesh = sphere
	var surface := Look.planet.duplicate() as StandardMaterial3D
	surface.disable_fog = true
	planet.material_override = surface
	planet.position = PLANET_OFFSET
	planet.rotation_degrees = Vector3(12, 30, 8)
	planet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_planet.add_child(planet)
	var atmosphere := MeshInstance3D.new()
	var shell := SphereMesh.new()
	shell.radius = 1450.0
	shell.height = 2900.0
	shell.radial_segments = 96
	shell.rings = 48
	atmosphere.mesh = shell
	var haze := Look.shield.duplicate() as StandardMaterial3D
	haze.albedo_color = Color(0.3, 0.55, 1.0, 0.22)
	haze.disable_fog = true
	atmosphere.material_override = haze
	atmosphere.position = PLANET_OFFSET
	atmosphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_planet.add_child(atmosphere)
	# Sister ships of the Bulwark's class holding formation.
	var fleet := Node3D.new()
	fleet.name = "Fleet"
	add_child(fleet)
	for c in [[Vector3(700, 260, -1500), 0.0], [Vector3(-500, 120, 1600), 0.0], [Vector3(1800, 60, 900), 10.0]]:
		var ship := MeshInstance3D.new()
		ship.mesh = ShipModels.sister_ship()
		ship.position = c[0]
		ship.rotation_degrees.y = c[1]
		ship.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fleet.add_child(ship)


## Doors and turbolifts sit outside the zones because each joins two of them.
func _connectors() -> void:
	var con := Node3D.new()
	con.name = "Connectors"
	world.add_child(con)
	con.add_child(Door.make(Vector3(-22.25, 0, 0), 90.0, ["hangar", "corridor"]))
	# The lift hall at the end of the corridor has one lift per deck; each deck
	# has one lift back. You arrive facing the way you walked in, turned by the
	# difference in yaw: hall lifts face into their shafts (-Z), deck lifts face
	# out of theirs.
	_lift_pair(con, Vector3(-72.5, 0, 0), 90.0, BRIDGE_DECK + Vector3(-7.5, 0, 0), -90.0, "bridge", "Command Bridge")
	_lift_pair(con, Vector3(-68.0, 0, -5.5), 0.0, FLIGHT_DECK + Vector3(-66.5, 0, 0), -90.0, "flightdeck", "Dorsal Flight Deck")
	_lift_pair(con, Vector3(-68.0, 0, 5.5), 180.0, DETENTION_DECK + Vector3(-34.5, 0, 0), -90.0, "detention", "Detention Level")


## Every flyable ship's home: [position, yaw in degrees, type]. Ships live
## under Connectors so they survive zone streaming; a destroyed one is replaced
## on its pad after a few seconds.
const FIGHTER_PADS := [
	# Hangar Bay 3 floor.
	[Vector3(7, 0, -15), -90.0, "hammer"], [Vector3(7, 0, 15), -90.0, "warden"], [Vector3(-9, 0, 15), -60.0, "lancer"],
	# Hangar side compartments (facing out into the hangar).
	[Vector3(-12.5, 0, -35.5), 180.0, "lancer"], [Vector3(0.5, 0, -35.5), 180.0, "warden"], [Vector3(13.5, 0, -35.5), 180.0, "lancer"],
	[Vector3(-12.5, 0, 35.5), 0.0, "warden"], [Vector3(0.5, 0, 35.5), 0.0, "lancer"], [Vector3(13.5, 0, 35.5), 0.0, "warden"],
	# Dorsal flight deck.
	[Vector3(-48, 150, -10), -90.0, "warden"], [Vector3(-48, 150, 10), -90.0, "lancer"],
	[Vector3(-26, 150, -10), -90.0, "hammer"], [Vector3(-26, 150, 10), -90.0, "hammer"],
	[Vector3(-4, 150, -10), -90.0, "lancer"], [Vector3(-4, 150, 10), -90.0, "lancer"],
	[Vector3(18, 150, -10), -90.0, "warden"], [Vector3(18, 150, 10), -90.0, "warden"],
	[Vector3(40, 150, -10), -90.0, "hammer"], [Vector3(40, 150, 10), -90.0, "lancer"],
]
var _pad_timers: Array[float] = []


func _process(delta: float) -> void:
	if not is_instance_valid(world):
		return
	var cam := get_viewport().get_camera_3d()
	if cam and _planet:
		_planet.global_position = cam.global_position
	if _pad_timers.is_empty():
		_pad_timers.resize(FIGHTER_PADS.size())
		_pad_timers.fill(0.0)
	var held := {}
	for f in get_tree().get_nodes_in_group("pilotable"):
		held[f.pad] = true
	for i in FIGHTER_PADS.size():
		if held.has(i):
			_pad_timers[i] = 8.0
			continue
		_pad_timers[i] -= delta
		if _pad_timers[i] <= 0.0:
			_pad_timers[i] = 8.0
			var pad: Array = FIGHTER_PADS[i]
			world.get_node("Connectors").add_child(PilotFighter.make(pad[0], deg_to_rad(pad[1]), i, pad[2]))


func _lift_pair(con: Node3D, hall_pos: Vector3, hall_yaw: float, deck_pos: Vector3, deck_yaw: float, deck_zone: String, deck_title: String) -> void:
	var go := Turbolift.make(hall_pos, hall_yaw, deck_zone, deck_title)
	var back := Turbolift.make(deck_pos, deck_yaw, "corridor", "Lift Hall")
	go.destination = back
	back.destination = go
	con.add_child(go)
	con.add_child(back)


# --- dev hooks ----------------------------------------------------------------
# Native:  godot --path . -- --spawn=bridge --pose=0,0.1,-10,0,-5 --hold=fire --shot=/tmp/a.png
# Web:     index.html?spawn=corridor
# --spawn   start in a zone (its spawn point)
# --pose    x,y,z,yaw_deg,pitch_deg in world space
# --hold    comma-separated input actions to hold down (implies --autoplay)
# --camyaw  orbit the camera around the player by this many degrees
# --fly     board a flyable fighter and lift off
# --flypose x,y,z,yaw_deg,pitch_deg: put the boarded fighter in flight there
# --land    with --flypose: press USE after a second to land
# --nohud   hide the HUD and the player (add --showplayer to keep them) for clean shots
# --shot    save a screenshot after --wait seconds (default 2.5) and quit

func dev_options() -> Dictionary:
	var opts := {}
	var args := Array(OS.get_cmdline_user_args())
	if OS.has_feature("web"):
		var search := str(JavaScriptBridge.eval("location.search", true))
		for pair in search.trim_prefix("?").split("&", false):
			args.append("--" + pair)
	for a in args:
		var kv := str(a).trim_prefix("--").split("=", true, 1)
		opts[kv[0]] = kv[1] if kv.size() > 1 else "1"
	return opts


## Simulates a thumb on the joystick, a swipe to look and a held FIRE button.
func _touch_demo() -> void:
	var size := get_viewport().get_visible_rect().size
	var send := func(ev: InputEvent) -> void: Input.parse_input_event(ev)
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.position = Vector2(160, size.y - 160)
	t.pressed = true
	send.call(t)
	for i in 6:
		await get_tree().process_frame
		var d := InputEventScreenDrag.new()
		d.index = 0
		d.position = Vector2(160 + i * 4, size.y - 160 - i * 14)
		send.call(d)
	var f := InputEventScreenTouch.new()
	f.index = 1
	f.position = Vector2(size.x - 120, size.y - 130)
	f.pressed = true
	send.call(f)
	for i in 10:
		await get_tree().process_frame
		var d := InputEventScreenDrag.new()
		d.index = 1
		d.position = f.position + Vector2(-i * 6, 0)
		send.call(d)
