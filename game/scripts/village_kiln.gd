extends Node3D
## 灰窑村全程序化搭建：山坳石壁、村舍（含窗光投影）、大灰窑、灯笼折线路、
## 陶婆婆、村口栅栏、瞭望塔剪影、地被散布（草/石/丛）、萤火虫、炊烟。
## 布局用局部坐标（村庄实例放在原点，局部=世界）。美术升级第一梯队见 docs/07。

var font: Font

# 关键点位（director / main 通过 to_global 换算）
var spawn_local := Vector3(-6.5, 0.06, 12.0)
var grandma_local := Vector3(7.2, 0.0, -8.0)
var kiln_spark_local := Vector3(7.9, 1.15, -8.6)
var gate_local := Vector3(2.8, 0.0, -14.4)
var dummy_local := Vector3(-4.5, 0.0, -9.5)

var lantern_lights: Array[OmniLight3D] = []

var _ember_light: OmniLight3D
var _noise := FastNoiseLite.new()
var _t := 0.0
var _gobo: ImageTexture
var _home_root: Node3D

const HOUSES := [
	{"pos": Vector3(-9.5, 0, 12.5), "rot": 18.0, "home": true, "h": 1.0},
	{"pos": Vector3(5.5, 0, 10.5), "rot": -35.0, "home": false, "h": 0.92},
	{"pos": Vector3(-12.0, 0, 1.5), "rot": 95.0, "home": false, "h": 1.08},
	{"pos": Vector3(11.5, 0, 3.5), "rot": -58.0, "home": false, "h": 0.96},
	{"pos": Vector3(-8.5, 0, -12.5), "rot": 118.0, "home": false, "h": 1.14},
]
const LANTERNS := [
	Vector3(-4.5, 0, 7.5), Vector3(0.5, 0, 5.0), Vector3(-3.0, 0, 0.5),
	Vector3(2.0, 0, -2.5), Vector3(-1.0, 0, -7.0), Vector3(4.0, 0, -10.5),
]
const TOWER_POS := Vector3(16.5, 0, -11.5)
# 散布避让点（x, z, 半径）
const AVOID := [
	[-9.5, 12.5, 3.2], [5.5, 10.5, 3.2], [-12.0, 1.5, 3.2], [11.5, 3.5, 3.2],
	[-8.5, -12.5, 3.2], [9.4, -10.2, 3.8], [7.2, -8.0, 1.6], [2.8, -14.4, 2.0],
	[-6.5, 12.0, 1.6], [-4.5, -9.5, 1.4], [-2.0, 6.8, 1.8], [16.5, -11.5, 2.6],
	[-4.2, 11.3, 1.2], [2.6, 11.8, 1.2], [-1.0, 8.6, 1.2], [7.6, -6.6, 1.2],
	[-10.8, -2.0, 1.2],
]
# 村中小径折线（散布避让，玩家动线）
const PATH_PTS := [
	Vector2(-6.5, 12.0), Vector2(-2.0, 7.0), Vector2(0.0, 2.0),
	Vector2(1.5, -3.0), Vector2(2.0, -8.0), Vector2(2.8, -14.0),
]


func _ready() -> void:
	_noise.seed = 55
	_noise.frequency = 9.0
	for h: Dictionary in HOUSES:
		_build_house(h)
	_build_kiln()
	for p: Vector3 in LANTERNS:
		_build_lantern(p)
	_build_props()
	_build_grandma()
	_build_rocks()
	_build_watchtower()
	_build_ground_cover()
	add_child(_make_fireflies())
	_make_smoke(_home_root.to_global(Vector3(1.0, 4.0, 1.0)))
	_make_smoke(Vector3(9.4, 4.8, -10.2))


func _process(delta: float) -> void:
	_t += delta
	if _ember_light != null:
		_ember_light.light_energy = 1.3 * (0.86 + 0.14 * _noise.get_noise_1d(_t * 7.0))


# ---------------------------------------------------------------- 村舍

func _build_house(cfg: Dictionary) -> void:
	var root := Node3D.new()
	root.position = cfg.pos
	root.rotation_degrees.y = cfg.rot
	add_child(root)
	if cfg.home:
		_home_root = root

	var hf: float = cfg.h
	var walls := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(3.6, 2.3 * hf, 4.4)
	walls.mesh = wm
	walls.position.y = 1.15 * hf
	walls.material_override = _mat(Color(0.56, 0.52, 0.46))
	root.add_child(walls)

	var roof := MeshInstance3D.new()
	var rm := PrismMesh.new()
	rm.size = Vector3(4.4, 1.5 * hf, 5.1)
	roof.mesh = rm
	roof.position.y = 2.3 * hf + 0.74 * hf
	roof.material_override = _mat(Color(0.27, 0.19, 0.14))
	root.add_child(roof)

	var door := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(0.9, 1.5 * hf, 0.12)
	door.mesh = dm
	door.position = Vector3(0, 0.75 * hf, -2.24)
	door.material_override = _mat(Color(0.23, 0.16, 0.11))
	root.add_child(door)

	# 窗：炉火余光 + 窗棂投影灯（生活形状的来源）
	var win_count := 2 if cfg.home else 1
	for i in range(win_count):
		var wx := -1.1 + 2.2 * float(i)
		var win := MeshInstance3D.new()
		var wmesh := BoxMesh.new()
		wmesh.size = Vector3(0.7, 0.55, 0.08)
		win.mesh = wmesh
		win.position = Vector3(wx, 1.35, -2.22)
		win.material_override = _glow(Color(1.0, 0.76, 0.42), 1.1)
		root.add_child(win)

		var spot := SpotLight3D.new()
		spot.position = Vector3(wx, 1.42, -2.45)
		spot.rotation_degrees.x = -56.0
		spot.light_color = Color(1.0, 0.7, 0.4)
		spot.spot_range = 6.5
		spot.spot_angle = 44.0
		spot.light_energy = 1.5
		spot.spot_attenuation = 1.3
		spot.shadow_enabled = false
		spot.light_projector = _window_gobo()
		root.add_child(spot)

	if cfg.home:
		var chim := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(0.5, 1.1, 0.5)
		chim.mesh = cm
		chim.position = Vector3(1.0, 3.4 * hf, 1.0)
		chim.material_override = _mat(Color(0.4, 0.38, 0.36))
		root.add_child(chim)


func _window_gobo() -> ImageTexture:
	if _gobo != null:
		return _gobo
	var img: Image
	if ClassDB.class_has_method("Image", "create_empty"):
		img = Image.create_empty(64, 64, false, Image.FORMAT_RGB8)
	else:
		img = Image.create(64, 64, false, Image.FORMAT_RGB8)
	var dark := Color(0.03, 0.03, 0.03)
	var lit := Color(1, 1, 1)
	img.fill(dark)
	img.fill_rect(Rect2i(12, 12, 40, 42), lit)
	img.fill_rect(Rect2i(29, 12, 6, 42), dark)    # 竖棂
	img.fill_rect(Rect2i(12, 30, 40, 5), dark)    # 横棂
	img.fill_rect(Rect2i(9, 9, 46, 4), dark)      # 上框
	img.fill_rect(Rect2i(9, 52, 46, 4), dark)     # 下框
	_gobo = ImageTexture.create_from_image(img)
	return _gobo


# ---------------------------------------------------------------- 灰窑

func _build_kiln() -> void:
	var root := Node3D.new()
	root.position = Vector3(9.4, 0, -10.2)
	root.rotation_degrees.y = -42.0
	add_child(root)

	var base := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 2.5
	bm.bottom_radius = 2.9
	bm.height = 0.9
	base.mesh = bm
	base.position.y = 0.45
	base.material_override = _mat(Color(0.3, 0.3, 0.32))
	root.add_child(base)

	var body := MeshInstance3D.new()
	var km := CylinderMesh.new()
	km.top_radius = 1.75
	km.bottom_radius = 2.15
	km.height = 3.1
	body.mesh = km
	body.position.y = 2.4
	body.material_override = _mat(Color(0.34, 0.34, 0.37))
	root.add_child(body)

	var dome := MeshInstance3D.new()
	var dm := SphereMesh.new()
	dm.radius = 1.75
	dm.height = 3.5
	dome.mesh = dm
	dome.scale = Vector3(1.0, 0.55, 1.0)
	dome.position.y = 3.95
	dome.material_override = _mat(Color(0.31, 0.31, 0.34))
	root.add_child(dome)

	var mouth := MeshInstance3D.new()
	var mm := BoxMesh.new()
	mm.size = Vector3(1.1, 1.5, 0.5)
	mouth.mesh = mm
	mouth.position = Vector3(-1.95, 1.6, 0)
	mouth.material_override = _mat(Color(0.04, 0.03, 0.03))
	root.add_child(mouth)

	var ember := MeshInstance3D.new()
	var em := BoxMesh.new()
	em.size = Vector3(0.7, 0.8, 0.1)
	ember.mesh = em
	ember.position = Vector3(-1.75, 1.35, 0)
	ember.material_override = _glow(Color(1.0, 0.45, 0.15), 1.5)
	root.add_child(ember)

	_ember_light = OmniLight3D.new()
	_ember_light.position = Vector3(-2.6, 1.6, 0)
	_ember_light.light_color = Color(1.0, 0.58, 0.28)
	_ember_light.omni_range = 8.0
	_ember_light.light_energy = 1.3
	_ember_light.shadow_enabled = false
	root.add_child(_ember_light)


# ---------------------------------------------------------------- 灯笼 / 杂物

func _build_lantern(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)

	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.05
	pm.bottom_radius = 0.07
	pm.height = 2.3
	pole.mesh = pm
	pole.position.y = 1.15
	pole.material_override = _mat(Color(0.25, 0.19, 0.14))
	root.add_child(pole)

	var head := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.3, 0.36, 0.3)
	head.mesh = hm
	head.position.y = 2.28
	head.material_override = _glow(Color(1.0, 0.78, 0.45), 1.1)
	root.add_child(head)

	var light := OmniLight3D.new()
	light.position = Vector3(0, 2.25, 0)
	light.light_color = Color(1.0, 0.72, 0.42)
	light.omni_range = 6.5
	light.light_energy = 1.1
	light.shadow_enabled = false
	root.add_child(light)
	lantern_lights.append(light)


func _build_props() -> void:
	# 柴堆
	for pos: Vector3 in [Vector3(-1.0, 0, 8.6), Vector3(7.6, 0, -6.6), Vector3(-10.8, 0, -2.0)]:
		for i in range(3):
			var log := MeshInstance3D.new()
			var lm := CylinderMesh.new()
			lm.top_radius = 0.09
			lm.bottom_radius = 0.1
			lm.height = 0.85
			log.mesh = lm
			log.rotation_degrees = Vector3(0, 15.0 * float(i) + 20.0, 90)
			log.position = pos + Vector3(0, 0.11 + 0.19 * float(i / 2), 0)
			log.material_override = _mat(Color(0.3, 0.22, 0.15))
			add_child(log)
	# 水缸（前景生活道具）
	for pos: Vector3 in [Vector3(-4.2, 0, 11.3), Vector3(2.6, 0, 11.8)]:
		var vat := MeshInstance3D.new()
		var vm := CylinderMesh.new()
		vm.top_radius = 0.44
		vm.bottom_radius = 0.32
		vm.height = 0.62
		vat.mesh = vm
		vat.position = pos + Vector3(0, 0.31, 0)
		vat.material_override = _mat(Color(0.4, 0.3, 0.24))
		add_child(vat)
		var water := MeshInstance3D.new()
		var wm2 := CylinderMesh.new()
		wm2.top_radius = 0.38
		wm2.bottom_radius = 0.38
		wm2.height = 0.04
		water.mesh = wm2
		water.position = pos + Vector3(0, 0.56, 0)
		water.material_override = _mat(Color(0.1, 0.14, 0.18))
		add_child(water)
	# 村口拒马
	for spec: Array in [
		[Vector3(0.4, 0.95, -16.2), Vector3(0.0, 0.0, 32.0)],
		[Vector3(0.4, 0.95, -16.2), Vector3(0.0, 0.0, -32.0)],
		[Vector3(0.4, 0.55, -16.2), Vector3(0.0, 0.0, 0.0)],
	]:
		var plank := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(2.8, 0.22, 0.22)
		plank.mesh = pm
		plank.position = spec[0]
		plank.rotation_degrees = spec[1]
		plank.material_override = _mat(Color(0.36, 0.27, 0.18))
		add_child(plank)


func _build_grandma() -> void:
	var root := Node3D.new()
	root.position = grandma_local
	root.rotation_degrees.y = 138.0
	add_child(root)

	var body := MeshInstance3D.new()
	var bm := CapsuleMesh.new()
	bm.radius = 0.3
	bm.height = 1.25
	body.mesh = bm
	body.position.y = 0.68
	body.material_override = _mat(Color(0.47, 0.5, 0.58))
	root.add_child(body)

	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.17
	hm.height = 0.34
	head.mesh = hm
	head.position.y = 1.46
	head.material_override = _mat(Color(0.78, 0.64, 0.52))
	root.add_child(head)

	var bun := MeshInstance3D.new()
	var um := SphereMesh.new()
	um.radius = 0.09
	um.height = 0.18
	bun.mesh = um
	bun.position = Vector3(0, 1.62, 0.1)
	bun.material_override = _mat(Color(0.62, 0.62, 0.6))
	root.add_child(bun)

	var stick := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.025
	sm.bottom_radius = 0.03
	sm.height = 1.3
	stick.mesh = sm
	stick.position = Vector3(0.4, 0.65, 0.15)
	stick.rotation_degrees.z = -8.0
	stick.material_override = _mat(Color(0.32, 0.24, 0.16))
	root.add_child(stick)

	var plate := Label3D.new()
	plate.text = "陶婆婆"
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plate.font_size = 42
	plate.outline_size = 12
	plate.pixel_size = 0.006
	plate.position.y = 2.0
	plate.modulate = Color(0.93, 0.85, 0.66)
	if font != null:
		plate.font = font
	root.add_child(plate)


# ---------------------------------------------------------------- 瞭望塔（天际线剪影）

func _build_watchtower() -> void:
	var root := Node3D.new()
	root.position = TOWER_POS
	add_child(root)
	var wood_dark := _mat(Color(0.22, 0.17, 0.12))
	for sx in [-0.5, 0.5]:
		var leg := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.34, 7.6, 0.34)
		leg.mesh = lm
		leg.position = Vector3(sx, 3.8, 0)
		leg.material_override = wood_dark
		root.add_child(leg)
	for y in [2.2, 4.6, 6.4]:
		var brace := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.35, 0.14, 0.14)
		brace.mesh = bm
		brace.position = Vector3(0, y, 0)
		brace.material_override = wood_dark
		root.add_child(brace)

	var platform := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(1.9, 0.18, 1.9)
	platform.mesh = pm
	platform.position.y = 7.7
	platform.material_override = wood_dark
	root.add_child(platform)

	var hut := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(1.35, 1.05, 1.35)
	hut.mesh = hm
	hut.position.y = 8.3
	hut.material_override = _mat(Color(0.3, 0.25, 0.2))
	root.add_child(hut)

	var roof := MeshInstance3D.new()
	var rm := PrismMesh.new()
	rm.size = Vector3(1.7, 0.7, 1.7)
	roof.mesh = rm
	roof.position.y = 9.15
	roof.material_override = _mat(Color(0.24, 0.17, 0.12))
	root.add_child(roof)

	var win := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(0.4, 0.4, 0.06)
	win.mesh = wm
	win.position = Vector3(0, 8.35, -0.7)
	win.material_override = _glow(Color(1.0, 0.74, 0.4), 1.4)
	root.add_child(win)

	var light := OmniLight3D.new()
	light.position = Vector3(0, 8.4, -0.9)
	light.light_color = Color(1.0, 0.72, 0.42)
	light.omni_range = 5.0
	light.light_energy = 0.9
	light.shadow_enabled = false
	root.add_child(light)
	lantern_lights.append(light)


# ---------------------------------------------------------------- 山坳石壁

func _build_rocks() -> void:
	for i in range(14):
		var ang := TAU * float(i) / 14.0 + 0.2
		var r := 27.0 + 6.0 * float(i % 3)
		var pos := Vector3(sin(ang) * r, 0.0, cos(ang) * r)
		if pos.z < -13.0 and absf(pos.x) < 8.0:
			continue   # 村口留豁口
		var size := Vector3(5.0 + float(i % 4) * 1.6, 8.0 + float(i % 3) * 3.0, 5.0 + float(i % 5) * 1.2)
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = pos
		body.rotation_degrees.y = float(i) * 37.0
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
		mi.material_override = _mat(Color(0.14, 0.15, 0.18))
		body.add_child(mi)
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		body.add_child(col)
		add_child(body)


# ---------------------------------------------------------------- 地被散布

func _build_ground_cover() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260828
	_cover_layer(_grass_multimesh(), 380, rng, 0.45, [
		Color(0.23, 0.26, 0.16), Color(0.30, 0.27, 0.15), Color(0.20, 0.22, 0.18),
	])
	_cover_layer(_stone_multimesh(), 70, rng, 0.3, [
		Color(0.21, 0.215, 0.24), Color(0.25, 0.245, 0.23), Color(0.19, 0.19, 0.22),
	])
	_cover_layer(_shrub_multimesh(), 55, rng, 0.4, [
		Color(0.15, 0.19, 0.12), Color(0.19, 0.21, 0.11), Color(0.13, 0.17, 0.14),
	])


func _cover_layer(mm: MultiMesh, count: int, rng: RandomNumberGenerator, noise_min: float,
		tones: Array[Color]) -> void:
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.instance_count = count
	var placed := 0
	var guard := 0
	while placed < count and guard < count * 30:
		guard += 1
		var x := rng.randf_range(-21.0, 21.0)
		var z := rng.randf_range(-14.0, 18.0)
		if _noise.get_noise_2d(x * 0.5, z * 0.5) < noise_min:
			continue
		if _in_avoid(x, z):
			continue
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU))
		basis = basis.scaled(Vector3.ONE * rng.randf_range(0.7, 1.3))
		mm.set_instance_transform(placed, Transform3D(basis, Vector3(x, 0.0, z)))
		mm.set_instance_color(placed, tones[rng.randi_range(0, tones.size() - 1)])
		placed += 1
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _in_avoid(x: float, z: float) -> bool:
	for a: Array in AVOID:
		var dx := x - float(a[0])
		var dz := z - float(a[1])
		if dx * dx + dz * dz < float(a[2]) * float(a[2]):
			return true
	for i in range(PATH_PTS.size() - 1):
		if _dist_to_segment(Vector2(x, z), PATH_PTS[i], PATH_PTS[i + 1]) < 1.7:
			return true
	return false


func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _finish_mm(mm: MultiMesh, mesh: Mesh) -> MultiMesh:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mesh.surface_set_material(0, mat)
	return mm


func _grass_multimesh() -> MultiMesh:
	var mm := MultiMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# 两片交叉四边形
	for quad_x_rot: float in [0.0, PI * 0.5]:
		var c := cos(quad_x_rot)
		var s := sin(quad_x_rot)
		var w := 0.09
		var h := 0.42
		var pts := [
			Vector3(-w * c, 0, -w * s), Vector3(w * c, 0, w * s),
			Vector3(w * c, h, w * s), Vector3(-w * c, h, -w * s),
		]
		var uv := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for idx: Array in [[0, 1, 2], [0, 2, 3]]:
			for vi: int in idx:
				st.set_normal(Vector3.UP)
				st.set_uv(uv[vi])
				st.add_vertex(pts[vi])
	var mesh := st.commit()
	mm.mesh = mesh
	return _finish_mm(mm, mesh)


func _stone_multimesh() -> MultiMesh:
	var mm := MultiMesh.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.13
	mesh.height = 0.26
	mm.mesh = mesh
	return _finish_mm(mm, mesh)


func _shrub_multimesh() -> MultiMesh:
	var mm := MultiMesh.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.3
	mesh.height = 0.6
	mm.mesh = mesh
	return _finish_mm(mm, mesh)


# ---------------------------------------------------------------- 空气生命

func _make_fireflies() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.position = Vector3(0, 1.7, 1.0)
	p.amount = 26
	p.lifetime = 7.0
	p.preprocess = 6.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(15.0, 1.6, 13.0)
	p.gravity = Vector3(0, 0.02, 0)
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.18
	p.direction = Vector3(1, 0, 0)
	p.spread = 180.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.0
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.7, 1.0])
	g.colors = PackedColorArray([
		Color(0.8, 0.95, 0.5, 0.0),
		Color(0.8, 0.95, 0.5, 0.85),
		Color(0.7, 0.85, 0.45, 0.5),
		Color(0.8, 0.95, 0.5, 0.0),
	])
	p.color_ramp = g
	var quad := QuadMesh.new()
	quad.size = Vector2(0.055, 0.055)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = qm
	p.mesh = quad
	return p


func _make_smoke(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.position = pos
	p.amount = 7
	p.lifetime = 4.5
	p.preprocess = 4.0
	p.direction = Vector3(0.25, 1, 0)
	p.spread = 7.0
	p.gravity = Vector3(0.05, 0.08, 0)
	p.initial_velocity_min = 0.45
	p.initial_velocity_max = 0.7
	p.scale_amount_min = 0.3
	p.scale_amount_max = 0.6
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([
		Color(0.32, 0.35, 0.42, 0.07),
		Color(0.32, 0.35, 0.42, 0.0),
	])
	p.color_ramp = g
	var quad := QuadMesh.new()
	quad.size = Vector2(0.42, 0.42)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.albedo_color = Color(1, 1, 1, 1)
	quad.material = qm
	p.mesh = quad
	add_child(p)


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.92
	return m


func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m
