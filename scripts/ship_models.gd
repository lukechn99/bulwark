class_name ShipModels
extends RefCounted
## Sculpted meshes and flight stats for every ship in the game. All designs are
## original. Small craft face -Z with their landing gear on y = 0; capital
## ships are built in world space.
##
## Meshes are built once and cached, so a hangar full of fighters shares a
## handful of meshes.

## Flyable craft. Speeds in m/s; turn is look sensitivity; guns are muzzle
## points; box is the collision box (centred at y = box_y); cam is how far
## back the chase camera sits.
const TYPES := {
	"lancer": {
		"title": "Lancer interceptor", "min": 18.0, "max": 85.0, "boost": 135.0,
		"turn": 1.45, "roll": 2.8, "hull": 70.0, "fire": 0.11, "damage": 11.0, "bolt": 1.6,
		"guns": [Vector3(-0.45, 1.45, -3.6), Vector3(0.45, 1.45, -3.6)],
		"box": Vector3(8.4, 1.3, 10.0), "box_y": 1.8, "cam": 15.0,
		"gear": [Vector3(-0.7, 1.3, 1.6), Vector3(0.7, 1.3, 1.6), Vector3(0, 1.3, -2.6)],
	},
	"warden": {
		"title": "Warden fighter", "min": 14.0, "max": 70.0, "boost": 115.0,
		"turn": 1.25, "roll": 2.2, "hull": 110.0, "fire": 0.14, "damage": 15.0, "bolt": 2.0,
		"guns": [Vector3(-5.0, 1.95, -1.3), Vector3(5.0, 1.95, -1.3)],
		"box": Vector3(10.4, 1.6, 12.0), "box_y": 1.95, "cam": 17.0,
		"gear": [Vector3(-1.1, 1.3, 2.4), Vector3(1.1, 1.3, 2.4), Vector3(0, 1.3, -3.0)],
	},
	"hammer": {
		"title": "Hammer bomber", "min": 10.0, "max": 52.0, "boost": 82.0,
		"turn": 0.85, "roll": 1.5, "hull": 220.0, "fire": 0.34, "damage": 40.0, "bolt": 3.0,
		"guns": [Vector3(-1.5, 1.7, -4.8), Vector3(1.5, 1.7, -4.8)],
		"box": Vector3(13.6, 2.2, 13.4), "box_y": 2.0, "cam": 22.0,
		"gear": [Vector3(-2.0, 1.15, 3.0), Vector3(2.0, 1.15, 3.0), Vector3(-1.4, 1.15, -3.6), Vector3(1.4, 1.15, -3.6)],
	},
}

static var _cache := {}


static func ship(type: String) -> ArrayMesh:
	var key := "ship:" + type
	if not _cache.has(key):
		var b := ShipBuilder.new()
		match type:
			"lancer": _lancer(b)
			"hammer": _hammer(b)
			"enemy": _enemy(b)
			_: _warden(b)
		_cache[key] = b.commit()
	return _cache[key]


static func gear(type: String) -> ArrayMesh:
	var key := "gear:" + type
	if not _cache.has(key):
		var b := ShipBuilder.new()
		for p: Vector3 in TYPES[type]["gear"]:
			b.tube(0.09, 0.07, p.y, Vector3(p.x, p.y / 2.0, p.z), Look.metal, Vector3.UP, 8)
			b.sphere(0.2, Vector3(p.x, 0.08, p.z), Look.hull_dark, Vector3(1, 0.4, 1.4), Vector3.ZERO, 10)
		_cache[key] = b.commit()
	return _cache[key]


# --- small craft --------------------------------------------------------------

## Lancer: a slim needle with forward-swept wings, twin engine pods and blue
## wingtips. Built for speed.
static func _lancer(b: ShipBuilder) -> void:
	var white := Look.ship_white
	b.loft([ShipBuilder.zring(4.6, 1.8, 0.3, 0.3), ShipBuilder.zring(3.6, 1.8, 0.55, 0.55), ShipBuilder.zring(1.0, 1.82, 0.66, 0.62),
		ShipBuilder.zring(-1.5, 1.78, 0.58, 0.52), ShipBuilder.zring(-3.6, 1.72, 0.36, 0.33), ShipBuilder.zring(-5.4, 1.68, 0.05, 0.05)], white)
	b.loft([ShipBuilder.zring(0.2, 1.82, 0.675, 0.635), ShipBuilder.zring(0.8, 1.82, 0.68, 0.64)], Look.armor_stripe, true, false, false)
	b.sphere(0.5, Vector3(0, 2.2, -1.5), Look.canopy, Vector3(0.85, 0.75, 2.2))
	for s in [-1.0, 1.0]:
		var inner := [ShipBuilder.xring(s * 0.45, 1.8, 1.9, 1.5, 0.14), ShipBuilder.xring(s * 2.6, 1.7, 1.15, 0.95, 0.1)]
		var outer := [inner[1], ShipBuilder.xring(s * 4.1, 1.55, 0.35, 0.42, 0.06)]
		b.loft(inner, white)
		b.loft(outer, Look.armor_stripe)
		var pod := [ShipBuilder.zring(5.2, 1.75, 0.26, 0.26, 2.0, 12, s * 0.95), ShipBuilder.zring(4.5, 1.75, 0.42, 0.42, 2.0, 12, s * 0.95),
			ShipBuilder.zring(2.2, 1.75, 0.4, 0.4, 2.0, 12, s * 0.95), ShipBuilder.zring(1.2, 1.75, 0.12, 0.12, 2.0, 12, s * 0.95)]
		b.loft(pod, Look.ship_grey)
		b.tube(0.3, 0.3, 0.08, Vector3(s * 0.95, 1.75, 5.22), Look.engine_glow, Vector3.BACK, 12)
		b.tube(0.06, 0.05, 1.4, Vector3(s * 0.45, 1.45, -2.9), Look.metal, Vector3.FORWARD, 8)
	b.loft([ShipBuilder.yring(2.25, 0.0, 3.5, 0.9, 0.06), ShipBuilder.yring(3.2, 0.0, 4.3, 0.35, 0.04)], white)


## Warden: the line fighter. A rounded fuselage, swept wings with red tips and
## long wingtip cannons, a tall fin and one big engine.
static func _warden(b: ShipBuilder) -> void:
	var white := Look.ship_white
	b.loft([ShipBuilder.zring(5.6, 1.95, 0.45, 0.42, 2.6), ShipBuilder.zring(4.6, 1.95, 0.92, 0.76, 2.6), ShipBuilder.zring(1.5, 2.0, 1.05, 0.85, 2.4),
		ShipBuilder.zring(-1.5, 1.92, 0.88, 0.72, 2.3), ShipBuilder.zring(-4.2, 1.78, 0.48, 0.42, 2.2), ShipBuilder.zring(-5.9, 1.7, 0.06, 0.06)], white)
	b.loft([ShipBuilder.zring(2.5, 1.99, 1.03, 0.84, 2.45), ShipBuilder.zring(3.1, 1.98, 1.0, 0.82, 2.5)], Look.trim_red, true, false, false)
	b.sphere(0.5, Vector3(0, 2.7, -0.7), Look.canopy, Vector3(1.1, 0.85, 2.5))
	for s in [-1.0, 1.0]:
		var inner := [ShipBuilder.xring(s * 0.9, 1.85, 1.6, 2.0, 0.17), ShipBuilder.xring(s * 3.4, 1.95, 2.35, 1.15, 0.11)]
		var outer := [inner[1], ShipBuilder.xring(s * 4.85, 2.0, 2.75, 0.6, 0.07)]
		b.loft(inner, white)
		b.loft(outer, Look.trim_red)
		b.tube(0.15, 0.11, 3.4, Vector3(s * 5.0, 1.95, 1.5), Look.ship_grey, Vector3.FORWARD, 10)
		b.tube(0.06, 0.06, 1.2, Vector3(s * 5.0, 1.95, -0.7), Look.metal, Vector3.FORWARD, 8)
		b.sphere(0.5, Vector3(s * 0.95, 1.85, 1.2), Look.ship_grey, Vector3(0.7, 1.1, 3.2))   # intakes
	b.tube(0.8, 0.62, 1.0, Vector3(0, 1.95, 5.65), Look.ship_grey, Vector3.BACK, 18)
	b.tube(0.56, 0.56, 0.08, Vector3(0, 1.95, 6.18), Look.engine_glow, Vector3.BACK, 18)
	b.loft([ShipBuilder.yring(2.7, 0.0, 3.8, 1.2, 0.08), ShipBuilder.yring(4.1, 0.0, 4.8, 0.45, 0.05)], white)


## Hammer: a heavy bomber. A wide flat lifting body, outboard engine pods on
## stub wings, gold trim and a dorsal turret.
static func _hammer(b: ShipBuilder) -> void:
	var grey := Look.ship_grey
	b.loft([ShipBuilder.zring(6.2, 1.95, 1.5, 0.6, 4.0), ShipBuilder.zring(4.5, 2.05, 2.3, 0.95, 4.0), ShipBuilder.zring(0.5, 2.1, 2.4, 1.0, 4.0),
		ShipBuilder.zring(-3.0, 2.0, 1.8, 0.85, 3.5), ShipBuilder.zring(-5.6, 1.9, 0.9, 0.5, 3.0), ShipBuilder.zring(-6.6, 1.85, 0.22, 0.18, 3.0)], grey)
	b.loft([ShipBuilder.zring(3.3, 2.08, 2.38, 1.0, 4.0), ShipBuilder.zring(3.9, 2.07, 2.37, 0.99, 4.0)], Look.accent_gold, true, false, false)
	b.sphere(0.5, Vector3(0, 2.8, -3.5), Look.canopy, Vector3(1.6, 0.8, 2.4))
	for s in [-1.0, 1.0]:
		var cx: float = s * 4.3
		b.loft([ShipBuilder.zring(6.4, 1.9, 0.5, 0.5, 2.0, 14, cx), ShipBuilder.zring(5.3, 1.9, 0.88, 0.88, 2.0, 14, cx),
			ShipBuilder.zring(1.0, 1.9, 0.92, 0.92, 2.0, 14, cx), ShipBuilder.zring(-2.4, 1.9, 0.6, 0.6, 2.0, 14, cx),
			ShipBuilder.zring(-3.4, 1.9, 0.12, 0.12, 2.0, 14, cx)], Look.ship_white)
		b.tube(0.42, 0.42, 0.08, Vector3(cx, 1.9, 6.42), Look.engine_glow, Vector3.BACK, 14)
		b.loft([ShipBuilder.xring(s * 2.2, 2.0, 2.2, 2.0, 0.25), ShipBuilder.xring(s * 3.6, 1.95, 2.2, 1.8, 0.22)], grey)
		b.loft([ShipBuilder.xring(s * 5.0, 1.95, 2.4, 1.4, 0.15), ShipBuilder.xring(s * 6.6, 1.85, 3.2, 0.6, 0.08)], Look.accent_gold)
		b.tube(0.1, 0.1, 1.6, Vector3(s * 1.5, 1.7, -4.1), Look.metal, Vector3.FORWARD, 8)
	b.sphere(0.65, Vector3(0, 3.05, 1.2), Look.hull_dark, Vector3(1, 0.8, 1))
	for s in [-1.0, 1.0]:
		b.tube(0.08, 0.08, 1.6, Vector3(s * 0.22, 3.15, 0.2), Look.metal, Vector3.FORWARD, 8)


## The enemy fighter (centred on its origin): a round sensor pod with a red
## eye and two curved blade wings that hook downward.
static func _enemy(b: ShipBuilder) -> void:
	var shell := Look.droid_shell
	b.loft([ShipBuilder.zring(3.2, 0, 0.35, 0.35, 2.0, 18), ShipBuilder.zring(2.4, 0, 0.82, 0.76, 2.0, 18), ShipBuilder.zring(0.0, 0, 1.0, 0.95, 2.0, 18),
		ShipBuilder.zring(-2.2, 0, 0.85, 0.8, 2.0, 18), ShipBuilder.zring(-3.2, 0, 0.45, 0.42, 2.0, 18), ShipBuilder.zring(-3.6, 0, 0.1, 0.1, 2.0, 18)], shell)
	b.loft([ShipBuilder.zring(0.6, 0, 1.01, 0.96, 2.0, 18), ShipBuilder.zring(1.2, 0, 0.99, 0.93, 2.0, 18)], Look.droid_mark, true, false, false)
	b.sphere(0.42, Vector3(0, 0.05, -3.3), Look.strip_red)
	b.tube(0.35, 0.35, 0.06, Vector3(0, 0, 3.24), Look.strip_red, Vector3.BACK, 12)
	for s in [-1.0, 1.0]:
		var rings := [ShipBuilder.xring(s * 0.8, 0.0, 0.6, 1.7, 0.14), ShipBuilder.xring(s * 2.8, 0.35, 0.9, 1.5, 0.12),
			ShipBuilder.xring(s * 4.4, -0.2, 1.2, 1.1, 0.1)]
		b.loft(rings, shell)
		b.loft([rings[2], ShipBuilder.xring(s * 5.2, -1.1, 1.6, 0.4, 0.06)], Look.droid_mark)


# --- capital ships ------------------------------------------------------------

## The Bulwark's outer hull in world space: a long arrowhead upper hull whose
## flat top carries the dorsal flight-deck trench, over a deep keel whose
## forward face opens into Hangar Bay 3. Returns [mesh, collision faces].
static func bulwark_hull() -> Array:
	if _cache.has("bulwark"):
		return _cache["bulwark"]
	var b := ShipBuilder.new()
	b.collect_faces = true
	_capital(b, Vector3.ZERO, true)
	var result := [b.commit(), b.faces]
	_cache["bulwark"] = result
	return result


## A sister ship of the same class, with its own command tower, centred on its
## origin. Returns [mesh, collision faces].
static func sister_ship() -> Array:
	if not _cache.has("sister"):
		var b := ShipBuilder.new()
		b.collect_faces = true
		_capital(b, Vector3(0, -150, 0), false)
		_tower(b, Vector3(-100, 16, 0))
		_cache["sister"] = [b.commit(), b.faces]
	return _cache["sister"]


## The enemy dreadnought (centred, nose +X): a swollen armoured core with a
## glowing red sensor band, and two great pincer arms curving forward from
## its flanks. Returns [mesh, collision faces].
static func dreadnought() -> Array:
	if _cache.has("dreadnought"):
		return _cache["dreadnought"]
	var b := ShipBuilder.new()
	b.collect_faces = true
	var shell := Look.droid_shell
	var C := func(x: float, r: float, h: float) -> PackedVector3Array:
		return ShipBuilder.ring(Vector3(x, 0, 0), r, h, 24, 2.3, Vector3.BACK, Vector3.UP)
	b.loft([C.call(-150, 18, 14), C.call(-120, 48, 36), C.call(-60, 82, 60), C.call(0, 92, 66),
		C.call(70, 74, 52), C.call(125, 34, 24), C.call(150, 6, 5)], shell)
	b.loft([C.call(-14, 93.5, 67), C.call(14, 93, 66.5)], Look.droid_mark, true, false, false)
	b.loft([C.call(96, 66, 47), C.call(104, 61, 43)], Look.strip_red, true, false, false)
	# Pincer arms: rings swept along a curve that bows outward from each flank
	# and hooks back in ahead of the bow, like a crab's claws.
	for side in [-1.0, 1.0]:
		var p0 := Vector3(-30, 0, side * 80.0)
		var p1 := Vector3(110, 0, side * 230.0)
		var p2 := Vector3(230, 0, side * 60.0)
		var rings := []
		var steps := 12
		for i in steps:
			var t := float(i) / (steps - 1)
			var center := p0.lerp(p1, t).lerp(p1.lerp(p2, t), t)
			var tangent := (2.0 * (1.0 - t) * (p1 - p0) + 2.0 * t * (p2 - p1)).normalized()
			var across := tangent.cross(Vector3.UP).normalized()
			var half_w := lerpf(30.0, 5.0, t)
			var half_h := lerpf(44.0, 8.0, t * t)
			rings.append(ShipBuilder.ring(center, half_w, half_h, 16, 2.6, across, Vector3.UP))
		b.loft(rings, shell)
		b.sphere(9.0, p2, Look.strip_red, Vector3(1, 1.3, 1))
		b.sphere(0.5, p0.lerp(p1, 0.25).lerp(p1.lerp(p2, 0.25), 0.25), Look.droid_mark, Vector3(60, 80, 60))
	# Dorsal and ventral fins, and the drive cluster at the stern.
	for up in [-1.0, 1.0]:
		var F := func(y: float, half_chord: float, cz: float) -> PackedVector3Array:
			return ShipBuilder.ring(Vector3(cz, y, 0), half_chord, 4.0 + (1.0 - absf(y) / 120.0) * 4.0, 12, 3.0, Vector3.RIGHT, Vector3.BACK)
		b.loft([F.call(up * 50.0, 70.0, -30.0), F.call(up * 95.0, 40.0, -55.0), F.call(up * 120.0, 10.0, -75.0)], shell)
	for y in [-24.0, 24.0]:
		for z in [-24.0, 24.0]:
			b.tube(16.0, 13.0, 30.0, Vector3(-160, y, z), Look.hull_dark, Vector3.RIGHT, 18)
			b.tube(12.0, 12.0, 1.0, Vector3(-175.6, y, z), Look.strip_red, Vector3.RIGHT, 18)
	var result := [b.commit(), b.faces]
	_cache["dreadnought"] = result
	return result


static func _capital(b: ShipBuilder, o: Vector3, trench: bool) -> void:
	var top := 166.0
	var lip := 4.0
	# x, half width at the top, bottom height
	var sections := [[-150, 105, 70], [-120, 115, 62], [-72, 119, 58], [-70, 119, 58], [0, 112, 60],
		[70, 96, 70], [72, 95, 71], [150, 68, 96], [250, 34, 130], [335, 2, 160]]
	var rings := []
	for sec in sections:
		var x: float = sec[0]
		var w: float = sec[1]
		var bot: float = sec[2]
		# The trench notch: wide enough for the side hangars where the trench
		# runs, and collapsed to nothing elsewhere so the deck plating is plain hull.
		var in_trench: bool = trench and x >= -70.0 and x <= 70.0
		var nz := 38.0 if in_trench else 0.0
		var nb := 148.0 if in_trench else top
		var pts := PackedVector3Array()
		for zy in [[w, top], [nz, top], [nz, nb], [-nz, nb], [-nz, top], [-w, top], [-w, top - lip],
				[-0.7 * w, bot], [0.7 * w, bot], [w, top - lip]]:
			pts.append(o + Vector3(x, zy[1], zy[0]))
		rings.append(pts)
	b.loft(rings, Look.hull, false, true, true, {1: Look.hull_dark, 2: Look.hull_dark, 3: Look.hull_dark, 5: Look.trim_red, 9: Look.trim_red})
	# Spine and armour ridges along the top.
	b.box(Vector3(210, 2.4, 5), o + Vector3(185, top + 1.2, 0), Look.hull_dark)
	for s in [-1.0, 1.0]:
		for i in 6:
			b.box(Vector3(18, 1.2, 6), o + Vector3(-120 + i * 34.0, top + 0.6, s * 72.0), Look.hull_dark)
		b.box(Vector3(120, 1.0, 3), o + Vector3(140, top + 0.5, s * 34.0), Look.hull_dark, Vector3(0, s * deg_to_rad(14), 0))
	# Engine bank across the stern.
	for z in [-70.0, -35.0, 0.0, 35.0, 70.0]:
		b.tube(14.0, 12.0, 12.0, o + Vector3(-155, 120, z), Look.hull_dark, Vector3.RIGHT, 24)
		b.tube(10.5, 10.5, 0.6, o + Vector3(-161.2, 120, z), Look.engine_glow, Vector3.RIGHT, 24)
	# The keel: a deep block under the upper hull, hollow so the hangar,
	# corridor and lift hall fit inside, with the hangar mouth in its bow face.
	var keel := []
	for x in [-110.0, 26.0]:
		var pts := PackedVector3Array()
		for zy in [[50, 72], [-50, 72], [-50, -10], [-36, -25], [36, -25], [50, -10]]:
			pts.append(o + Vector3(x, zy[1], zy[0]))
		keel.append(pts)
	b.loft(keel, Look.hull, false, true, false, {2: Look.trim_red})
	var fx := 26.0
	b.box(Vector3(2, 53.5, 100), o + Vector3(fx, 18.5 + 53.5 / 2.0, 0), Look.hull)
	for s in [-1.0, 1.0]:
		b.box(Vector3(2, 28.5, 21), o + Vector3(fx, 4.25, s * 39.5), Look.hull)
		b.box(Vector3(2.4, 1.2, 21), o + Vector3(fx, 14.0, s * 39.5), Look.trim_red)
	b.box(Vector3(2, 9.5, 58), o + Vector3(fx, -5.75, 0), Look.hull)
	b.box(Vector3(2, 15, 72), o + Vector3(fx, -17.5, 0), Look.hull)
	for s in [-1.0, 1.0]:
		b.box(Vector3(2, 15, 14), o + Vector3(fx, -17.5, s * 43.0), Look.hull_dark)
	# Ventral fins on the keel.
	for x in [-80.0, -30.0]:
		b.box(Vector3(30, 8, 3), o + Vector3(x, -29, 0), Look.hull_dark)


## A stepped command tower with a lit bridge band, for the sister ships.
static func _tower(b: ShipBuilder, base: Vector3) -> void:
	var R := func(y: float, rx: float, rz: float) -> PackedVector3Array:
		return ShipBuilder.ring(base + Vector3(0, y, 0), rx, rz, 16, 3.5, Vector3.RIGHT, Vector3.BACK)
	b.loft([R.call(0, 18, 15), R.call(16, 15, 12), R.call(24, 12, 9), R.call(30, 17, 13), R.call(36, 15, 11), R.call(40, 8, 6)], Look.hull, false)
	b.loft([R.call(31, 17.2, 13.2), R.call(33.5, 17.0, 13.0)], Look.screen_blue, false, false, false)
	b.tube(0.5, 0.3, 14, base + Vector3(-3, 47, 3), Look.metal, Vector3.UP, 8)


## The frigate Steadfast's hull around its repair bay (frigate-local, nose +X).
## Returns [mesh, collision faces].
static func frigate() -> Array:
	if _cache.has("frigate"):
		return _cache["frigate"]
	var b := ShipBuilder.new()
	b.collect_faces = true
	var R := func(x: float, y: float, rz: float, ry: float) -> PackedVector3Array:
		return ShipBuilder.ring(Vector3(x, y, 0), rz, ry, 20, 3.0, Vector3.BACK, Vector3.UP)
	# Aft engineering section and drives.
	b.loft([R.call(-80, 4, 8, 7), R.call(-72, 4, 14, 12), R.call(-40, 4, 16, 13), R.call(-23, 4, 16, 12)], Look.hull)
	b.loft([R.call(-56, 4.3, 16.1, 13.1), R.call(-52, 4.3, 16.1, 13.1)], Look.trim_red, true, false, false)
	for z in [-8.0, 0.0, 8.0]:
		b.tube(3.6, 3.2, 3.0, Vector3(-80, 4, z), Look.hull_dark, Vector3.RIGHT, 16)
		b.tube(3.0, 3.0, 0.3, Vector3(-81.6, 4, z), Look.engine_glow, Vector3.RIGHT, 16)
	# Forward hull and the hammerhead prow.
	b.loft([R.call(23, 2, 12, 7), R.call(50, 2, 11, 6.5), R.call(78, 2, 9, 5.5), R.call(90, 2, 5, 3)], Look.hull)
	var H := func(z: float, rx: float, ry: float) -> PackedVector3Array:
		return ShipBuilder.ring(Vector3(86, 2, z), rx, ry, 16, 3.0)
	b.loft([H.call(-26, 2, 1.5), H.call(-20, 8, 4), H.call(0, 9, 4.5), H.call(20, 8, 4), H.call(26, 2, 1.5)], Look.hull)
	b.loft([H.call(-8, 9.1, 4.6), H.call(-6, 9.1, 4.6)], Look.trim_red, true, false, false)
	b.loft([H.call(6, 9.1, 4.6), H.call(8, 9.1, 4.6)], Look.trim_red, true, false, false)
	# Tower above the drives.
	var T := func(y: float, rx: float, rz: float) -> PackedVector3Array:
		return ShipBuilder.ring(Vector3(-46, y, 0), rx, rz, 16, 3.0, Vector3.RIGHT, Vector3.BACK)
	b.loft([T.call(12, 10, 8), T.call(20, 8, 6), T.call(25, 9, 7), T.call(28, 6, 4)], Look.hull, false)
	b.loft([T.call(21.5, 8.7, 6.7), T.call(23.5, 8.9, 6.9)], Look.screen_blue, false, false, false)
	var result := [b.commit(), b.faces]
	_cache["frigate"] = result
	return result


## The enemy corvette (corvette-local, nose +X): a ribbed spine, a broad
## hammer bow and a cluster of drives. Returns [mesh, collision faces].
static func corvette() -> Array:
	if _cache.has("corvette"):
		return _cache["corvette"]
	var b := ShipBuilder.new()
	b.collect_faces = true
	var shell := Look.droid_shell
	var R := func(x: float, rz: float, ry: float) -> PackedVector3Array:
		return ShipBuilder.ring(Vector3(x, 0, 0), rz, ry, 18, 2.5, Vector3.BACK, Vector3.UP)
	b.loft([R.call(-74, 4, 3.5), R.call(-60, 8, 6), R.call(0, 6.5, 5), R.call(55, 8, 6), R.call(70, 12, 8)], shell)
	var H := func(z: float, rx: float, ry: float) -> PackedVector3Array:
		return ShipBuilder.ring(Vector3(80, 0, z), rx, ry, 16, 2.5)
	b.loft([H.call(-24, 2, 2), H.call(-18, 9, 6), H.call(0, 12, 7.5), H.call(18, 9, 6), H.call(24, 2, 2)], shell)
	b.loft([H.call(-4, 12.1, 7.6), H.call(4, 12.1, 7.6)], Look.droid_mark, true, false, false)
	for x in [-40.0, 0.0, 40.0]:
		var torus := TorusMesh.new()
		torus.inner_radius = 14.0
		torus.outer_radius = 17.0
		torus.rings = 24
		torus.ring_segments = 8
		b.add_arrays(torus.get_mesh_arrays(), Look.hull_dark, Transform3D(Basis(Vector3.BACK, PI / 2.0), Vector3(x, 0, 0)))
		for a in 4:
			var ang := a * PI / 2.0 + PI / 4.0
			b.tube(0.8, 0.8, 9.5, Vector3(x, cos(ang) * 10.0, sin(ang) * 10.0), Look.hull_dark,
				Vector3.UP if a % 2 == 0 else Vector3.FORWARD, 8)
	for y in [-6.0, 6.0]:
		for z in [-6.0, 6.0]:
			b.tube(3.2, 2.8, 12.0, Vector3(-80, y, z), shell, Vector3.RIGHT, 14)
			b.tube(2.5, 2.5, 0.4, Vector3(-86.2, y, z), Look.strip_red, Vector3.RIGHT, 14)
	var result := [b.commit(), b.faces]
	_cache["corvette"] = result
	return result
