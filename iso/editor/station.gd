@tool
extends Node3D
@export var action_id := "container"
@export var title := "КОНТЕЙНЕР"
@export_enum("loot","locked","terminal","record","stairs","sealed") var kind := "loot"
@export var record := ""
@export var initial_contents: Array[Dictionary]=[]

@export_multiline var custom_text := ""
