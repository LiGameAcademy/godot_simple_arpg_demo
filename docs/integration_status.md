# Feature integration status

The candidate combines the combat, inventory pilot, web-export and preparation histories while retaining the recorded lesson-40 narrative contracts. The stable pre-integration state remains at `archive/2026-11-02/before-feature-integration` (`ed59e46`). Recorded course tags are unchanged.

## Validated behavior

Windows Godot 4.7.2 passes all four runtime suites: course narrative/checkpoints, 34 inventory cases, real melee/boss/quest/resolution/death-restore integration, and fireball/multicast/arcane/sacrifice. The integration suite also verifies stack acquisition events, no acquisition events during inventory restore, story input locks, actual dash displacement, actual cooldown reduction, actual talent damage and read-only talent configuration.

The skill dependency is published at `3520ac320b6c476ec40a4555b765d0255471cf9a`, through [GAS PR #1](https://github.com/LiGameAcademy/godot_gameplay_abilities/pull/1) and [UID metadata PR #2](https://github.com/LiGameAcademy/godot_gameplay_abilities/pull/2). Both pass Linux Godot 4.7.2 CI; the runtime fixes also pass an independent disposable Windows host.

## Open gate

The integrated editor emits `Plugin is not attached to debugger` from `editor_debugger_plugin.cpp:102` at shutdown. It has no GDScript call stack and does not occur in the game suites. Normal and headless import/editor shutdown paths reproduce it. It still reproduces with the console autoloads, editor plugins and native debug-draw extension independently isolated, and with fresh editor settings. The pre-integration ARPG archive imports without it. Therefore this is an unresolved integration/editor interaction, not an established pre-existing ARPG warning. The CI import gate must continue to fail on it.

A similar engine-side diagnostic is tracked in [Godot issue #117243](https://github.com/godotengine/godot/issues/117243); that issue is not proof that this local case has the same cause or is fixed.

Separately, the GAS baseline retains exactly two script resources (`GameplayEffect` and `GameplayFilterData`, three ObjectDB objects) on Godot 4.7.2 exit. That exact set reproduces at unmodified GAS `34bc173` with only a type preload. The runners print and allow only that documented baseline; other errors and extra resources fail.

## Reproduction

```sh
python tests/run_checks.py --godot /absolute/path/to/godot
# Diagnostic separation only; this does not satisfy the full CI gate:
python tests/run_checks.py --runtime-only --godot /absolute/path/to/godot
```

Narrative checkpoints and inventory/equipment snapshots remain separate. Talents and ordinary enemy state are not persisted by narrative checkpoints. Optional preview scenes are archived behind `.gdignore`; the current executable checks live in `tests/`. Gameplay balance and final presentation remain prototype work.
