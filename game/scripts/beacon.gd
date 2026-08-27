extends Node3D
## 灰盒烽火台：靠近按 F 点燃，光穹推夜。M1 招牌演出载体。

signal lit_changed(beacon: Node3D)

const IGNITE_TIME := 1.4
const INTERACT_RANGE := 2.8

var player_body   # duck typing，main 注入

var _lit := false
var _bowl_light: OmniLight3D
var _dome_light: OmniLight3D
var _ember_mat: StandardMaterial3D
var _flame: CPUParticles3D
var _prompt: Label3D
var _flick_noise := FastNoiseLite.new()
var _t := 0.0
var _base_energy := 6.0


func _ready() -> void:
	_flick_noise.seed = 20260827
	_flick_noise.frequency = 6.0

	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 1.05
	base_mesh.bottom_radius = 1.3
	base_mesh.height = 0.5
	base.mesh = base_mesh
	base.position.y = 0.25
	base.material_override = _stone(Color(0.30, 0.31, 0.36))
	add_child(base)

	var shaft := MeshInstance3D.new()
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.52
	shaft_mesh.bottom_radius = 0.72
	shaft_mesh.height = 3.0
	shaft.mesh = shaft_mesh
	shaft.position.y = 2.0
	shaft.material_override = _stone(Color(0.36, 0.37, 0.43))
	add_child(shaft)

	var bowl := MeshInstance3D.new()
	var bowl_mesh := CylinderMesh.new()
	bowl_mesh.top_radius = 0.8
	bowl_mesh.bottom_radius = 0.45
	bowl_mesh.height = 0.5
	bowl.mesh = bowl_mesh
	bowl.position.y = 3.65
	bowl.material_override = _stone(Color(0.27, 0.25, 0.24))
	add_child(bowl)

	# 柴堆（未点燃时只有一点余烬红）
	var ember := MeshInstance3D.new()
	var ember_mesh := CylinderMesh.new()
	ember_mesh.top_radius = 0.42
	ember_mesh.bottom_radius = 0.5
	ember_mesh.height = 0.28
	ember.mesh = ember_mesh
	ember.position.y = 3.75
	_ember_mat = StandardMaterial3D.new()
	_ember_mat.albedo_color = Color(0.16, 0.09, 0.06)
	_ember_mat.emission_enabled = true
	_ember_mat.emission = Color(0.9, 0.25, 0.08)
	_ember_mat.emission_energy_multiplier = 0.35
	ember.material_override = _ember_mat
	add_child(ember)

	_bowl_light = OmniLight3D.new()
	_bowl_light.position = Vector3(0, 4.1, 0)
	_bowl_light.light_color = Color(1.0, 0.72, 0.4)
	_bowl_light.omni_range = 13.0
	_bowl_light.light_energy = 0.0
	_bowl_light.shadow_enabled = false
	add_child(_bowl_light)

	_dome_light = OmniLight3D.new()
	_dome_light.position = Vector3(0, 6.5, 0)
	_dome_light.light_color = Color(1.0, 0.78, 0.5)
	_dome_light.omni_range = 26.0
	_dome_light.light_energy = 0.0
	_dome_light.shadow_enabled = false
	add_child(_dome_light)

	_flame = _make_flame()
	_flame.position = Vector3(0, 3.95, 0)
	_flame.emitting = false
	add_child(_flame)

	_prompt = Label3D.new()
	_prompt.text = "[F] LIGHT THE BEACON"
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.font_size = 46
	_prompt.outline_size = 12
	_prompt.pixel_size = 0.006
	_prompt.position.y = 4.9
	_prompt.modulate = Color(0.95, 0.85, 0.6)
	_prompt.visible = false
	add_child(_prompt)


func _process(delta: float) -> void:
	_t += delta
	if player_body != null and not _lit:
		var near := global_position.distance_to(player_body.global_position) < INTERACT_RANGE
		_prompt.visible = near
	var e := 0.0
	if _lit:
		e = _base_energy * (0.9 + 0.1 * _flick_noise.get_noise_1d(_t * 9.0))
	_bowl_light.light_energy = e
	_dome_light.light_energy = e * 0.32


func _physics_process(_delta: float) -> void:
	if _lit or player_body == null:
		return
	if global_position.distance_to(player_body.global_position) < INTERACT_RANGE \
			and Input.is_action_just_pressed("interact"):
		try_interact()


func try_interact() -> bool:
	if _lit:
		return false
	if player_body != null and global_position.distance_to(player_body.global_position) > INTERACT_RANGE:
		return false
	ignite()
	return true


func ignite() -> void:
	if _lit:
		return
	_lit = true
	_prompt.visible = false
	_prompt.text = "BEACON LIT"
	_prompt.modulate = Color(1.0, 0.8, 0.45)
	_prompt.visible = true
	_flame.emitting = true
	_ember_mat.emission_energy_multiplier = 2.2
	var tw := create_tween()
	tw.tween_method(_set_ignite_ratio, 0.0, 1.0, IGNITE_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func(): _prompt.visible = false)
	lit_changed.emit(self)


func _set_ignite_ratio(r: float) -> void:
	_base_energy = 6.0 * r


func is_lit() -> bool:
	return _lit


func _make_flame() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 22
	p.lifetime = 0.6
	p.direction = Vector3.UP
	p.spread = 14.0
	p.gravity = Vector3(0, 1.4, 0)
	p.initial_velocity_min = 0.9
	p.initial_velocity_max = 1.8
	p.scale_amount_min = 0.45
	p.scale_amount_max = 0.85
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.3
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([
		Color(1.0, 0.62, 0.22, 0.75),
		Color(0.95, 0.35, 0.08, 0.6),
		Color(0.45, 0.08, 0.02, 0.0),
	])
	p.color_ramp = g
	var quad := QuadMesh.new()
	quad.size = Vector2(0.17, 0.17)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.albedo_color = Color(1, 1, 1, 1)
	qm.disable_receive_shadows = true
	quad.material = qm
	p.mesh = quad
	return p


func _stone(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.95
	return m
