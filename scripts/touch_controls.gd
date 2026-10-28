extends Control
## On-screen controls for phones and tablets, plus the fullscreen button that
## every device gets.
##
## - Left side: a floating joystick appears wherever the thumb lands. Pushing it
##   to the rim sprints.
## - Right side: swipe anywhere to look around.
## - Buttons: FIRE (hold; you can drag on it to aim while shooting), AIM
##   (toggle), JUMP and USE.
##
## Everything works by pressing the same input actions the keyboard uses, so
## the player script doesn't know whether input came from touch or keys.

const LOOK_SENS := 0.0055
## Phones are short, and the UI scales with screen height, so thumbs get bigger targets.
const UI_SCALE := 1.35
const STICK_RADIUS := 70.0 * UI_SCALE
const STICK_ZONE := 0.42   # left fraction of the screen that starts the joystick

## True once the first touch arrives; the touch UI is hidden until then.
var touch_mode := false
var aim_on := false

var _stick_touch := -1
var _stick_origin := Vector2.ZERO
var _stick_knob := Vector2.ZERO
var _look_touches: Dictionary = {}    # index -> last position
var _button_touches: Dictionary = {}  # index -> button name
var _font: Font


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	resized.connect(queue_redraw)


# --- layout -------------------------------------------------------------------

func _buttons() -> Dictionary:
	var s := size
	var k := UI_SCALE
	var b := {
		"fire": [Vector2(s.x - 120 * k, s.y - 130 * k), 62.0 * k, "FIRE"],
		"aim": [Vector2(s.x - 255 * k, s.y - 80 * k), 42.0 * k, "AIM"],
		"jump": [Vector2(s.x - 95 * k, s.y - 280 * k), 42.0 * k, "JUMP"],
		"interact": [Vector2(s.x - 240 * k, s.y - 215 * k), 38.0 * k, "USE"],
	}
	if not touch_mode:
		b = {}
	b["fullscreen"] = [Vector2(s.x - 44, 40), 24.0, ""]
	return b


func _button_at(p: Vector2) -> String:
	var buttons := _buttons()
	for name in buttons:
		var spec: Array = buttons[name]
		if p.distance_to(spec[0]) <= spec[1] + 12.0:
			return name
	return ""


# --- input --------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	# The fullscreen button also answers mouse clicks on desktop.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _button_at(event.position) == "fullscreen":
			toggle_fullscreen()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("fullscreen"):
		toggle_fullscreen()
		return
	if event is InputEventScreenTouch:
		_touch(event)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		_drag(event)
		get_viewport().set_input_as_handled()


func _touch(e: InputEventScreenTouch) -> void:
	if e.pressed:
		if not touch_mode:
			_enter_touch_mode()
		var button := _button_at(e.position)
		if button == "fullscreen":
			toggle_fullscreen()
		elif button == "aim":
			aim_on = not aim_on
			if aim_on:
				Input.action_press("aim")
			else:
				Input.action_release("aim")
		elif button != "":
			_button_touches[e.index] = button
			Input.action_press(button)
			if button == "fire":
				_look_touches[e.index] = e.position   # drag on FIRE to aim
		elif e.position.x < size.x * STICK_ZONE and _stick_touch == -1:
			_stick_touch = e.index
			_stick_origin = e.position
			_stick_knob = e.position
		else:
			_look_touches[e.index] = e.position
	else:
		if e.index == _stick_touch:
			_stick_touch = -1
			_set_move(Vector2.ZERO)
		if _button_touches.has(e.index):
			Input.action_release(_button_touches[e.index])
			_button_touches.erase(e.index)
		_look_touches.erase(e.index)
	queue_redraw()


func _drag(e: InputEventScreenDrag) -> void:
	if e.index == _stick_touch:
		var offset := e.position - _stick_origin
		if offset.length() > STICK_RADIUS:
			offset = offset.normalized() * STICK_RADIUS
		_stick_knob = _stick_origin + offset
		_set_move(offset / STICK_RADIUS)
		queue_redraw()
	elif _look_touches.has(e.index):
		var delta: Vector2 = e.position - _look_touches[e.index]
		_look_touches[e.index] = e.position
		var player := Zones.player as Player
		if player:
			var scale := 0.55 if aim_on else 1.0
			player.add_look(delta.x * LOOK_SENS * scale, delta.y * LOOK_SENS * scale)


func _set_move(v: Vector2) -> void:
	_axis("move_left", "move_right", v.x)
	_axis("move_forward", "move_back", v.y)
	if v.y < -0.92 and not aim_on:
		Input.action_press("sprint")
	else:
		Input.action_release("sprint")


func _axis(negative: String, positive: String, value: float) -> void:
	if value < -0.15:
		Input.action_press(negative, -value)
		Input.action_release(positive)
	elif value > 0.15:
		Input.action_press(positive, value)
		Input.action_release(negative)
	else:
		Input.action_release(negative)
		Input.action_release(positive)


func _enter_touch_mode() -> void:
	touch_mode = true
	Player.autoplay = true
	# Phones get a lighter frame: lower 3D resolution, no MSAA, no sun shadows.
	var vp := get_viewport()
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.scaling_3d_scale = 0.7
	for sun in get_tree().get_nodes_in_group("sun"):
		(sun as DirectionalLight3D).shadow_enabled = false
	queue_redraw()


static func toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


# --- drawing ------------------------------------------------------------------

func _process(_delta: float) -> void:
	# Track the visible area directly; anchors alone left this at zero size
	# when it was created inside the HUD.
	var screen := get_viewport_rect().size
	if size != screen:
		position = Vector2.ZERO
		size = screen
	queue_redraw()


func _draw() -> void:
	var buttons := _buttons()
	var fs: Array = buttons["fullscreen"]
	_draw_fullscreen_icon(fs[0], DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	if not touch_mode:
		return
	if size.y > size.x:
		_center_text("Turn your phone sideways to play", size / 2.0, 22)
	var held := _button_touches.values()
	for name in buttons:
		if name == "fullscreen":
			continue
		var spec: Array = buttons[name]
		var active: bool = held.has(name) or (name == "aim" and aim_on)
		var fill := Color(0.55, 0.8, 1.0, 0.35) if active else Color(0, 0, 0, 0.28)
		if name == "fire":
			fill = Color(1.0, 0.35, 0.25, 0.45) if active else Color(0.6, 0.1, 0.08, 0.32)
		if name == "interact" and _prompt_visible() == false and not active:
			fill.a *= 0.5
		draw_circle(spec[0], spec[1], fill)
		draw_arc(spec[0], spec[1], 0, TAU, 48, Color(1, 1, 1, 0.55), 2.0, true)
		_center_text(spec[2], spec[0], 22 if spec[1] > 70 else 17)
	if _stick_touch != -1:
		draw_circle(_stick_origin, STICK_RADIUS, Color(0, 0, 0, 0.25))
		draw_arc(_stick_origin, STICK_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.4), 2.0, true)
		draw_circle(_stick_knob, 30.0 * UI_SCALE, Color(0.55, 0.8, 1.0, 0.55))
	else:
		# A hint where the stick lives.
		var hint := Vector2(150, size.y - 150) * Vector2(UI_SCALE, 1.0) - Vector2(0, 40)
		draw_arc(hint, STICK_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.18), 2.0, true)
		_center_text("MOVE", hint, 13, 0.4)


func _prompt_visible() -> bool:
	var hud := get_tree().get_first_node_in_group("hud")
	return hud != null and hud.has_prompt()


func _draw_fullscreen_icon(c: Vector2, exit: bool) -> void:
	draw_circle(c, 24.0, Color(0, 0, 0, 0.3))
	var col := Color(1, 1, 1, 0.8)
	var r := 9.0
	var l := 5.0
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		# Corner brackets: pointing outward to enter fullscreen, inward to leave.
		var tip: Vector2 = c + corner * (r - l if exit else r)
		var dir := 1.0 if exit else -1.0
		draw_line(tip, tip + Vector2(corner.x * l * dir, 0), col, 2.0)
		draw_line(tip, tip + Vector2(0, corner.y * l * dir), col, 2.0)


func _center_text(text: String, at: Vector2, font_size: int, alpha := 0.9) -> void:
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(_font, at + Vector2(-w / 2.0, font_size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, alpha))
