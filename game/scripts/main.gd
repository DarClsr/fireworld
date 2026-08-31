extends Node3D
## M2a 灰窑村序章：永夜山坳小村 + 教学链 + 授火仪式 + 村口烽火推夜预演。
## 运行参数（`--` 之后）：
##   --smoke                headless 冒烟自检（序章触发链），PASS 后 quit(0)
##   --shot=path_base       演出截图（village/ceremony/gate/bench）后 quit(0)
##   --nofog                关体积雾（性能对照用）

const PlayerScript := preload("res://scripts/player.gd")
const DummyScript := preload("res://scripts/dummy.gd")
const SwarmScript := preload("res://scripts/seed_swarm.gd")
const BeaconScript := preload("res://scripts/beacon.gd")
const VillageScript := preload("res://scripts/village_kiln.gd")
const DirectorScript := preload("res://scripts/prologue_director.gd")
const DialogueScript := preload("res://scripts/dialogue_box.gd")

var player
var dummy
var swarm
var beacon
var village
var director
var dialogue

var env: Environment
var moon: DirectionalLight3D
var _we: WorldEnvironment
var _grading_layer: CanvasLayer
var day_mode := false
var hud: Label
var obj_label: Label
var _banner_title: Label
var _banner_sub: Label
var _fade_rect: ColorRect
var _lit_count := 0
var _campfire_light: OmniLight3D

var _checks := 0
var _shot_base := ""
var _fog_off := false
var _smoke_requested := false
var _findcube := false
var _frame := 0
var _fps_accum := 0.0
var _fps_n := 0
var _deltas: Array[float] = []
var _flick := FastNoiseLite.new()
var _t := 0.0


func _ready() -> void:
	InputDefs.ensure_actions()
	_flick.seed = 7
	_flick.frequency = 7.0

	for a in OS.get_cmdline_user_args():
		if a == "--smoke":
			_smoke_requested = true
		elif a == "--nofog":
			_fog_off = true
		elif a == "--findcube":
			_findcube = true
		elif a == "--day":
			day_mode = true
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
	if _campfire_light != null:
		_campfire_light.light_energy = 2.4 * (0.88 + 0.12 * _flick.get_noise_1d(_t * 8.0))
	if is_instance_valid(player) and player.global_position.y < -6.0:
		player.global_position = village.to_global(village.spawn_local)
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
		hud.text = "FPS %d | seeds %d | beacons %d | frame %d" % [
				roundi(fps), swarm.seed_count(), _lit_count, _frame]
		_fps_accum = 0.0
		_fps_n = 0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("add_seed"):
		if swarm.seed_count() > 0:   # 授火前不许作弊加籽
			swarm.add_seed(1)
	elif event.is_action_pressed("toggle_time"):
		day_mode = not day_mode
		_apply_time_of_day()
	elif event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and DisplayServer.get_name() != "headless":
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## 昼夜切换：重建环境 + 调天光 + 村内灯火按日/夜取值。
func _apply_time_of_day() -> void:
	if day_mode:
		env = _make_day_environment()
		moon.rotation_degrees = Vector3(-52, 35, 0)
		moon.light_color = Color(1.0, 0.95, 0.82)
		moon.light_energy = 1.25
	else:
		env = _make_night_environment()
		moon.rotation_degrees = Vector3(-38, 140, 0)
		moon.light_color = Color(0.6, 0.7, 1.0)
		moon.light_energy = 0.5
	_we.environment = env
	if _grading_layer != null:
		_grading_layer.visible = not day_mode
	if village != null:
		village.set_day(day_mode)
	if _campfire_light != null:
		_campfire_light.light_energy = 1.0 if day_mode else 2.4


func lit_count() -> int:
	return _lit_count


# ---------------------------------------------------------------- 世界搭建

func _build_world() -> void:
	var cn := CnFont.get_font()
	env = _make_night_environment()
	_we = WorldEnvironment.new()
	_we.environment = env
	add_child(_we)
	moon = _make_moon()
	add_child(moon)
	_grading_layer = _make_grading_overlay()
	add_child(_grading_layer)

	add_child(_make_platform(Vector3(0, -0.5, 2.0), Vector2(46, 36)))   # 村子地面 z∈[-16,20]

	village = VillageScript.new()
	village.font = cn
	add_child(village)

	player = PlayerScript.new()
	player.position = village.to_global(village.spawn_local)
	add_child(player)

	dummy = DummyScript.new()
	dummy.position = village.to_global(village.dummy_local)
	dummy.label_font = cn
	add_child(dummy)

	swarm = SwarmScript.new()
	swarm.auto_start = false   # 授火仪式后才发星籽
	swarm.player_body = player
	add_child(swarm)
	player.swarm = swarm

	beacon = BeaconScript.new()
	beacon.position = village.to_global(village.gate_local)
	beacon.scale = Vector3.ONE * 0.62
	beacon.player_body = player
	beacon.label_font = cn
	beacon.lit_changed.connect(func(_b): _lit_count += 1)
	add_child(beacon)

	add_child(_make_campfire(Vector3(-2.0, 0, 6.8)))

	dialogue = DialogueScript.new()
	add_child(dialogue)
	_build_hud(cn)

	director = DirectorScript.new()
	director.main = self
	director.player = player
	director.dummy = dummy
	director.swarm = swarm
	director.beacon = beacon
	director.village = village
	director.dialogue = dialogue
	add_child(director)
	director.run.call_deferred()

	if day_mode:
		_apply_time_of_day()


func _make_night_environment() -> Environment:
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = _make_starry_sky_material()
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.45, 0.48, 0.66)
	e.ambient_light_energy = 0.34
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 1.3
	e.glow_enabled = true
	e.glow_intensity = 0.5
	e.ssao_enabled = true
	e.ssao_radius = 0.6
	e.ssao_intensity = 1.6
	e.fog_enabled = true
	e.fog_light_color = Color(0.075, 0.085, 0.17)
	e.fog_density = 0.008
	e.fog_sky_affect = 0.15
	if _fog_off:
		return e
	e.volumetric_fog_enabled = true
	e.volumetric_fog_density = 0.016
	e.volumetric_fog_albedo = Color(0.55, 0.6, 0.75)
	e.volumetric_fog_emission = Color(0.06, 0.09, 0.16)
	e.volumetric_fog_emission_energy = 0.8
	e.volumetric_fog_anisotropy = 0.6
	e.volumetric_fog_length = 48.0
	return e


## 程序化星空：星（网格哈希+闪烁）+ 月亮本体与月晕 + 地平线薄云剪影。
func _make_starry_sky_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type sky;

uniform vec3 moon_dir = vec3(0.0, 0.0, 0.0);

float hash13(vec3 p) {
	p = fract(p * 443.8975);
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 443.8975);
	p3 += dot(p3, p3.yzx + 19.19);
	return fract((p3.x + p3.y) * p3.z);
}
float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float h = clamp(dir.y, -1.0, 1.0);
	vec3 top = vec3(0.010, 0.016, 0.045);
	vec3 horizon = vec3(0.055, 0.075, 0.14);
	vec3 col = mix(horizon, top, pow(clamp(h, 0.0, 1.0), 0.55));
	if (h < 0.0) {
		col = mix(horizon, vec3(0.02, 0.025, 0.05), clamp(-h * 3.0, 0.0, 1.0));
	}

	// 星星：上半天球 3D 网格哈希
	if (h > 0.02) {
		vec3 g = dir * 60.0;
		vec3 cell = floor(g);
		vec3 f = fract(g) - 0.5;
		float rnd = hash13(cell);
		if (rnd > 0.90) {
			vec3 off = vec3(hash13(cell + 7.1), hash13(cell + 13.7), hash13(cell + 29.3)) - 0.5;
			float d = length(f - off * 0.8);
			float tw = 0.55 + 0.45 * sin(TIME * (1.0 + rnd * 3.0) + rnd * 40.0);
			float star = smoothstep(0.13, 0.0, d) * tw * (rnd - 0.90) / 0.10;
			col += vec3(0.9, 0.95, 1.0) * star * 0.9 * smoothstep(0.02, 0.2, h);
		}
	}

	// 月亮：圆盘 + 边缘软化 + 月晕 + 简单斑驳
	float md = dot(dir, normalize(moon_dir));
	float disc = smoothstep(0.99928, 0.99946, md);
	float maria = 0.82 + 0.36 * noise2(SKY_COORDS * 90.0);
	col += vec3(0.95, 0.97, 1.0) * disc * maria * 1.7;
	col += vec3(0.5, 0.62, 0.9) * pow(clamp(md, 0.0, 1.0), 320.0) * 0.4;

	// 地平线薄云剪影（缓慢漂移）
	float band = smoothstep(0.32, 0.02, abs(h - 0.10));
	float cl = noise2(vec2(atan(dir.x, dir.z) * 3.0, h * 26.0) + vec2(TIME * 0.004, 0.0));
	cl = smoothstep(0.46, 0.78, cl) * band;
	col = mix(col, vec3(0.085, 0.10, 0.17), cl * 0.7);

	COLOR = col;
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = shader
	var mb := Basis.from_euler(Vector3(deg_to_rad(-38.0), deg_to_rad(140.0), 0.0))
	sm.set_shader_parameter("moon_dir", (-mb.z).normalized())
	return sm


func _make_moon() -> DirectionalLight3D:
	var m := DirectionalLight3D.new()
	m.rotation_degrees = Vector3(-38, 140, 0)
	m.light_color = Color(0.6, 0.7, 1.0)
	m.light_energy = 0.5
	m.shadow_enabled = true
	m.directional_shadow_max_distance = 60.0
	return m


## 白天环境：蓝天 + 天光环境光 + 轻雾，无体积雾无调色。
func _make_day_environment() -> Environment:
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.28, 0.5, 0.85)
	mat.sky_horizon_color = Color(0.68, 0.79, 0.9)
	mat.ground_bottom_color = Color(0.3, 0.32, 0.3)
	mat.ground_horizon_color = Color(0.6, 0.65, 0.68)
	sky.sky_material = mat
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 1.0
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 1.1
	e.glow_enabled = true
	e.glow_intensity = 0.2
	e.fog_enabled = true
	e.fog_light_color = Color(0.7, 0.78, 0.88)
	e.fog_density = 0.004
	e.fog_sky_affect = 0.1
	return e


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
void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	// 夜晚色彩科学：阴影微偏蓝（轻）、亮部保色；轻加饱和与对比
	float shadow_mask = 1.0 - smoothstep(0.0, 0.45, lum);
	col = mix(col, col * vec3(0.82, 0.86, 1.1), shadow_mask * 0.4);
	col += vec3(0.012, 0.013, 0.02);   // 抬一点黑位
	float l2 = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l2), col, 1.07);
	col = clamp((col - 0.5) * 1.04 + 0.5, vec3(0.0), vec3(1.0));
	float d = distance(SCREEN_UV, vec2(0.5, 0.55));
	col *= 1.0 - smoothstep(0.5, 1.1, d) * 0.26;
	COLOR = vec4(col, 1.0);
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


func _ground_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.33, 0.30, 0.23)
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
		log.material_override = _flat(Color(0.2, 0.14, 0.1))
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

	_campfire_light = OmniLight3D.new()
	_campfire_light.position = Vector3(0, 0.9, 0)
	_campfire_light.light_color = Color(1.0, 0.7, 0.4)
	_campfire_light.omni_range = 8.0
	_campfire_light.light_energy = 2.4
	_campfire_light.shadow_enabled = false
	root.add_child(_campfire_light)
	return root


func _build_hud(cn: FontFile) -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 1
	add_child(canvas)
	hud = Label.new()
	hud.position = Vector2(12, 10)
	hud.text = "booting..."
	canvas.add_child(hud)

	obj_label = Label.new()
	obj_label.position = Vector2(12, 34)
	if cn != null:
		obj_label.add_theme_font_override("font", cn)
	obj_label.add_theme_font_size_override("font_size", 19)
	obj_label.add_theme_color_override("font_color", Color(0.9, 0.82, 0.6))
	obj_label.text = ""
	canvas.add_child(obj_label)

	var banner_box := VBoxContainer.new()
	banner_box.set_anchors_preset(Control.PRESET_CENTER)
	banner_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	banner_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner_title = Label.new()
	_banner_title.add_theme_font_size_override("font_size", 34)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	if cn != null:
		_banner_title.add_theme_font_override("font", cn)
	_banner_sub = Label.new()
	_banner_sub.add_theme_font_size_override("font_size", 18)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_sub.add_theme_color_override("font_color", Color(0.75, 0.72, 0.66))
	if cn != null:
		_banner_sub.add_theme_font_override("font", cn)
	banner_box.add_child(_banner_title)
	banner_box.add_child(_banner_sub)
	banner_box.modulate.a = 0.0
	canvas.add_child(banner_box)

	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 12
	add_child(fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 1)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(_fade_rect)


# ---------------------------------------------------------------- 演出服务（导演调用）

func fade_from_black(dur: float) -> void:
	_fade_rect.visible = true
	_fade_rect.color.a = 1.0
	var tw := create_tween()
	tw.tween_property(_fade_rect, "color:a", 0.0, dur)
	tw.tween_callback(func(): _fade_rect.visible = false)


func set_objective(text: String) -> void:
	obj_label.text = text


func show_banner(title: String, sub: String) -> void:
	_banner_title.text = title
	_banner_sub.text = sub
	var box: Control = _banner_title.get_parent()
	var tw := create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 0.8)
	tw.tween_interval(3.5)
	tw.tween_property(box, "modulate:a", 0.0, 1.2)


func push_back_night() -> void:
	if day_mode:
		return
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(env, "ambient_light_energy", 0.42, 1.6)
	tw.tween_property(moon, "light_energy", 0.38, 1.6)
	tw.tween_property(env, "fog_density", 0.005, 1.6)
	if env.volumetric_fog_enabled:
		tw.tween_property(env, "volumetric_fog_density", 0.012, 1.6)
	for l in village.lantern_lights:
		tw.tween_property(l, "light_energy", 1.7, 1.6)


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
	_check(swarm.seed_count() == 0, "seeds locked before ceremony (got %d)" % swarm.seed_count())

	var opened := await _wait_until(func(): return dialogue.is_open(), 500)
	_check(opened, "intro dialogue opened")
	dialogue.debug_finish()
	await _wait_until(func(): return director.stage == 1, 200)   # T_MOVE

	player.debug_set_move(Vector3(0, 0, -1))
	await _wait_until(func(): return director.stage >= 2, 500)   # T_ATTACK
	player.debug_clear_move()
	player.global_position = village.to_global(village.dummy_local) + Vector3(0.5, 0.06, 1.7)
	await _wait_physics(3)

	for i in range(3):
		var hp0: float = dummy.hp
		player.debug_attack(false)
		await _wait_until(func(): return dummy.hp < hp0 - 0.001 or dummy.broken, 400)
	await _wait_until(func(): return director.stage >= 3, 200)   # T_ROLL
	await _wait_until(func(): return player.state == 0, 200)     # 等攻击收招回 MOVE

	player.debug_roll()
	await _wait_until(func(): return player.state == 0, 150)     # 回到 MOVE
	player.debug_roll()
	await _wait_until(func(): return player.state == 0, 150)
	_check(director.stage >= 4, "tutorials done -> TO_KILN (stage=%d)" % director.stage)

	player.global_position = village.to_global(village.grandma_local) + Vector3(1.0, 0.06, 0.8)
	var talk := await _wait_until(func(): return dialogue.is_open(), 300)
	_check(talk, "ceremony dialogue opened")
	dialogue.debug_finish()
	await _wait_until(func(): return director.stage == 6, 200)   # CEREMONY
	var to_gate := await _wait_until(func(): return director.stage == 7, 700)   # TO_GATE(含仪式演出)
	_check(to_gate, "ceremony finished -> TO_GATE")
	dialogue.debug_finish()

	_check(swarm.seed_count() == 3, "seeds granted (got %d)" % swarm.seed_count())

	player.global_position = beacon.global_position + Vector3(1.2, 0.06, 0.9)
	player.velocity = Vector3.ZERO
	await _wait_physics(5)
	_check(beacon.try_interact(), "gate beacon ignited")
	_check(beacon.is_lit(), "beacon lit")
	_check(lit_count() == 1, "lit_count == 1")

	var done := false
	for i in range(800):
		if dialogue.is_open():
			dialogue.debug_finish()
		if director.stage == 10:   # DONE
			done = true
			break
		await get_tree().physics_frame
	_check(done, "prologue reached DONE (stage=%d)" % director.stage)
	_check(env.ambient_light_energy > 0.35, "night pushed back (ambient=%.2f)" % env.ambient_light_energy)

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

	# Beat 1 村庄全景：沿灯笼路望向灰窑
	_aim_cam(cin, Vector3(-19.0, 6.5, 15.5), Vector3(5.0, 0.8, -6.0))
	await _r(110)
	await _snap(_shot_base + "_village.png")

	# Beat 1.5 样板房特写（资产版灯芽家）
	_aim_cam(cin, Vector3(-14.5, 2.3, 16.8), Vector3(-9.3, 1.7, 12.2))
	await _r(20)
	await _snap(_shot_base + "_house.png")

	# Beat 1.6 东方正屋特写（three.js 程序化建模）
	_aim_cam(cin, Vector3(10.8, 3.2, 20.5), Vector3(5.0, 1.9, 15.6))
	await _r(20)
	await _snap(_shot_base + "_oriental.png")

	# Beat 2 仪式：火种飞向灯芽（连续跳过途中所有对话直到仪式开演）
	director.debug_ff_tutorials()
	player.global_position = village.to_global(village.grandma_local) + Vector3(1.0, 0.06, 0.9)
	for i in range(8):
		if director.stage >= 6:
			break
		if dialogue.is_open():
			dialogue.debug_finish()
		await _r(10)
	await _wait_until(func(): return director.stage == 6, 400)   # CEREMONY
	await _r(48)   # 火种飞到半程
	await _snap(_shot_base + "_ceremony.png")
	await _wait_until(func(): return director.stage == 7, 700)   # TO_GATE
	if dialogue.is_open():
		dialogue.debug_finish()

	# Beat 3 推夜：村口烽火点燃之后（低机位直视，避灯笼）
	cin.make_current()   # 仪式恢复了玩家相机，演出机位要抢回来
	player.global_position = beacon.global_position + Vector3(1.4, 0.06, 1.0)
	player.velocity = Vector3.ZERO
	await _wait_physics(5)
	beacon.try_interact()
	_aim_cam(cin, Vector3(0.0, 2.2, -9.0), Vector3(2.8, 1.5, -14.4))
	await _r(140)
	await _snap(_shot_base + "_gate.png")
	if _findcube:
		var fc := get_viewport().get_camera_3d()
		print("[CUBE] camera=", fc.name, " at ", fc.global_position)
		var from := fc.global_position
		var dirn := (-fc.global_basis.z).normalized()
		for n in get_tree().root.find_children("*", "VisualInstance3D", true, false):
			var vi := n as VisualInstance3D
			if vi == null or not vi.visible:
				continue
			var to := vi.global_position - from
			var t := to.dot(dirn)
			if t < 0.5 or t > 30.0:
				continue
			var off := (to - dirn * t).length()
			if off < 2.5:
				print("[CUBE] t=%.1f off=%.2f pos=%s %s <- %s" % [t, off, vi.global_position, vi.name, vi.get_parent().name])

	# Beat 4 基准
	await _r(240)
	var tail := _deltas.slice(maxi(_deltas.size() - 120, 0))
	var sum := 0.0
	for d: float in tail:
		sum += d
	var avg_fps := roundi(float(tail.size()) / maxf(sum, 0.0001))
	print("[BENCH] avg fps last 120 frames = ", avg_fps)
	_aim_cam(cin, Vector3(17.0, 5.5, 15.0), Vector3(-1.0, 1.0, -3.0))
	await _r(10)
	await _snap(_shot_base + "_bench.png")

	get_tree().quit(0)
