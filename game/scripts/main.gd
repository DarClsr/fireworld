extends Node3D
## M1 灰盒：永夜世界 + 木籽藤桥 + 烽台点火推夜。
## 运行参数（`--` 之后）：
##   --smoke                headless 冒烟自检，PASS 后 quit(0)
##   --shot=path_base       演出式截图（wide/bridge/beacon/bench 四张）后 quit(0)

const PlayerScript := preload("res://scripts/player.gd")
const DummyScript := preload("res://scripts/dummy.gd")
const SwarmScript := preload("res://scripts/seed_swarm.gd")
const BeaconScript := preload("res://scripts/beacon.gd")
const BridgeScript := preload("res://scripts/vine_bridge.gd")

const SPAWN := Vector3(0, 0.06, 0.5)

var player
var dummy
var swarm
var beacon
var bridge
var hud: Label
var _lit_count := 0
var _camp_light: OmniLight3D
var _flick := FastNoiseLite.new()
var _t := 0.0

var _checks := 0
var _shot_base := ""
var _fog_off := false
var _smoke_requested := false
var _frame := 0
var _fps_accum := 0.0
var _fps_n := 0
var _deltas: Array[float] = []


func _ready() -> void:
	InputDefs.ensure_actions()
	_flick.seed = 7
	_flick.frequency = 7.0

	for a in OS.get_cmdline_user_args():
		if a == "--smoke":
			_smoke_requested = true
		elif a == "--nofog":
			_fog_off = true
		elif a.begins_with("--shot="):
			_shot_base = a.trim_prefix("--shot=")

	_build_world()

	if DisplayServer.get_name() != "headless" and _shot_base == "":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _smoke_requested:
		_run_smoke.call_deferred()
	elif _shot_base != "":
		_run_shot_timeline.call_deferred()


func _physics_process(delta: float) -> void:
	_t += delta
	if _camp_light != null:
		_camp_light.light_energy = 2.6 * (0.88 + 0.12 * _flick.get_noise_1d(_t * 8.0))
	if is_instance_valid(player) and player.global_position.y < -6.0:
		player.global_position = SPAWN
		player.velocity = Vector3.ZERO


func _process(delta: float) -> void:
	_frame += 1
	_deltas.append(delta)
	if _deltas.size() > 600:
		_deltas = _deltas.slice(_deltas.size() - 600)
	_fps_accum += delta
	_fps_n += 1
	if _fps_n >= 30 and is_instance_valid(hud):
		var fps := float(_fps_n) / maxf(_fps_accum, 0.0001)
		var form := "RAW"
		if player.selected_form == 1:
			form = "WOOD"
		hud.text = "FPS %d | seeds %d | beacons %d/1 | FORM %s | frame %d" % [
				roundi(fps), swarm.seed_count(), _lit_count, form, _frame]
		_fps_accum = 0.0
		_fps_n = 0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("add_seed"):
		swarm.add_seed(1)
	elif event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and DisplayServer.get_name() != "headless":
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func lit_count() -> int:
	return _lit_count


# ---------------------------------------------------------------- 世界搭建

func _build_world() -> void:
	add_child(_make_night_environment())
	add_child(_make_moon())
	add_child(_make_grading_overlay())

	add_child(_make_platform(Vector3(0, -0.5, -6.0), Vector2(24, 32)))    # 主平台 z∈[-22,10]
	add_child(_make_platform(Vector3(0, -0.5, -35.0), Vector2(10, 10)))   # 小岛 z∈[-40,-30]
	add_child(_make_abyss_floor())

	for spec: Array in [
		[Vector3(-4.5, 0.75, -7.0), Vector3(1.6, 1.5, 1.6)],
		[Vector3(5.5, 0.5, -10.0), Vector3(1.2, 1.0, 2.4)],
		[Vector3(-8.0, 1.25, -15.0), Vector3(2.2, 2.5, 2.2)],
		[Vector3(3.4, 0.5, -37.2), Vector3(1.2, 1.0, 1.2)],
	]:
		add_child(_make_block(spec[0], spec[1]))

	add_child(_make_campfire(Vector3(2.3, 0, 1.6)))

	player = PlayerScript.new()
	player.position = SPAWN
	add_child(player)

	dummy = DummyScript.new()
	dummy.position = Vector3(0, 0, -1.55)
	add_child(dummy)

	swarm = SwarmScript.new()
	swarm.player_body = player
	add_child(swarm)
	player.swarm = swarm

	bridge = BridgeScript.new()
	add_child(bridge)

	beacon = BeaconScript.new()
	beacon.position = Vector3(0, 0, -35.0)
	beacon.player_body = player
	beacon.lit_changed.connect(func(_b): _lit_count += 1)
	add_child(beacon)

	var canvas := CanvasLayer.new()
	canvas.layer = 1
	add_child(canvas)
	hud = Label.new()
	hud.position = Vector2(12, 10)
	hud.text = "booting..."
	canvas.add_child(hud)


func _make_night_environment() -> WorldEnvironment:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.012, 0.02, 0.05)
	mat.sky_horizon_color = Color(0.07, 0.1, 0.18)
	mat.ground_bottom_color = Color(0.004, 0.005, 0.01)
	mat.ground_horizon_color = Color(0.05, 0.07, 0.13)
	sky.sky_material = mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.55, 0.75)
	env.ambient_light_energy = 0.22
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.08, 0.14)
	env.fog_density = 0.012
	env.fog_sky_affect = 0.15
	if _fog_off:
		return
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.026
	env.volumetric_fog_albedo = Color(0.5, 0.56, 0.72)
	env.volumetric_fog_emission = Color(0.06, 0.09, 0.16)
	env.volumetric_fog_emission_energy = 0.8
	env.volumetric_fog_anisotropy = 0.6
	env.volumetric_fog_length = 48.0
	we.environment = env
	return we


func _make_moon() -> DirectionalLight3D:
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-38, 140, 0)
	moon.light_color = Color(0.6, 0.7, 1.0)
	moon.light_energy = 0.28
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 60.0
	return moon


func _make_grading_overlay() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = -1
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float strength = 0.30;
void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 graded = mix(col, lum * vec3(0.45, 0.62, 1.05), 0.45);
	float d = distance(SCREEN_UV, vec2(0.5, 0.55));
	float vig = smoothstep(0.42, 1.05, d);
	vec3 outc = mix(col, graded, strength);
	outc *= 1.0 - vig * 0.45;
	COLOR = vec4(outc, 1.0);
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = shader
	rect.material = sm
	layer.add_child(rect)
	return layer


func _make_platform(center: Vector3, size: Vector2) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = center
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(size.x, 1.0, size.y)
	mi.mesh = bm
	mi.material_override = _ground_material()
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, 1.0, size.y)
	col.shape = shape
	body.add_child(col)
	return body


func _make_abyss_floor() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(160, 160)
	mi.mesh = pm
	mi.position.y = -9.0
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.012, 0.014, 0.022)
	m.roughness = 1.0
	mi.material_override = m
	return mi


func _ground_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.30, 0.34, 0.26)
	var noise := FastNoiseLite.new()
	noise.frequency = 0.05
	var nt := NoiseTexture2D.new()
	nt.width = 256
	nt.height = 256
	nt.noise = noise
	mat.albedo_texture = nt
	mat.uv1_scale = Vector3(10.0, 10.0, 1.0)
	mat.roughness = 1.0
	return mat


func _make_block(pos: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _flat(Color(0.30, 0.30, 0.29))
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	return body


func _make_campfire(pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	for i in range(3):
		var log := MeshInstance3D.new()
		var lm := CylinderMesh.new()
		lm.top_radius = 0.05
		lm.bottom_radius = 0.06
		lm.height = 0.85
		log.mesh = lm
		log.rotation_degrees = Vector3(78, 120.0 * float(i), 0)
		log.position.y = 0.12
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.2, 0.14, 0.1)
		m.roughness = 1.0
		log.material_override = m
		root.add_child(log)

	var p := CPUParticles3D.new()
	p.position.y = 0.32
	p.amount = 14
	p.lifetime = 0.5
	p.direction = Vector3.UP
	p.spread = 10.0
	p.gravity = Vector3(0, 1.1, 0)
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.1
	p.scale_amount_min = 0.3
	p.scale_amount_max = 0.5
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.16
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	g.colors = PackedColorArray([
		Color(1.0, 0.62, 0.22, 0.7),
		Color(0.95, 0.35, 0.08, 0.55),
		Color(0.45, 0.08, 0.02, 0.0),
	])
	p.color_ramp = g
	var quad := QuadMesh.new()
	quad.size = Vector2(0.13, 0.13)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = qm
	p.mesh = quad
	root.add_child(p)

	_camp_light = OmniLight3D.new()
	_camp_light.position = Vector3(0, 0.9, 0)
	_camp_light.light_color = Color(1.0, 0.7, 0.4)
	_camp_light.omni_range = 8.5
	_camp_light.light_energy = 2.6
	_camp_light.shadow_enabled = false
	root.add_child(_camp_light)
	return root


func _flat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	return m


# ---------------------------------------------------------------- 冒烟自检

func _check(cond: bool, what: String) -> void:
	if cond:
		_checks += 1
	else:
		print("[SMOKE] FAIL: ", what)
		get_tree().quit(1)


func _run_smoke() -> void:
	print("[SMOKE] begin")
	await get_tree().physics_frame
	await _wait_physics(20)

	_check(is_instance_valid(player), "player alive")
	_check(is_instance_valid(dummy), "dummy alive")
	_check(swarm.seed_count() == 3, "initial seeds = 3 (got %d)" % swarm.seed_count())

	var hp0: float = dummy.hp
	player.debug_attack(false)
	var got_light := await _wait_until(func(): return dummy.hp < hp0 - 0.001, 300)
	_check(got_light, "light attack damaged dummy")

	var hp1: float = dummy.hp
	player.debug_attack(true)
	var got_heavy := await _wait_until(func(): return dummy.hp < hp1 - 0.001, 360)
	_check(got_heavy, "heavy attack damaged dummy")

	swarm.add_seed(2)
	await _wait_physics(60)
	_check(swarm.seed_count() == 5, "seeds grew to 5 (got %d)" % swarm.seed_count())

	# —— M1：掷木籽 → 长桥 → 过沟 ——
	player.debug_set_move(Vector3(0, 0, -1))
	var at_edge := await _wait_until(func(): return player.global_position.z < -18.5, 400)
	_check(at_edge, "reached gap edge")
	player.debug_clear_move()

	var seeds_before: int = swarm.seed_count()
	player.debug_throw()
	var thrown := await _wait_until(func(): return swarm.seed_count() == seeds_before - 1, 90)
	_check(thrown, "seed consumed on throw")

	var grown := await _wait_until(func(): return bridge.is_grown(), 300)
	_check(grown, "vine bridge grown")

	player.debug_set_move(Vector3(0, 0, -1))
	var crossed := await _wait_until(func(): return player.global_position.z < -31.0, 500)
	player.debug_clear_move()
	_check(crossed, "crossed to islet")
	_check(player.global_position.y > -1.5, "stood on bridge/islet")

	# —— M1：烽台交互 ——
	player.global_position = Vector3(1.5, 0.06, -33.9)
	player.velocity = Vector3.ZERO
	await _wait_physics(5)
	_check(beacon.try_interact(), "interact ignites beacon")
	_check(beacon.is_lit(), "beacon lit")
	_check(lit_count() == 1, "lit_count == 1")

	await _wait_physics(60)
	_check(swarm.all_positions_finite(), "seed transforms finite")

	print("[SMOKE] PASS %d checks" % _checks)
	get_tree().quit(0)


func _wait_physics(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame


func _wait_until(pred: Callable, max_frames: int) -> bool:
	for i in range(max_frames):
		if pred.call():
			return true
		await get_tree().physics_frame
	return pred.call()


# ---------------------------------------------------------------- 截图演出

func _aim_cam(cam: Camera3D, eye: Vector3, at: Vector3) -> void:
	cam.global_position = eye
	cam.look_at(at, Vector3.UP)


func _r(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _snap(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("[SHOT] saved ", path)


func _run_shot_timeline() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	var dir := _shot_base.get_base_dir()
	if dir != "":
		DirAccess.make_dir_recursive_absolute(dir)
	var cin := Camera3D.new()
	cin.fov = 54.0
	add_child(cin)
	cin.make_current()

	# Beat 1 夜营全景：篝火、木桩、星籽
	_aim_cam(cin, Vector3(3.6, 1.8, 4.5), Vector3(0.1, 1.0, -0.7))
	await _r(45)
	await _snap(_shot_base + "_wide.png")

	# Beat 2 藤桥：长桥过沟
	bridge.grow()
	player.debug_set_move(Vector3(0, 0, -1))
	await _wait_until(func(): return player.global_position.z < -26.0, 500)
	player.debug_clear_move()
	_aim_cam(cin, Vector3(4.2, 2.2, -25.4), Vector3(0, 0.5, -27.5))
	await _r(14)
	await _snap(_shot_base + "_bridge.png")

	# Beat 3 推夜：点火瞬间
	player.global_position = Vector3(1.5, 0.06, -33.9)
	player.velocity = Vector3.ZERO
	await _wait_physics(5)
	beacon.try_interact()
	_aim_cam(cin, Vector3(6.2, 3.6, -26.2), Vector3(0, 2.6, -35.0))
	await _r(100)
	await _snap(_shot_base + "_beacon.png")

	# Beat 4 基准
	await _r(240)
	var tail := _deltas.slice(maxi(_deltas.size() - 120, 0))
	var sum := 0.0
	for d: float in tail:
		sum += d
	var avg_fps := roundi(float(tail.size()) / maxf(sum, 0.0001))
	print("[BENCH] avg fps last 120 frames = ", avg_fps)
	_aim_cam(cin, Vector3(3.6, 1.8, 4.5), Vector3(0.1, 1.0, -0.7))
	await _r(10)
	await _snap(_shot_base + "_bench.png")

	get_tree().quit(0)
