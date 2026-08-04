import 'package:flutter/widgets.dart';
import 'package:mirror_logic/domain/theme/theme_catalog.dart';
import 'package:mirror_logic/domain/theme/visual_theme.dart';

/// Global active visual pack. [MedievalColors] reads [current]; UI under
/// [ThemeScope] rebuilds when [notifier] changes (see app [ThemeScope] host).
abstract final class ThemeController {
  static final ValueNotifier<VisualTheme> notifier = ValueNotifier(
    ThemeCatalog.goldenSun,
  );

  static VisualTheme get current => notifier.value;

  static void apply(VisualTheme theme) {
    final next = ThemeCatalog.byId(theme.id);
    if (identical(notifier.value, next)) return;
    notifier.value = next;
  }

  static void applyById(String id) => apply(ThemeCatalog.byId(id));

  /// Depend on the equipped hall so this element rebuilds on equip.
  static String watch(BuildContext context) {
    context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    return current.id;
  }
}

/// Pushes [ThemeController.notifier] into the tree. Keep this under
/// [AudioScope] and above the navigator so hall swaps never tear down audio.
class ThemeScope extends InheritedNotifier<ValueNotifier<VisualTheme>> {
  ThemeScope({super.key, required super.child})
    : super(notifier: ThemeController.notifier);
}
