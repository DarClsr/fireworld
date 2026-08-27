extends CanvasLayer
## 自制轻量对话框：底部面板 + 打字机 + F/点击推进。
## 用法：start([{"speaker": "陶婆婆", "text": "..."}])，结束后发 finished。

signal finished

const CPS := 42.0

var _lines: Array = []
var _idx := -1
var _typing := false
var _shown := 0.0
var _total := 0
var _open := false

var _panel: PanelContainer
var _name_label: Label
var _text_label: RichTextLabel


func _ready() -> void:
	layer = 10
	visible = false
	var font := CnFont.get_font()

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var wrap := MarginContainer.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_theme_constant_override("margin_left", 70)
	wrap.add_theme_constant_override("margin_right", 70)
	wrap.add_theme_constant_override("margin_bottom", 46)
	root.add_child(wrap)

	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.055, 0.09, 0.93)
	sb.border_color = Color(0.85, 0.66, 0.35, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 20.0
	sb.content_margin_right = 20.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 14.0
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.custom_minimum_size = Vector2(0, 138)
	_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	wrap.add_child(_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_panel.add_child(v)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 22)
	_name_label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.45))
	if font != null:
		_name_label.add_theme_font_override("font", font)
	v.add_child(_name_label)

	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled = false
	_text_label.fit_content = false
	_text_label.scroll_active = false
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_label.add_theme_font_size_override("normal_font_size", 20)
	_text_label.add_theme_color_override("default_color", Color(0.93, 0.92, 0.88))
	if font != null:
		_text_label.add_theme_font_override("normal_font", font)
	v.add_child(_text_label)

	_panel.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			_advance())


func start(lines: Array) -> void:
	_lines = lines
	_idx = -1
	_open = true
	visible = true
	_next()


func is_open() -> bool:
	return _open


func _next() -> void:
	_idx += 1
	if _idx >= _lines.size():
		_close()
		return
	var line: Dictionary = _lines[_idx]
	_name_label.text = line.get("speaker", "")
	_text_label.text = line.get("text", "")
	_total = _text_label.text.length()
	_shown = 0.0
	_typing = true
	_text_label.visible_characters = 0


func _process(delta: float) -> void:
	if not _typing:
		return
	_shown += delta * CPS
	_text_label.visible_characters = int(_shown)
	if _text_label.visible_characters >= _total:
		_text_label.visible_characters = -1
		_typing = false


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("attack_light") \
			or event.is_action_pressed("jump"):
		_advance()
		get_viewport().set_input_as_handled()


func _advance() -> void:
	if _typing:
		_typing = false
		_text_label.visible_characters = -1
	else:
		_next()


func _close() -> void:
	_open = false
	visible = false
	finished.emit()


func debug_finish() -> void:
	if not _open:
		return
	_close()
