# 基于行为树的连击系统使用指南

示例使用 [combo_attack.tres](../data/abilities/combo_attack.tres) 配置三连击。默认玩家数据和斧子装备引用同一份资源。

## 三段配置

| 段数 | 主动技能资源 | 当前表现 |
| --- | --- | --- |
| 1 | [basic_attack.tres](../data/abilities/basic_attack.tres) | 普通攻击动画，使用近战盒判定并应用伤害。 |
| 2 | [basic_attack.tres](../data/abilities/basic_attack.tres) | 复用第一段的主动技能配置。 |
| 3 | [heavy_attack.tres](../data/abilities/heavy_attack.tres) | 播放跳跃重击动画，沿用普通攻击的近战盒范围。命中时使用 1.5 倍伤害倍率。 |

在 Inspector 中编辑三连击资源的 `combo_steps`。每一项引用一个 `ActiveAbilityDefinition`，同一个资源可以用在多个位置。前摇、动画、目标获取和命中效果在各段的主动技能资源配置。

## 施放和继续连击

默认玩家按鼠标左键启动 `combo_attack`，在上一段结束后的窗口内再次按下同一个按键继续。代码调用使用 `GameplayAbilityComponent.try_activate_ability(&"combo_attack", context)`。续段继续调用同一个入口。

默认执行树接受首次施放，然后在执行首段之前统一提交整套费用。费用失败时不执行任何段，也不开始冷却。整套结束或续段窗口超时后进入冷却。这个示例的续段窗口和整套冷却均为 1 秒。

## 验证

运行 `python tests/run_checks.py --godot /path/to/godot`。资源检查会加载 `data/abilities` 下的每个 `.tres`，并验证玩家和斧子都引用实际的三段配置。

在游戏里按一次鼠标左键，等窗口超时可验证连击收尾。再启动一轮，在前两段结束后各按一次，第三段应播放跳跃重击动画并在命中时扣血。前两段命中后拉开距离，第三段应挥空，整套仍正常进入冷却。
