class_name MeshMerge
extends RefCounted
## يدمج أشكال البناء الساكنة في شبكة واحدة لكل خامة.
##
## المباني والجسور والأسيجة مبنيّة من صناديق صغيرة: 302 عقدة مقابل
## 21,880 مثلثاً فقط — أي 72 مثلثاً للعقدة. كل عقدة استدعاء رسم،
## فالكلفة هنا في عدد الاستدعاءات لا في الهندسة.
##
## الدمج يحفظ: التصادم (أجسام منفصلة)، والمصابيح، وأي عقدة لها
## أبناء أو اسم يُشار إليه. ولا يُدمَج إلا ما لا يتحرّك.

## لا تُدمَج عقدة اسمها في هذه المجموعة ولا عقدة لها أبناء
const KEEP := ["Door", "Window", "Interact", "Light", "Lamp", "Glow"]

static func _mergeable(n: Node) -> bool:
	if not (n is MeshInstance3D):
		return false
	var mi := n as MeshInstance3D
	if mi.mesh == null or mi.get_child_count() > 0:
		return false
	if mi.visibility_range_end > 0.0:
		return false          # له نطاق رؤية خاص: الدمج يُفقده
	for k in KEEP:
		if str(mi.name).contains(k):
			return false
	return true

## يدمج أبناء `root` القابلين للدمج. يُعيد عدد العقد التي أُزيلت.
static func merge_subtree(root: Node3D) -> int:
	var groups := {}        # بصمة الخامة -> {mat, surfaces:[{st}]}
	var victims: Array[MeshInstance3D] = []
	_collect(root, root, groups, victims)
	if victims.is_empty():
		return 0
	var made := 0
	for key in groups:
		var g: Dictionary = groups[key]
		var st: SurfaceTool = g["st"]
		var mesh := st.commit()
		if mesh == null or mesh.get_surface_count() == 0:
			continue
		var mi := MeshInstance3D.new()
		mi.name = "Merged_%d" % made
		mi.mesh = mesh
		mi.material_override = g["mat"]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		root.add_child(mi)
		made += 1
	var removed := 0
	for v in victims:
		v.get_parent().remove_child(v)
		v.queue_free()
		removed += 1
	return removed

static func _collect(root: Node3D, n: Node, groups: Dictionary,
		victims: Array[MeshInstance3D]) -> void:
	for c in n.get_children():
		if _mergeable(c):
			var mi := c as MeshInstance3D
			var mat: Material = mi.material_override
			if mat == null and mi.mesh.get_surface_count() > 0:
				mat = mi.mesh.surface_get_material(0)
			var key := str(mat.get_instance_id()) if mat else "none"
			if not groups.has(key):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[key] = {"st": st, "mat": mat}
			var xf := root.global_transform.affine_inverse() * mi.global_transform
			(groups[key]["st"] as SurfaceTool).append_from(mi.mesh, 0, xf)
			victims.append(mi)
		elif c is Node3D:
			_collect(root, c, groups, victims)
