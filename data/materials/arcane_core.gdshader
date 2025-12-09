shader_type spatial;
// 无光照，双面渲染，叠加模式（让能量看起来更亮）
render_mode unshaded, cull_disabled, blend_add; 

// --- 颜色配置 ---
uniform vec4 core_color : source_color = vec4(0.0, 0.8, 1.0, 1.0); // 青蓝色核心
uniform vec4 edge_color : source_color = vec4(0.6, 0.0, 1.0, 1.0); // 紫色边缘

// --- 噪波配置 ---
// 【重要】请在 Inspector 里拖入一个 NoiseTexture2D，勾选 Seamless
uniform sampler2D noise_tex; 
uniform float scroll_speed = 2.0; // 能量流动速度
uniform float flicker_speed = 10.0; // 闪烁速度

void vertex() {
    // 轻微的顶点脉冲，让它看起来在呼吸
    float pulse = sin(TIME * flicker_speed) * 0.05;
    VERTEX += NORMAL * pulse;
}

void fragment() {
    // 1. 制造能量向后流动的效果
    // 我们让 UV 主要沿一个方向滚动 (假设模型 UV 已经展好)
    vec2 scroll_uv = UV + vec2(TIME * scroll_speed * 0.5, TIME * scroll_speed);
    float noise = texture(noise_tex, scroll_uv).r;
    
    // 2. 菲涅尔效应 (Fresnel)：让边缘发光
    // 奥术的菲涅尔应该更锐利
    float fresnel = pow(1.0 - dot(NORMAL, VIEW), 3.0);
    
    // 3. 核心亮度：结合噪波和菲涅尔
    // 噪波越白的地方，越接近核心色；边缘越接近边缘色
    float energy_mask = noise + fresnel;
    vec3 final_color = mix(edge_color.rgb, core_color.rgb, energy_mask);
    
    // 4. 强度叠加
    ALBEDO = final_color;
    // 使用 blend_add 模式时，Alpha 通道控制叠加的强度
    // 让边缘和噪波暗部稍微透明一点
    ALPHA = clamp(energy_mask * 1.5, 0.0, 1.0);
}