class_name AssetLib
## 第三方资产放置器 v2：载入 glb + 旧化 shader（噪声尘垢/底部脏渍/局部色变），
## 治「白模感」。可选 tint 覆写特定件的颜色（如屋顶压深铜）。
## 用法：AssetLib.place(parent, "res://assets/.../x.glb", pos, rot_y_deg, scale, tint)

const PALETTE_TINT := Color(0.92, 0.86, 0.78)   # 轻度暖灰乘色（保住原包大部分色）
static var _aging_shader: Shader = null


static func place(parent: Node, path: String, pos: Vector3, rot_y_deg: float = 0.0,
		scl: Vector3 = Vector3.ONE, tint: Color = Color(0, 0, 0, 0)) -> Node3D:
	var ps: PackedScene = load(path)
	if ps == null:
		push_warning("AssetLib: missing " + path)
		return null
	var node: Node3D = ps.instantiate()
	node.position = pos
	node.rotation_degrees.y = rot_y_deg
	node.scale = scl
	parent.add_child(node)
	_recoat(node, tint)
	return node


static func _aging() -> Shader:
	if _aging_shader != null:
		return _aging_shader
	var s := Shader.new()
	s.code = """
shader_type spatial;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform float grime_strength = 0.45;
uniform float seed = 0.0;
varying vec3 wpos;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 443.8975);
	p3 += dot(p3, p3.yzx + 19.19);
	return fract((p3.x + p3.y) * p3.z);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 base = texture(albedo_tex, UV) * tint;
	float n1 = vnoise(wpos.xz * 2.3 + vec2(wpos.y * 1.1, seed));
	float n2 = vnoise(wpos.xz * 0.55 + vec2(seed * 3.1, -wpos.y * 0.4));
	float grime = smoothstep(0.35, 0.8, n1) * 0.6 + smoothstep(0.55, 0.95, n2) * 0.4;
	vec3 dirt = vec3(0.30, 0.27, 0.24);
	float bottom_dirt = smoothstep(1.3, 0.0, wpos.y);
	vec3 aged = base.rgb;
	aged = mix(aged, aged * dirt * 1.2,
			clamp(grime * grime_strength + bottom_dirt * 0.4, 0.0, 0.75));
	aged *= 1.0 + smoothstep(1.5, 3.0, wpos.y) * 0.06;
	ALBEDO = aged;
	ROUGHNESS = 0.92;
	SPECULAR = 0.2;
}
"""
	_aging_shader = s
	return s


static func _recoat(root: Node, tint_override: Color) -> void:
	var stack: Array[Node] = [root]
	var mesh_idx := 0
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		stack.append_array(cur.get_children())
		var mi := cur as MeshInstance3D
		if mi == null:
			continue
		_recoat_mesh(mi, tint_override, mesh_idx)
		mesh_idx += 1


static func _recoat_mesh(mi: MeshInstance3D, tint_override: Color, mesh_idx: int) -> void:
	var mesh := mi.mesh
	if mesh == null:
		return
	for i in range(mesh.get_surface_count()):
		var src := mi.get_active_material(i)
		var tex: Texture2D = null
		var tint := Color(1, 1, 1, 1)
		if src is BaseMaterial3D:
			var bm := src as BaseMaterial3D
			tex = bm.albedo_texture
			tint = bm.albedo_color
			var lum := tint.get_luminance()
			tint = tint.lerp(Color(lum, lum, lum), 0.12)   # 压一点原包艳色
		if tint_override.a > 0.0:
			tint *= tint_override
		if tex == null:
			tex = _flat_tex(tint)
			tint = Color.WHITE
		var sm := ShaderMaterial.new()
		sm.shader = _aging()
		sm.set_shader_parameter("albedo_tex", tex)
		sm.set_shader_parameter("tint", tint)
		sm.set_shader_parameter("grime_strength", 0.45)
		sm.set_shader_parameter("seed", float(mesh_idx) * 1.7 + float(i) * 0.6)
		mi.set_surface_override_material(i, sm)


static func _flat_tex(color: Color) -> ImageTexture:
	# 纯色兜底纹理（材质没有贴图时用）
	var img: Image
	if ClassDB.class_has_method("Image", "create_empty"):
		img = Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	else:
		img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)
