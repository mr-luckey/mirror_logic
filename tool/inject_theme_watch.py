from pathlib import Path
import re

ROOT = Path(r"d:\Playstore\mirror_logic")

FILES = [
    "lib/presentation/widgets/medieval/medieval_toast.dart",
    "lib/presentation/widgets/medieval/medieval_hand.dart",
    "lib/presentation/widgets/medieval/medieval_option_rows.dart",
    "lib/presentation/widgets/medieval/medieval_gameplay_hud.dart",
    "lib/presentation/widgets/medieval/medieval_resource_chip.dart",
    "lib/presentation/widgets/medieval/medieval_star_row.dart",
    "lib/presentation/widgets/medieval/medieval_objective_banner.dart",
    "lib/presentation/widgets/medieval/medieval_panel.dart",
    "lib/presentation/widgets/medieval/medieval_bronze_button.dart",
    "lib/presentation/widgets/medieval/medieval_toggle.dart",
    "lib/presentation/widgets/medieval/medieval_progress.dart",
    "lib/presentation/widgets/medieval/medieval_screen_header.dart",
    "lib/presentation/widgets/medieval/medieval_button.dart",
    "lib/presentation/widgets/medieval/medieval_rate_dialog.dart",
    "lib/presentation/widgets/medieval/medieval_torch.dart",
    "lib/presentation/widgets/medieval/medieval_art.dart",
    "lib/presentation/widgets/medieval/medieval_exit_scope.dart",
    "lib/presentation/widgets/medieval/medieval_wood_background.dart",
    "lib/presentation/widgets/ads/ad_banner_slot.dart",
    "lib/presentation/screens/about/about_screen.dart",
    "lib/presentation/screens/settings/settings_screen.dart",
    "lib/presentation/screens/level_complete/level_complete_screen.dart",
    "lib/presentation/screens/main_menu/main_menu_screen.dart",
    "lib/presentation/screens/level_select/level_select_screen.dart",
    "lib/presentation/screens/theme_shop/theme_shop_screen.dart",
    "lib/presentation/screens/gameplay/gameplay_screen.dart",
    "lib/presentation/screens/gameplay/gameplay_fx_layer.dart",
    "lib/presentation/screens/gameplay/gameplay_walkthrough_layer.dart",
    "lib/presentation/screens/onboarding/onboarding_screen.dart",
    "lib/presentation/screens/splash/splash_screen.dart",
    "lib/presentation/screens/chapter_select/chapter_select_screen.dart",
]

IMPORT = "import 'package:mirror_logic/domain/theme/theme_controller.dart';\n"


def ensure_import(text: str) -> str:
    if "domain/theme/theme_controller.dart" in text:
        return text
    lines = text.splitlines(keepends=True)
    last_import = 0
    for i, line in enumerate(lines):
        if line.startswith("import "):
            last_import = i
    lines.insert(last_import + 1, IMPORT)
    return "".join(lines)


def inject_watches(text: str) -> tuple[str, int]:
    lines = text.splitlines(keepends=True)
    out: list[str] = []
    added = 0
    i = 0
    while i < len(lines):
        line = lines[i]
        out.append(line)
        if re.search(r"Widget build\(BuildContext context\) \{", line):
            nxt = lines[i + 1] if i + 1 < len(lines) else ""
            if "ThemeController.watch(context)" not in nxt:
                indent_match = re.match(r"^(\s*)", nxt)
                indent = indent_match.group(1) if indent_match and indent_match.group(1) else "    "
                # If next line is only closing brace, still inject
                if nxt.strip() == "}":
                    indent = re.match(r"^(\s*)", line).group(1) + "  "
                out.append(f"{indent}ThemeController.watch(context);\n")
                added += 1
        i += 1
    return "".join(out), added


def main() -> None:
    for rel in FILES:
        path = ROOT / rel
        original = path.read_text(encoding="utf-8")
        text = ensure_import(original)
        text, added = inject_watches(text)
        if text != original:
            path.write_text(text, encoding="utf-8")
            print(f"updated {rel} (+{added})")
        else:
            print(f"unchanged {rel}")


if __name__ == "__main__":
    main()
