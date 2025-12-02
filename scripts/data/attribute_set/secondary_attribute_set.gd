extends GameplayAttributeSet
class_name SecondaryAttributeSet

## 二级属性集 (Derived Attributes)
## 负责维护：一级属性 -> 二级属性 的动态映射

# 配置：{ 二级属性ID: { 一级属性ID: 倍率 } }
@export var attribute_mappings: Dictionary = {
	&"health": { &"strength": 2.0, &"vitality": 10.0 },
	&"mana": {"intelligence": 10.0 },
	&"attack":     { &"strength": 2.0},
	&"defense":    { &"vitality": 1.5, &"strength": 0.5 },
	&"crit_rate": { &"agility": 0.01 },
}

# --- 性能优化：反向索引 ---
# 格式：{ 一级属性ID: [受影响的二级属性ID, ...] }
# 避免每次属性变化都遍历整个 mapping 字典
var _dependency_cache: Dictionary[StringName, Array] = {}

func instantiate_attributes() -> Dictionary:
	_init_cache()
	return super()

# --- 核心逻辑 ---

# 1. 初始化依赖 (在 Component ready 时调用)
func resolve_dependencies(comp: GameplayAttributeComponent) -> void:
	# 遍历所有配置的二级属性，强制重算一次
	for sec_id in attribute_mappings:
		_recalculate_derived_attribute(comp, sec_id)

# 2. 实时响应变化
func on_attribute_changed(comp: GameplayAttributeComponent, attr_id: StringName, _new_val: float) -> void:
	# 检查缓存：当前变化的属性是否是一级属性？
	if not _dependency_cache.has(attr_id):
		return
		
	# 获取所有受影响的二级属性列表
	var affected_secondaries = _dependency_cache[attr_id]
	
	# 逐个重算
	for sec_id in affected_secondaries:
		_recalculate_derived_attribute(comp, sec_id)

# 3. 计算逻辑
func _recalculate_derived_attribute(comp: GameplayAttributeComponent, sec_id: StringName) -> void:
	# A. 获取该属性在 Resource 配置中的原始初始值 (Constant)
	# 注意：这里我们遍历 attributes 字典来找 ID 匹配的项，这比存实例要慢一点，但更安全
	# 如果追求极致性能，可以在 _init_cache 里把 初始值也缓存起来
	var initial_base = 0.0
	for attr_res in attributes:
		if attr_res.attribute_id == sec_id:
			initial_base = attributes[attr_res]
			break
			
	# B. 计算所有一级属性的加成
	var bonus = 0.0
	var mapping = attribute_mappings[sec_id] # { strength: 10.0, ... }
	
	for prim_id in mapping:
		var multiplier = mapping[prim_id]
		# 获取一级属性的最终值 (Final Value)
		var prim_val = comp.get_value(prim_id)
		bonus += prim_val * multiplier
		
	# C. 设置新的基础值 (NewBase = ConfigBase + Bonus)
	# 这样，外部给 MaxHP 施加的 Modifier (比如 Buff +10% MaxHP) 依然有效，且是在这个新 Base 上计算
	comp.set_base_value(sec_id, initial_base + bonus)

# 初始化时构建缓存
func _init_cache() -> void:
	_dependency_cache.clear()
	for sec_id in attribute_mappings:
		var primaries = attribute_mappings[sec_id]
		for prim_id in primaries:
			if not _dependency_cache.has(prim_id):
				_dependency_cache[prim_id] = []
			_dependency_cache[prim_id].append(sec_id)
