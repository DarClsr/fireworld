class_name InputDefs
## 输入动作集中定义处：幂等，可重复调用。


static func ensure_actions() -> void:
	_add("move_left", [_key(KEY_A)])
	_add("move_right", [_key(KEY_D)])
	_add("move_forward", [_key(KEY_W)])
	_add("move_back", [_key(KEY_S)])
	_add("jump", [_key(KEY_SPACE)])
	_add("attack_light", [_mouse(MOUSE_BUTTON_LEFT), _key(KEY_J)])
	_add("attack_heavy", [_mouse(MOUSE_BUTTON_RIGHT), _key(KEY_K)])
	_add("add_seed", [_key(KEY_E)])
	_add("release_mouse", [_key(KEY_ESCAPE)])


static func _add(action_name: String, events: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for ev in events:
		InputMap.action_add_event(action_name, ev)


static func _key(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	return ev


static func _mouse(button_index: MouseButton) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button_index
	return ev
