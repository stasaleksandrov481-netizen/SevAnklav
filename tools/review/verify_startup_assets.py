"""Exercise clean / incomplete / in-place updates in an isolated project copy.

Usage: python tools/review/verify_startup_assets.py --godot /path/to/godot
The working project and its saves are never mutated by these fault cases.
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def write(path, text):
    path.write_text(text, encoding="utf-8")


def run(exe, report):
    results = []
    with tempfile.TemporaryDirectory(prefix="sevanlkav_startup_") as temp:
        temp = Path(temp)
        fixture = temp / "project"
        shutil.copytree(ROOT, fixture, ignore=shutil.ignore_patterns(".git", "docs"))
        paths = ["iso/maps/level2/opaque_shadow.gd", "iso/maps/level2/furniture.gd",
                 "iso/maps/level2/runtime.gd", "iso/maps/level2/regions.json",
                 "iso/maps/level2/wall_section_ids.png", "iso/maps/level2/wall_section_ids.png.import"]
        originals = {p: (fixture / p).read_bytes() for p in paths}
        for case in ["complete", "mask_missing", "stale_shadow", "stale_furniture", "critical_missing"]:
            for p, data in originals.items():
                (fixture / p).write_bytes(data)
            env = os.environ.copy()
            env.update(XDG_DATA_HOME=str(temp / ("data_" + case)), SEVANKLAV_STARTUP_CASE=case,
                       SEVANKLAV_RESTORE_FILES="{}")
            if case == "mask_missing":
                (fixture / paths[4]).unlink()
                (fixture / paths[5]).unlink()
            if case in ["stale_shadow", "stale_furniture"]:
                p = paths[0] if case == "stale_shadow" else paths[1]
                source = originals[p].decode()
                restored = temp / (case + ".txt")
                write(restored, source)
                if case == "stale_shadow":
                    # The pre-A03.1 interface, retained by a running editor.
                    old = source.replace(",contact_height:float=0.0", "")
                    old = old.replace(" if contact_height>0.0:", " if false:")
                    old = old.replace("contact_height", "0.0")
                else:
                    old = re.sub(r"^func native_material[\s\S]*?(?=^func part)", "", source, flags=re.M)
                    old = old.replace(';m.set_shader_parameter("surface_tile",surface)', '')
                write(fixture / p, old)
                env["SEVANKLAV_RESTORE_FILES"] = json.dumps({"res://" + p: str(restored)})
            if case == "critical_missing":
                restored = temp / "regions.txt"
                restored.write_bytes(originals[paths[3]])
                (fixture / paths[3]).unlink()
                env["SEVANKLAV_REGIONS_SOURCE"] = str(restored)
            cmd = [exe, "--headless", "--path", str(fixture), "--fixed-fps", "60",
                   "--script", "res://tools/review/verify_startup_assets.gd"]
            proc = subprocess.run(cmd, env=env, capture_output=True, text=True, timeout=90)
            text = proc.stdout + proc.stderr
            errors = [s for s in text.splitlines() if re.search(r"SCRIPT ERROR|ERROR:|Parse Error|Assertion failed", s)]
            result = {"case": case, "exit_code": proc.returncode,
                      "passed": proc.returncode == 0 and not errors and "STARTUP ASSETS PASS" in text,
                      "result": [s for s in text.splitlines() if "PASS" in s], "errors": errors[:5]}
            results.append(result)
            print(json.dumps(result, ensure_ascii=False), flush=True)
            if not result["passed"]:
                print(text[-6000:], flush=True)
                break
    if report:
        Path(report).write_text(json.dumps(results, ensure_ascii=False, indent=2) + "\n")
    return 0 if len(results) == 5 and all(r["passed"] for r in results) else 1


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--report")
    args = parser.parse_args()
    raise SystemExit(run(str(Path(args.godot).resolve()), args.report))
