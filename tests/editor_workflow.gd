@tool
extends RefCounted
var failed:=0
var checks:=0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failed+=1; push_error(label)
func frames(plugin: Node, count:=5) -> void:
	for i in range(count): await plugin.get_tree().process_frame
func run(plugin: EditorPlugin) -> void:
	plugin.get_tree().create_timer(30).timeout.connect(func(): plugin.get_tree().quit(1))
	await plugin.get_tree().create_timer(3.0).timeout
	var path:="res://tests/_editor_workflow_tmp.tscn"
	var original=load("res://iso/maps/zarya_bunker.tscn").instantiate(); original.map_id="qa_editor"
	var copy:=PackedScene.new(); copy.pack(original); ResourceSaver.save(copy,path); original.free()
	plugin.get_editor_interface().open_scene_from_path(path)
	await frames(plugin,30)
	var map=plugin._root()
	print("EDITOR_ROOT ",plugin.get_editor_interface().get_edited_scene_root())
	check(map!=null,"Editable map opens in Godot editor")
	if map==null: plugin.get_tree().quit(1); return
	check(map.get_node("capsule").visible and map.get_node("airlock").visible,"Whole bunker is visible in editor")
	if DisplayServer.get_name()!="headless":
		plugin.get_editor_interface().set_main_screen_editor("3D")
		await frames(plugin,15)
		await RenderingServer.frame_pre_draw
		var camera=plugin.get_editor_interface().get_editor_viewport_3d(0).get_camera_3d()
		camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=110
		camera.position=Vector3(48,68,64); camera.look_at(Vector3(12,0,0),Vector3.UP)
		await RenderingServer.frame_post_draw
		plugin.get_viewport().get_texture().get_image().save_png("res://editor_bunker_overview.png")
	var before: int=map.get_child_count()
	plugin.palette.select(0); plugin._place(Vector3(100,0,100)); await frames(plugin)
	check(map.get_child_count()==before+1,"Palette adds new room")
	var undo=plugin.get_undo_redo(); var history=undo.get_history_undo_redo(undo.get_object_history_id(map))
	history.undo(); await frames(plugin)
	check(map.get_child_count()==before,"Undo removes room")
	history.redo(); await frames(plugin)
	check(map.get_child_count()==before+1,"Redo restores room")
	var region=map.get_child(map.get_child_count()-1)
	var floor_piece=region.find_child("Floor",true,false)
	floor_piece.dimensions=Vector3(14,0.18,10); await frames(plugin)
	check(floor_piece.get_node("Generated/Surface").mesh.size==Vector3(14,0.18,10),"Dimensions rebuild mesh")
	var physics=floor_piece.get_node("Generated").find_children("*","CollisionShape3D",true,false)
	check(physics[0].shape.size==Vector3(14,0.18,10),"Collision matches dimensions")
	var door_index:=0
	for i in range(plugin.entries.size()):
		if plugin.entries[i][1]=="door": door_index=i
	plugin.palette.select(door_index); plugin._place(Vector3(100,0,95)); await frames(plugin)
	plugin._cut_door(); await frames(plugin)
	var blocked:=false
	for piece in region.get_children():
		if piece.get_script()!=preload("res://iso/editor/piece.gd") or piece.kind!="Wall": continue
		var local: Vector3=piece.to_local(Vector3(100,1,95))
		if AABB(-piece.dimensions/2,piece.dimensions).has_point(local): blocked=true
	check(not blocked,"Cut door leaves no wall collision across opening")
	plugin.get_editor_interface().save_scene(); await frames(plugin)
	var reloaded=ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE).instantiate()
	check(reloaded.get_child_count()==map.get_child_count(),"Saved scene retains authoring edits")
	reloaded.free()
	print("EDITOR_WORKFLOW_CHECKS ",checks," FAILED ",failed)
	plugin.get_tree().quit(1 if failed else 0)
