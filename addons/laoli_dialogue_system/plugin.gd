@tool
extends EditorPlugin
## 批量登记互相依赖的服务，重新打开工程后生效；保留宿主已有 Autoload。
const SERVICES: Dictionary[String, String] = {
	"DialogueManager": "scripts/core/dialogue/dialogue_manager.gd",
}
const OWNED_SETTING: String = "laoli_dialogue_system/installed_autoloads"

func _enter_tree() -> void:
	var base: String = (get_script() as Script).resource_path.get_base_dir()
	var installed: Array[String] = []
	installed.assign(ProjectSettings.get_setting(OWNED_SETTING, []))
	for service: String in SERVICES:
		var path: String = base.path_join(SERVICES[service])
		var setting: String = "autoload/" + service
		if ProjectSettings.has_setting(setting):
			if String(ProjectSettings.get_setting(setting)).trim_prefix("*") != path:
				push_error("Autoload 名称冲突，保留宿主配置：" + service)
			continue
		ProjectSettings.set_setting(setting, "*" + path)
		if not installed.has(service):
			installed.append(service)
	if not installed.is_empty():
		ProjectSettings.set_setting(OWNED_SETTING, installed)
		if not _save_settings():
			return
		print("叙事插件 Autoload 已登记；首次启用后重新打开工程，使所有服务同时生效。")

func _disable_plugin() -> void:
	var base: String = (get_script() as Script).resource_path.get_base_dir()
	var installed: Array[String] = []
	installed.assign(ProjectSettings.get_setting(OWNED_SETTING, []))
	for service: String in installed:
		var setting: String = "autoload/" + service
		if SERVICES.has(service) and String(ProjectSettings.get_setting(setting, "")).trim_prefix("*") == base.path_join(SERVICES[service]):
			ProjectSettings.set_setting(setting, null)
	ProjectSettings.set_setting(OWNED_SETTING, null)
	_save_settings()

func _save_settings() -> bool:
	var error: Error = ProjectSettings.save()
	if error != OK:
		push_error("插件 Autoload 设置保存失败，错误码：%d" % error)
		return false
	return true
