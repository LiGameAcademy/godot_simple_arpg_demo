@tool
extends OmniLight3D

## 火光跳动脚本
## 原理：使用噪声纹理生成平滑随机的值，来调制光照强度。

@export_group("Flicker Settings")
## 基础强度（平均亮度）
@export var base_energy: float = 3.0
## 强度波动范围（±这个值）
@export var energy_variation: float = 1.5
## 跳动速度（频率）
@export var flicker_speed: float = 8.0

# 使用 FastNoiseLite 生成自然的随机感
var _noise = FastNoiseLite.new()
var _time_cursor: float = 0.0

func _ready() -> void:
	# 初始化噪声
	_noise.seed = randi() # 每次随机种子不同
	_noise.frequency = 1.0 # 基础频率
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM # 使用分形布朗运动，更像自然火焰

func _process(delta: float) -> void:
	# 推进时间指针
	_time_cursor += delta * flicker_speed
	
	# 采样噪声值 (范围通常在 -1.0 到 1.0 之间)
	# 使用 get_noise_1d 就足够了
	var noise_val = _noise.get_noise_1d(_time_cursor)
	
	# 计算最终强度：基础值 + (噪声值 * 波动范围)
	# 结果会在 (base - variation) 到 (base + variation) 之间波动
	var final_energy = base_energy + (noise_val * energy_variation)
	
	# 应用强度（防止出现负数）
	light_energy = max(final_energy, 0.0)
