@abstract
extends Resource
class_name GameAction 

## 可以在编辑器里给动作写备注
@export var description: String = ""

# 核心接口：执行动作
# initiator: 谁发起了交互？(通常是 Player)
# target: 交互的对象是谁？(比如宝箱本身)
@abstract func execute(initiator: Node, target: Node) -> void
