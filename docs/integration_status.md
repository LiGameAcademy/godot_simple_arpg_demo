# Feature integration and validation

The integrated project combines combat, inventory pilot, web-export and preparation histories while retaining the recorded lesson-40 narrative contracts. The pre-integration state remains at `archive/2026-11-02/before-feature-integration` (`ed59e46`). Recorded course tags are unchanged.

## Behavior covered by checks

The Godot 4.7.2 suite covers resource import, course narrative/checkpoints, 34 inventory cases, real melee/boss/quest/resolution/death-restore integration, and fireball/multicast/arcane/sacrifice. It also verifies stack acquisition events, no acquisition events during inventory restore, story input locks, actual dash displacement, actual cooldown reduction, actual talent damage and read-only talent configuration.

The skill dependency is pinned to `f62369fbb575103f194f87684d7f56c389d42df1`, published through [GAS PR #1](https://github.com/LiGameAcademy/godot_gameplay_abilities/pull/1), [UID metadata PR #2](https://github.com/LiGameAcademy/godot_gameplay_abilities/pull/2) and [debug-window PR #3](https://github.com/LiGameAcademy/godot_gameplay_abilities/pull/3). Dependency contracts run independently from ARPG in disposable Windows and Linux hosts. ARPG CI uses a fresh recursive checkout and the same complete integration gate.

## Resolved editor shutdown regression

The behavior-tree debug panel is a `Window`. Its scene originally defaulted to visible, and its runtime `_ready()` hid it. The editor does not execute that runtime script, so loading the ARPG scene opened the debug window during editor initialization and shutdown. Windows and Linux then emitted `Plugin is not attached to debugger` from `editor_debugger_plugin.cpp:102`.

Serializing `visible = false` in the reusable panel scene removes that error without disabling the panel or weakening the CI gate. A regression checks the panel is hidden before entering the tree or running `_ready()`. The debug shortcut still opens it explicitly at runtime. Windows full-import/runtime checks and a complete editor session now exit without the debugger diagnostic; Linux dependency CI checks the same initial-state contract.

## Known dependency baseline

Godot 4.7.2 retains exactly two GAS script resources (`GameplayEffect` and `GameplayFilterData`, three ObjectDB objects) at exit. That set reproduces at unmodified GAS `34bc173` merely preloading `ActiveAbilityDefinition`, without creating ability instances. The runners print and allow only that exact resource set and count. Script errors, the resolved debugger diagnostic, extra retained resources, unexpected engine errors and missing pass markers fail validation. This integration does not claim to fix that pre-existing script-retention issue.

## Reproduction

```sh
python tests/run_checks.py --godot /absolute/path/to/godot
# Diagnostic separation only; CI always runs imports too:
python tests/run_checks.py --runtime-only --godot /absolute/path/to/godot
```

Narrative checkpoints and inventory/equipment snapshots remain separate. Talents and ordinary enemy state are not persisted by narrative checkpoints. Optional historical preview scenes are excluded by `.gdignore`; executable checks live in `tests/`. Gameplay balance and final presentation remain prototype work. Godot 4.5 and subjective gameplay feel have not been validated.
