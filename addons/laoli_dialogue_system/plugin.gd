@tool
extends EditorPlugin

func _enter_tree() -> void:
	# 当插件在编辑器中被激活时，此函数会被调用
	add_autoload_singleton("DialogueManager", "uid://c78rt38n1bais")
	print("老李的对话系统插件已激活！")

func _exit_tree() -> void:
	# 当插件被禁用时，此函数会被调用
	remove_autoload_singleton("DialogueManager")
	print("老李的对话系统插件已禁用。")
