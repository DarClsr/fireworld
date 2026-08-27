extends Node3D
## 训练木桩：受击摇晃+飘字，血量归零后倒伏并自动复原。M0 验收靶子。

signal damaged(amount: float)

const MAX_HP := 60.0

var hp := MAX_HP
var broken := false

var _holder: Node3D
var _label: Label3D
const FloatText := preload("res://scripts/floating_text.gd")


func _ready() -> void:
	_holder = Node3D.new()
	add_child(_holder)

	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.32
	base_mesh.bottom_radius = 0.38
	base_mesh.height = 0.1
	base.mesh = base_mesh
	base.position.y = 0.05
	base.material_override = _flat(Color(0.46, 0.46, 0.44))
	_holder.add_child(base)

	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.155
	tm.bottom_radius = 0.215
	tm.height = 1.55
	trunk.mesh = tm
	trunk.position.y = 0.82
	trunk.rotation_degrees.z = 2.5
	trunk.material_override = _wood(Color(0.45, 0.33, 0.22))
	_holder.add_child(trunk)

	var cross := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.055
	cm.bottom_radius = 0.055
	cm.height = 1.15
	cross.mesh = cm
	cross.rotation_degrees.z = 90.0
	cross.position.y = 1.12
	cross.material_override = _wood(Color(0.41, 0.30, 0.21))
	_holder.add_child(cross)

	var band := MeshInstance3D.new()
	var band_mesh := CylinderMesh.new()
	band_mesh.top_radius = 0.185
	band_mesh.bottom_radius = 0.195
	band_mesh.height = 0.16
	band.mesh = band_mesh
	band.position.y = 1.3
	band.material_override = _flat(Color(0.63, 0.22, 0.17))
	_holder.add_child(band)

	var hb := Area3D.new()
	hb.collision_layer = 4
	hb.collision_mask = 0
	hb.monitoring = false
	hb.monitorable = true
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.1, 1.5, 1.1)
	cs.shape = bs
	cs.position.y = 0.85
	hb.add_child(cs)
	add_child(hb)

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 40
	_label.outline_size = 10
	_label.no_depth_test = true
	_label.pixel_size = 0.006
	_label.position.y = 1.95
	_label.modulate = Color(0.92, 0.88, 0.8)
	add_child(_label)
	_refresh_label()


func receive_hit(damage: float, _dir: Vector3, knock: float, heavy: bool) -> void:
	if broken:
		return
	hp -= damage
	damaged.emit(damage)
	_refresh_label()
	_float_number(damage, heavy)
	_shake(knock)


func _refresh_label() -> void:
	var shown := maxf(hp, 0.0)
	_label.text = "POST %.0f / %d" % [shown, int(MAX_HP)]
	if hp <= 0.0:
		_label.text = "..."


func _float_number(damage: float, heavy: bool) -> void:
	var ft := FloatText.new()
	ft.amount = damage
	ft.strong = heavy
	add_child(ft)


func _shake(knock: float) -> void:
	var amp := clampf(0.035 + knock * 0.008, 0.035, 0.09)
	var tw := create_tween()
	for i in range(4):
		var off := amp * (1.0 - float(i) / 5.0)
		var x := off
		if i % 2 == 1:
			x = -off
		tw.tween_property(_holder, "position:x", x, 0.045)
	tw.tween_property(_holder, "position:x", 0.0, 0.05)


func _break_apart() -> void:
	broken = true
	_label.text = "..."
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_holder, "rotation:z", deg_to_rad(-76.0), 0.55) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_holder, "position:y", -0.1, 0.55)
	tw.chain().tween_interval(2.0)
	tw.chain().tween_callback(_restore)


func _restore() -> void:
	broken = false
	hp = MAX_HP
	_refresh_label()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_holder, "rotation:z", 0.0, 0.5) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_holder, "position:y", 0.0, 0.5)


func _process(_delta: float) -> void:
	# 血量掉光检查放在帧末，避免与 shake 的 tween 抢 holder 属性时序混乱
	if hp <= 0.0 and not broken:
		_break_apart()


func _wood(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.95
	return m


func _flat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	return m
