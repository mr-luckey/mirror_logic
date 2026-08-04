from pathlib import Path
import re

p = Path("lib/domain/theme/theme_catalog.dart")
text = p.read_text(encoding="utf-8")

text = text.replace(
    """    // Keep the live cyan beam — this hall is already shipping.
    laserCore: Color(0xFFCCFFFF),
    laserMid: Color(0xFF00F2FF),
    laserGlow: Color(0xFF40C8FF),
    crystal: Color(0xFF80D0FF),
    crystalDeep: Color(0xFF2090C0),""",
    """    laserCore: Color(0xFFFFF4C8),
    laserMid: Color(0xFFFFD060),
    laserGlow: Color(0xFFE8A830),
    crystal: Color(0xFFFFE088),
    crystalDeep: Color(0xFFC88820),""",
)

text = re.sub(r"\n\s*atmosphereAsset: '[^']+',", "", text)

out = []
i = 0
while True:
    start = text.find("static const VisualTheme", i)
    if start < 0:
        out.append(text[i:])
        break
    out.append(text[i:start])
    vt = text.find("VisualTheme(", start)
    depth = 0
    j = vt
    while j < len(text):
        if text.startswith("VisualTheme(", j):
            depth += 1
            j += len("VisualTheme(")
            continue
        ch = text[j]
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                j += 1
                break
        j += 1
    block = text[vt:j]
    mid = re.search(r"id:\s*(starterId|'([^']+)')", block)
    if mid and mid.group(1) == "starterId":
        tid = "golden_sun"
    else:
        tid = mid.group(2) if mid else "golden_sun"
    assets = f"""
    floorAsset: VisualTheme.floorOf('{tid}'),
    wallHAsset: VisualTheme.wallHOf('{tid}'),
    wallVAsset: VisualTheme.wallVOf('{tid}'),"""
    if tid != "golden_sun":
        assets += f"\n    atmosphereAsset: VisualTheme.atmosphereOf('{tid}'),"
    if "accentGlow:" in block:
        block = block.replace("\n    accentGlow:", assets + "\n    accentGlow:")
    else:
        block = block[:-1] + "," + assets + "\n  )"
    out.append(text[start:vt] + block)
    i = j

result = "".join(out)
# Fix atmosphereAssets getter if it still references old field
p.write_text(result, encoding="utf-8")
print("floorAsset", result.count("floorAsset"))
print("atmosphereAsset", result.count("atmosphereAsset"))
print("done")
