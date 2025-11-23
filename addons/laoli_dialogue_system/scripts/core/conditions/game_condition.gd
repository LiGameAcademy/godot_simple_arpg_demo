@abstract
extends Resource
class_name GameCondition 

# 检查条件是否满足
# activator: 谁想发起交互？(通常是 Player)
# target: 交互对象是谁？(比如门)
# 返回: true (通过) / false (拒绝)
@abstract func is_met(activator: Node, target: Node) -> bool
## 便捷方法：从JSON数据初始化GameCondition实例
@abstract func init_from_data(condition_data: Dictionary) -> void

# 可选：如果不满足，返回的错误提示文本
func get_failure_message() -> String:
	return "条件未满足。"
