# Godot Simple ARPG Demo

[简体中文](README_zh-CN.md) · [Narrative plugin](https://github.com/LiGameAcademy/laoli_dialogue_system)

A low-poly Godot course host for NPC dialogue, quests, room transitions, and Resource-driven cutscenes. The current stable mainline follows the recorded course through lesson 40, with necessary runtime fixes and a pinned narrative plugin dependency.

Broader ability-system, equipment and inventory features are being integrated on a separate branch. They are not yet part of this stable version.

## Setup

Use **Godot 4.7.2**. Godot 4.5 compatibility has not been verified.

```sh
git clone --recurse-submodules https://github.com/LiGameAcademy/godot_simple_arpg_demo.git
cd godot_simple_arpg_demo
git submodule update --init --recursive
```

Open the root project.godot, wait for resource import, then run the main scene. The narrative plugin is mounted at addons/laoli_dialogue_system and pinned to the validated v0.1.0 commit. Dependency upgrades require explicit validation and a host gitlink update.

## Current behavior

- NPC dialogue choices, actions, conditions, quests and rewards.
- Boss introduction and resolution sequences, correlated dialogue sessions, skip/cancel cleanup and control restoration.
- Stable narrative checkpoints for story flags, quest progress and minimal dialogue history.
- The course's simplified boss flow: enter the boss room, finish or skip the introduction, then press K to simulate defeat and trigger the resolution.

The host owns actors, camera presentation, world rules and save eligibility. Shared dialogue/quest/cutscene execution lives in the plugin. This stable version does not include the separate combat/ability and inventory-trial branches.

## Controls

| Input | Action |
| --- | --- |
| WASD | Move |
| E | Interact |
| Left mouse | Basic attack animation |
| B | Inventory |
| F | Skip a cutscene |
| K | Simulate boss defeat after the introduction |
| F5 / L | Save / restore a narrative checkpoint |

Checkpoint buttons are also available. Checkpoints do not contain full character or inventory state. scripts/tests/cutscene_workshop.tscn is an interactive presentation sandbox; press I to start.

## Versions and branches

master is the protected stable branch. Work is integrated through PRs; temporary branches are removed only after merge/verification or explicit archival.

- course/lesson-40-recorded: original recorded follow-along version.
- course/lesson-40: course closeout with runtime fixes, before plugin migration.
- archive/2026-11-02/before-feature-integration: stable narrative host before combining gameplay branches.

Existing course and archive tags are retained. Use them when matching an older recording instead of moving the tags to new implementations.

## Verification

```sh
godot --headless --path . --editor --import
godot --headless --fixed-fps 60 --path . res://tests/verify_course_closeout.tscn --quit-after 10000
```

The regression covers intro/resolution, skip/cancel, three checkpoint phases, bad-save protection, animation and material isolation, host actions and teleporter signals. It uses a disposable checkpoint. Automated checks do not replace final visual and gameplay acceptance.
