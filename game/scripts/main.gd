extends Node3D
## M0 灰盒切片：全程序化搭建世界。
## 运行参数（在 `--` 之后）：
##   --smoke                     headless 冒烟自检，PASS 后 quit(0)
##   --shot=path_base            演出式截图，输出 path_base_wide.png / path_base_close.png 后 quit(0)

const PlayerScript := preload("res://scripts/player.gd")
const DummyScript := preload("res://scripts/dummy.gd")
const SwarmScript := preload("res://scripts/seed_swarm.gd")

var player
var dummy
var swarm
var hud: Label

var _checks := 0
var _shot_base := ""
var _frame := 0
var _fps_accum := 0.0
var _fps_n := 0
var _deltas: Array[float] = []


func _ready() -> void:
	InputDefs.ensure_actions()
	_build_world()

	for a in OS.get_cmdline_user_args():
		if a == "--smoke":
			_run_smoke.call_deferred()
		elif a.begins_with("--shot="):
			_shot_base = a.trim_prefix("--shot=")

	if DisplayServer.get_name() != "headless" and _shot_base == "":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _shot_base != "":
		_run_shot_timeline.call_deferred()


func _process(delta: float) -> void:
	_frame += 1
	_deltas.append(delta)
	if _deltas.size() > 600:
		_deltas = _deltas.slice(_deltas.size() - 600)
	_fps_accum += delta
	_fps_n += 1
	if _fps_n >= 30 and is_instance_valid(hud):
		var fps := float(_fps_n) / maxf(_fps_accum, 0.0001)
		hud.text = "FPS %d | seeds %d | frame %d" % [roundi(fps), swarm.seed_count(), _frame]
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


# ---------------------------------------------------------------- 世界搭建

func _build_world() -> void:
	add_child(_make_environment())
	add_child(_make_sun())
	add_child(_make_floor())
	for spec: Array in [
		[Vector3(-4.5, 0.75, -7.0), Vector3(1.6, 1.5, 1.6)],
		[Vector3(5.5, 0.5, -10.0), Vector3(1.2, 1.0, 2.4)],
		[Vector3(-8.0, 1.25, -15.0), Vector3(2.2, 2.5, 2.2)],
	]:
		add_child(_make_block(spec[0], spec[1]))

	player = PlayerScript.new()
	player.position = Vector3(0, 0.06, 0.5)
	add_child(player)

	dummy = DummyScript.new()
	dummy.position = Vector3(0, 0, -1.55)   # 玩家正前方 ~2m，攻击直接够得到
	add_child(dummy)

	swarm = SwarmScript.new()
	swarm.player_body = player
	add_child(swarm)

	var canvas := CanvasLayer.new()
	add_child(canvas)
	hud = Label.new()
	hud.position = Vector2(12, 10)
	hud.text = "booting..."
	canvas.add_child(hud)


func _make_environment() -> WorldEnvironment:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.20, 0.29, 0.47)
	mat.sky_horizon_color = Color(0.73, 0.69, 0.62)
	mat.ground_bottom_color = Color(0.13, 0.14, 0.16)
	mat.ground_horizon_color = Color(0.58, 0.55, 0.50)
	sky.sky_material = mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.45
	we.environment = env
	return we


func _make_sun() -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	return sun


func _make_floor() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	mi.mesh = pm
	mi.material_override = _ground_material()
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 0.1, 80)
	col.shape = box
	col.position.y = -0.05
	body.add_child(col)
	return body


func _ground_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.40, 0.45, 0.34)
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
	mi.material_override = _flat(Color(0.52, 0.51, 0.48))
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	return body


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

	# Beat 1 全景：横扫命中瞬间
	_aim_cam(cin, Vector3(-3.2, 1.85, 3.3), Vector3(0.15, 0.95, -0.55))
	await _r(30)
	player.debug_attack(false)
	await _r(16)
	await _snap(_shot_base + "_wide.png")

	# Beat 2 特写：星籽群环绕 + 重击起手
	swarm.add_seed(3)
	_aim_cam(cin, Vector3(2.3, 1.5, 4.3), Vector3(0.2, 1.25, 1.6))
	await _r(40)
	player.debug_attack(true)
	await _r(20)
	await _snap(_shot_base + "_close.png")

	# Beat 3 基准：预热后再量帧率（排掉首启着色器编译干扰）
	await _r(240)
	var tail := _deltas.slice(maxi(_deltas.size() - 120, 0))
	var sum := 0.0
	for d: float in tail:
		sum += d
	var avg_fps := roundi(float(tail.size()) / maxf(sum, 0.0001))
	print("[BENCH] avg fps last 120 frames = ", avg_fps)
	_aim_cam(cin, Vector3(-3.2, 1.85, 3.3), Vector3(0.15, 0.95, -0.55))
	await _r(10)
	await _snap(_shot_base + "_bench.png")

	get_tree().quit(0)
