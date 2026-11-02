# ARPG 对话、任务与剧情演出示例

[English](README.md)


`master` 是常规课程截至第 40 课的收口版本，以录制跟做分支 `dq_system_tutorial` 的 `f404fb8` 为基础。后续新增课程不在本次收口范围。

本版本保留课程中的简化流程：进入 Boss 房触发入场演出，按 `K` 模拟击败，然后播放收尾演出。备课版的实际 Boss 战斗、新技能系统和新版背包没有混入本课程主线。

## 插件依赖

对话、任务、历史与演出执行核心由 Git 子模块 `addons/laoli_dialogue_system` 提供，来源为 [laoli_dialogue_system](https://github.com/LiGameAcademy/laoli_dialogue_system)。本工程固定到验证过的提交，不跟随远端自动升级。

首次克隆使用 `git clone --recurse-submodules`；已有检出在切换版本后执行 `git submodule update --init --recursive`。插件使用说明见 [插件文档](addons/laoli_dialogue_system/docs/README.md)。

宿主显式注册游戏事件、任务数据库与配置查询；Boss 片段、镜头、剧情提交和三阶段检查点仍由 ARPG 管理。新版动作通过 GameAction 的条件检查与布尔执行接口接入，传送请求由场景信号交给关卡处理。课程录制和收口标签保持不变。

## 运行

使用 Godot **4.7.2** 打开根目录的 `project.godot`，等待首次资源导入完成，再运行主场景。未验证 Godot 4.5 兼容性。

- `WASD` 移动，`E` 交互，鼠标左键攻击，`B` 打开背包。
- `F` 跳过演出；Boss 入场后按 `K` 模拟击败。
- `F5` 保存叙事检查点，`L` 读取；界面也提供保存和读取按钮。
- `scripts/tests/cutscene_workshop.tscn` 是课程交互式演出试验场，按 `I` 开始。

检查点记录剧情、任务和对白历史，不是完整角色或背包存档。

## 收口修复

- 演出控制器按调用方传入的资源验证和播放，收尾不再误播默认入场演出。
- 修正任务接取失败时的提示节点引用。
- 修复 153 个 glTF 模型指向旧纹理位置的问题，统一引用已有纹理。
- 动画导出使用明确的资源路径，保留自定义轨道；待机、行走、跑步的循环设置写入导入配置，避免首次导入重置。
- 统一玩家场景文件为 `prefabs/player.tscn`，与现有资源引用的大小写一致。

## 课程版本与其他分支

原分支保留。以下标签用于固定整理前的版本，不表示各分支的功能已经合并：

| 标签 | 提交 | 用途 |
| --- | --- | --- |
| `course/lesson-40-recorded` | `f404fb8` | 第 40 课录制时的原始跟做版 |
| `course/lesson-40` | 本次收口提交 | 原始课程加必要运行修复及回归验证 |
| `archive/2026-11-02/master-before-course` | `2aa2c70` | 整理前的旧发布版 |
| `archive/2026-11-02/quest-system` | `83e5e04` | 备课版，包含实际 Boss 战斗 |
| `archive/2026-11-02/combat` | `b9c8eff` | 技能、属性与装备路线 |
| `archive/2026-11-02/inventory-pilot` | `927e9e9` | 新背包迁移试验版 |
| `archive/2026-11-02/itch-io` | `3b3bcde` | 旧发布扩展路线 |
| `archive/2026-11-02/dev` | `545aaa3` | 已被旧 master 包含的历史开发分支 |

战斗、新背包和插件子模块化应在后续明确接入范围后迁移，不按冲突文件整体覆盖。

## 回归验证

```powershell
godot --headless --path . --editor --import
godot --headless --fixed-fps 60 --path . res://tests/verify_course_closeout.tscn --quit-after 10000
```

测试使用独立临时检查点，验证正常入场和收尾、跳过、取消、三阶段恢复、坏档保护、持续动画和材质实例隔离。成功时输出 `PASS: course intro/resolution...` 并返回 0。此验证不代替最终画面与操作手感的人工验收。
