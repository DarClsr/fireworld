extends Node3D
## 一颗星籽：呼吸发光小球 + 扑翼 + 微尘拖尾。位移由 SeedSwarm 驱动，这里只管卖萌。

var _idx := 0
var _t := 0.0
var _noise := FastNoiseLite.new()

var _core_mat: StandardMaterial3D
var _halo_mat: StandardMaterial3D
var _wing_l: MeshInstance3D
var _wing_r: MeshInstance3D


func setup(index: int) -> void:
	_idx = index
	_t = randf() * TAU
	_noise.seed = index * 917 + 7
	_noise.frequency = 1.6


func _ready() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.115
	sphere.height = 0.23
	sphere.radial_segments = 18
	sphere.rings = 9

	_core_mat = StandardMaterial3D.new()
	_core_mat.albedo_color = Color(0.99, 0.78, 0.42)
	_core_mat.emission_enabled = true
	_core_mat.emission = Color(1.0, 0.68, 0.30)
	_core_mat.emission_energy_multiplier = 1.25
	_core_mat.roughness = 0.4

	var body := MeshInstance3D.new()
	body.mesh = sphere
	body.scale = Vector3.ONE * 0.8
	body.material_override = _core_mat
	add_child(body)

	_halo_mat = StandardMaterial3D.new()
	_halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_halo_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_halo_mat.albedo_color = Color(1.0, 0.72, 0.36, 0.10)
	_halo_mat.no_depth_test = false
	var halo := MeshInstance3D.new()
	var halo_mesh := SphereMesh.new()
	halo_mesh.radius = 0.115
	halo_mesh.height = 0.23
	halo.mesh = halo_mesh
	halo.scale = Vector3.ONE * 1.5
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.material_override = _halo_mat
	add_child(halo)

	var wing_mat := _core_mat.duplicate() as StandardMaterial3D
	wing_mat.emission_energy_multiplier = 0.9
	_wing_l = _make_wing(sphere, wing_mat)
	_wing_l.position.x = -0.13
	_wing_l.scale = Vector3(1.55, 0.3, 0.8)
	_wing_r = _make_wing(sphere, wing_mat)
	_wing_r.position.x = 0.13
	_wing_r.scale = Vector3(1.55, 0.3, 0.8)

	_add_sparkles()


func _make_wing(base_sphere: SphereMesh, mat: Material) -> MeshInstance3D:
	var wing := MeshInstance3D.new()
	wing.mesh = base_sphere
	wing.material_override = mat
	wing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wing)
	return wing


func _add_sparkles() -> void:
	var p := CPUParticles3D.new()
	p.amount = 12
	p.lifetime = 0.6
	p.gravity = Vector3(0, 0.28, 0)
	p.initial_velocity_min = 0.08
	p.initial_velocity_max = 0.22
	p.scale_amount_min = 0.5
	p.scale_amount_max = 0.9
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.09

	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.albedo_color = Color(1.0, 0.8, 0.45, 0.65)
	qm.disable_receive_shadows = true
	quad.material = qm
	p.mesh = quad
	add_child(p)


func _process(delta: float) -> void:
	_t += delta
	var breath := sin(_t * 3.1 + float(_idx) * 1.7)
	_core_mat.emission_energy_multiplier = 1.1 + 0.3 * breath
	_halo_mat.albedo_color.a = 0.08 + 0.04 * breath
	var flap := sin(_t * 15.0 + float(_idx) * 2.1)
	_wing_l.rotation.z = 0.55 * flap
	_wing_r.rotation.z = -0.55 * flap
