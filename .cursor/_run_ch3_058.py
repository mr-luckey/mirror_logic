from tool.generate_levels_extreme import validate, simulate
import json
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

REF = "ch3_058"
path = Path("assets/levels/ch3_058.json")
raw = path.read_text()
compact = "\n" not in raw.strip() or raw.strip().count("\n") < 3
d = json.loads(raw)
md = d["metadata"]

def sol_map(d):
    ma = d["intendedSolution"]["mirrorAngles"]
    if isinstance(ma, dict):
        return {k: float(v) for k, v in ma.items()}
    out = {}
    for item in ma:
        mid = item.get("id") or item.get("mirrorId")
        ang = item.get("angle") if "angle" in item else item.get("a")
        out[str(mid)] = float(ang)
    return out

sol = sol_map(d)
lit, hits = simulate(d, sol)
ok = validate(d)
ok_full = ok and "c1" in lit and hits == len(d["mirrors"]) == d["requiredMirrorBounces"]
print("PRE title", d["title"])
print("PRE designer", md.get("designer"), "band", md.get("difficultyBand"), "score", md.get("difficultyScore"), "hardness", md.get("hardness"))
print("PRE mirrors", len(d["mirrors"]), "obstacles", len(d.get("obstacles", [])), "req", d["requiredMirrorBounces"])
print("PRE patternId", md.get("patternId"), "pathBias", md.get("pathBias"), "wallStyle", md.get("wallStyle"))
print("PRE validate", ok, "lit", lit, "hits", hits, "ok_full", ok_full)

hardened = False
if not ok_full:
    import subprocess, sys
    print("RUNNING harden...")
    r = subprocess.run([sys.executable, "tool/_harden_one.py", "--file", str(path)])
    print("harden exit", r.returncode)
    if r.returncode != 0:
        raise SystemExit(r.returncode)
    d = json.loads(path.read_text())
    md = d["metadata"]
    hardened = True

md["designer"] = "canonical_v2_hardened"
md["difficultyBand"] = "ch3_insane"
md["difficultyScore"] = 97.0
md["hardness"] = 0.97
md["wallStyle"] = "mid_segment_rails"
if compact:
    path.write_text(json.dumps(d, separators=(",", ":")) + "\n")
else:
    path.write_text(json.dumps(d, indent=2) + "\n")

mem_path = Path(".cursor/level_core_memory.json")
m = json.loads(mem_path.read_text())
updated = 0
for u in m["used_patterns"]:
    if u.get("levelRef") == REF:
        u["wallStyle"] = "mid_segment_rails"
        u["title"] = d["title"]
        updated += 1
m["last_hardened"] = REF
m.setdefault("stats", {})["lastAssigned"] = {"level": REF, "patternId": md.get("patternId")}
mem_path.write_text(json.dumps(m, indent=2) + "\n")

sol = sol_map(d)
lit, hits = simulate(d, sol)
ok = validate(d)
ok_full = ok and "c1" in lit and hits == len(d["mirrors"]) == d["requiredMirrorBounces"]
print("FINAL title", d["title"])
print("FINAL designer", md["designer"], "band", md["difficultyBand"], "score", md["difficultyScore"], "hardness", md["hardness"])
print("FINAL mirrors", len(d["mirrors"]), "obstacles", len(d.get("obstacles", [])), "req", d["requiredMirrorBounces"])
print("FINAL validate", ok, "lit", lit, "hits", hits, "ok_full", ok_full)
print("hardened", hardened, "mem_updated", updated, "last_hardened", m["last_hardened"])
assert ok_full
print("EXIT:0")
