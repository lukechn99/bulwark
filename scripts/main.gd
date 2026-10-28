extends Node3D
## Boots the game: environment and backdrop, the connectors between zones,
## the player and HUD, then streams in the first zone.

const BRIDGE_DECK := Vector3(0, 300, 0)

var world: Node3D
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
	player.snap_camera()
	player.process_mode = Node.PROCESS_MODE_INHERIT
	if dev.has("autoplay") or dev.has("hold"):
		Player.autoplay = true
	if dev.has("hold"):
		for action in str(dev["hold"]).split(","):
			Input.action_press(action)
	if dev.has("touchdemo"):
		_touch_demo()
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
	env.fog_density = 0.0035
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
	var sky := Node3D.new()
	sky.name = "Backdrop"
	add_child(sky)
	var planet := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1400.0
	sphere.height = 2800.0
	sphere.radial_segments = 96
	sphere.rings = 48
	planet.mesh = sphere
	planet.material_override = Look.planet
	planet.position = Vector3(3000, -400, 300)
	planet.rotation_degrees = Vector3(12, 30, 8)
	planet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sky.add_child(planet)
	var atmosphere := MeshInstance3D.new()
	var shell := SphereMesh.new()
	shell.radius = 1440.0
	shell.height = 2880.0
	shell.radial_segments = 96
	shell.rings = 48
	atmosphere.mesh = shell
	var haze := Look.shield.duplicate() as StandardMaterial3D
	haze.albedo_color = Color(0.3, 0.55, 1.0, 0.18)
	haze.cull_mode = BaseMaterial3D.CULL_FRONT
	atmosphere.material_override = haze
	atmosphere.position = planet.position
	atmosphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sky.add_child(atmosphere)
	Kit.begin(sky)
	for c in [[Vector3(900, 120, -1300), 35.0, 1.0], [Vector3(1500, -60, 400), -60.0, 0.8], [Vector3(700, 260, 900), 200.0, 0.55]]:
		_distant_cruiser(sky, c[0], c[1], c[2])
	Kit.end(100000.0)


## An original wedge-hulled cruiser silhouette with a stepped superstructure.
func _distant_cruiser(parent: Node3D, pos: Vector3, yaw: float, s: float) -> void:
	var ship := Node3D.new()
	ship.position = pos
	ship.rotation_degrees.y = yaw
	ship.scale = Vector3.ONE * s
	parent.add_child(ship)
	var hull := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(120, 40, 360)
	prism.left_to_right = 0.5
	hull.mesh = prism
	hull.material_override = Look.hull
	hull.rotation_degrees = Vector3(-90, 0, 0)
	hull.scale = Vector3(1, 1, 0.5)
	ship.add_child(hull)
	Kit.block(ship, Vector3(30, 26, 60), Vector3(0, 18, 120), Look.hull, false)
	Kit.block(ship, Vector3(14, 12, 24), Vector3(0, 36, 132), Look.hull_dark, false)
	var stripe := Kit.block(ship, Vector3(124, 3, 300), Vector3(0, 0, 10), Look.trim_red, false)
	stripe.scale = Vector3(0.4, 1, 1)
	for x in [-36.0, 0.0, 36.0]:
		var eng := Kit.cylinder(ship, 9.0, 4.0, Vector3(x, 2, 182), Look.engine_glow, false)
		eng.rotation_degrees.x = 90


## Doors and turbolifts sit outside the zones because each joins two of them.
func _connectors() -> void:
	var con := Node3D.new()
	con.name = "Connectors"
	world.add_child(con)
	con.add_child(Door.make(Vector3(-22.25, 0, 0), 90.0, ["hangar", "corridor"]))
	var down := Turbolift.make(Vector3(-64.5, 0, 0), 90.0, "bridge", "Command Bridge")
	var up := Turbolift.make(BRIDGE_DECK + Vector3(-7.5, 0, 0), -90.0, "corridor", "Port Service Corridor")
	down.destination = up
	up.destination = down
	con.add_child(down)
	con.add_child(up)


# --- dev hooks ----------------------------------------------------------------
# Native:  godot --path . -- --spawn=bridge --pose=0,0.1,-10,0,-5 --hold=fire --shot=/tmp/a.png
# Web:     index.html?spawn=corridor
# --spawn   start in a zone (its spawn point)
# --pose    x,y,z,yaw_deg,pitch_deg in world space
# --hold    comma-separated input actions to hold down (implies --autoplay)
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
