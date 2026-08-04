from pathlib import Path
import re

p = Path("lib/presentation/screens/gameplay/gameplay_painter.dart")
text = p.read_text(encoding="utf-8")
start = text.find("  void _drawThemeAmbience")
end = text.find("  void _drawBoardAtmosphere")
body = text[start:end]
new_body = re.sub(r"(\n)(      case )", r"\n        break;\1\2", body)
new_body = re.sub(r"(\n)(      default:)", r"\n        break;\1\2", new_body)
new_body = new_body.replace(
    "switch (id) {\n        break;\n      case",
    "switch (id) {\n      case",
    1,
)
text = text[:start] + new_body + text[end:]
p.write_text(text, encoding="utf-8")
print("ok")
