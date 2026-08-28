extends SceneTree
## 资产尺寸检视：headless 打印每个 glb 的包围盒，供模块拼装用。
## 运行：godot --headless --path game --script res://tools/inspect_assets.gd

func _initialize() -> void:
	var dir := "res://assets/kenney_castle_kit/"
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".glb"):
			continue
		var ps: PackedScene = load(dir + f)
		if ps == null:
			print("%s  LOAD FAIL" % f)
			continue
		var node := ps.instantiate()
		var aabb := _scene_aabb(node)
		print("%-42s size=(%.2f, %.2f, %.2f)  min=(%.2f, %.2f, %.2f)" % [
				f, aabb.size.x, aabb.size.y, aabb.size.z,
				aabb.position.x, aabb.position.y, aabb.position.z])
		node.free()
	quit(0)


func _scene_aabb(root: Node) -> AABB:
	var merged := AABB()
	var first := true
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		var mi := n as MeshInstance3D
		if mi == null:
			continue
		var ab := mi.mesh.get_aabb() if mi.mesh != null else AABB()
		var xf := mi.global_transform if mi.is_inside_tree() else mi.transform
		# 不在树里时手动沿父链累计变换
		if not mi.is_inside_tree():
			xf = _world_xf(mi)
		ab = xf * ab
		if first:
			merged = ab
			first = false
		else:
			merged = merged.merge(ab)
	return merged


func _world_xf(n: Node3D) -> Transform3D:
	var xf := n.transform
	var p := n.get_parent()
	while p is Node3D:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf
