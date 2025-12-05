extends Node

## 游戏手感管理器（单例 v3.0 - Trauma & Kickback）
## 负责管理战斗中的手感反馈，包括顿帧（HitStop）和屏幕震动（Screen Shake）
## 
## 优化点：
## 1. 使用 Trauma 平方算法，震动更自然
## 2. 加入 Directional Kickback（方向性后坐力），打击感更强
## 3. 顿帧逻辑精简，防止卡顿感
## 4. 纯业务逻辑层实现，不依赖具体场景结构

# ========== 信号 ==========
## 触发顿帧信号
## [param] duration: float 顿帧时长（秒）
signal hit_stop_triggered(duration: float)

## 触发屏幕震动信号
## [param] trauma: float 创伤值（0.0-1.0）
signal screen_shake_triggered(trauma: float)

# ========== 运行时状态 ==========
## 顿帧前的原始时间缩放（用于安全恢复，兼容子弹时间、加速Buff等）
var _pre_hit_stop_time_scale: float = 1.0
## 顿帧结束时间（毫秒，使用结束时间戳，比 duration 更精准）
var _hit_stop_end_time_msec: int = 0
## 【核心】当前创伤值（0.0 - 1.0），线性增加，平方衰减
var _trauma: float = 0.0
## 【核心】当前震动方向（归一化向量，用于方向性后坐力）
var _shake_direction: Vector2 = Vector2.ZERO
## 当前相机偏移
var _current_camera_offset: Vector3 = Vector3.ZERO
## 噪声生成器（用于平滑的震动效果）
var _noise: FastNoiseLite = null
## 噪声采样光标（用于连续采样）
var _noise_cursor: float = 0.0

# ========== 配置 ==========
@export_group("Hit Stop")
## 是否启用顿帧
@export var enable_hit_stop: bool = true
## 轻攻击顿帧（建议 0.05 - 0.08）
@export var stop_duration_light: float = 0.06
## 重攻击顿帧（建议 0.1 - 0.15）
@export var stop_duration_heavy: float = 0.12

@export_group("Screen Shake")
## 是否启用屏幕震动
@export var enable_screen_shake: bool = true
## 震动最大位移（像素或米）
@export var max_offset: float = 0.5
## 震动最大旋转（弧度，可选）
@export var max_roll: float = 0.05
## 创伤衰减速度（每秒减少多少创伤值，建议 1.5 - 2.0）
@export var trauma_decay: float = 2.0
## 噪声频率（震动速度，建议 20 - 30）
@export var noise_frequency: float = 25.0

func _ready() -> void:
	# 【关键】必须设置为 Always，否则当 time_scale=0 时，_process 不会运行，顿帧无法结束！
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 监听统一游戏事件（更统一的方式）
	AbilityEventBus.game_event_occurred.connect(_on_game_event_occurred)
	
	# 初始化时间缩放
	_pre_hit_stop_time_scale = Engine.time_scale
	
	# 初始化噪声生成器（用于平滑的震动效果）
	_noise = FastNoiseLite.new()
	_noise.seed = randi()
	_noise.frequency = 1.0  # 我们在 process 里手动控制频率
	_noise.fractal_octaves = 2

func _process(delta: float) -> void:
	# 1. 处理顿帧（使用系统时钟，不受 time_scale 影响）
	if _hit_stop_end_time_msec > 0:
		if Time.get_ticks_msec() >= _hit_stop_end_time_msec:
			_end_hit_stop()
	
	# 2. 处理震动（Trauma 衰减）
	if _trauma > 0.0:
		# 使用真实时间 delta，防止顿帧期间震动停止
		# 这里我们选择：顿帧时震动也暂停，等时间恢复瞬间爆发，手感更硬
		var real_delta = delta / Engine.time_scale if Engine.time_scale > 0.0 else 0.0
		
		# 衰减创伤值
		_trauma = max(_trauma - trauma_decay * real_delta, 0.0)
		_update_shake_offset(real_delta)
	else:
		# 归零复位
		if _current_camera_offset != Vector3.ZERO:
			_current_camera_offset = Vector3.ZERO
			_apply_camera_offset()

# ========== 顿帧系统（极简版）==========

## 触发顿帧（HitStop）
## [param] duration: float 顿帧时长（秒）
func trigger_hit_stop(duration: float) -> void:
	if not enable_hit_stop:
		return
	
	# 记录当前时间作为"恢复点"
	# 如果已经在顿帧，只有当新持续时间更长时才覆盖
	var end_time: int = Time.get_ticks_msec() + int(duration * 1000.0)
	if end_time > _hit_stop_end_time_msec:
		if _hit_stop_end_time_msec == 0:
			# 只在第一次进入时记录原始时间缩放
			_pre_hit_stop_time_scale = Engine.time_scale
		
		_hit_stop_end_time_msec = end_time
		Engine.time_scale = 0.0  # 完全停止（或者 0.05 做慢动作）
		
		hit_stop_triggered.emit(duration)
		print("GameFeelManager: HitStop triggered (duration: %.3f, pre_scale: %.2f)" % [duration, _pre_hit_stop_time_scale])

## 结束顿帧
func _end_hit_stop() -> void:
	Engine.time_scale = _pre_hit_stop_time_scale
	_hit_stop_end_time_msec = 0
	print("GameFeelManager: HitStop ended (restored time_scale: %.2f)" % [_pre_hit_stop_time_scale])

# ========== 震动系统（Trauma 版）==========

## 增加创伤值
## [param] amount: 增加量（0.0 - 1.0）。轻击 0.3，重击 0.6，爆炸 1.0
## [param] direction: 冲击方向（2D向量），Vector2.ZERO 表示纯乱震
func add_trauma(amount: float, direction: Vector2 = Vector2.ZERO) -> void:
	if not enable_screen_shake:
		return
	
	_trauma = clamp(_trauma + amount, 0.0, 1.0)
	
	# 如果有特定方向，混合进去；否则保持之前的方向或随机
	if direction != Vector2.ZERO:
		_shake_direction = direction.normalized()
	else:
		# 如果是乱震，就把方向重置，让噪声主导
		pass
	
	screen_shake_triggered.emit(_trauma)
	print("GameFeelManager: Trauma added (amount: %.2f, total: %.2f, direction: %s)" % [amount, _trauma, direction])

## 更新震动偏移（Trauma 系统）
## [param] delta: float 真实时间增量（不受 time_scale 影响）
func _update_shake_offset(delta: float) -> void:
	if not is_instance_valid(_noise):
		return
	
	# 【核心算法】震动强度 = 创伤值的平方（Quadratic Falloff）
	# 这让震动在高强度时非常剧烈，但衰减时非常平滑自然
	var shake_strength = _trauma * _trauma
	
	_noise_cursor += delta * noise_frequency
	
	# 1. 噪声震动（Perlin Noise）- 产生随机晃动
	var noise_x = _noise.get_noise_2d(_noise_cursor, 0.0)
	var noise_y = _noise.get_noise_2d(_noise_cursor, 100.0)
	
	# 2. 方向性后坐力（Kickback）
	# 如果有 _shake_direction，我们让震动主要发生在这个轴上
	# 比如：向右攻击，相机主要在 X 轴震动
	var offset_x = 0.0
	var offset_y = 0.0
	
	if _shake_direction != Vector2.ZERO:
		# 混合：70% 沿冲击方向震动 + 30% 随机扰动
		offset_x = (_shake_direction.x * 0.7 + noise_x * 0.3) * max_offset * shake_strength
		offset_y = (_shake_direction.y * 0.7 + noise_y * 0.3) * max_offset * shake_strength
	else:
		# 纯随机
		offset_x = noise_x * max_offset * shake_strength
		offset_y = noise_y * max_offset * shake_strength
	
	# Z轴震动（可选，增加立体感）
	# 注意：如果需要 Roll（旋转），可以通过事件单独发送
	# var roll = _noise.get_noise_2d(_noise_cursor, 200.0) * max_roll * shake_strength
	
	# 存储并分发
	_current_camera_offset = Vector3(offset_x, offset_y, 0.0)
	
	# 注意：如果你的相机支持 Roll（旋转），可以通过事件发出去
	# 这里为了简单只发位移
	_apply_camera_offset()

## 应用相机偏移
## 通过 AbilityEventBus 通知场景中的相机系统应用偏移
func _apply_camera_offset() -> void:
	# 触发事件，让场景中的相机系统监听并应用偏移
	AbilityEventBus.trigger_game_event(&"camera_offset_update", {
		"offset": _current_camera_offset
	})

## 获取当前相机偏移（供外部查询）
func get_current_camera_offset() -> Vector3:
	return _current_camera_offset

## 统一游戏事件回调
## 监听所有游戏事件，筛选出伤害事件并触发手感反馈
## 
## 【设计说明】将"是否震动"的判断权交给配置，而不是硬编码 "Player"
## 建议：在 GameplayCue 中配置震动，而不是在这里全局监听
## 但为了快速实现和向后兼容，保留现状
func _on_game_event_occurred(event_type: StringName, context: Dictionary) -> void:
	# 只处理伤害事件
	if event_type != &"damage_dealt":
		return
	
	# 增加安全性检查
	if not context.has("instigator"):
		return
	
	# 提取事件上下文
	var instigator = context.get("instigator") as Node
	var target = context.get("target") as Node
	var final_damage = context.get("final_damage", 10.0) as float
	var is_crit = context.get("is_crit", false) as bool  # 假设有暴击标记
	
	# 只对玩家造成的伤害触发手感反馈
	if not is_instance_valid(instigator):
		return
	
	# 检查是否是玩家（根据组名或节点名判断）
	# 【TODO】未来应该从 context 或 damage_info 中读取配置，而不是硬编码判断
	var is_player = instigator.is_in_group("Player") or instigator.name == "Player"
	if not is_player:
		return
	
	# --- 1. 计算打击方向（用于震屏）---
	var shake_dir = Vector2.ZERO
	if is_instance_valid(target) and target is Node3D and instigator is Node3D:
		# 计算从 施法者 -> 目标 的方向（相机应该向这个方向的反方向震，或者沿这个方向震）
		# 通常：攻击向右，相机向右猛冲一下再回弹，或者向左后坐力
		# 这里我们模拟"冲击力"，向攻击方向震动
		var dir_3d = (target.global_position - instigator.global_position).normalized()
		
		# 将 3D 方向投影到屏幕空间（简化版：假设是俯视角，只取 XZ 平面）
		# 注意：这里需要根据你的相机角度调整。如果是 TopDown，X是X，Z是Y。
		shake_dir = Vector2(dir_3d.x, dir_3d.z)
	
	# --- 2. 判断轻重攻击（通过 Damage 或 Tag）---
	if is_crit or final_damage > 50:  # 重攻击阈值
		trigger_hit_stop(stop_duration_heavy)  # 0.12s
		add_trauma(0.6, shake_dir)             # 增加 60% 创伤
	else:
		trigger_hit_stop(stop_duration_light)   # 0.06s
		add_trauma(0.3, shake_dir)             # 增加 30% 创伤

