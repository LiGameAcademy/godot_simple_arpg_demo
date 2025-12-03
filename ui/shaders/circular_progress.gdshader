shader_type canvas_item;

// 环形进度条 Shader
// 用于显示技能冷却进度
// 从顶部开始，顺时针填充

uniform float progress : hint_range(0.0, 1.0) = 0.0;  // 进度值（0.0 = 完成，1.0 = 刚开始）
uniform float thickness : hint_range(0.0, 0.5) = 0.15;  // 圆环厚度（相对于半径）
uniform vec4 progress_color : source_color = vec4(0.2, 0.2, 0.2, 0.8);  // 冷却中的颜色
uniform vec4 ready_color : source_color = vec4(1.0, 1.0, 1.0, 0.0);  // 冷却完成的颜色（通常透明）

void fragment() {
	// 将UV坐标转换为以中心为原点的坐标（-0.5 到 0.5）
	vec2 center = vec2(0.5, 0.5);
	vec2 coord = UV - center;

	// 计算距离中心的距离
	float dist = length(coord);

	// 计算角度（atan2 返回 -PI 到 PI，我们需要转换为 0 到 2*PI，顶部为 0）
	float angle = atan(coord.y, coord.x);
	// 转换为从顶部（-PI/2）开始的角度，范围 0 到 2*PI
	angle = angle + PI * 0.5;
	if (angle < 0.0) {
		angle += PI * 2.0;
	}

	// 归一化角度到 0-1 范围（0 = 顶部，顺时针增加）
	float normalized_angle = angle / (PI * 2.0);

	// 判断是否在圆环范围内
	float inner_radius = 0.5 - thickness;
	float outer_radius = 0.5;
	bool in_ring = dist >= inner_radius && dist <= outer_radius;

	// 判断是否在冷却范围内
	// progress 从 1.0（刚开始冷却）到 0.0（冷却完成）
	// 我们需要显示"还在冷却"的部分，即从顶部开始，顺时针 progress 比例的部分
	// 所以 normalized_angle <= progress 表示还在冷却
	bool in_progress = normalized_angle <= progress;

	// 计算颜色
	vec4 color = vec4(0.0);
	if (in_ring) {
		if (in_progress) {
			// 冷却中：使用进度颜色
			color = progress_color;
		} else {
			// 冷却完成：使用就绪颜色（通常透明）
			color = ready_color;
		}
	}

	COLOR = color;
}
