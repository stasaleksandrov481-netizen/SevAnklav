extends RefCounted
# One native-back listener dispatches only to the most recently opened visible UI.
const KEY:="anklav_native_back_router"
static func install(owner: Node, callback: Callable) -> void:
	var tree:=owner.get_tree()
	var router: Router=tree.get_meta(KEY) if tree.has_meta(KEY) else null
	if router==null:
		router=Router.new();router.tree=tree;router.original_policy=tree.quit_on_go_back
		tree.set_meta(KEY,router);tree.quit_on_go_back=false
		tree.root.go_back_requested.connect(router.dispatch)
	router.entries.append({"owner":weakref(owner),"callback":callback})
static func remove(owner: Node) -> void:
	var tree:=owner.get_tree()
	var router: Router=tree.get_meta(KEY) if tree.has_meta(KEY) else null
	if router==null:return
	for i in range(router.entries.size()-1,-1,-1):
		var node=router.entries[i].owner.get_ref()
		if node==null or node==owner:router.entries.remove_at(i)
	if router.entries.is_empty():
		if tree.root.go_back_requested.is_connected(router.dispatch):tree.root.go_back_requested.disconnect(router.dispatch)
		tree.quit_on_go_back=router.original_policy;tree.remove_meta(KEY)
static func request(tree: SceneTree) -> void:
	var router: Router=tree.get_meta(KEY) if tree.has_meta(KEY) else null
	if router!=null:router.dispatch()
class Router extends RefCounted:
	var tree: SceneTree
	var original_policy:=true
	var entries: Array=[]
	func dispatch() -> void:
		for i in range(entries.size()-1,-1,-1):
			var owner=entries[i].owner.get_ref()
			if not is_instance_valid(owner) or not owner.is_inside_tree() or owner.is_queued_for_deletion():continue
			var node: Node=owner
			var visible:=true
			while node!=null:
				if node is CanvasItem and not (node as CanvasItem).visible:visible=false;break
				if node is CanvasLayer and not (node as CanvasLayer).visible:visible=false;break
				node=node.get_parent()
			if visible and entries[i].callback.is_valid():entries[i].callback.call();return
