extends CanvasLayer
## Crosshair, health, zone title, prompts, streaming indicator and screen fades.

var _crosshair: Control
var _health_fill: ColorRect
var _zone_label: Label
var _zone_tween: Tween
var _prompt: Label
var _prompts: Dictionary = {}
var _message: Label
var _stream: Label
var _fade: ColorRect
var _damage: ColorRect
var _start: Control
var _hit_time := 0.0
var _hit_kill := false
var _kills: Label

const ACCENT := Color(0.55, 0.8, 1.0)


func _ready() -> void:
	add_to_group("hud")
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_damage = _rect(root, Color(0.8, 0.05, 0.02, 0.0))
	_crosshair = Control.new()
	_crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.draw.connect(_draw_crosshair)
	root.add_child(_crosshair)

	# Health bar, bottom left.
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0, 0, 0, 0.45)
	bar_bg.anchor_top = 1.0
	bar_bg.anchor_bottom = 1.0
	bar_bg.offset_left = 32
	bar_bg.offset_right = 292
	bar_bg.offset_top = -46
	bar_bg.offset_bottom = -34
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar_bg)
	_health_fill = ColorRect.new()
	_health_fill.color = ACCENT
	_health_fill.position = Vector2(2, 2)
	_health_fill.size = Vector2(256, 8)
	_health_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_bg.add_child(_health_fill)
	var hl := _label(root, "HEALTH", 12, Color(1, 1, 1, 0.7))
	hl.anchor_top = 1.0
	hl.anchor_bottom = 1.0
	hl.offset_left = 32
	hl.offset_top = -68
	_kills = _label(root, "", 14, Color(1, 1, 1, 0.8))
	_kills.anchor_left = 1.0
	_kills.anchor_right = 1.0
	_kills.anchor_top = 1.0
	_kills.anchor_bottom = 1.0
	_kills.offset_left = -232
	_kills.offset_right = -32
	_kills.offset_top = -52
	_kills.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_zone_label = _label(root, "", 22, Color(1, 1, 1, 0.0))
	_zone_label.offset_left = 32
	_zone_label.offset_top = 28
	_stream = _label(root, "", 13, ACCENT)
	_stream.offset_left = 32
	_stream.offset_top = 62

	_prompt = _centered(root, 18, 0.72)
	_message = _centered(root, 30, 0.38)

	var touch := preload("res://scripts/touch_controls.gd").new()
	touch.name = "TouchControls"
	root.add_child(touch)

	_fade = _rect(root, Color(0, 0, 0, 1.0))
	_start = _start_panel(root)
	fade(0.0, 0.8)

	Zones.zone_changed.connect(_on_zone_changed)
	Zones.streaming_changed.connect(_on_streaming)


func _process(delta: float) -> void:
	var player := Zones.player as Player
	if player:
		_health_fill.size.x = 256.0 * clampf(player.health / Player.MAX_HEALTH, 0.0, 1.0)
		_health_fill.color = ACCENT if player.health > 35.0 else Color(1.0, 0.35, 0.25)
		_kills.text = "DRONES DOWN  %d" % player.kills if player.kills > 0 else ""
	_damage.color.a = move_toward(_damage.color.a, 0.0, delta * 0.8)
	_hit_time = maxf(0.0, _hit_time - delta)
	_start.visible = not Player.is_playing()
	_crosshair.queue_redraw()


func _draw_crosshair() -> void:
	var c := _crosshair.size / 2.0
	var aiming := Input.is_action_pressed("aim")
	var gap := 5.0 if aiming else 9.0
	var col := Color(1, 1, 1, 0.85)
	for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		_crosshair.draw_line(c + d * gap, c + d * (gap + 7.0), col, 2.0)
	_crosshair.draw_circle(c, 1.5, col)
	if _hit_time > 0.0:
		var hc := Color(1.0, 0.3, 0.2, _hit_time * 5.0) if _hit_kill else Color(1, 1, 1, _hit_time * 5.0)
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			_crosshair.draw_line(c + d * 6.0, c + d * 12.0, hc, 2.0)


## Owners set or clear their own prompt; the most recent non-empty one shows.
func set_prompt(owner: Object, text: String) -> void:
	if text == "":
		_prompts.erase(owner)
	else:
		_prompts[owner] = text
	_prompt.text = _prompts.values().back() if _prompts.size() > 0 else ""


func has_prompt() -> bool:
	return _prompt.text != ""


func show_message(text: String) -> void:
	_message.text = text


func damage_flash() -> void:
	_damage.color.a = minf(0.35, _damage.color.a + 0.12)


func hit_marker(killed: bool) -> void:
	_hit_time = 0.2
	_hit_kill = killed


func fade(to_alpha: float, seconds: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", to_alpha, seconds)
	await tw.finished


func _on_zone_changed(_id: String, title: String) -> void:
	_zone_label.text = title.to_upper()
	if _zone_tween:
		_zone_tween.kill()
	_zone_tween = create_tween()
	_zone_tween.tween_property(_zone_label, "modulate:a", 1.0, 0.4).from(0.0)
	_zone_tween.tween_interval(2.5)
	_zone_tween.tween_property(_zone_label, "modulate:a", 0.0, 1.0)
	_zone_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))


func _on_streaming(ids: Array) -> void:
	_stream.text = "" if ids.is_empty() else "Streaming %s…" % ", ".join(ids.map(func(i): return Zones.title(i)))


func _start_panel(root: Control) -> Control:
	var panel := ColorRect.new()
	panel.color = Color(0.0, 0.01, 0.03, 0.55)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := _label(box, "BULWARK", 54, Color(1, 1, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var touch := DisplayServer.is_touchscreen_available()
	var sub := _label(box, "Tap to deploy" if touch else "Click to deploy", 20, ACCENT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var help := _label(box, "Left thumb moves · swipe right side to look\nHold FIRE (drag it to aim) · AIM zooms · USE rides turbolifts" if touch else "WASD move · Shift sprint · Space jump · Mouse look\nLeft click fire · Right click aim · E use · F fullscreen · Esc release mouse", 14, Color(1, 1, 1, 0.75))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return panel


func _rect(parent: Control, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


func _label(parent: Control, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _centered(parent: Control, size: int, y_anchor: float) -> Label:
	var l := _label(parent, "", size, Color(1, 1, 1, 0.95))
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.anchor_top = y_anchor
	l.anchor_bottom = y_anchor
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
