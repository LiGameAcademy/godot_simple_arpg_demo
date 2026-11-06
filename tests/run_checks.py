"""Validate imports and real ARPG integration against the pinned dependencies."""
import argparse
from pathlib import Path
import re
import subprocess
import tempfile


def check_output(output, marker=None):
    errors = [line for line in output.splitlines() if "ERROR:" in line or "Parse Error" in line]
    known = "ERROR: 2 resources still in use at exit."
    if any(not line.startswith(known) for line in errors):
        return False
    if errors:
        retained = set(re.findall(r"Resource still in use: (.*?) \(GDScript\)", output))
        expected = {"res://addons/godot_gameplay_abilities/scripts/effects/gameplay_effect.gd",
                    "res://addons/godot_gameplay_abilities/scripts/filters/gameplay_filter_data.gd"}
        if retained != expected or "WARNING: 3 ObjectDB instances were leaked" not in output:
            return False
        print("KNOWN BASELINE: Godot 4.7.2 script retention (see GAS tests/README.md).")
    return marker is None or marker in output


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", required=True)
    parser.add_argument("--runtime-only", action="store_true", help="Diagnostic runs only; CI always validates imports too.")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    suites = [("verify_course_closeout", "PASS: course intro/resolution"),
              ("inventory_pilot_smoke", "ARPG inventory pilot: 35 passed, 0 failed"),
              ("verify_feature_integration", "PASS: feature integration"),
              ("verify_spell_integration", "PASS: spell integration")]
    commands = [] if args.runtime_only else [("import", ["--editor", "--import"], None)]
    commands += [(name, ["--fixed-fps", "60", f"res://tests/{name}.tscn", "--quit-after", "10000"], marker)
                 for name, marker in suites]
    with tempfile.TemporaryDirectory(prefix="arpg-checks-") as logs:
        for name, options, marker in commands:
            command = [args.godot, "--headless", "--verbose", "--path", str(root), *options]
            result = subprocess.run(command, capture_output=True, text=True,
                                    encoding="utf-8", errors="replace", timeout=180)
            output = result.stdout + result.stderr
            (Path(logs) / f"{name}.log").write_text(output, encoding="utf-8")
            if result.returncode or not check_output(output, marker):
                print(output)
                raise SystemExit(f"FAILED: {name}")
            print(f"PASS: {name}")


if __name__ == "__main__":
    main()
