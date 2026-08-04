from pathlib import Path
import re

p = Path("lib/domain/theme/theme_catalog.dart")
text = p.read_text(encoding="utf-8")
repls = [
    (r"VisualTheme\.floorOf\('([^']+)'\)", r"'assets/images/themes/\1/floor.webp'"),
    (r"VisualTheme\.wallHOf\('([^']+)'\)", r"'assets/images/themes/\1/wall_h.webp'"),
    (r"VisualTheme\.wallVOf\('([^']+)'\)", r"'assets/images/themes/\1/wall_v.webp'"),
    (
        r"VisualTheme\.atmosphereOf\('([^']+)'\)",
        r"'assets/images/themes/\1/atmosphere.webp'",
    ),
]
for pat, rep in repls:
    text = re.sub(pat, rep, text)
p.write_text(text, encoding="utf-8")
print("floor literals", text.count("/floor.webp"))
print("done")
