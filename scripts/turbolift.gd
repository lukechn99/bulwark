class_name Turbolift
extends Node3D
## A turbolift pad. Standing on it and pressing E rides to the paired lift: the
## screen fades, the destination zone loads behind the fade, and the player is
## placed at the same spot relative to the other lift.

var destination: Turbolift
var dest_zone := ""
var label := ""
var _busy := false
var _ring: MeshInstance3D


static func make(pos: Vector3, yaw_degrees: float, zone_id: String, text: String) -> Turbolift:
	var t := Turbolift.new()
	t.position = pos
	t.rotation_degrees.y = yaw_degrees
	t.dest_zone = zone_id
	t.label = text
	return t


func _ready() -> void:
	_ring = Kit.strip(self, Vector3(2.2, 0.03, 2.2), Vector3(0, 0.02, 0), Look.strip_blue) as MeshInstance3D
	Kit.strip(self, Vector3(1.9, 0.04, 1.9), Vector3(0, 0.025, 0), Look.metal)


func player_inside() -> bool:
	var p := Zones.player
	if not p:
		return false
	var d := p.global_position - global_position
	return absf(d.x) < 1.2 and absf(d.z) < 1.2 and d.y > -0.5 and d.y < 2.0


func _process(_delta: float) -> void:
	var inside := player_inside()
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and not _busy:
		hud.set_prompt(self, "%s  Turbolift to %s" % ["[USE]" if Player.autoplay else "[E]", label] if inside else "")
	_ring.visible = not inside or int(Time.get_ticks_msec() / 300.0) % 2 == 0
	if inside and not _busy and Input.is_action_just_pressed("interact"):
		_ride(hud)


func _ride(hud: Node) -> void:
	_busy = true
	var p := Zones.player as CharacterBody3D
	hud.set_prompt(self, "")
	Zones.pin(dest_zone)
	await hud.fade(1.0, 0.35)
	await Zones.load_now(dest_zone)
	# A beat of travel time, so it feels like a ride rather than a teleport.
	await get_tree().create_timer(0.6).timeout
	var local := global_transform.affine_inverse() * p.global_position
	p.global_position = destination.global_transform * local
	if p.has_method("turn"):
		p.turn(destination.global_rotation.y - global_rotation.y)
	p.velocity = Vector3.ZERO
	if p.has_method("snap_camera"):
		p.snap_camera()
	await get_tree().physics_frame
	Zones.unpin(dest_zone)
	await hud.fade(0.0, 0.35)
	_busy = false
